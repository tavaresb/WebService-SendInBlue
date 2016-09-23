use Test::More tests => 2;
use Test::Exception;
use IO::Socket::INET;
use LWP::UserAgent;

require_ok( 'WebService::SendInBlue' );

SKIP: {
  skip "No API KEY", 1 unless $ENV{'SENDINBLUE_API_KEY'};

  my $a = WebService::SendInBlue->new('api_key'=> $ENV{'SENDINBLUE_API_KEY'});

  $campaigns_list = $a->campaigns();
  
  $a->campaign_recipients_file_url($campaigns_list->{'data'}{'campaign_records'}[-1]{'id'}, 'all');

}
