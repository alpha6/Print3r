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


sub process_command {
    my $handle = shift;
    my $data = shift;

    if ($data->{'command'} eq 'status') {
        say sprintf("Printer temp: %.1f@%.1f", $data->{'E0'}, $data->{'B'});
    } elsif ($data->{'command'} eq 'connect') {
        say $data->{'message'};
        $handle->push_write(json => {command => 'print_file', params => {filename => 'test.gcode'}});
    }
    else {
        say Dumper($data);
    }

}


my $workers_timer = AnyEvent->timer(
    after    => 30,
    interval => 30,
    cb       => sub {
        say "Sending commands";
        for my $key (keys(%connections)) {
            
            my $handler = $connections{$key};
            $handler->push_write(json => {command => "status"});
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
                
                $self->push_read(json => sub {
                    my ($handle, $data) = @_;
                    process_command($handle, $data);
                });    
                            
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

        $handle->push_write(json => {command => "connect", params => {port => "/dev/ttyUSB0", speed => 115200 }});
        return;
    }
);

print "Listening on $host\n";

$cv->recv;
