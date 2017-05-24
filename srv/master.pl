#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IPC::Open3;
use JSON;

use Data::Dumper;

my $cv = AE::cv;

my $host = '127.0.0.1';
my $port = 44244;

my $printer_port = '/dev/ttyUSB0';
my $port_speed = 115200;

my %connections;


my $workers_timer = AnyEvent->timer(
    after    => 10,
    interval => 10,
    cb       => sub {
        say "Sending commands";
        for my $key (keys(%connections)) {
            
            my $handler = $connections{$key};
            $handler->push_write(sprintf("HELLO %s\n",time()));
        }
    }
);

tcp_server(
    $host, $port,
    sub {
        my ($fh, $clienthost, $clientport) = @_;

        print "Connected... [$clienthost][$clientport]\n";

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;
                my $data = $self->rbuf;
                chomp($data);
                say "Received: " . $data . "\n";
            },
            on_eof => sub {
                my ($hdl) = @_;
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to client.\n";
                $hdl->destroy();
            },
        );
        $connections{$handle} = $handle;    # keep it alive.

        $handle->push_write("OLOLO\n");
        return;
    }
);

print "Listening on $host\n";

$cv->recv;
