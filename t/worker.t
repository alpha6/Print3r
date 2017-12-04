use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker;

use Data::Dumper;

$ENV{'TESTING'} = 1;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Worker->connect('Print3r::Worker', '/dev/ttyUSB0', 115200, sub { say Dumper \@_}), 'Print3r::Worker');
};

my $cmd = Print3r::Worker->connect('/dev/ttyUSB0', 115200, sub { say Dumper \@_});

subtest 'check_version' => sub {
    is($cmd->VERSION, 'v0.0.4', 'check that the test is for suitable module version');
};

done_testing;
