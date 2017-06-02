#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use AnyEvent::ReadLine::Gnu;

use Getopt::Long qw(GetOptionsFromString);

use Data::Dumper;

my $handle;
my $rl;

my $server_addr = '127.0.0.1';
my $server_port = 44243;

my $cv = AE::cv;

my $port  = '/dev/ttyUSB0';
my $speed = 115200;
my $cmd   = "";
my @opts  = qw/port=s speed=i file=s
  /;


# Connect to server
tcp_connect(
    $server_addr,
    $server_port,
    sub {
        my ($fh) = @_
          or die "Unable to connect: $!";

        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;
                $handle->push_read(
                    json => sub {
                        my ( $handle, $data ) = @_;
                        $rl->print( Dumper($data));
                    }
                );

            },
            on_eof => sub {
                my ($hdl) = @_;
                $rl->print( "Connecton to server was closed.\n");
                $hdl->destroy();
                exit 0;
            },
            on_error => sub {
                my $hdl = shift;
                $rl->print( "Lost connecton to server.\n");
                $hdl->destroy();
                exit 1;
            },
        );

        $handle->push_write( json => { command => "status" } );
    }
);

# now initialise readline
$rl = new AnyEvent::ReadLine::Gnu prompt => "cmd> ", on_line => sub {
    my $line = shift;

    if ( $line =~ m/^[G|M|T].*/ ) {
        $handle->push_write(
            json => { command => 'send', value => $line } );
    }
    else {
        my $input = parse_input($line);
        $handle->push_write( json =>
              { command => $input->{'command'}, %{ $input->{'options'} } }
        );
    }    
};

$cv->recv;


sub parse_input {
    my $input_line = shift;
    chomp $input_line;

    # say "[$input_line]";

    my ( $cmd, @args ) = split /\s+/, $input_line;
    my $args = join ' ', @args;

    my $mopts = {};
    GetOptionsFromString( $args, $mopts, @opts );

    # say Dumper($mopts);
    return { command => $cmd, options => $mopts };

}