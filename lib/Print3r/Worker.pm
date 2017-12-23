package Print3r::Worker;

use v5.20;

use warnings;
no if $] >= 5.018, warnings => 'experimental::smartmatch';
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.7');

use JSON;
use AnyEvent::Handle;
use Data::Dumper;

use Print3r::Logger;
use Print3r::Worker::Port;
use Print3r::Worker::Commands::PrinterReplyParser;

use Carp;

my $queue_size = 32;    #queue size is 32 commands by default
my $parser = Print3r::Worker::Commands::PrinterReplyParser->new();
my $log    = Print3r::Logger->get_logger(
    'file',
    file   => 'worker.log',
    synced => 1,
    level  => 'debug'
);

my $line_number = 0;
my $line_separator = "\012";

sub connect ( $class, $device_port, $port_speed, $command_callback ) {
#    $log->debug( 'connect: ' . Dumper( \@_ ) );

    my $self = { ready => -1, };

    $log->debug("Connecting.. [$device_port] [$port_speed]");
    my $port = Print3r::Worker::Port->new( $device_port, $port_speed );

    $self->{'printer_port'}   = $port;
    $self->{'commands_queue'} = [];

    local $/ = $line_separator;

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
                    return 1 if ( $line eq q{} );    #Skip empty lines

                    $log->debug( sprintf( 'Recv [%s]', $line ) );
                    my $parsed_reply = $parser->parse_line($line);

                    if ( $parsed_reply->{'printer_ready'} ) {
                        $self->{'commands_ok_recv'}++;
                        $log->debug(sprintf('[%s] Ok received', $self->{'commands_ok_recv'}));
                        $self->{'ready'} = 1;
                        $self->_send_command();
                    }

                    $command_callback->($parsed_reply);
                    return 1;
                }
            );
        },
    );

    bless $self, $class;

    #Enable commands numeration to prevent "ok" reaction on a trash in the port.
    $self->restart_line_counter();

    return $self;
}

sub _send_command {
    my $self = shift;

    if ( $#{ $self->{'commands_queue'} } >= 0 && $self->{'ready'} ) {
        ++$self->{'commands_sent'};
        ++$line_number;
        my $command = $self->_buid_command(shift @{ $self->{'commands_queue'} });

        $self->{'printer_handle'}
            ->push_write( sprintf( '%s%s', $command, $line_separator ) );
        $self->{'ready'} = 0;
        $log->debug(
            sprintf( 'Sent [%s] [%s].', $self->{'commands_sent'}, $command ) );
        return 1;
    }
    elsif ( $#{ $self->{'commands_queue'} } < 0 ) {
        $log->debug('Queue is empty!');
        return -1;
    }
    else {
        $log->debug(
            sprintf( 'Printer is not ready. Status [%s]', $self->{'ready'} ) );
        return 0;
    }
}

sub _buid_command($self, $line) {
    my $command = sprintf('N%s %s', $line_number, $line);

    #Calculating checksum. http://reprap.org/wiki/G-code#.2A:_Checksum
    my $cs;
    $cs ^= $_ for unpack  'C*', $command;
    $cs &= 0xff;

    return sprintf('%s*%d', $command, $cs);

}

sub write {
    my $self    = shift;
    my $command = shift;
    chomp $command;

    if ( $#{ $self->{'commands_queue'} } < $queue_size ) {
        push @{ $self->{'commands_queue'} }, $command;
        return $self->_send_command() if ( $self->{'ready'} );
        return 1;

    }

    $log->debug(
        sprintf( 'Queue size more than limit',
            $#{ $self->{'commands_queue'} } )
    );
    return 0;

}

sub restart_line_counter($self) {
    $self->{commands_sent} = 1;
    $self->{'commands_ok_recv'} = 0;

    $self->{'printer_handle'}->push_write(sprintf('%s%s', $self->_buid_command('M110 N0'), $line_separator));
    $line_number = 0; #Set 0 
}

1;

