package Print3r::Worker::Port::TestSocketINET;
use base IO::Socket::INET;

use Data::Dumper;
use feature qw(say);

sub write {

	say STDERR Dumper(\@_);
	my $self = shift;
	$self->SUPER::send(@_);
}

1;