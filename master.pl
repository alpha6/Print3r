#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IPC::Open3;

my $cv = AE::cv;

my $host = '127.0.0.1';
my $port = 44244;

my $alive_timer = AnyEvent->timer(
    after    => 60,
    interval => 60,
    cb       => sub {
        say "Server alive";
    }
);

my %connections;
tcp_server(
    $host, $port,
    sub {
        my ($fh) = @_;

        print "Connected...\n";

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;
                print "Received: " . $self->rbuf . "\n";
            },
            on_eof => sub {
                my ($hdl) = @_;
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to clien.";
                $hdl->destroy();
            },
        );
        $connections{$handle} = $handle;    # keep it alive.

        return;
    }
);

print "Listening on $host\n";

$cv->recv;
