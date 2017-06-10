requires 'AnyEvent';
requires 'AnyEvent::Handle';
requires 'AnyEvent::Socket';
requires 'IPC::Open2';
requires 'JSON';
requires 'Log::Log4perl';
requires 'Try::Tiny';
requires 'Getopt::Long';
requires 'AnyEvent::ReadLine::Gnu';
requires 'Device::SerialPort';
requires 'Carp';

on test => sub {
    requires 'Test::More';
    requires 'Test::Deep';
};