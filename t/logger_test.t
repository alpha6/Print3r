use lib 'lib';
use strict;
use warnings;

use Test::More;
use Test::Fatal;

subtest 'creates correct object' => sub {
    isa_ok(LoggerTest->new, 'LoggerTest');
};

subtest 'has default log level' => sub {
    my $logger = LoggerTest->new;

    is $logger->level, 'error';
};

subtest 'sets log level' => sub {
    my $logger = LoggerTest->new;

    $logger->set_level('debug');

    is $logger->level, 'debug';
};

subtest 'not throws when known log level' => sub {
    my $log = LoggerTest->new;

    for my $level (qw/error warn debug/) {
        ok !exception { $log->set_level($level) };
    }
};

subtest 'throws exception when invalid log level' => sub {
    my $log = LoggerTest->new;

    ok exception { $log->set_level('unknown') };
};

subtest 'prints formatted line' => sub {
    my $output = [];
    my $log = _build_logger(output => $output);

    for my $level (qw/error warn debug/) {
        $log->$level('message');

        like $output->[-1],
          qr/\d\d\d\d-\d\d-\d\d \d\d:\d\d:\d\d \[$level\] message/;
    }
};

subtest 'logs when level is higher' => sub {
    my $output = [];
    my $log = _build_logger(output => $output);

    my $levels = {
        error => [qw/error/],
        warn  => [qw/error warn/],
        debug => [qw/error warn debug/],
    };

    for my $level (keys %$levels) {
        $log->set_level($level);
        for my $test_level (@{$levels->{$level}}) {
            $log->$test_level('message');

            ok $output->[-1];
        }
    }
};

subtest 'not logs when level is lower' => sub {
    my $output = [];
    my $log = _build_logger(output => $output);

    my $levels = {
        error => [qw/warn debug/],
        warn  => [qw/debug/],
    };

    for my $level (keys %$levels) {
        $log->set_level($level);
        for my $test_level (@{$levels->{$level}}) {
            $log->$test_level('message');

            ok !$output->[-1], "not log '$test_level' when '$level'";
        }
    }
};

sub _build_logger {
    my $logger = LoggerTest->new(@_);
    $logger->set_level('debug');
    return $logger;
}

done_testing;

package LoggerTest;
use base 'Print3r::Logger::LoggerBase';

sub new {
    my $self = shift->SUPER::new(@_);
    my (%params) = @_;

    $self->{output} = $params{output};

    return $self;
}

sub _print {
    my $self = shift;

    push @{$self->{output}}, @_;
}
