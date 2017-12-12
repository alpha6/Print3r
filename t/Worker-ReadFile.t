use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;
use File::Temp qw/ tempfile tempdir /;

use Print3r::Worker::ReadFile;

use Data::Dumper;

my $fh = tempfile();
for (1..10) {
    print $fh "$_\n";
}

my $reader = Print3r::Worker::ReadFile->new($fh);

subtest 'creates correct object' => sub {
    isa_ok($reader, 'Print3r::Worker::ReadFile');
};


subtest 'check_version' => sub {
    is($reader->VERSION, 'v0.0.1', 'check that the test is for suitable module version');
};


subtest 'has_next' => sub {
    ok($reader->has_next, 'Has next elements');
};

subtest 'current_start' => sub {
    is($reader->current(), 0, 'Current is 0 at test file start');
};

subtest 'next' => sub {
    my $i = 0;
    while($reader->has_next()) {
        $i++;
        is($reader->next(), $i, 'Next element');
    }  
    is($i, 9, '9 lines');
};

subtest 'current_end' => sub {
    is($reader->current(), 9, 'Current is  at test file end');
};

subtest 'rewind' => sub {
    $reader->rewind;
    is($reader->current(), 0, 'Current is 0 after rewind');
};

subtest 'current_line' => sub {
    is($reader->current_line(), 1, 'Current has value 1');
    is($reader->current_line(), 1, 'Current still has value 1');
};

subtest 'rewind_to_line' => sub {
    $reader->rewind(4);
    is($reader->current(), 4, 'Current is 4 after rewind');
};

subtest 'rewind_to_end' => sub {
    $reader->rewind(20);
    is($reader->current(), 9, 'Current is 9 after rewind');
};

done_testing;