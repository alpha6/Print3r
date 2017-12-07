package Print3r::Worker::Port::Serial;

use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.1');

use Carp;
use Device::SerialPort;

sub connect ( $device_port, $port_speed ) {
    my $class = shift;

    my $port = Device::SerialPort->new($device_port)
      or croak "Can't connect to [$device_port] at speed [$port_speed]";

    $port->handshake('none');
    $port->baudrate($port_speed);    # Configure this to match your device
    $port->databits(8);
    $port->parity('none');
    $port->stopbits(1);
    $port->stty_echo(0);
    $port->debug(1);
    $port->error_msg('ON');

    my $self = { port => $port };
    $self->{self_closure} = $self;

    bless $self, $class;

    return *$port->{'HANDLE'};
}

sub DESTORY {
    my $self = shift;
    delete $self->{'self_closure'};
}

1;
