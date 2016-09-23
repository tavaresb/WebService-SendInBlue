use Test::More tests => 1;
use Test::Exception;
use IO::Socket::INET;
use LWP::UserAgent;

require_ok( 'WebService::SendInBlue' );

my $a = WebService::SendInBlue->new('api_key'=> $ENV{'SENDINBLUE_API_KEY'});
#$a->campaigns( page_limit=>1, page=>1 );
#$a->smtp_statistics( aggregate=>0, days=>100);


print STDERR "***** $ip *****\n";

my $socket = IO::Socket::INET->new(PeerAddr => "$ip:55555", Proto=>'tcp');

$a->campaign_recipients( 14, "http://$ip:55555", 'all' );

my $recv_data = "";
$socket->recv($recv_data,10);
print STDERR $recv_data;

#$a->processes();
