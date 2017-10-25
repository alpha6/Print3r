use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Commands;

use Data::Dumper;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Commands->new, 'Print3r::Commands');
};

my $cmd = Print3r::Commands->new;

subtest 'check_version' => sub {
    is($cmd->VERSION, 'v0.0.2', 'check that the test is for suitable module version');
};

done_testing;