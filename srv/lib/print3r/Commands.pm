package print3r::worker;

use v5.20;
our $VERSION = version->declare("v0.0.1");

use JSON;
use IO::Socket::INET;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    $self->{'handler'} = undef;
    return $self;
}



1;
