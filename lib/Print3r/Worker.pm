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

use Print3r::Logger;
use Print3r::Worker::Port;
use Print3r::Worker::Commands::PrinterReplyParser;

use Carp;

my $queue_size = 32;    #queue size is 32 commands by default
my $parser = Print3r::Worker::Commands::PrinterReplyParser->new();
my $log = Print3r::Logger->get_logger( 'stderr', level => 'debug' );

sub connect ( $class, $device_port, $port_speed, $command_callback ) {
    $log->debug( 'connect: ' . Dumper( \@_ ) );

    my $self = { ready => -1, };

    $log->debug("Connecting.. [$device_port] [$port_speed]");
    my $port = Print3r::Worker::Port->new( $device_port, $port_speed );

    # say STDERR "Port: ".ref $port;

    $self->{'printer_port'}   = $port;
    $self->{'commands_queue'} = [];

    $self->{'commands_sent'} = 0;
    $self->{'commands_ok_recv'} = 0;

    $self->{'printer_handle'} = AnyEvent::Handle->new(
        fh       => $port,
        on_error => sub {    #on_error
            my ( $hdl, $fatal, $message ) = @_;

            $hdl->destroy;
            undef $hdl;

            croak("$fatal : $message");
        },
        on_read => sub {     #on_read
            my $p_hdl = shift;
            $p_hdl->push_read(
                line => sub {
                    my ( undef, $line ) = @_;
                    return if ( $line eq '' );    #Skip empty lines

                    $log->debug( sprintf( "Source line [%s]", $line ) );
                    my $parsed_reply = $parser->parse_line($line);

                    $log->debug( 'Parsed reply: ' . Dumper($parsed_reply) );

                    if ( $parsed_reply->{'printer_ready'} ) {
                        $self->{'ready'} = 1;
                        $self->{'commands_ok_recv'}++;
                        if ($self->{'commands_sent'} < $self->{'commands_ok_recv'}) {
                            $log->error("Received more ok replies than commands sent!");
                            $log->error(sprintf("sent [%s] ok [%s]",$self->{'commands_sent'}, $self->{'commands_ok_recv'}));
                        }
                        $self->_send_command();
                    }

                    $command_callback->($parsed_reply);
                }
            );
        },
    );

    bless $self, $class;
    return $self;
}

sub _send_command {
    my $self = shift;

   # $log->debug('Sending command from queue...');
   # $log->debug( sprintf('Queue size [%s]', $#{ $self->{'commands_queue'} } ));
   # $log->debug( sprintf( 'Status [%s]', $self->{'ready'} ) );

    if ( $#{ $self->{'commands_queue'} } >= 0 && $self->{'ready'} ) {
        $self->{'commands_sent'}++;
        $self->{'printer_handle'}
          ->push_write( shift @{ $self->{'commands_queue'} } );
        $self->{'ready'} = 0;
        $log->debug( sprintf( 'Sent. Status [%s]', $self->{'ready'} ) );
        return 1;
    }
    elsif ( $#{ $self->{'commands_queue'} } < 0 ) {
        $log->debug("Queue is empty!");
        return 0;
    }
    else {
        $log->debug(
            sprintf( 'Printer is not ready. Status [%s]', $self->{'ready'} ) );
        return 0;
    }

}

sub write {
    my $self    = shift;
    my $command = shift;

   # $log->debug('Writing command to queue...');
   # $log->debug( sprintf( 'Command [%s]', $command ) );
   # $log->debug( sprintf('Queue size [%s]', $#{ $self->{'commands_queue'} } ));
   # $log->debug( sprintf( 'Status [%s]', $self->{'ready'} ) );

    if ( $#{ $self->{'commands_queue'} } < $queue_size ) {
        push @{ $self->{'commands_queue'} }, $command;
        $self->_send_command() if ( $self->{'ready'} );
        return 1;
    }
    else {
        $log->debug(
            sprintf( 'Queue size more than limit',
                $#{ $self->{'commands_queue'} } )
        );
        return 0;
    }
}

sub init_printer {
    my $self = shift;
    if ( $self->{'ready'} < 0 ) {
        $self->{'printer_handle'}->push_write("M105\015\012");
        return 1;
    }
    return 0;
}

1;

