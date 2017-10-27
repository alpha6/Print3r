package Print3r::Logger::LoggerBase;

use strict;
use warnings;

use Carp qw(croak);
use List::Util qw(first);
use Time::Moment;

my $LEVELS = {
    error => 1,
    warn  => 2,
    info  => 3,
    debug => 4,
    trace => 5
};

sub new {
    my $class = shift;
    my (%params) = @_;

    my $self = {};
    bless $self, $class;

    $self->{file} = $params{file};

    return $self;
}

sub set_level {
    my $self = shift;
    my ($new_level) = @_;

    croak('Unknown log level')
      unless first { $new_level eq $_ } keys %$LEVELS;

    $self->{'level'} = $new_level;

    return $self->{'level'};
}

sub level {
    my $self = shift;

    return $self->{level} || 'error';
}

sub info  { return shift->_log( 'info',  @_ ) }
sub error { return shift->_log( 'error', @_ ) }
sub warn  { return shift->_log( 'warn',  @_ ) }
sub debug { return shift->_log( 'debug', @_ ) }
sub trace { return shift->_log( 'trace', @_ ) }

sub _log {
    my $self = shift;
    my ( $level, $message ) = @_;

    return if $LEVELS->{$level} > $LEVELS->{ $self->{'level'} };

    my $time = Time::Moment->now->strftime('%Y-%m-%d %T%3f');

    for (split /\n/, $message) {
        my $text = sprintf("%s [%s] %s\n", $time, $level, $_);

        $self->_print($text);
    }

    return;
}

sub _print { croak 'Not implemented!' }

1;
