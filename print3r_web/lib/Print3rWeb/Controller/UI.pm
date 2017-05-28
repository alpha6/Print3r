package Print3rWeb::Controller::Ui;
use Mojo::Base 'Mojolicious::Controller';

sub main {
	my $self = shift;

  	# Render template "example/welcome.html.ep" with message
  	$self->render(msg => 'Index');
}

sub settings {
	my $self = shift;

	$self->render(msg => "Settings page");
}

1;