package Print3r::Worker::Port::TestSocketINET;
use base IO::Socket::INET;

use Data::Dumper;
use feature qw(say);

sub write {    #just make an interface comapatible with Device::SerialPort
    my $self = shift;
    $self->SUPER::send(@_);
}

1;
