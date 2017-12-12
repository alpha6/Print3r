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
use Tie::File;

use Try::Tiny;
use Carp;

use Getopt::Long;

use Print3r::Commands;
use Print3r::Worker;
use Print3r::Logger;
use Print3r::Worker::ReadFile;

use Data::Dumper;

my $cv = AE::cv;

my $log = Print3r::Logger->get_logger(
    'file',
    file   => 'worker.log',
    synced => 1,
    level  => 'debug'
);

my $plog = undef;    # printing logger

my $handle;
my $printer_handle = undef;
my $printing_file  = undef;
my $port_handle    = undef;
my $reader         = undef;
my %timers;

my $print_file_path = undef;

my $in_command_flag  = 0;
my $is_printer_ready = 1;
my $is_print_paused  = 0;

my $line_number = 0;    #current printing line

my $printer_port = '/dev/ttyUSB0';
my $port_speed   = 115200;

GetOptions(
    'p=s' => \$printer_port,
    's=i' => \$port_speed
);

my $worker;

sub get_printing_logger {
    my $filename = fileparse( $print_file_path, qr/\.[^.]*/ );

    my $date = Time::Moment->now->strftime('%F_%H.%M');

    my $log_file = sprintf( '%s_%s.log', $filename, $date );
    my $logger = Print3r::Logger->get_logger(
        'file',
        file   => $log_file,
        synced => 1,
        level  => 'info'
    );
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
    state $prev_command_accepted = 1;

    # Check that the printer is ready for new commands and set flag
    if ( exists( $command->{'printer_ready'} ) ) {
        $is_printer_ready = $command->{'printer_ready'};
    }

# The temperature is processing separately because it should be shown while printing.
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

            $line_number = 0;
            $plog        = get_printing_logger();

            #Rewind to line when recovering print
            if ( $command->{'start_line'} > 0 ) {
                $reader->rewind( $command->{'start_line'} );
            }

            if ( !$reader->has_next ) {
                croak "No lines to print is available!";
            }

            my $gcode_line;

            if ( $prev_command_accepted > 0 ) {
                while ( $gcode_line = $reader->next() ) {
                    last if ( $gcode_line =~ m/^[G|M|T].*/ );
                }

            }
            else {
                $gcode_line = $reader->current_line();
            }
            $plog->info( 'sent: ' . $gcode_line );
            $prev_command_accepted = $worker->write($gcode_line);

        }
        catch {
            $handle->push_write( json =>
                  { command => 'error', message => "Printing error: $_" } );
        };

    }
    elsif ( !$is_print_paused && $command->{'printer_ready'} ) {
        if ( defined($printing_file) && $is_printer_ready ) {

            try {

                my $gcode_line;

                if ( $prev_command_accepted > 0 ) {
                    if ( $reader->has_next ) {
                        while ( $gcode_line = $reader->next() ) {
                            last if ( $gcode_line =~ m/^[G|M|T].*/ );
                        }
                    }
                    else {
                        $handle->push_write(
                            json => {
                                command => 'message',
                                line =>
                                  sprintf(
                                    'Printing has ended. Printed [%d] lines.',
                                    $reader->current ),
                            }
                        );
                        undef $printing_file;
                        return;
                    }

                }
                else {
                    $gcode_line = $reader->current_line();
                }
                $plog->info( 'sent: ' . $gcode_line );
                $prev_command_accepted = $worker->write($gcode_line);

            }
            catch {
                $plog->error( sprintf( 'Printing error: %s', $_ ) );
                $is_print_paused = 1;
                $handle->push_write(
                    json => {
                        command => 'error',
                        message => sprintf(
                            'Printing error: %s in line %s',
                            $_, $reader->current)
                        }
                        );
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
            $worker->write('M105');
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
            #$plog->info('other: '.$command->{'line'}) if (defined $plog);
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
            $worker = Print3r::Worker->connect( $printer_port, $port_speed,
                \&process_command );
            $worker->init_printer();
        }
        catch {
            say STDERR "Error: $_";
            $handle->push_write(
                json => {
                    command => 'connect',
                    status  => 'error',
                    message => sprintf(
                        'Connection to port [%s] failed. Reason [%s]',
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
        $worker->write('M105');

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
                $reader = Print3r::Worker::ReadFile->new($printing_file);

                $print_file_path = $params->{'file'};

                process_command( { type => 'start_printing' } );
            },
            send => sub {
                my $self   = shift;
                my $params = shift;
                $log->info( sprintf( 'External G-Code: %s', Dumper($params) ) );
                $worker->write( $params->{'value'} );
            },
            disconnect => sub {
                $log->info('Disconnecting...');
                shutdown_worker(0);
            },
            pause => sub {
                process_command( { type => 'pause' } );
            },
            resume => sub {
                process_command( { type => 'resume' } );
            },
            recover => sub {    #Recover printing if worker(or printer) died
                my $self   = shift;
                my $params = shift;
                $log->info(
                    sprintf( 'Recovering print. File: %s', $params->{'file'} )
                );

                my $start_line = 0;
                try {
                    open( my $rec_fh, '<',
                        sprintf( '%s.RECOVER', $params->{'file'} ) );

                    $start_line = <$rec_fh>;
                    chomp $start_line;
                    close $rec_fh;

                    unlink sprintf( '%s.RECOVER', $params->{'file'} );

                }
                catch {
                    $log->error(
                        sprintf( 'can not open RECOVER file for file: %s',
                            $params->{'file'} )
                    );
                    $log->error( sprintf('Recovering aborted') );
                    return;
                };

                open( $printing_file, '<', $params->{'file'} ) or die $!;

                $print_file_path = $params->{'file'};

                process_command(
                    { type => 'start_printing', start_line => $start_line } );
            },
            stop => sub {
                $log->info('Stopping print...');
                process_command( { type => 'stop' } );
            },
            status => sub {
                $worker->write('M105');

            }
        }
    );

    #Getting temperature from the printer
    my $test_timer = AnyEvent->timer(
        after    => 20,
        interval => 20,
        cb       => sub {

            # say sprintf("Alive %s", time());
            if ( defined $worker ) {
                $worker->write('M105');
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
        try {
            if ( defined $worker ) {
                $worker->close();
            }
        }
        catch {
            $log->error('Port handle already destroyed!');
        };

        try {
            if ( defined $print_file_path ) {
                open( my $fh, '>', sprintf( '%s.RECOVER', $print_file_path ) )
                  or die $!;
                print $fh $line_number;
                close $fh;
            }

        };

        $handle->destroy();
        exit $status;
    }
