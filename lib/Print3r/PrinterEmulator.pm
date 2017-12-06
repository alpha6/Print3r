package Print3r::PrinterEmulator;

use strict;
use warnings;

use feature qw(say signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.3');

use Carp;
use AnyEvent::Handle;
use AnyEvent::Socket;

use Data::Dumper;

use Print3r::Logger;
use Print3r::Worker::Port::TestSocketINET;
use Print3r::Worker::Commands::GCODEParser;
my $parser = Print3r::Worker::Commands::GCODEParser->new;

my $log = Print3r::Logger->get_logger( 'file', file => 'emulator.log', synced => 1, level => 'debug' );

my $temp_change_step = 1;
my $temp_timer;

sub _new {
    bless {}, shift;
}

sub connect($class) {
    my $self = {
        hotend_temp => 22,
        bed_temp    => 22,
    };

    my $hdl;

    $log->debug('Creating listener...');
    my $listen_handle = AnyEvent::Socket::tcp_server(
        undef, 34832,
        sub {
            my ( $clsock, $host, $port ) = @_;

            $hdl = AnyEvent::Handle->new(
                fh      => $clsock,
                on_read => sub {
                    $hdl->push_read(
                        line => sub {
                            my ( undef, $line ) = @_;
                            chomp $line;
                            $log->debug(sprintf('Got line: %s', $line));
                            $self->process_line( $hdl, $line );
                        }
                    );
                },
                on_eof => sub {
                    $log->info("client connection $host:$port: eof");
                    $log->info("Shutting down emulator");

                    $hdl->fh->close;
                    undef $hdl;
                    exit(0);
                },
                on_error => sub {
                    $log->error("Client connection error: $host:$port: $!");
                },
            );

            # $hdl->push_write('start');

        }
    );

    $self->{'server'} = $listen_handle;

    bless $self, $class;

    return $self;
}

sub process_line ( $self, $handle, $line ) {
    $log->debug("Processing line: " . $line);

    my $code_data = $parser->parse_code($line);
    if ( $code_data->{'type'} eq 'common' ) {
        $handle->push_write( sprintf "ok %s\015\012", $code_data->{'code'} );
    }
    elsif ( $code_data->{'type'} eq 'info_req' ) {
        if ( $code_data->{'code'} eq 'M105' ) {    #Return current temp
            $self->_send_reply(
                $handle,
                sprintf "ok T:%s.0 /0.0 \@0 B:%s.0 /0.0 \@0\015\012",
                $self->{'hotend_temp'},
                $self->{'bed_temp'}
            );
        }
    }
    elsif ( $code_data->{'type'} eq 'temperature' ) {

        #Process temperature changes
        if ( $code_data->{'async'} == 0 ) {

            my $heater_name = $code_data->{'heater'} . '_temp';
            $temp_timer = AnyEvent->timer(
                after    => 0.5,
                interval => 0.5,
                cb       => sub {
                    if ( $code_data->{'target_temp'} > $self->{$heater_name} )
                    {
                        $self->{$heater_name} += $temp_change_step;
                        if ( $code_data->{'target_temp'}
                            < $self->{$heater_name} )
                        {
                            $self->{$heater_name}
                                = $code_data->{'target_temp'};
                        }
                    }
                    elsif (
                        $code_data->{'target_temp'} < $self->{$heater_name} )
                    {
                        $self->{$heater_name} -= $temp_change_step;
                        if ( $code_data->{'target_temp'}
                            > $self->{$heater_name} )
                        {
                            $self->{$heater_name}
                                = $code_data->{'target_temp'};
                        }
                    }
                    else {
                        #Temperature reached. Send message and remove timer
                        $handle->push_write(
                            sprintf
                                "ok T:%s.0 /0.0 \@0 B:%s.0 /0.0 \@0\015\012",
                            $self->{'hotend_temp'}, $self->{'bed_temp'}
                        );
                        undef $temp_timer;
                        return;
                    }

                    $self->_send_reply(
                        $handle,
                        sprintf "T:%s.0 /0.0 \@0 B:%s.0 /0.0 \@0\015\012",
                        $self->{'hotend_temp'},
                        $self->{'bed_temp'},
                        int rand(255),
                    );
                }
            );
        }
        else {
            $self->{ $code_data->{'heater'} . '_temp' }
                = $code_data->{'target_temp'};
            $self->_send_reply(
                $handle,
                sprintf(
                    "ok T:%s.0 /0.0 \@0 B:%s.0 /0.0 \@0\015\012",
                    $self->{'hotend_temp'},
                    $self->{'bed_temp'}
                )
            );
        }
    }
}

#make small delay before reply
sub _send_reply ( $self, $handle, $reply ) {
    my $timer;
    $timer = AnyEvent->timer(
        after => 0.2,
        cb    => sub {
            $handle->push_write($reply);
            undef $timer;
        }
    );
}

sub DESTORY {
    my $self = shift;
    delete $self->{'self_closure'};
    undef $self;
}

1;
