package Print3r::Worker::Port;

use v5.20;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature qw(signatures);
no warnings qw(experimental::signatures);
our $VERSION = version->declare('v0.0.1');

use Print3r::Worker::Port::Serial;

use Data::Dumper;

#A fabric class that returns a serial port handler that controls serial port in given environment.
sub new ( $class, $device_port, $port_speed ) {
    if ( $ENV{'TESTING'} ) {
        require Print3r::Worker::Port::TestPort;
        return Print3r::Worker::Port::TestPort->connect();
    }

    require Print3r::Worker::Port::Serial;
    return Print3r::Worker::Port::Serial->connect( $device_port, $port_speed );
}

1;
