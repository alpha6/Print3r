#!/usr/bin/env perl

use v5.20;

use lib 'lib';
use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;

use Log::Log4perl;

use Getopt::Long;

use Print3r::Commands;
use Print3r::Worker;

use Data::Dumper;

my $cv = AE::cv;


Log::Log4perl::init('log4perl.conf');
my $log = Log::Log4perl->get_logger('default');

my $handle;
my $printer_handle = undef;
my $printing_file = undef;
my $port_handle = undef;
my %timers;
my $in_command_flag = 0;
my $is_printer_ready = 1;


my $printer_port = '/dev/ttyUSB0';
my $port_speed = 115200;

GetOptions(
	'p=s' => \$printer_port,
	's=i' => \$port_speed
	);

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
	    	$log->debug(sprintf("line [%s]\n", $line));
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
	$log->debug("Parsed command: ".Dumper($command));
	$log->debug("Printer status: [$is_printer_ready]");
	if (exists($command->{'printer_ready'})) {
		$is_printer_ready = $command->{'printer_ready'};
		$log->debug("Printer status: [$is_printer_ready]");
	}
	if ($command->{'type'} eq 'start_printing') {
		if (defined($printing_file)) {
			my $next_command;
			eval {
				$next_command = get_line();
			};
			if ($@) {
				$handle->push_write(json => { command => "error", message => "Printing error: $@"});	
			} else {
        		$port_handle->write("$next_command\n");	
			}
		} else {
			$handle->push_write(json => { command => "error", message => "No file to print is available"});
		}
		
	} elsif ($command->{'printer_ready'}) {
		$log->debug("Printer ready confirmed");
		if (defined($printing_file) && $is_printer_ready) {
			my $next_command = get_line();
        	$port_handle->write("$next_command\n");
        }
	} elsif ($command->{'type'} eq 'temperature') {
		$handle->push_write(json => { command => 'status', E0 => $command->{'E0'}, B => $command->{'B'}});
	} 
}

sub connect_to_printer {
	$port_handle = $worker->connect_to_printer($printer_port, $port_speed);


		#Creating AE::Handle for the  port of the printer
		my $fh = $port_handle->{'HANDLE'};
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
    	$handle->push_write(json => {command => "connect", status => "ready", message => "Connected to [".$printer_port."]", pid => $$, port => $printer_port, speed => $port_speed});
    	
	    #Start communication with the printer
	    $port_handle->write("M105\n");
}

my $commands = print3r::Commands->new({
	print => sub {
		my $self = shift;
		my $params = shift;
		$log->debug("printing file: ".Dumper($params));
		open ($printing_file, '<', $params->{'file'}) or die $!;
		process_command({type => "start_printing"});
		},
	send => sub {
		$log->debug("send:".Dumper(\@_));
		my $self = shift;
		my $params = shift;
		$log->debug("G-Code: ".Dumper($params));
		$port_handle->write(sprintf("%s\n", $params->{'value'}));
	},
	disconnect => sub {
		$port_handle->close();
		$handle->destroy();
		exit 0;
		},
});



#Getting temperature from the printer
my $test_timer = AnyEvent->timer(
    after    => 20,
    interval => 20,
    cb       => sub {
        # say sprintf("Alive %s", time());
        if (defined $port_handle) {
        	if (!$in_command_flag) {
        		$port_handle->write("M105\n");	
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
                    $log->debug("Worker read:".Dumper($data));
                    my $name = lc($data->{'command'});
                    my $params = $data->{'params'};
                    $commands->$name($params);
                });
                
            },
            on_eof => sub {
                my ($hdl) = @_;
                $log->error("Connecton to server was closed.");
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                $log->error(print "Lost connecton to server.");
                $hdl->destroy();
            },
        );

      $handle->push_write (json => { command => "HELLO"});
      # set_heartbeat();
      connect_to_printer();
});



$cv->recv;