#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IPC::Open2;
use JSON;
use Log::Log4perl;

use Data::Dumper;

my $cv = AE::cv;

my $host         = '127.0.0.1';
my $port         = 44244;         #Workers interface
my $control_port = 44243;         #Control interface

my $printer_port = '/dev/ttyUSB0';
my $port_speed   = 115200;

my %connections;
my %workers;
my $control_handle = undef;

my $is_cli_connected = 0;
my $is_user_command  = 0;

Log::Log4perl::init('log4perl.conf');
my $log = Log::Log4perl->get_logger('default');

$log->info('Started...');

my $workers_timer = AnyEvent->timer(
    after    => 30,
    interval => 30,
    cb       => sub {

        # say "Sending commands";
        for my $key ( keys(%connections) ) {

            my $handler = $connections{$key}{'handle'};
            $handler->push_write( json => { command => "status" } );
        }
    }
);

#Workers interface
tcp_server(
    $host, $port,
    sub {
        my ( $fh, $clienthost, $clientport ) = @_;

        $log->info("Connected... [$clienthost][$clientport]\n");

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;

                $self->push_read(
                    json => sub {
                        my ( $handle, $data ) = @_;
                        $log->debug( "Printer data " . Dumper($data) );
                        process_printer_command( $handle, $data );
                    }
                );

            },
            on_eof => sub {
                my ($hdl) = @_;
                say "Client disconnected";
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to client.\n";
                $hdl->destroy();
            },
        );
        $connections{$handle} = $handle;    # keep it alive.

        return;
    }
);

#CLI interface
tcp_server(
    $host,
    $control_port,
    sub {
        my ( $fh, $clienthost, $clientport ) = @_;

        if ( defined($control_handle) ) {
            $log->error("Only one controll process is allowed!");
            syswrite $fh, "Only one controll process is allowed!";
            return;
        }

        $log->info("CLI connected... [$clienthost][$clientport]\n");

        $control_handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;

                $self->push_read(
                    json => sub {
                        my ( $handle, $data ) = @_;
                        process_command( $control_handle, $data );
                    }
                );

            },
            on_eof => sub {
                my ($hdl) = @_;
                $log->error("CLI disconnected.\n");
                $hdl->destroy();
                $is_cli_connected = 0;
                undef($control_handle);
            },
            on_error => sub {
                my $hdl = shift;
                $log->error("Lost connecton to control interface.\n");
                $is_cli_connected = 0;
                $hdl->destroy();
                undef($control_handle);
            },
        );

        $is_cli_connected = 1;
        return;
    }
);

$log->info("Listening on $host:$port\n");

$cv->recv;

sub process_printer_command {
    my $handle = shift;
    my $data   = shift;
    $log->debug( "process_command: " . Dumper($data) );

    # If is set this flag - force send raw answer line to CLI
    if ($is_user_command) {
        $is_user_command = 0;
        $control_handle->push_write(
            json => {
                reply => $data->{'line'}
            }
        ) if ($is_cli_connected);
    }

    if ( $data->{'command'} eq 'connect' ) {   #Worker connection status message

        $log->info(
            sprintf(
                "Worker [%s] is connected to [%s] at speed [%s]",
                $data->{'pid'}, $data->{'port'}, $data->{'speed'}
            )
        );

        #Change handler key name to port name
        $connections{ $data->{'port'} } = {
            handle => $handle,
            pid    => $data->{'pid'},
            port   => $data->{'port'},
            speed  => $data->{'speed'}
        };
        delete( $connections{$handle} );

        #Set flag that worker connected
        $workers{ $data->{'pid'} }{'is_connected'} = 1;
        if ( defined $control_handle ) {
            $control_handle->push_write(
                json => {
                    reply => sprintf(
                        "Worker [%s] is connected to [%s] at speed [%s]",
                        $data->{'pid'}, $data->{'port'}, $data->{'speed'}
                    )
                }
            );
        }
    }
    elsif ( $data->{'command'} eq 'status' ) {
        $log->info(
            sprintf( "Printer temp: %.1f@%.1f", $data->{'E0'}, $data->{'B'} ) );
    }
    elsif ( $data->{'command'} eq 'message' ) {
        $log->info( sprintf( "Printer message: %s", $data->{'message'} ) );

        $control_handle->push_write(
            json => {
                reply => $data->{'line'}
            }
        ) if ($is_cli_connected);
    }
    else {
        $log->error( sprintf( "Printer message: %s", $data->{'line'} ) );
        $control_handle->push_write(
            json => {
                reply => $data->{'line'}
            }
        ) if ($is_cli_connected);
    }

}

sub process_command {
    my $handle = shift;
    my $data   = shift;
    $log->debug( "process_command: " . Dumper($data) );

    if ( $data->{'command'} eq 'connect' ) {

        #Spawn new worker
        my ( $chld_out, $chld_in );
        my $pid;
        eval {
            $pid = open2(
                $chld_out, $chld_in, './worker.pl',
                '-p=' . $data->{'port'},
                '-s=' . $data->{'speed'}
            );
        };
        if ($@) {
            $log->error("Error: $@");
        }

        $workers{$pid} = { chld_in => $chld_in, chld_out => $chld_out };
        if ($is_cli_connected) {
            $control_handle->push_write( json =>
                  { reply => sprintf( "Worker started with pid [%s]", $pid ) }
            );
        }
    }
    elsif ( $data->{'command'} eq 'status' ) {

        # Send workers list to CLI

        my $reply_str = "Active workers:\n";

        for my $key ( keys %connections ) {
            $reply_str .= sprintf(
                "worker [%d] connected to port [%s]\n",
                $connections{$key}{'pid'},
                $connections{$key}{'port'}
            );
        }

        $control_handle->push_write( json => { reply => $reply_str } );
    }
    elsif ( $data->{'command'} eq 'send' ) {

        # Send command to printer

        if ( scalar( keys(%connections) ) == 1 ) {
            my ($h_name) = keys %connections;
            my $handler = $connections{$h_name}{'handle'};

            $is_user_command = 1; #Set flag to return raw printer answer to user

            $log->debug( sprintf( "User command set [%d]", $is_user_command ) );

            $handler->push_write(
                json => {
                    command => 'send',
                    params  => { value => $data->{'value'} }
                }
            );
        }
        else {
            $control_handle->push_write(
                json => {
                    command => 'error',
                    message =>
                      'Invalid count of connections. Select printer first.'
                }
            );

            $log->error('Invalid count of connections. Select printer first.');
        }

    }
    elsif ( $data->{'command'} eq 'print' ) {

        # Print file

        my ($h_name) = keys %connections;
        my $handler = $connections{$h_name}{'handle'};
        $handler->push_write( json =>
              { command => 'print', params => { file => $data->{'file'} } } );
    }
    elsif ( $data->{'command'} eq 'disconnect' ) {

        # Drop print and stop worker
        my ($h_name) = keys %connections;
        my $handler = $connections{$h_name}{'handle'};

        $handler->push_write(
            json => { command => 'disconnect', params => {} } );
        delete( $connections{$h_name} );
    }
    elsif ( $data->{'command'} eq 'stop' ) {

        # Stop print

        my ($h_name) = keys %connections;
        my $handler = $connections{$h_name}{'handle'};
        $handler->push_write( json => { command => 'stop', params => {} } );
    }
    else {
        #Call if command not set
        $log->error( "Unknown command:" . Dumper($data) );
        $control_handle->push_write(
            json => {
                reply => sprintf( "Unknown command [%s]", $data->{'command'} )
            }
        );
    }
}
