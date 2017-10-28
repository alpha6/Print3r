use lib 'lib';
use strict;
use warnings;

use Test::More;
use Test::Fatal;
use Print3r::Logger;

subtest 'creates stderr logger' => sub {
    my $logger = Print3r::Logger->get_logger('stderr');

    isa_ok $logger, 'Print3r::Logger::LoggerSTDERR';
};

subtest 'creates file logger' => sub {
    my $logger = Print3r::Logger->get_logger('file');

    isa_ok $logger, 'Print3r::Logger::LoggerFILE';
};

subtest 'throws when unknown logger' => sub {
    # ok exception { Logger->build('unknown') };
    my $logger = Print3r::Logger->get_logger('unknown');
    isa_ok $logger, 'Print3r::Logger::LoggerSTDERR';
};

done_testing;