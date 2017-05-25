#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use Data::Dumper;
 
my $cv = AE::cv;



my $handle;
my %timers;

my $test_timer = AnyEvent->timer(
    after    => 5,
    interval => 5,
    cb       => sub {
            say sprintf("Alive %s", time());
        }
    );


sub set_heartbeat {
	
	my $heartbeat_timer = AnyEvent->timer(
    after    => 10,
    interval => 10,
    cb       => sub {
            $handle->push_write(json => { command => "HEARTBEAT"});
        }
    );
    $timers{'heartbeat_timer'} = $heartbeat_timer;
}


tcp_connect ("127.0.0.1", 44244,
   sub {
      my ($fh) = @_
         or die "unable to connect: $!";

	  
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;                
                $handle->push_read( json => sub {
                    my ($handle, $data) = @_;
                    say Dumper($data);
                });
            },
            on_eof => sub {
                my ($hdl) = @_;
                print "Connecton to server was closed.";
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to server.";
                $hdl->destroy();
            },
        );

      $handle->push_write (json => { command => "HELLO"});
      set_heartbeat();
});

$cv->recv;