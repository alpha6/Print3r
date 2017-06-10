package print3r::Commands::Master;

use v5.20;
use feature qw(signatures);
no warnings qw(experimental::signatures);

use Try::Tiny;
use IPC::Open2;

our $VERSION = version->declare("v0.0.1");

my $log = undef;

sub new {
    my $class = shift;
    $log = shift;

    bless {}, $class;
}

#Spawn worker which will be speak with printer
sub connect ($port = '/dev/ttyUSB0', $speed = 115200) {
    #Spawn new worker
        my ( $chld_out, $chld_in );
        my $pid;
        try {
            $pid = open2(
                $chld_out, $chld_in, './worker.pl',
                '-p=' . $port,
                '-s=' . $speed
            );
        } catch {
            $log->error("Worker spawn error: $_");
            
                return sprintf( 'Worker spawn error: %s', $_ );
            
        }

        $workers{$pid} = { chld_in => $chld_in, chld_out => $chld_out };
        return sprintf( 'Worker started with pid [%s]', $pid );
}

# Send workers list to CLI
# TODO: should return JSON
sub status (%connections) {
        my $reply_str = "Active workers:\n";

        for my $key ( keys %connections ) {
            $reply_str .= sprintf(
                "worker [%d] connected to port [%s]\n",
                $connections{$key}{'pid'},
                $connections{$key}{'port'}
            );
        }

        return $reply_str;
}

# Send RAW G-Code to printer
sub send ($printer_handler, $is_user_command = 0) {
    
            $printer_handler->push_write(
                json => {
                    command => 'send',
                    params  => { value => $data->{'value'} }
                }
            );
}

# Print file
sub print ($printer_handler) {
    $printer_handler->push_write( json =>
              { command => 'print', params => { file => $data->{'file'} } } );
}

# Pause current print
sub pause ($printer_handler) {
    $printer_handler->push_write( json => { command => 'pause', params => {} } );
}

# resume paused print
sub resume ($printer_handler) {
    $printer_handler->push_write( json => { command => 'resume', params => {} } );
}

# Disconnect from printer and shutdown worker
sub disconnect ($printer_handler) {
    $printer_handler->push_write(
            json => { command => 'disconnect', params => {} } );
}

# Stop current print
sub stop ($printer_handler) {
    $printer_handler->push_write(
            json => { command => 'stop', params => {} } );
}

1;