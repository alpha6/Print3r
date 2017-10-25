Yet another 3d-printer control tool.

TravisCI: [![Build Status](https://travis-ci.org/alpha6/Print3r.svg?branch=master)](https://travis-ci.org/alpha6/Print3r)
kritika.io: [![Kritika Analysis Status](https://kritika.io/users/alpha6/repos/1636900371975369/heads/master/status.svg)](https://kritika.io/users/alpha6/repos/1636900371975369/heads/master/)

The early prototype!


Dependencies:

    perl-5.20 or more
    libreadline-dev (for cli.pl)


How to use:

* **master.pl** - the main process to manage workers and CLI interface (and the web in future).
* **cli.pl** - CLI interface.
* **worker.pl** - worker. Started by the master process.


CLI commands:

* **connect --port <serialPort> --speed <port_speed>** - by default the port is */dev/ttyUSB0* and speed is *115200*
* **print --file <path/to/file.gcode>** - prints g-code file on the first connected printer (yes it is a current limit for the prototype for now).
* **pause** - pause printing
* **stop** - stop printing
* **disconnect** - stop printing and shutdown the worker
* **exit** - exit from CLI
* **status** - show list of connected workers
* **Any G-code command** - any g-code command from [RepRap wiki](http://reprap.org/wiki/G-code).


