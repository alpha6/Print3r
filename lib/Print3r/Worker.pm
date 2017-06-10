package Print3r::Worker;

use v5.20;
our $VERSION = version->declare("v0.0.2");

use JSON;
use AnyEvent::Handle;
use Device::SerialPort;
use Data::Dumper;

use Carp;

sub new {
    my $class = shift;
    my $self = {
        printer_handle => undef,
    };
    bless $self, $class;
    return $self;
}

sub connect_to_printer{
    my $self = shift;
    my $device_port = shift;
    my $port_speed = shift || 115200;

    say "Connecting.. [$device_port] [$port_speed]";
    my $port = Device::SerialPort->new($device_port) or croak "Can't connect to [$device_port] at speed [$port_speed]";

    $port->handshake("none");
    $port->baudrate($port_speed);    # Configure this to match your device
    $port->databits(8);
    $port->parity("none");
    $port->stopbits(1);
    $port->stty_echo(0);
    $port->debug(1);
    $port->error_msg('ON');

    $self->{'printer_port'} = $port;

    return 1;
}

sub get_raw_handler {
    my $self = shift;
    croak "Printer isn't connected" unless defined $self->{'printer_port'};

    return $self->{'printer_port'}{'HANDLE'};
}

sub parse_line {
    my $self = shift;
    my $line = shift;
    my $type = {};

    say "PLine: [$line]";

    if ($line =~ /^ok T:(\d+\.\d+) \/(\d+\.\d+)/) {
        $type->{'printer_ready'} = 1;
        $type->{'type'} = "temperature";
        $type->{'E0'} = $1;
        $type->{'B'} = $2;
        $type->{'line'} = $line;
    }
    elsif ( $line =~ /^(ok|start)/ ) {
        # say "ready";
        $type->{'type'} = "ready";
        $type->{'printer_ready'} = 1;
        $type->{'line'} = $line;
    }
    elsif ($line eq 'Watchdog Reset') {
        $type->{'type'} = "error";
        $type->{'printer_ready'} = 0;
        $type->{'line'} = $line;
    } 
    else {
        $type->{'type'} = "other";
        $type->{'printer_ready'} = 0;
        $type->{'line'} = $line;
    }


    return $type;
}





1;
