package Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API;

# This file is part of Koha.
#
# Koha is free software; you can redistribute it and/or modify it under the
# terms of the GNU General Public License as published by the Free Software
# Foundation; either version 3 of the License, or (at your option) any later
# version.
#
# Koha is distributed in the hope that it will be useful, but WITHOUT ANY
# WARRANTY; without even the implied warranty of MERCHANTABILITY or FITNESS FOR
# A PARTICULAR PURPOSE.  See the GNU General Public License for more details.
#
# You should have received a copy of the GNU General Public License along
# with Koha; if not, write to the Free Software Foundation, Inc.,
# 51 Franklin Street, Fifth Floor, Boston, MA 02110-1301 USA.

use Modern::Perl;

use Mojo::Base 'Mojolicious::Controller';

use HTTP::Request::Common;
use JSON qw( to_json );
use YAML qw( Load );

use C4::Context;

=head1 API

=head2 Class Methods

=head3 Returns TwiML for the given message

=cut

sub get_debits {
    warn "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::get_debits";
    my $c = shift->openapi->valid_input or return;

    my $accountline_ids = $c->param('accountlines');
    warn "IDS: $accountline_ids";

    my @ids = split(/,/, $accountline_ids );

    my $accountlines = Koha::Account::Lines->search({ accountlines_id => \@ids } )->unblessed;

    my $total = 0;
    $total += $_->{amountoutstanding} for @$accountlines;
    $total = Koha::Number::Price->new( $total )->format_for_editing;

    my $json = to_json( { total => $total, accountlines => $accountlines } );

    return $c->render( status => 200, format => "json", text => $json );
}

sub send_transaction {
    warn "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::send_transaction";
    my $c = shift->openapi->valid_input or return;

    my $accountline_ids = $c->param('accountlines');
    my $amount = $c->param('amount') / 100; # Periods asplode things, so we recieve the amount in cents
    warn "AMOUNT: $amount";
    warn "IDS: $accountline_ids";

    my @ids = split(/,/, $accountline_ids );

    my $self = Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY->new({});

    my $CustomerId      = $self->retrieve_data('CustomerId');
    my $CustomerName    = $self->retrieve_data('CustomerName');
    my $UserName        = $self->retrieve_data('UserName');
    my $Password        = $self->retrieve_data('Password');
    my $ApiKey          = $self->retrieve_data('ApiKey');
    my $ServerIP        = $self->retrieve_data('ServerIP');
    my $ServerAddress   = $self->retrieve_data('ServerAddress');
    my $RegisterMapping = $self->retrieve_data('RegisterMapping');

    my $mapping = Load( $RegisterMapping );

    my $register_id = C4::Context->userenv->{register_id};

    my $terminal_id = $mapping->{$register_id};
    return $c->render( status => 404, format => "json", json => { error => "TERM", description => "Terminal mapping for register $register_id found" } ) unless $terminal_id;

    my $json = to_json( { amount => $amount });

    return $c->render( status => 200, format => "json", text => $json );
}

sub amd_callback {
    warn "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::amd_callback";
    my $c = shift->openapi->valid_input or return;
    return try {

        my $message_id = $c->validation->param('message_id');
        return $c->render( status => 204, text => q{} );
    }
    catch {
        warn "CAUGHT UNHANDLED ERROR: $_";
        $c->unhandled_exception($_);
    }
}

1;
