use lib 'lib';
use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Capture::Tiny qw(capture_stderr);
use Print3r::Logger::LoggerSTDERR;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Logger::LoggerSTDERR->new, 'Print3r::Logger::LoggerSTDERR');
};

subtest 'prints to stderr' => sub {
    my $log = _build_logger();

    for my $level (qw/error warn debug/) {
        my $stderr = capture_stderr {
            $log->$level('message');
        };

        ok $stderr;
    }
};

subtest 'prints to stderr with \n' => sub {
    my $log = _build_logger();

    for my $level (qw/error warn debug/) {
        my $stderr = capture_stderr {
            $log->$level('message');
        };

        like $stderr, qr/\n$/;
    }
};

sub _build_logger {
    my $logger = Print3r::Logger::LoggerSTDERR->new;
    $logger->set_level('debug');
    return $logger;
}

done_testing;