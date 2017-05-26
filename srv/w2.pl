#!/usr/bin/env perl

use v5.20;

use lib 'lib';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use Print3r::Commands;
use Print3r::Worker;

use Data::Dumper;
 
my $cv = AE::cv;



my $handle;
my $printer_handle = undef;
my $printer_port = undef;
my $printing_file = undef;
my %timers;
my $in_command_flag = 0;
my $is_printer_ready = 1;

my $worker = Print3r::Worker->new();

sub get_line {
	while (1) {
		my $line = <$printing_file>;

	    unless ( defined($line) ) {
	    	undef $printing_file;
	        die "No strings left in file";
	    }

	    if ($line =~ m/^[G|M|T].*/) {
	    	chomp $line;
	    	printf("line [%s]\n", $line);
	    	return $line;	    
	    } 
	}
    
}

sub set_heartbeat {
	
	my $heartbeat_timer = AnyEvent->timer(
    after    => 10,
    interval => 10,
    cb       => sub {
            $handle->push_write(json => { command => "HEARTBEAT"});
        }
    );
    $timers{'heartbeat_timer'} = $heartbeat_timer;
}

sub process_command {
	my $command = shift;
	say "Parsed command: ".Dumper($command);
	say "Printer status: [$is_printer_ready]";
	if (exists($command->{'printer_ready'})) {
		$is_printer_ready = $command->{'printer_ready'};
		say "Printer status: [$is_printer_ready]";
	}
	if ($command->{'type'} eq 'start_printing') {
		if (defined($printing_file)) {
			my $next_command = get_line();
        	$printer_port->write("$next_command\n");	
		} else {
			$handle->push_write(json => { command => "error", message => "No file to print is available"});
		}
		
	} elsif ($command->{'printer_ready'}) {
		say "Printer ready confirmed";
		if (defined($printing_file) && $is_printer_ready) {
			my $next_command = get_line();
        	$printer_port->write("$next_command\n");
        }
	} elsif ($command->{'type'} eq 'temperature') {
		$handle->push_write(json => { command => 'status', E0 => $command->{'E0'}, B => $command->{'B'}});
	}
}

my $commands = print3r::Commands->new({
	hello => sub { say "YOYOYO! HELLO!"},
	connect => sub { 
		my $params = shift;
		$printer_port = $worker->connect_to_printer($params->{'port'}, $params->{'speed'});


		#Creating AE::Handle for the  port of the printer
		my $fh = $printer_port->{'HANDLE'};
    	$printer_handle = AnyEvent::Handle->new(
	        fh => $fh,
	        on_error => sub {
	            my ($printer_handle, $fatal, $message) = @_;
	            $printer_handle->destroy;
	            undef $printer_handle;
	            print STDERR "$fatal : $message\n";
	            $handle->push_write (json => { command => "error", message => $message});
	        },
	        on_read => sub {
	            my $printer_handle = shift;
	            $printer_handle->push_read(line => sub {
	                my ($printer_handle, $line) = @_;
	                my $parsed_reply = $worker->parse_line($line);
	                process_command($parsed_reply);
	                })
	        });
    	$handle->push_write(json => {command => "connect", status => "ready", message => "Connected to [".$params->{'port'}."]"});
	    #Start communication with the printer
	    $printer_port->write("M105\n")
		},
	print_file => sub {
		my $params = shift;
		say "print file: ".Dumper($params);
		open $printing_file, '<', $params->{'filename'} or die $!;
		process_command({type => "start_printing"});
		},
});



#Getting temperature from the printer
my $test_timer = AnyEvent->timer(
    after    => 20,
    interval => 20,
    cb       => sub {
        # say sprintf("Alive %s", time());
        if (defined $printer_port) {
        	if (!$in_command_flag) {
        		$printer_port->write("M105\n");	
        	}
        }
    });


tcp_connect ("127.0.0.1", 44244,
   sub {
      my ($fh) = @_
         or die "unable to connect: $!";

	  
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;                
                $handle->push_read( json => sub {
                    my ($handle, $data) = @_;
                    say Dumper($data);
                    my $name = lc($data->{'command'});
                    my $params = $data->{'params'};
                    $commands->$name($params);
                });
                
            },
            on_eof => sub {
                my ($hdl) = @_;
                print "Connecton to server was closed.";
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to server.";
                $hdl->destroy();
            },
        );

      $handle->push_write (json => { command => "HELLO"});
      set_heartbeat();
});



$cv->recv;