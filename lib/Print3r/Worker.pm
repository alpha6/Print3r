package Print3r::Worker;

use v5.20;

use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.4');

use JSON;
use AnyEvent::Handle;
use Data::Dumper;

use Print3r::Worker::Port;
use Print3r::Worker::Commands::PrinterReplyParser;

use Carp;

my $queue_size = 32; #queue size is 32 commands by default
my $parser = Print3r::Worker::Commands::PrinterReplyParser->new();

sub connect {
    my $class = shift;
    my $device_port = shift;
    my $port_speed = shift;
    my $processing_command = shift;
    
    my $self = {
        ready => -1,
    };

    say Dumper($processing_command);

    say "Connecting.. [$device_port] [$port_speed]";
    my $port = Print3r::Worker::Port->new($device_port, $port_speed);
    
    # say STDERR "Port: ".ref $port;

    $self->{'printer_port'} = $port;
    $self->{'commands_queue'} = [];

    $self->{'printer_handle'} = AnyEvent::Handle->new(
        fh       => $port,
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
                    my $parsed_reply = $parser->parse_line($line);
           
                    say "Parsed reply: ".Dumper($parsed_reply);

                    if ($parsed_reply->{'type'} eq 'ready') {
                        $self->{'ready'} = 1;
                        $self->send_command();
                    }

                    $processing_command->($parsed_reply);
                }
            );
        },     
    );

    bless $self, $class;
    return $self;
}

sub send_command {
    my $self = shift;

    if ($#{$self->{'commands_queue'}} > 0 && $self->{'ready'}) {
        $self->{'printer_handle'}->push_write(shift @{$self->{'commands_queue'}});
        $self->{'ready'} = 0;
        return 1;
    } 

    return 0;
}

sub write {
    my $self = shift;
    my $command = shift;

    if ($#{$self->{'commands_queue'}} < $queue_size) {
        push @{$self->{'commands_queue'}}, $command;
        return 1;    
    } else {
        return 0;
    }
}

sub init_printer {
    my $self = shift;
    if ($self->{'ready'} < 0) {
        $self->{'printer_handle'}->push_write("M105\015\012");
        return 1;
    }
    return 0;
}


1;

