package Print3r::Worker::ReadFile;

use strict;
use warnings;
use Carp;

use Tie::File;

our $VERSION = version->declare('v0.0.1');
use feature qw(signatures);
no warnings qw(experimental::signatures);

sub new($class, $filename) {
    my @content;
    tie (@content, 'Tie::File', $filename) or die $!;


    my $self = {
        content => \@content,
        current => 0,
        max_line => $#content,
    };

    bless $self, $class;
    return $self;
}

sub has_next($self) {
    return 1 if ($self->{'current'} < $self->{'max_line'}) ;

    return 0;
}

sub next($self) {
    return $self->{'content'}[$self->{'current'}++];
}

sub current_line($self) {
    return $self->{'content'}[$self->{'current'}];
}

sub current($self) {
    return $self->{'current'};
}

sub rewind($self, $line = 0) {
    $line = $self->{'max_line'} if ($line > $self->{'max_line'});
    $self->{'current'} = $line;
}

1;