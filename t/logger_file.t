use lib 'lib';
use strict;
use warnings;

use Test::More;
use Test::Fatal;
use File::Temp;
use Print3r::Logger::LoggerFILE;

subtest 'creates correct object' => sub {
    isa_ok(Print3r::Logger::LoggerFILE->new, 'Print3r::Logger::LoggerFILE');
};

subtest 'prints to file' => sub {
    
    for my $level (qw/error warn debug/) {
        my $file = File::Temp->new;
        my $log = _build_logger(file => $file->filename);

        $log->$level('message');
        undef $log;

        my $content = _slurp($file);

        ok $content;
    }
};

subtest 'prints to stderr with \n' => sub {
    for my $level (qw/error warn debug/) {
    
        my $file = File::Temp->new;
        my $log = _build_logger(file => $file);

        $log->$level('message');

        undef $log;

        my $content = _slurp($file);

        like $content, qr/\n$/;
    }
};

sub _slurp {
    my $file = shift;
    my $content = do { local $/; open my $fh, '<', $file->filename or die $!; <$fh> };
    return $content;
}

sub _build_logger {
    my $logger = Print3r::Logger::LoggerFILE->new(@_);
    $logger->set_level('debug');
    return $logger;
}

done_testing;