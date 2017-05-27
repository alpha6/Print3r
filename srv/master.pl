#!/usr/bin/env perl

use v5.20;

use AnyEvent;
use AnyEvent::Handle;
use AnyEvent::Socket;
use IPC::Open2;
use JSON;
use Log::Log4perl;

use Data::Dumper;

my $cv = AE::cv;

my $host = '127.0.0.1';
my $port = 44244; #Workers interface
my $control_port = 44243; #Control interface

my $printer_port = '/dev/ttyUSB0';
my $port_speed = 115200;

my %connections;
my %workers;
my $control_handle = undef;


Log::Log4perl::init('log4perl.conf');
my $log = Log::Log4perl->get_logger('default');

$log->info('Started...');

sub process_command {
    my $handle = shift;
    my $data = shift;
    $log->debug("process_command: ".Dumper($data));

    if ($data->{'command'} eq 'status') {
        $log->info(sprintf("Printer temp: %.1f@%.1f", $data->{'E0'}, $data->{'B'}));
    } 
    elsif($data->{'command'} eq 'spawn_worker') {
        #Spawn new worker
        my($chld_out, $chld_in);
        my $pid;
        eval {
            $pid = open2($chld_out, $chld_in, './worker.pl', '-p='.$data->{'port'}, '-s='.$data->{'speed'});    
        };
        if ($@) {
            $log->error("Error: $@");
        }
        
        $workers{$pid} = {chld_in => $chld_in, chld_out => $chld_out};
        if ($control_handle) {
            $control_handle->push_write(json => {reply => sprintf("Worker started with pid [%s]", $pid)});    
        }
        

    } elsif ($data->{'command'} eq 'connect') { #Worker connection status message
        #Set flag that worker connected
        $log->info(sprintf("Worker [%s] is connected to [%s] at speed [%s]", $data->{'pid'}, $data->{'port'}, $data->{'speed'}));
        $log->debug($data->{'message'});
        $workers{$data->{'pid'}}{'is_connected'} = 1;
        if (defined $control_handle) {
            $control_handle->push_write(json => {reply => sprintf("Worker [%s] is connected to [%s] at speed [%s]", $data->{'pid'}, $data->{'port'}, $data->{'speed'})});    
        }
        # $handle->push_write(json => {command => 'print_file', params => {filename => 'test.gcode'}});
    } elsif ($data->{'command'} eq 'master_status') {
        
        $control_handle->push_write(json => { handlers => %workers});
    } elsif ($data->{'command'} eq 'send') { #Send command to printer

        if (scalar(keys(%connections)) == 1) {
            my ($h_name) = keys %connections;
            # say Dumper(\%connections);
            my $handler = %connections{$h_name};
            $handler->push_write(json => { command => 'send', params => {value => $data->{'value'}}});
        } else {
            $control_handle->push_write(json => { command => 'error', message => 'Invalid count of connections'});
        }
        
    } 
    else {
        $log->warn(Dumper($data));
    }

}


my $workers_timer = AnyEvent->timer(
    after    => 30,
    interval => 30,
    cb       => sub {
        say "Sending commands";
        for my $key (keys(%connections)) {
            
            my $handler = $connections{$key};
            $handler->push_write(json => {command => "status"});
        }
    }
);

tcp_server(
    $host, $port,
    sub {
        my ($fh, $clienthost, $clientport) = @_;

        $log->info("Connected... [$clienthost][$clientport]\n");

        my $handle;
        $handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;
                
                $self->push_read(json => sub {
                    my ($handle, $data) = @_;
                    process_command($handle, $data);
                });    
                            
            },
            on_eof => sub {
                my ($hdl) = @_;
                say "Client disconnected";
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                print "Lost connecton to client.\n";
                $hdl->destroy();
            },
        );
        $connections{$handle} = $handle;    # keep it alive.

        # $handle->push_write(json => {command => "connect", params => {port => "/dev/ttyUSB0", speed => 115200 }});
        return;
    }
);

tcp_server (
    $host, $control_port, 
    sub {
        my ($fh, $clienthost, $clientport) = @_;

        if (defined($control_handle)) {
            syswrite $fh, "Only one controll process is allowed!";
            return;
        }


        $log->info("CLI connected... [$clienthost][$clientport]\n");

        $control_handle = AnyEvent::Handle->new(
            fh      => $fh,
            poll    => 'r',
            on_read => sub {
                my ($self) = @_;
                
                $self->push_read(json => sub {
                    my ($handle, $data) = @_;
                    process_command($control_handle, $data);
                });    
                            
            },
            on_eof => sub {
                my ($hdl) = @_;
                $hdl->destroy();
            },
            on_error => sub {
                my $hdl = shift;
                $log->error("Lost connecton to control interface.\n");
                $hdl->destroy();
            },
        );

        return;     
    }
);

$log->info("Listening on $host:$port\n");

$cv->recv;
