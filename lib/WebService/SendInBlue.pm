use strict;
use warnings;

package WebService::SendInBlue;

use HTTP::Request;
use LWP::UserAgent;
use JSON;
use Data::Dumper;
use IO::Socket::INET;

# ABSTRACT: Perl API to SendInBlue rest api

our $API_BASE_URI = 'https://api.sendinblue.com/v2.0/';

sub new {
    my ($class, %args) = @_;

    die "api_key is mandatory" unless $args{'api_key'};

    return bless { api_key => $args{'api_key'} }, $class;
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

    my $ua = new LWP::UserAgent();
    my $ip = $ua->get('http://ipv4bot.whatismyipaddress.com/')->content;

    my $socket = IO::Socket::INET->new(
	LocalHost => "0.0.0.0", 
        LocalPort => "2888",
	Proto     => "tcp",
        Listen    => 15,
        Timeout   => 600,
        Reuse     => 1,
    ) || die "$@";
    
    my $req = $self->campaign_recipients( $campaign_id, "http://$ip:2888", $type );
    return $req unless $req->{'code'} eq 'success';
    
    my $client_socket = $socket->accept();
    my $client_address = $client_socket->peerhost();
    my $client_port = $client_socket->peerport();

    #print "connection from $client_address:$client_port\n";

    my @recv_data = $socket->getlines();
    #print STDERR "**** @recv_data ****\n";

    my $buf;
    $socket->recv($buf, 1024);
    my $message = "";
    while (length($buf) > 0) {
     $message .= $buf;
     $socket->recv($buf, 1024, MSG_DONTWAIT);
    }
    #print STDERR "*** $message ****";
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
    }

    my $resp = $self->ua->request($req);

    #print STDERR Dumper($resp->content);
    my $json = decode_json($resp->content());

    #print STDERR Dumper($json);
    return $json;
}

sub ua {
    my $self = shift;

    return LWP::UserAgent->new();
}

1;
