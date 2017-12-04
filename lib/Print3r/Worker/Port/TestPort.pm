package Print3r::Worker::Port::TestPort;

use strict;
use warnings;

use feature qw(say signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.1');

use Carp;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IO::Socket::INET;

sub _new {
    bless {}, shift;
}

sub connect($class) {
    my $self = {};

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
                            $hdl->push_write(
                                sprintf( "ok %s\015\012", $line ) );

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

sub DESTORY {
    my $self = shift;
    delete $self->{'self_closure'};
    undef $self;
}

1;
