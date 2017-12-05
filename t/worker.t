use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;

use Print3r::Worker;

use Data::Dumper;

$ENV{'TESTING'} = 1;

my $reply;
my $worker = Print3r::Worker->connect( '/dev/ttyUSB0', 115200,
    sub { $reply = $_[0]; } );

subtest 'creates correct object' => sub {
    isa_ok( $worker, 'Print3r::Worker' );
};

subtest 'check_version' => sub {
    is( $worker->VERSION, 'v0.0.4',
        'check that the test is for suitable module version' );
};

subtest 'init' => sub {
    $reply = undef;
    my $cv = AE::cv;

    my $res = $worker->init_printer();

    my $timer = AnyEvent->timer(
        after => 1,
        cb    => sub {
            if ( defined $reply ) {
                cmp_deeply(
                    {   'line'          => 'ok T:22.0 /0.0 @0 B:22.0 /0.0 @0',
                        'E0'            => '22.0',
                        'printer_ready' => 1,
                        'B'             => '22.0',
                        'type'          => 'temperature'
                    },
                    $reply,
                    "Check init",
                );
            }
            else {
                fail "No reply from callback";
            }

            $cv->send;
        }
    );
    $cv->recv;
};

done_testing;
