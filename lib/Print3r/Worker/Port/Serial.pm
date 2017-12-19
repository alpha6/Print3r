package Print3r::Worker::Port::Serial;

use strict;
use warnings;
use feature qw(signatures);
no warnings qw(experimental::signatures);

our $VERSION = version->declare('v0.0.1');

use Carp;
use IO::Termios;

use Fcntl;
use POSIX qw(:termios_h);
use IO::Handle;

# use constant CRTSCTS => 020000000000;

use constant SPACE => q{ };

sub connect ( $class, $device_port, $port_speed ) {



    my $stty = IO::Termios->open($device_port);
    # my $mode = sprintf('%s,8,n,1', $port_speed);
    # # say STDERR "mode: [$mode]";
    # $stty->set_mode($mode);
    # $stty->setflag_echo( 0 );

    my @params = qw( 115200 -parenb -parodd -cmspar cs8 hupcl -cstopb cread clocal -crtscts
    ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel -iutf8
    -opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
    -isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke -flusho -extproc
        );

    my $command = sprintf('stty -F %s %s', $device_port, join(SPACE, @params));

    print STDERR "stty call: $command\n";

    system ($command);
    print "device: $device_port\n";
    return $stty;

    # sysopen( USB, $device_port, O_RDWR  ) || die "failed to open $! \n";

    # my $term = POSIX::Termios->new();
    # $term->getattr( fileno(USB) ) || die("Failed getattr: $!");
    # my $echo = $term->getlflag();

    # print sprintf('%b',$echo)."\n";
    # $echo &= ~ECHO;
    # $echo &= ~ECHOK;
    # $echo &= ~ECHOE;
    # $echo &= ~ECHONL;

    # print sprintf('%b',$echo)."\n";
    # $term->setlflag($echo);
    # print sprintf('%b',$term->getlflag())."\n";

    # # my $c_flag = $term->getcflag();
    # # $c_flag &= ~PARENB;
    # # $c_flag &= ~CSTOPB;
    # # $c_flag &= ~CSIZE;
    # # # $c_flag &= ~CRTSCTS;
    # # $c_flag |= CS8;

    # # $term->setcflag($c_flag);

    # $term->setcflag(
    #     &POSIX::CS8 | &POSIX::CREAD | &POSIX::CLOCAL | &POSIX::HUPCL );
    # $term->setiflag(~&POSIX::IGNBRK);

    # $term->getattr( fileno(USB) ) || die("Failed getattr: $!");
    # $term->setospeed(4098);
    # $term->setispeed(4098);
    # $term->setattr( fileno(USB), TCSANOW ) || die "Failed setattr: $!";

    # # sleep 30;

    # return IO::Termios->new(\*USB);
}

1;

__END__

http://hasyweb.desy.de/services/computing/perl/node138.html
https://docstore.mik.ua/orelly/perl/prog3/ch32_36.htm
https://www.cmrr.umn.edu/~strupp/serial.html

=head1 minicom port params

alpha6@orangepizero:~$ stty -F /dev/ttyACM0 -a
speed 115200 baud; rows 0; columns 0; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>; eol2 = <undef>; swtch = <undef>; start = ^Q; stop = ^S; susp = ^Z; rprnt = ^R; werase = ^W; lnext = ^V; discard = ^O;
min = 1; time = 5;
-parenb -parodd -cmspar cs8 hupcl -cstopb cread clocal crtscts
ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr -icrnl -ixon -ixoff -iuclc -ixany -imaxbel -iutf8
-opost -olcuc -ocrnl -onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
-isig -icanon -iexten -echo -echoe -echok -echonl -noflsh -xcase -tostop -echoprt -echoctl -echoke -flusho -extproc

=head1 Print3r port params

alpha6@orangepizero:~$ stty -F /dev/ttyACM0 -a
speed 115200 baud; rows 0; columns 0; line = 0;
intr = ^C; quit = ^\; erase = ^?; kill = ^U; eof = ^D; eol = <undef>; eol2 = <undef>; swtch = <undef>; start = ^Q; stop = ^S; susp = ^Z; rprnt = ^R; werase = ^W; lnext = ^V; discard = ^O;
min = 1; time = 0;
-parenb -parodd -cmspar cs8 hupcl -cstopb cread clocal -crtscts
-ignbrk -brkint -ignpar -parmrk -inpck -istrip -inlcr -igncr icrnl ixon -ixoff -iuclc -ixany -imaxbel -iutf8
opost -olcuc -ocrnl onlcr -onocr -onlret -ofill -ofdel nl0 cr0 tab0 bs0 vt0 ff0
isig icanon iexten -echo echoe echok -echonl -noflsh -xcase -tostop -echoprt echoctl echoke -flusho -extproc
