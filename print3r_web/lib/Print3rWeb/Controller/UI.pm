package Print3rWeb::Controller::Ui;
use Mojo::Base 'Mojolicious::Controller';

sub main {
	my $self = shift;

  	# Render template "example/welcome.html.ep" with message
  	$self->render(msg => 'Welcome to the Mojolicious real-time web framework!');
}

1;