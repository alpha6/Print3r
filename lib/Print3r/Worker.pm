package Print3r::Worker;

use v5.20;
use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
our $VERSION = version->declare('v0.0.3');

use JSON;
use AnyEvent::Handle;
use Device::SerialPort;
use Data::Dumper;

use Carp;

my $queue_size = 32; #queue size is 32 commands by default

sub connect {
    my $class = shift;
    my $device_port = shift;
    my $port_speed  = shift || 115200;
    my $processing_command = shift;

    my $self = {};

    say "Connecting.. [$device_port] [$port_speed]";
    my $port = Device::SerialPort->new($device_port)
      or croak "Can't connect to [$device_port] at speed [$port_speed]";

    $port->handshake('none');
    $port->baudrate($port_speed);    # Configure this to match your device
    $port->databits(8);
    $port->parity('none');
    $port->stopbits(1);
    $port->stty_echo(0);
    $port->debug(1);
    $port->error_msg('ON');

    $self->{'printer_port'} = $port;
    $self->{'commands_queue'} = [];

    my $printer_handle = AnyEvent::Handle->new(
        fh       => $port->{'HANDLE'},
        on_error => sub { #on_error
            my ( $hdl, $fatal, $message ) = @_;
            
            $hdl->destroy;
            undef $hdl;
            
            croak("$fatal : $message");
        },
        on_read => sub { #on_read
            my $p_hdl = shift;
            $p_hdl->push_read(
                line => sub {
                    my ( undef, $line ) = @_;
                    my $parsed_reply = $self->parse_line($line);
           
                    if ($parsed_reply->{'type'} eq 'ready') {
                        $self->send_command();
                    }

                    &$processing_command->($parsed_reply);
                }
            );
        },

         
    );

    bless $self, $class;
    return $self;
}

sub send_command {
    my $self = shift;

    if ($#{$self->{'commands_queue'}} > 0) {
        $self->{'printer_port'}->write(shift $self->{'commands_queue'});
        return 1;
    } 

    return 0;
}

sub write {
    my $self = shift;
    my $command = shift;

    if ($#{$self->{'commands_queue'}} < $queue_size) {
        push $self->{'commands_queue'}, $command;
        return 1;    
    } else {
        return 0;
    }
}

sub parse_line {
    my $self = shift;
    my $line = shift;
    my $type = {};

    for ($line) {
        when (/^ok T:(\d+\.\d+) \/\d+\.\d+/) {
            $type = $self->_parse_temp_line($line);
        }
        when (/^(ok|start)/) {
            $type->{'type'}          = 'ready';
            $type->{'printer_ready'} = 1;
            $type->{'line'}          = $line;
        }
        when (/halt|kill|stop/i) {
            $type->{'type'}          = 'error';
            $type->{'printer_ready'} = 0;
            $type->{'line'}          = $line;
        }
        when (/reset or M999 required/) {
            $type->{'type'}          = 'error';
            $type->{'printer_ready'} = 0;
            $type->{'line'}          = $line;
        }
        when ('Watchdog Reset') {
            $type->{'type'}          = 'error';
            $type->{'printer_ready'} = 0;
            $type->{'line'}          = $line;
        }
        default {
            $type->{'type'}          = 'other';
            $type->{'printer_ready'} = 0;
            $type->{'line'}          = $line;
        }
    }
    return $type;
}

sub _parse_temp_line {
    my $self   = shift;
    my $line   = shift;
    my $parsed = {};

    $parsed->{'type'} = 'temperature';
    $parsed->{'line'} = $line;
    $parsed->{'B'} = undef;    #Undefined if printer doesn't have heated bed

    my @line = split /\s+/, $line;

    for my $item (@line) {
        if ( $item eq 'ok' ) {
            $parsed->{'printer_ready'} = 1;
        }
        elsif ( $item =~ /T(?<ex_num>\d+)?:(?<temp>\d+\.\d+)/ ) {
            $parsed->{ sprintf( 'E%s', $+{ex_num} || 0 ) } = $+{'temp'};
        }
        elsif ( $item =~ /B:?(\d+\.\d+)/ ) {

            #B\d+\.\d+ - Marlin dialect
            #B:\d+\.\d+ - Smoothieware
            $parsed->{'B'} = $1;
        }
    }

    return $parsed;
}

1;

# RECV: start
# RECV: echo: External Reset
# RECV: Marlin 1.1.0-RC8
# RECV: echo: Last Updated: 2016-12-06 12:00 | Author: (none, default config)
# RECV: Compiled: Apr 13 2017
# RECV: echo: Free Memory: 13426  PlannerBufferBytes: 1232
# RECV: echo:Hardcoded Default Settings Loaded
# RECV: echo:Steps per unit:
# RECV: echo:  M92 X94.00 Y94.00 Z94.00 E540.00
# RECV: echo:Maximum feedrates (mm/s):
# RECV: echo:  M203 X200.00 Y200.00 Z200.00 E25.00
# RECV: echo:Maximum Acceleration (mm/s2):
# RECV: echo:  M201 X3000 Y3000 Z3000 E10000
# RECV: echo:Accelerations: P=printing, R=retract and T=travel
# SENT: M105
# RECV: echo:  M204 P1000.00 R3000.00 T1500.00
# RECV: echo:Advanced variables: S=Min feedrate (mm/s), T=Min travel feedrate (mm/s), B=minimum segment time (ms), X=maximum XY jerk (mm/s),  Z=maximum Z jerk (mm/s),  E=maximum E jerk (mm/s)
# RECV: echo:  M205 S0.00 T0.00 B20000 X20.00 Y20.00 Z20.00 E5.00
# RECV: echo:Home offset (mm)
# RECV: echo:  M206 X0.00 Y0.00 Z0.00
# RECV: Auto Bed Leveling:
# RECV: echo:  M420 S0
# RECV: echo:Endstop adjustment (mm):
# RECV: echo:  M666 X0.00 Y0.00 Z0.00
# RECV: echo:Delta settings: L=diagonal_rod, R=radius, S=segments_per_second, ABC=diagonal_rod_trim_tower_[123]
# RECV: echo:  M665 L185.50 R85.19 S200.00 A0.00 B0.00 C0.00
# RECV: echo:PID settings:
# RECV: echo:  M301 P22.20 I1.08 D114.00
# RECV: echo:Filament settings: Disabled
# RECV: echo:  M200 D1.75
# RECV: echo:  M200 D0
# RECV: echo:Z-Probe Offset (mm):
# RECV: echo:  M851 Z0.00
# RECV: ok T:0.0 /0.0 @:0
