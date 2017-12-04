use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker::Commands::GCODEParser;

use Data::Dumper;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Worker::Commands::GCODEParser->new, 'Print3r::Worker::Commands::GCODEParser');
};

my $parser = Print3r::Worker::Commands::GCODEParser->new;

subtest 'check_version' => sub {
    is($parser->VERSION, 'v0.0.1', 'check that the test is for correct module version');
};

subtest 'parse temperature commands' => sub {
    cmp_deeply( 
        {
            code => 'M104 S200',
            async => 1,
            type => 'temperature',
            target_temp => 200,
            heater => 'hotend',
        }, 
        $parser->parse_code('M104 S200'),
        "Check M104",
    );
    cmp_deeply( 
        {
            code => 'M109 S200',
            async => 0,
            type => 'temperature',
            target_temp => 200,
            heater => 'hotend',
        }, 
        $parser->parse_code('M109 S200'),
        "Check M109",
    );
    cmp_deeply( 
        {
            code => 'M140 S200',
            async => 1,
            type => 'temperature',
            target_temp => 200,
            heater => 'bed',
        }, 
        $parser->parse_code('M140 S200'),
        "Check M140",
    );
    cmp_deeply( 
        {
            code => 'M190 S200',
            async => 0,
            type => 'temperature',
            target_temp => 200,
            heater => 'bed',
        }, 
        $parser->parse_code('M190 S200'),
        "Check M190",
    );
};

subtest 'parse common g-code' => sub {
    cmp_deeply( 
        {
            code => 'G1 X100 Y100 Z100',
            type => 'common',
        }, 
        $parser->parse_code('G1 X100 Y100 Z100'),
        "Check M190",
    );
};

done_testing;