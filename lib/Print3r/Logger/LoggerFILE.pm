package Print3r::Logger::LoggerFILE;

use strict;
use warnings;

use base 'Print3r::Logger::LoggerBase';

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{file} = $params{file};

    return $self;
}

sub _print {
    my $self = shift;
    my ($message) = @_;

    open my $fh, '>>', $self->{file} or die $!;
    print $fh $message;
    close $fh;
}

1;