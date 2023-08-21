package Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY;

use Modern::Perl;

use base qw(Koha::Plugins::Base);

use C4::Auth;
use C4::Context;
use Koha::Notice::Messages;

use HTTP::Request::Common;
use LWP::UserAgent;
use Mojo::JSON qw(decode_json);

## Here we set our plugin version
our $VERSION         = "{VERSION}";
our $MINIMUM_VERSION = "19.11.06";

## Here is our metadata, some keys are required, some are optional
our $metadata = {
    name            => 'Comprise SmartPAY Plugin',
    author          => 'Kyle M Hall',
    date_authored   => '2020-05-13',
    date_updated    => "1900-01-01",
    minimum_version => $MINIMUM_VERSION,
    maximum_version => undef,
    version         => $VERSION,
    description     => 'This plugin enables sending of phone message to patrons via Twilio.',
};

sub new {
    my ($class, $args) = @_;

    ## We need to add our metadata here so our base class can access it
    $args->{'metadata'} = $metadata;
    $args->{'metadata'}->{'class'} = $class;

    ## Here, we call the 'new' method for our base class
    ## This runs some additional magic and checking
    ## and returns our actual $self
    my $self = $class->SUPER::new($args);

    return $self;
}

sub configure {
    my ($self, $args) = @_;
    my $cgi = $self->{'cgi'};

    unless ($cgi->param('save')) {
        my $template = $self->get_template({file => 'configure.tt'});

        ## Grab the values we already have for our settings, if any exist
        $template->param(
            CustomerId      => $self->retrieve_data('CustomerId'),
            CustomerName    => $self->retrieve_data('CustomerName'),
            UserName        => $self->retrieve_data('UserName'),
            Password        => $self->retrieve_data('Password'),
            ApiKey          => $self->retrieve_data('ApiKey'),
            ServerIP        => $self->retrieve_data('ServerIP'),
            ServerAddress   => $self->retrieve_data('ServerAddress'),
            RegisterMapping => $self->retrieve_data('RegisterMapping'),
        );

        $self->output_html($template->output());
    }
    else {
        $self->store_data({
            CustomerId      => $cgi->param('CustomerId'),
            CustomerName    => $cgi->param('CustomerName'),
            UserName        => $cgi->param('UserName'),
            Password        => $cgi->param('Password'),
            ApiKey          => $cgi->param('ApiKey'),
            ServerIP        => $cgi->param('ServerIP'),
            ServerAddress   => $cgi->param('ServerAddress'),
            RegisterMapping => $cgi->param('RegisterMapping'),
        });
        $self->go_home();
    }
}

sub install() {
    my ($self, $args) = @_;

    return 1;
}

sub upgrade {
    my ($self, $args) = @_;

    return 1;
}

sub uninstall() {
    my ($self, $args) = @_;

    return 1;
}

sub api_routes {
    my ($self, $args) = @_;

    my $spec_str = $self->mbf_read('openapi.json');
    my $spec     = decode_json($spec_str);

    return $spec;
}

sub api_namespace {
    my ($self) = @_;

    return 'smartpay';
}

1;
