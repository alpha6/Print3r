package Print3r::Worker::Port::Serial;

use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.1');

use Carp;
use IO::Termios;

sub connect ( $class, $device_port, $port_speed ) {

    my $stty = IO::Termios->open($device_port);
    $stty->set_mode(sprintf('%s,8,n,1', $port_speed));
    $stty->setflag_echo( 0 );

    my $self = { port => $stty };
    $self->{self_closure} = $self;

    bless $self, $class;

    return $stty;
}

sub DESTORY {
    my $self = shift;
    delete $self->{'self_closure'};
}

1;
