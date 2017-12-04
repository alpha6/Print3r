use lib 'lib';

use v5.20;
use strict;
use warnings;

use Test::More;
use Test::Deep;
use Capture::Tiny qw(capture_stderr);

use Print3r::Worker::Port::TestPort;
use Print3r::Worker::Commands::PrinterReplyParser;

use AnyEvent;

use Data::Dumper;

$ENV{'TESTING'} = 1;

my $reply_parser = Print3r::Worker::Commands::PrinterReplyParser->new;

my $check_package = Print3r::Worker::Port::TestPort->_new();
subtest 'creates correct object' => sub {
    isa_ok( $check_package, 'Print3r::Worker::Port::TestPort' );
};

subtest 'check_version' => sub {
    is( $check_package->VERSION, 'v0.0.2',
        'check that the test is for suitable module version' );
};

my $port = Print3r::Worker::Port::TestPort->connect();

subtest 'check_connection' => sub {

    my $stat = syswrite( $port, "test\r\n", 6 );

    my $cv    = AE::cv;
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
    my $stat = syswrite( $port, sprintf( "%s\n", $gcode ) );

    my $cv    = AE::cv;
    my $timer = AnyEvent->timer(
        after => 0.1,
        cb    => sub {
            sysread( $port, my $line, 1024 );
            chomp($line);

            like( $line, qr/^ok /, 'Test common reply format' );
            $cv->send;
        }
    );

    $cv->recv;
};

subtest 'check_sync_temps' => sub {
    local $/ = "\r\n";

    for my $gcode ( 'M109 S25', 'M109 S23', 'M190 S25' ) {
        my $stat = syswrite( $port, sprintf( "%s\n", $gcode ) );

        my $cv = AE::cv;

        my $hdl;
        my $steps = 0;
        $hdl = AnyEvent::Handle->new(
            fh      => $port,
            on_read => sub {
                $hdl->push_read(
                    line => sub {
                        my ( undef, $line ) = @_;
                        my $reply = $reply_parser->parse_line($line);

                        if (   ( $reply->{'type'} eq 'temperature' )
                            && ( $reply->{'printer_ready'} == 1 ) )
                        {
                            if ( $steps > 0 ) {
                                ok( $reply->{'E0'},
                                    sprintf( 'Check %s', $gcode ) );
                            } else {
                                fail(sprintf( 'Check %s failed. No steps before temp has set.', $gcode )); 
                            }
                            undef $hdl;
                            $cv->send;
                        }
                        elsif ( $reply->{'type'} eq 'other' ) {
                            $steps++;
                        }

                    }
                );
            },
            on_eof => sub {
                print STDERR "Connection closed. EOF\n";
                $hdl->fh->close;
                undef $hdl;
                $cv->send;
            },
            on_error => sub {
                print STDERR "Connection error: $!\n";
                undef $hdl;
                $cv->send;
            },
        );

        $cv->recv;
    }
};


subtest 'check_async_temps' => sub {
    local $/ = "\r\n";

    for my $gcode ( 'M104 S25', 'M104 S23', 'M140 S25' ) {
        my $stat = syswrite( $port, sprintf( "%s\n", $gcode ) );

        my $cv = AE::cv;

        my $hdl;
        my $steps = 0;
        $hdl = AnyEvent::Handle->new(
            fh      => $port,
            on_read => sub {
                $hdl->push_read(
                    line => sub {
                        my ( undef, $line ) = @_;
                        my $reply = $reply_parser->parse_line($line);

                        if (   ( $reply->{'type'} eq 'temperature' )
                            && ( $reply->{'printer_ready'} == 1 ) )
                        {
                            if ( $steps == 0 ) {
                                ok( $reply->{'E0'},
                                    sprintf( 'Check %s', $gcode ) );
                            } else {
                                fail(sprintf( 'Check %s failed. Wouldn\'t step before temperature has set in async mode', $gcode )); 
                            }
                            undef $hdl;
                            $cv->send;
                        }
                        elsif ( $reply->{'type'} eq 'other' ) {
                            $steps++;
                        }

                    }
                );
            },
            on_eof => sub {
                print STDERR "Connection closed. EOF\n";
                $hdl->fh->close;
                undef $hdl;
                $cv->send;
            },
            on_error => sub {
                print STDERR "Connection error: $!\n";
                undef $hdl;
                $cv->send;
            },
        );

        $cv->recv;
    }
};

subtest 'check_M105' => sub {
    local $/ = "\r\n";

    my $gcode = 'M105';
    my $stat = syswrite( $port, sprintf( "%s\n", $gcode ) );

    my $cv    = AE::cv;
    my $hdl;
        
        $hdl = AnyEvent::Handle->new(
            fh      => $port,
            on_read => sub {
                $hdl->push_read(
                    line => sub {
                        my ( undef, $line ) = @_;
                        my $reply = $reply_parser->parse_line($line);
                        
                        if (   ( $reply->{'type'} eq 'temperature' )
                            && ( $reply->{'printer_ready'} == 1 ) )
                        {
                            
                                is( $reply->{'E0'}, '23.0',
                                    sprintf( 'Check hotend %s', $gcode ) );
                                is( $reply->{'B'}, '25.0',
                                    sprintf( 'Check bed %s', $gcode ) );
                            
                            undef $hdl;
                            $cv->send;
                        }
                        

                    }
                );
            },
            on_eof => sub {
                print STDERR "Connection closed. EOF\n";
                $hdl->fh->close;
                undef $hdl;
                $cv->send;
            },
            on_error => sub {
                print STDERR "Connection error: $!\n";
                undef $hdl;
                $cv->send;
            },
        );

    $cv->recv;
};

done_testing;
