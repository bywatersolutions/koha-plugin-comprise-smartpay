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

use URI::Escape;
use HTTP::Request::Common;
use JSON qw( to_json );
use Mojo::JSON qw( decode_json );
use YAML qw( Load );

use C4::Context;

=head1 API

=head2 Class Methods

=head3 Returns TwiML for the given message

=cut

sub get_debits {
    warn
      "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::get_debits";
    my $c = shift->openapi->valid_input or return;

    my $accountline_ids = $c->param('accountlines');

    my @ids = split( /,/, $accountline_ids );

    my $accountlines =
      Koha::Account::Lines->search( { accountlines_id => \@ids } )->unblessed;

    my $total = 0;
    $total += $_->{amountoutstanding} for @$accountlines;
    $total = Koha::Number::Price->new($total)->format_for_editing;

    my $json = to_json( { total => $total, accountlines => $accountlines } );

    return $c->render( status => 200, format => "json", text => $json );
}

sub send_transaction {
    warn
"Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::send_transaction";
    my $c = shift->openapi->valid_input or return;

    my $accountline_ids = $c->param('accountlines');
    my $amount          = $c->param('amount') /
      100;    # Periods asplode things, so we recieve the amount in cents

    # Look up the patron from the first accountline
    my ($id)        = split( /,/, $accountline_ids );
    my $accountline = Koha::Account::Lines->find($id);
    my $cardnumber  = $accountline->patron->cardnumber;

    my $self = Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY->new( {} );

    my $CustomerId      = $self->retrieve_data('CustomerId');
    my $CustomerName    = $self->retrieve_data('CustomerName');
    my $UserName        = $self->retrieve_data('UserName');
    my $Password        = $self->retrieve_data('Password');
    my $ApiKey          = $self->retrieve_data('ApiKey');
    my $ServerIP        = $self->retrieve_data('ServerIP');
    my $ServerAddress   = $self->retrieve_data('ServerAddress');
    my $RegisterMapping = $self->retrieve_data('RegisterMapping');

    my $mapping = Load($RegisterMapping);

    my $register_id = C4::Context->userenv->{register_id};

    my $terminal_id = $mapping->{$register_id};
    return $c->render(
        status => 404,
        format => "json",
        json   => {
            error       => "TERM",
            description => "Terminal mapping for register $register_id found"
        }
    ) unless $terminal_id;

    my $header = HTTP::Headers->new;
    $header->header( 'Content-Type' => 'application/json; charset=utf-8' );
    $header->header( 'accept'       => 'application/json' );

    my $uuid = generate_uuid();
    my $content = {
        CustomerID => $CustomerId,
        TerminalID => $terminal_id,
        UserName   => $UserName,
        Password   => $Password,
        Amount     => $amount,
        TrackId    => $uuid,
        PatronId   => $cardnumber,
        Detail     => "Payment for fees",
    };
    my $params = join('&', map { "$_=" . uri_escape( $content->{$_} ) } keys %$content );

    my $url = "$ServerAddress?SendTransaction&$params";

    my $ua      = LWP::UserAgent->new;

    my $request = HTTP::Request::Common::GET(
        $url,
        Header  => $header,
    );
    my $response = $ua->request($request);

    unless ( $response->is_success ) {
        warn "Comprise SmartPAY response indicates failure: "
          . $response->status_line;
    }

    my $json = $response->decoded_content;

    return $c->render( status => 200, format => "json", text => $json );
}

sub query_result {
    warn
"Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::query_result";
    my $c = shift->openapi->valid_input or return;

    my $track_number = $c->param('tracknumber');

    my $self = Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY->new( {} );

    my $CustomerId      = $self->retrieve_data('CustomerId');
    my $UserName        = $self->retrieve_data('UserName');
    my $Password        = $self->retrieve_data('Password');
    my $ServerAddress   = $self->retrieve_data('ServerAddress');
    my $RegisterMapping = $self->retrieve_data('RegisterMapping');

    my $mapping = Load($RegisterMapping);

    my $register_id = C4::Context->userenv->{register_id};

    my $terminal_id = $mapping->{$register_id};
    return $c->render(
        status => 404,
        format => "json",
        json   => {
            error       => "TERM",
            description => "Terminal mapping for register $register_id found"
        }
    ) unless $terminal_id;

    my $header = HTTP::Headers->new;
    $header->header( 'Content-Type' => 'application/json; charset=utf-8' );
    $header->header( 'accept'       => 'application/json' );

    my $uuid = generate_uuid();
    my $content = {
        CustomerID => $CustomerId,
        TerminalID => $terminal_id,
        UserName   => $UserName,
        Password   => $Password,
        TrackNo    => $track_number,
    };
    my $params = join('&', map { "$_=" . uri_escape( $content->{$_} ) } keys %$content );

    my $url = "$ServerAddress?QueryResult&$params";

    my $ua      = LWP::UserAgent->new;

    my $request = HTTP::Request::Common::GET(
        $url,
        Header  => $header,
    );
    my $response = $ua->request($request);

    unless ( $response->is_success ) {
        warn "Comprise SmartPAY response indicates failure: "
          . $response->status_line;
    }

    my $json = $response->decoded_content;

    return $c->render( status => 200, format => "json", text => $json );
}

sub generate_uuid {
    my $uuid = '';
    for ( 1 .. 4 ) {
        $uuid .= pack 'I', int( rand( 2**32 ) );
    }

    substr $uuid, 6, 1, chr( ord( substr( $uuid, 6, 1 ) ) & 0x0f | 0x40 );

    return join '', map { unpack 'H*', $_ }
      map { substr $uuid, 0, $_, '' } ( 4, 2, 2, 2, 6 );
}

1;
