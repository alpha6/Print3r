#!/usr/bin/env perl
# For Linux
use strict;
use v5.20;
use warnings;
use Time::HiRes qw/sleep/;
use Device::SerialPort;
use IO::Socket::INET;

use Data::Dumper;

my $file = shift;

# auto-flush on socket
$| = 1;

# create a connecting socket
my $socket = new IO::Socket::INET(
    PeerHost => '127.0.0.1',
    PeerPort => '44244',
    Proto    => 'tcp',
);
die "cannot connect to the server $!\n" unless $socket;
print "connected to the server\n";

# data to send to a server
my $req  = 'hello world';
my $size = $socket->send($req);
print "sent data of length $size\n";

# notify server that request has been sent
shutdown( $socket, 1 );

# receive a response of up to 1024 characters from server
my $response = "";
$socket->recv( $response, 1024 );
print "received response: $response\n";

$socket->close();

say "Connecting..";
my $port = Device::SerialPort->new("/dev/ttyUSB0");

$port->handshake("none");
$port->baudrate(115200);    # Configure this to match your device
$port->databits(8);
$port->parity("none");
$port->stopbits(1);
$port->stty_echo(0);
$port->debug(1);
$port->error_msg('ON');

my $ready_flag = 0;

open( my $fh, "<", $file ) || die "Cann't open $!";

sub get_line {
    my $line = <$fh>;

    unless ( defined($line) ) {
        return undef;
    }

    chomp($line);
    if ( length($line) == 0 ) {
        $line = "";
    }
    if ( index( $line, ';' ) == 0 ) {
        $line = "";
    }

    # printf("line [%s]\n", $line);
    return $line;
}

$port->write("M105\n")
  ; #Empty command for start communication with printer. That prevent need to restart printer before communication

while (1) {
    if ( $ready_flag == 1 ) {

        my $next_command = get_line();
        unless ( defined($next_command) ) {
            last;
        }
        if ( $next_command eq "" ) {
            next;
        }

        print "> $next_command\n";
        $port->write("$next_command\n");
        $ready_flag = 0;
    }

    # Poll to see if any data is coming in
    if ( my $char = $port->lookfor() ) {
        $char =~ s/\r//;
        print "< $char\n";
        if ( $char =~ m/^(ok|start)$/ ) {
            $ready_flag = 1;
        }
        else {
            $ready_flag = 0;

            # print "unknown: $char\n";
        }
    }
}

$port->close || warn "close failed";
close($fh);
