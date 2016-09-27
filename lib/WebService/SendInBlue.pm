use strict;
use warnings;

package WebService::SendInBlue;

use HTTP::Request;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use IO::Socket::INET;
use URI::Query;

# ABSTRACT: Perl API to SendInBlue rest api

our $API_BASE_URI = 'https://api.sendinblue.com/v2.0/';

sub new {
    my ($class, %args) = @_;

    die "api_key is mandatory" unless $args{'api_key'};

    my $debug = $args{'debug'} || $ENV{'SENDINBLUE_DEBUG'} || 0;

    return bless { api_key => $args{'api_key'}, debug => $debug }, $class;
}

sub lists {
    my ($self, %args) = @_;

    return $self->_make_request("list", 'GET', params => \%args);
} 

sub lists_users {
    my ($self, %args) = @_;

    $args{'listids'} = delete $args{'lists_ids'};

    return $self->_make_request("list/display", 'POST', params => \%args);
} 

sub campaigns {
    my ($self, %args) = @_;
    return $self->_make_request("campaign/detailsv2", 'GET', params => \%args);
}

sub campaign_details {
    my ($self, $campaign_id) = @_;
    return $self->_make_request(sprintf("campaign/%s/detailsv2", $campaign_id), 'GET');
}

sub campaign_recipients {
    my ($self, $campaign_id, $notify_url, $type) = @_;
    my %params = ( type => $type, notify_url => $notify_url );
    return $self->_make_request(sprintf("campaign/%s/recipients", $campaign_id), 'POST', params => \%params);
}

sub campaign_recipients_file_url{
    my ($self, $campaign_id, $type) = @_;

    my $inbox = $self->ua->post("http://api.webhookinbox.com/create/");
    die "Inbox request failed" unless $inbox->is_success;

    $self->log($inbox->decoded_content);
    sleep(1);

    my $inbox_data = decode_json($inbox->decoded_content);
    my $inbox_url  = $inbox_data->{'base_url'};

    my $req = $self->campaign_recipients( $campaign_id, $inbox_url."/in/", $type );
    return $req unless $req->{'code'} eq 'success';

    my $process_id = $req->{'data'}->{'process_id'};

    my $max_wait = 10;
    for (my $i=0; $i <= $max_wait; $i++) {
        # Get inbox items
        my $items = $self->ua->get($inbox_url."/items/?order=-created&max=20");
        die "Inbox request failed" unless $items->is_success;

        $self->log($items->decoded_content);

        my $items_data = decode_json($items->decoded_content);
        for my $i (@{$items_data->{'items'}}) {
            my %data = URI::Query->new($i->{'body'})->hash;
            $self->log(Dumper(\%data));

            next unless $data{'proc_success'} == $process_id;

            return { 'code' => 'success', 'data' => $data{'url'} }; 
        }

        sleep(10);
    }
    die "Unable to wait more for the export file url";
}

sub smtp_statistics {
    my ($self, %args) = @_;
    return $self->_make_request("statistics", 'POST', params => \%args);
}

sub processes {
    my ($self, %args) = @_;
    return $self->_make_request("process", 'GET', params => \%args);
}

sub _make_request {
    my ($self, $uri, $method, %args) = @_;
    
    my $req = HTTP::Request->new();

    $req->header('api-key' => $self->{'api_key'});
    $req->header('api_key' => $self->{'api_key'});
    $req->method($method);
    $req->uri($API_BASE_URI.$uri);

    if ( $args{'params'} ) {
        $req->content(encode_json($args{'params'}));
        $self->log(encode_json($args{'params'}));
    }

    my $resp = $self->ua->request($req);

    $self->log(Dumper($resp->content));

    my $json = decode_json($resp->content());

    $self->log(Dumper($json));
    return $json;
}

sub ua {
    my $self = shift;

    return LWP::UserAgent->new();
}

sub log {
    my ($self, $line) = @_;

    return unless $self->{'debug'};

    print STDERR "[".ref($self)."] $line\n";
}

1;
