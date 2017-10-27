#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use lib 'lib';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use File::Basename;
use Time::Moment;

use Try::Tiny;

use Getopt::Long;

use Print3r::Commands;
use Print3r::Worker;
use Print3r::Logger;

use Data::Dumper;

my $cv = AE::cv;

my $log = Print3r::Logger->get_logger( 'file', file => 'worker.log' );
my $plog = undef;    # printing logger

my $handle;
my $printer_handle = undef;
my $printing_file  = undef;
my $port_handle    = undef;
my %timers;

my $print_file_path = undef;

my $in_command_flag  = 0;
my $is_printer_ready = 1;
my $is_print_paused  = 0;

my $printer_port = '/dev/ttyUSB0';
my $port_speed   = 115200;

GetOptions(
    'p=s' => \$printer_port,
    's=i' => \$port_speed
);

my $worker = Print3r::Worker->new();

sub get_line {
    state $line_number = 0;
    while ( my $line = <$printing_file> ) {
        if ( $line =~ m/^[G|M|T].*/ ) {
            chomp $line;
            $plog->debug( sprintf( "line [%s]\n", $line ) );
            $line_number++;
            return $line;
        }
    }

    return $line_number;
}

sub get_printing_logger {
    my $filename = fileparse( $print_file_path, qr/\.[^.]*/ );

    my $tm   = Time::Moment->now;
    my $date = $tm->strftime('%F_%H.%M');

    my $log_file = sprintf( '%s_%s.log', $filename, $date );
    my $logger = Print3r::Logger->get_logger( 'file', file => $log_file, synced => 1 );
    $logger->set_level('debug');

    return $logger;
}

sub set_heartbeat {

    my $heartbeat_timer = AnyEvent->timer(
        after    => 10,
        interval => 10,
        cb       => sub {
            $handle->push_write( json => { command => 'HEARTBEAT' } );
        }
    );
    $timers{'heartbeat_timer'} = $heartbeat_timer;

    return;
}

sub process_command {
    my $command = shift;

    # Check that the printer is ready for new commands and set flag
    if ( exists( $command->{'printer_ready'} ) ) {
        $is_printer_ready = $command->{'printer_ready'};
    }

# The temperature is processed separately because it should be shown while printing.
    if ( $command->{'type'} eq 'temperature' ) {
        $handle->push_write(
            json => {
                command => 'status',
                E0      => $command->{'E0'},
                B       => $command->{'B'},
                line    => $command->{'line'},
            }
        );
    }

    if ( $command->{'type'} eq 'start_printing' ) {
        try {
            $plog = get_printing_logger();
            if ( my $next_command = get_line() ) {
                $port_handle->write("$next_command\n");
                $plog->info($next_command);
            }
            else {
                $handle->push_write(
                    json => {
                        command => 'error',
                        message => 'No file to print is available'
                    }
                );
            }

        }
        catch {
            $handle->push_write( json =>
                  { command => 'error', message => "Printing error: $_" } );
        };

    }
    elsif ( !$is_print_paused && $command->{'printer_ready'} ) {
        if ( defined($printing_file) && $is_printer_ready ) {
            my $next_command = get_line();
            $plog->info($next_command);

            try {
                #The function get_line return number only if print ended
                if ( $next_command !~ /^\d+$/ ) {
                    $port_handle->write("$next_command\n");
                }
                else {
                    $handle->push_write(
                        json => {
                            command => 'message',
                            line =>
                              sprintf(
                                'Printing has ended. Printed [%d] lines.',
                                $next_command ),
                        }
                    );
                    undef $printing_file;
                }
            }
            catch {
                $plog->error( sprintf( 'Printing error: %s', $_ ) );
                $is_print_paused = 1;
                $handle->push_write( json =>
                      { command => 'error', message => "Printing error: $_" } );
            };

        }
    }
    elsif ( $command->{'type'} eq 'error' ) {

        # If got error: pause print and send error message to master.
        $is_print_paused = 1;

        $handle->push_write(
            json => {
                command => 'error',
                line =>
                  sprintf( 'Print emergency stopped!. Printer message: %d',
                    $command->{'line'} ),
            }
        );
    }
    elsif ( $command->{'type'} eq 'pause' ) {
        $is_print_paused = 1;

        $log->info('Printing has paused.');
        $plog->warn('Printing has paused.');
        $handle->push_write(
            json => {
                command => 'message',
                line    => sprintf('Printing has paused!'),
            }
        );
    }
    elsif ( $command->{'type'} eq 'resume' ) {
        $is_print_paused = 0;

        $log->info('Printing has resumed.');
        $plog->warn('Printing has resumed.');
        $handle->push_write(
            json => {
                command => 'message',
                line    => sprintf('Printing has resumed!'),
            }
        );

        # Send command to resume printing
        $port_handle->write("M105\n");
    }
    elsif ( $command->{'type'} eq 'stop' ) {
        $log->info('Print stopped.');
        $plog->warn('Print stopped.');

        $is_printer_ready = 0;
        undef($printing_file);

        $handle->push_write(
            json => {
                command => 'message',
                line    => sprintf('Printing has stopped!'),
            }
        );
    }
    else {
        $handle->push_write(
            json => {
                command => 'other',
                line    => $command->{'line'},
            }
        );
    }

    return;
}

