use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker;

use Data::Dumper;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Worker->new, 'Print3r::Worker');
};

my $worker = Print3r::Worker->new;

subtest 'parse temp line' => sub {
    my $line = 'ok T:25.9 /0.0 @:0';

    cmp_deeply( 
        {
            printer_ready => 1,
            type => "temperature",
            E0 => "25.9",
            B => "0.0",
            line => $line,
        }, 
        $worker->parse_line($line),
        "Check temp line1",
    );
};

subtest 'parse start' => sub {
    for my $line (qw/ok start/) {
        cmp_deeply( 
            {
                printer_ready => 1,
                type => 'ready',
                line => $line,
            }, 
            $worker->parse_line($line),
            "Check start line",
        );
    }
};

subtest 'parse_other' => sub {
    my $line = 'Marlin 1.1.0-RC8';

    cmp_deeply( 
            {
                printer_ready => 0,
                type => 'other',
                line => $line,
            }, 
            $worker->parse_line($line),
            "Check other",
        );
};

done_testing;