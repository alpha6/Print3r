package Print3r::Worker::Port::TestPort;

use strict;
use warnings;

use feature qw(say signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.3');

use Carp;
use IPC::Open2;
use Cwd 'abs_path';

use Print3r::Worker::Port::TestSocketINET;

use Data::Dumper;

sub _new {
    bless {}, shift;
}

sub connect($class) {

    my $abs_path = abs_path('printer_emulator.pl');

    my ( $chld_out, $chld_in );
    my $pid = open2( $chld_out, $chld_in, $abs_path );

    sleep 1;

    my $self = {
        in  => $chld_in,
        out => $chld_out,
        pid => $pid,
    };

    # say Dumper($self);

    my $client = Print3r::Worker::Port::TestSocketINET->new(
        PeerAddr => 'localhost',
        PeerPort => 34832,
        Proto    => 'tcp',
        Timeout  => 5,
    ) || croak $!;

    bless $self, $class;
    $self->{'self'} = $self;

    return $client;
}

1;