sub connect_to_printer {
    try {
        $port_handle =
          $worker->connect_to_printer( $printer_port, $port_speed );
    }
    catch {
        $handle->push_write(
            json => {
                command => 'connect',
                status  => 'error',
                message => sprintf(
                    'Connecion to port [%s] failed. Reason [%s]',
                    $printer_port, $_
                ),
                pid   => $$,
                port  => $printer_port,
                speed => $port_speed
            }
        );

        #TODO: make workers reusable
        shutdown_worker(1);
    };

    #Creating AE::Handle for the  port of the printer
    my $fh = $port_handle->{'HANDLE'};
    $printer_handle = AnyEvent::Handle->new(
        fh       => $fh,
        on_error => sub {
            my ( undef, $fatal, $message ) = @_;
            $printer_handle->destroy;
            undef $printer_handle;
            print STDERR "$fatal : $message\n";
            $handle->push_write(
                json => { command => 'error', message => $message } );

            shutdown_worker(1);
        },
        on_read => sub {
            my $p_hdl = shift;
            $p_hdl->push_read(
                line => sub {
                    my ( undef, $line ) = @_;
                    my $parsed_reply = $worker->parse_line($line);
                    process_command($parsed_reply);
                }
            );
        }
    );
    $handle->push_write(
        json => {
            command => 'connect',
            status  => 'ready',
            message => sprintf( 'Connected to [%s]', $printer_port ),
            pid     => $$,
            port    => $printer_port,
            speed   => $port_speed
        }
    );

    #Start communication with the printer
    $port_handle->write("M105\n");

    return;
}

my $commands = Print3r::Commands->new(
    {
        print => sub {
            my $self   = shift;
            my $params = shift;
            $log->info(
                sprintf( 'Starting print. File: %s', $params->{'file'} ) );
            open( $printing_file, '<', $params->{'file'} ) or die $!;

            $print_file_path = $params->{'file'};

            process_command( { type => 'start_printing' } );
        },
        send => sub {
            my $self   = shift;
            my $params = shift;
            $log->info( sprintf( 'External G-Code: %s', Dumper($params) ) );
            $port_handle->write( sprintf( "%s\n", $params->{'value'} ) );
        },
        disconnect => sub {
            $log->info('Disconnecting...');
            $port_handle->close();
            $handle->destroy();
            exit 0;
        },
        pause => sub {
            process_command( { type => 'pause' } );
        },
        resume => sub {
            process_command( { type => 'resume' } );
        },
        stop => sub {
            $log->info('Stopping print...');
            process_command( { type => 'stop' } );
        },
        status => sub {
            $port_handle->write("M105\n");

        }
    }
);

#Getting temperature from the printer
my $test_timer = AnyEvent->timer(
    after    => 20,
    interval => 20,
    cb       => sub {

        # say sprintf("Alive %s", time());
        if ( defined $port_handle ) {
            if ( !$in_command_flag ) {
                $port_handle->write("M105\n");
            }
        }
    }
);

# Connect to master
tcp_connect(
    '127.0.0.1',
    44244,
    sub {
        my ($fh) = @_
          or die "unable to connect: $!";

        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {    #Process master command
                $handle->push_read(
                    json => sub {
                        my ( undef, $data ) = @_;
                        my $name   = lc( $data->{'command'} );
                        my $params = $data->{'params'};
                        $commands->$name($params);
                    }
                );

            },
            on_eof => sub {
                my ($hdl) = @_;
                $log->error('Connecton to server was closed.');
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                $log->error('Lost connecton to server.');
                $hdl->destroy();
            },
        );

        # set_heartbeat();
        connect_to_printer();
    }
);

$cv->recv;

sub shutdown_worker {
    my $status = shift || 0;
    sleep(1);
    exit $status;
}
