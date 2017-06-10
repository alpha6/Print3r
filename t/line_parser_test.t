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
            B => undef,
            line => $line,
        }, 
        $worker->parse_line($line),
        "Check temp line without bed",
    );

    my $line_bed ='ok T:22.8 /0.0 @0 B:24.7 /0.0 @0';

    cmp_deeply( 
        {
            printer_ready => 1,
            type => "temperature",
            E0 => "22.8",
            B => "24.7",
            line => $line_bed,
        }, 
        $worker->parse_line($line_bed),
        "Check temp line with bed",
    );

    my $line_dual = 'ok T:25.9 /0.0 @:0 T1:25.5 /0.0 @0 B26.2 /0.0 @0';

    cmp_deeply( 
        {
            printer_ready => 1,
            type => "temperature",
            E0 => "25.9",
            E1 => "25.5",
            B => "26.2",
            line => $line_dual,
        }, 
        $worker->parse_line($line_dual),
        "Check temp line dual",
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