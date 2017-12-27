use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker::Commands::PrinterReplyParser;

use Data::Dumper;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Worker::Commands::PrinterReplyParser->new, 'Print3r::Worker::Commands::PrinterReplyParser');
};

my $worker = Print3r::Worker::Commands::PrinterReplyParser->new;

subtest 'check_version' => sub {
    is($worker->VERSION, 'v0.0.2', 'check that the test is for correct module version');
};

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
    my @lines = ('Marlin 1.1.0-RC8',
    'Reporting endstop status');

    for my $line (@lines) {
        cmp_deeply( 
            {
                printer_ready => 0,
                type => 'other',
                line => $line,
            }, 
            $worker->parse_line($line),
            "Check other [$line]",
        );
    }
    
};

#TODO: Get all error messages from Marlin and Smoothieware
subtest 'error_line' => sub {
    my @lines = (
        'Limit switch +X was hit - reset or M999 required',
        'Temperature took too long to be reached on B, HALT asserted, TURN POWER OFF IMMEDIATELY - reset or M999 required',
        'Error: Printer halted. kill() called !!',
        'Error:No Checksum with line number, Last Line: 7',
        'Error:Line Number is not Last Line Number+1, Last Line: 7',
        'Printer stopped due to errors. Fix the error and use M999 to restart. (Temperature is reset. Set it after restarting)',
        'STOP called because of BLTouch error - restart with M999',
        'STOP called because of unhomed error - restart with M999',
        'KILL caused by too much inactive time - current command: ',
        'KILL caused by KILL button/pin',

    );
    
    for my $line (@lines) {
        cmp_deeply( 
            {
                printer_ready => 0,
                type => 'error',
                line => $line,
            }, 
            $worker->parse_line($line),
            "Catching one from error lines: [$line]",
        );

    }
};

done_testing;

__END__

