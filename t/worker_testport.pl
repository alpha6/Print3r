use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;
use Capture::Tiny qw(capture_stderr);

use Print3r::Worker::Port::TestPort;

use AnyEvent;

use Data::Dumper;

$ENV{'TESTING'} = 1;

my $check_package = Print3r::Worker::Port::TestPort->_new();
subtest 'creates correct object' => sub {
    isa_ok( $check_package, 'Print3r::Worker::Port::TestPort' );
};

subtest 'check_version' => sub {
    is( $check_package->VERSION, 'v0.0.1',
        'check that the test is for suitable module version' );
};

my $port = Print3r::Worker::Port::TestPort->connect();	

subtest 'check_connection' => sub {
	
    my $stat = syswrite( $port, "test\r\n", 6 );
    
    my $cv = AE::cv;
    my $timer = AnyEvent->timer(
        after => 0.1,
        cb    => sub {
            sysread( $port, my $line, 1024 );
            
            ok $line;
            $cv->send;
        }
    );
    
    $cv->recv;
};

subtest 'check_reply_format' => sub {
	local $/ = "\r\n";
	
	my $gcode = 'M84';
    my $stat = syswrite( $port, sprintf("%s\n", $gcode) );
    
    my $cv = AE::cv;
    my $timer = AnyEvent->timer(
        after => 0.1,
        cb    => sub {
            sysread( $port, my $line, 1024 );
            chomp ($line);

            say sprintf('line [%s]', $line);
            like ($line, qr/^ok /, 'Test common reply format');
            $cv->send;
        }
    );
    
    $cv->recv;
};



done_testing;
