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

## TODO: rename to correct name once js is complete
sub intranet_js {
    return q|
$(document).ready(function() {
    const smartpayButton = `<input style="margin-left: 5px" type="submit" id="pay-selected-via-smartpay" name="pay_via_smartpay" value="Pay via SmartPAY" class="submit"> 
  <div class="modal fade" id="smartpayModal" role="dialog">
    <div class="modal-dialog">    
      <div class="modal-content">
        <div class="modal-header">
          <h4 id="smartpay-title" class="modal-title">Comprise SmartPAY processing</h4>
        </div>
        <div id="smartpay-body" class="modal-body">
          Payment in progress...
        </div>
        <div class="modal-footer">
          <button id="smartpay-cancel" type="button" class="btn btn-default">Cancel</button>
        </div>
      </div>
    </div>
  </div>`;
    $(smartpayButton).insertAfter('#writeoff-selected');

    $('.cb').on("change", function() {
        if ($('.cb:checkbox:checked').length > 0) {
            $('#pay-selected-via-smartpay').removeAttr("disabled");
        } else {
            $('#pay-selected-via-smartpay').attr("disabled", "disabled");
        }
    });

    $("#pay-selected-via-smartpay").on("click", function(e) {
        e.preventDefault();

        let accountline_ids = [];
        $(".cb:checked").each(function() {
            const id = $(this).attr("name").split("_")[2];
            accountline_ids.push(id);
        });

        const accountlines = encodeURIComponent(accountline_ids.join());

        const debit_url = `http://192.168.1.20:8081/api/v1/contrib/smartpay/get_debits/${accountlines}`;
        $.getJSON(debit_url, function(data) {
            const total = data.total;
            let amount = prompt("Enter amount to collect", total);
            if (amount != null) {
                const regex = /^\d*(\.\d{1,2})?\s*$/;
                if (regex.test(amount)) {
                    //Start pay station
                    function getCookie(name) {
                        let value = `; ${document.cookie}`;
                        let parts = value.split(`; ${name}=`);
                        if (parts.length === 2) return parts.pop().split(';').shift();
                    }
                    amount = encodeURIComponent(amount * 100); // Periods asplode things, so we send the amount in cents
                    const send_transaction_url = `/api/v1/contrib/smartpay/send_transaction/${accountlines}/${amount}`;
                    $.getJSON(send_transaction_url, function(data) {
                        if (data.ret == 0) {
                            $('#smartpayModal').modal({
                                backdrop: 'static',
                                keyboard: false
                            });
                            const tracknumber = data.tracknumber;
                            const query_result_url = `/api/v1/contrib/smartpay/query_result/${tracknumber}`;
                            let myVar = setInterval(myTimer, 1000);

                            $('#smartpay-cancel').on('click', function() {
                                clearInterval(myVar);

                                const cancel_transaction_url = `/api/v1/contrib/smartpay/end_transaction_cancel/${tracknumber}/${amount}`;
                                $.getJSON(cancel_transaction_url, function(data) {
                                    console.log(data);

                                    $('#smartpayModal').modal('hide');

                                    if (data.ret == 1) {
                                        alert("ERROR ENDING TRANSACTION: " + data.error);
                                    }
                                });
                            });


                            function myTimer() {
                                $.getJSON(query_result_url, function(data) {
                                    console.log(data);
                                    if (data.status == "Failed") {
                                        $('#smartpayModal').modal('hide');
                                        clearInterval(myVar);
                                        alert("Transaction Canceled");
                                    }
                                    if (data.status == "Canceled") {
                                        $('#smartpayModal').modal('hide');
                                        clearInterval(myVar);
                                        alert("Transaction Canceled");
                                    }
                                    if (data.status == "Success") {
                                        $('#smartpayModal').modal('hide');
                                        clearInterval(myVar);
                                        const end_transaction_url = `/api/v1/contrib/smartpay/end_transaction/${tracknumber}/${accountlines}/${amount}`;
                                        $.getJSON(end_transaction_url, function(data) {
                                            if (data.ret == 1) {
                                                $('#smartpayModal').modal('hide');
                                                alert("ERROR ENDING TRANSACTION: " + data.error);
                                            } else {
                                                //const get_receipt_url = `/api/v1/contrib/smartpay/get_receipt/${tracknumber}`;
                                                const get_receipt_url = `/cgi-bin/koha/members/printfeercpt.pl?action=print&accountlines_id=${data.payment_id}`;
                                                window.open(get_receipt_url, "Receipt", 'width=600,height=600,resizable=yes,toolbar=false,scrollbars=yes,top');
                                            }
                                        });
                                    }
                                });
                            }
                        } else {
                            alert("ERROR: " + data.error);
                        }
                    });
                } else {
                    alert(`The amount "${amount}" is invalid. Please specify as a currency format ( e.g. 1.00 )`);
                }
            }
        });

    });

});
|;
}

sub install {
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
