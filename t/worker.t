use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker;

use Data::Dumper;

$ENV{'TESTING'} = 1;

my $worker = Print3r::Worker->connect('/dev/ttyUSB0', 115200, sub { say Dumper \@_});

subtest 'creates correct object' => sub {
    isa_ok($worker, 'Print3r::Worker');
};

subtest 'check_version' => sub {
    is($worker->VERSION, 'v0.0.4', 'check that the test is for suitable module version');
};

done_testing;
