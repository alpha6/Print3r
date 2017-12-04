package Print3r::Worker::Port::TestPort;

use strict;
use warnings;

use feature qw(say signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.2');

use Carp;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IO::Socket::INET;

use Data::Dumper;

use Print3r::Worker::Commands::GCODEParser;
my $parser = Print3r::Worker::Commands::GCODEParser->new;

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
                            $self->process_line( $hdl, $line );
                        }
                    );
                },
                on_eof => sub {
                    print STDERR "client connection $host:$port: eof\n";
                    $hdl->fh->close;
                    undef $hdl;
                    $self->DESTROY;
                },
                on_error => sub {
                    print STDERR "Client connection error: $host:$port: $!\n";
                },
            );

        }
    );

    my $client = IO::Socket::INET->new(
        PeerAddr => 'localhost',
        PeerPort => 34832,
        Proto    => 'tcp',
        Timeout  => 5,
    ) || croak $!;

    $self->{'server'} = $listen_handle;

    bless $self, $class;
    $self->{'self_closure'} = $self;

    return $client;
}

sub process_line ( $self, $handle, $line ) {
    my $code_data = $parser->parse_code($line);
    if ( $code_data->{'type'} eq 'common' ) {
        $handle->push_write( sprintf "ok %s\015\012", $code_data->{'code'} );
    }
    elsif ( $code_data->{'type'} eq 'info_req' ) {
        if ( $code_data->{'code'} eq 'M105' ) { #Return current temp
            $handle->push_write(
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

                    $handle->push_write(
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
            $handle->push_write(
                sprintf "ok T:%s.0 /0.0 \@0 B:%s.0 /0.0 \@0\015\012",
                $self->{'hotend_temp'},
                $self->{'bed_temp'}
            );
        }
    }
}

sub DESTORY {
    my $self = shift;
    delete $self->{'self_closure'};
    undef $self;
}

1;
