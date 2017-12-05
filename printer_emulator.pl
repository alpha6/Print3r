#!/usr/bin/env perl

use v5.20;
use strict;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';

use lib 'lib';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use File::Basename;
use Time::Moment;

use Try::Tiny;

use Getopt::Long;

use Print3r::PrinterEmulator;

my $cv    = AE::cv;

say "Starting printer emulator...";
my $emu = Print3r::PrinterEmulator->connect();
say "Started. Receiving commands";

$cv->recv;