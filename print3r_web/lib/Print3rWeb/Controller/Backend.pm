package Print3rWeb::Controller::Backend;
use Mojo::Base 'Mojolicious::Controller';

sub events {
  my $c = shift;

  # Increase inactivity timeout for connection a bit
  $c->inactivity_timeout(300);

  # Change content type and finalize response headers
  $c->res->headers->content_type('text/event-stream');
  $c->write;

  # Subscribe to "message" event and forward "log" events to browser
  my $cb = $c->app->log->on(message => sub {
    my ($log, $level, @lines) = @_;
    $c->write("event:log\ndata: [$level] @lines\n\n");
  });

  # Unsubscribe from "message" event again once we are done
  $c->on(finish => sub {
    my $c = shift;
    $c->app->log->unsubscribe(message => $cb);
  });
};

1;
