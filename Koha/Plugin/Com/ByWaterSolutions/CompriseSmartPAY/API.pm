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
use WWW::Form::UrlEncoded qw(parse_urlencoded);
use Try::Tiny;

=head1 API

=head2 Class Methods

=head3 Returns TwiML for the given message

=cut

sub twiml {
    warn "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::twiml";
    my $c = shift->openapi->valid_input or return;

    my $message_id = $c->validation->param('message_id');

    my $tw;

    return $c->render( status => 200, format => "xml", text => $tw->to_string );
}

sub update_message_status {
    warn "Koha::Plugin::Com::ByWaterSolutions::CompriseSmartPAY::API::update_message_status";
    my $c = shift->openapi->valid_input or return;

    my $message_id = $c->validation->param('message_id');

    return $c->render( status => 204, text => q{} );
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
