package Print3r::Logger::LoggerBase;

use strict;
use warnings;

use Carp qw(croak);
use List::Util qw(first);
use Time::Piece;

my $LEVELS = {
    error => 1,
    warn  => 2,
    debug => 3
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

    $self->{level} = $new_level;
}

sub level {
    my $self = shift;

    return $self->{level} || 'error';
}

sub info { shift->_log('info', @_) }
sub error { shift->_log('error', @_) }
sub warn  { shift->_log('warn',  @_) }
sub debug { shift->_log('debug', @_) }

sub _log {
    my $self = shift;
    my ($level, $message) = @_;

    return unless $LEVELS->{$level} <= $LEVELS->{$self->level};

    my $time = Time::Piece->new->strftime('%Y-%m-%d %T');

    my $text = join '', $time, " [$level] ", $message, "\n";

    $self->_print($text);
}

sub _print { ... }

1;