package Print3r::Commands;

use v5.20;
use warnings;
our $VERSION = version->declare('v0.0.1');

use JSON;
use IO::Socket::INET;
use Data::Dumper;

our $AUTOLOAD;

sub new {
    my $class = shift;
    my $commands = shift;

    my $self = {
    	commands => $commands,
    };


    say Dumper($self);

    bless $self, $class;
    return $self;
}

sub AUTOLOAD {
	my ($self) = @_;
	my $name = $AUTOLOAD;

	return if $name =~ /^.*::[A-Z]+$/;
  	$name =~ s/^.*:://;   # strip fully-qualified portion

	return unless exists $self->{'commands'}{$name};
	my $sub = $self->{'commands'}{$name};

	no strict 'refs';
  	*{$AUTOLOAD} = $sub;
  	use strict 'refs';
  	goto &{$sub};
}


1;
