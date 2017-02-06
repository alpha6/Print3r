package print3r::worker;

use v5.20;
our $VERSION = version->declare("v0.0.1");

use JSON;
use IO::Socket::INET;
use Data::Dumper;

sub new {
    my $class = shift;
    my $self = {};
    bless $self, $class;

    $self->{'handler'} = undef;
    return $self;
}

sub connect {
    my $self   = shift;
    my $adress = shift;
    my $port   = shift;

    use IO::Socket::INET;

    # auto-flush on socket
    $| = 1;

    # creating a listening socket
    my $socket = new IO::Socket::INET(
        PeerHost => $adress,
        PeerPort => $port,
        Proto     => 'tcp',
    );
    die "cannot create socket $!\n" unless $socket;
    print "server waiting for client connection on port 7777\n";

    $self->{'handler'} = $socket;

    return 1;
}

sub send {
    my $self = shift;
    my $msg  = shift;

    $self->{'handler'}->send( encode_json( { msg => $msg } ) );
    shutdown($self->{'handler'}, 1);
}

sub status {
    my $self   = shift;
    my $status = shift;

    $self->{'handler'}->send( encode_json( { status => $status } ) );
    shutdown($self->{'handler'}, 1);
}

sub read {
    my $self = shift;

    my $rbuf = '';
    $self->{'handler'}->read( $rbuf, 1024 );

    say $rbuf;

    eval { return decode_json($rbuf); };
    if ($@) {
        say "err: $@";
        return "";
    }
}

sub close {
    my $self = shift;
    $self->{'handler'}->close();
    undef $self;
}


1;
