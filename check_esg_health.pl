#!/usr/bin/perl -w 
#===============================================================================
# Script Name   : check_esg_health.pl
# Usage Syntax  : check_esg_health.pl [-v] -U <User> -P <Password> -H <Host> -N <Name> [-S] [-B <List>]
# Author        : Start81 (DESMAREST JULIEN)
# Version       : 1.1.0
# Last Modified : 22/05/2023 
# Modified By   : Start81 (DESMAREST JULIEN)
# Description   : Get esg health via nsx rest api
# Depends On    : REST::Client,Data::Dumper,Getopt::Long,MIME::Base64,LWP::UserAgent,IO::Socket::SSL
#
# Changelog:
#    Legend:
#       [*] Informational, [!] Bugfix, [+] Added, [-] Removed
#
# - 08/04/2021 | 1.0.0 | [*] initial realease
# - 11/01/2022 | 1.0.1 | [!] use strict and bug fix when using blacklist
# - 07/02/2022 | 1.0.2 | [!] Bug fix when parsing vm state
# - 22/05/2023 | 1.1.0 | [+] force critical flag and remove check on activeVseHaIndex
#===============================================================================
use strict;
use warnings;
use REST::Client;
use Data::Dumper;
use JSON;
use Getopt::Long;
use MIME::Base64;
use LWP::UserAgent;
use IO::Socket::SSL;
use Readonly;
use File::Basename;
my $o_verb;
my $o_login;
my $o_mdp;
my $o_host;
my $o_blacklist = q{};
my $o_ssl;
my $o_fcritical;
my $o_name;
my $o_help;
my $client;
my $ua;
my $msg = q{};
my $tmp;
my %errors=('OK'=>0,'WARNING'=>1,'CRITICAL'=>2,'UNKNOWN'=>3);
Readonly our $VERSION => '1.1.0';
my %services= ('routing' => 'Applied', 'sslvpn' => 'up', 'ipsec' => 'up', 'syslog' => 'up', 'highAvailability' => 'up', 'firewall' => 'Applied', 'nat' => 'Applied');
sub verb { my $t=shift; if ($o_verb) {print $t,"\n"}  ; return 0}
sub print_usage {
    my $name = basename($0);
    print "Usage: $name [-v] -U <User> -P <Password> -H <Host> -N <Name> [-S] [-F] [-B <List>]\n";
    return 0
}

sub help {
    print "check_esg_health " . $VERSION . "\n";
    print_usage();
    print <<'EOT'; 
-v, --verbose
    print extra debugging information
-h, --help
    print this help message
-S  --SSL 
    Use SSL
-H, --Host=<Host> 
    Hostname or IP of the nsx server 
-U, --User=<User> 
    User for webservice authentication
-P,--Password=<Password>
    Password for webservice authentication 
-N --Name=<Name>
    Name of the edge to check 
-B --Blacklist=<List>
    list of service to ignore ex sslvpn, ipsec, nat, routing, syslog, highAvailability, firewall, routing
-F --Forcecritical
    Force critical state when edge status is yellow
EOT
return 0;
}
sub check_options {
    Getopt::Long::Configure ("bundling");
    GetOptions(
        'v' => \$o_verb, 'verbose' => \$o_verb,
        'h' => \$o_help, 'help' => \$o_help,
        'S' => \$o_ssl, 'SSL' => \$o_ssl,
        'F' => \$o_fcritical, 'Forcecritical' => \$o_fcritical,
        'H:s' => \$o_host, 'Host:s' => \$o_host,
        'N:s' => \$o_name, 'Name:s' => \$o_name,
        'U:s' => \$o_login, 'User:s' => \$o_login,
        'P:s' => \$o_mdp, 'Password:s' => \$o_mdp,
        'B:s' => \$o_blacklist, 'Blacklist:s' => \$o_blacklist,
        );
    if (defined  $o_help ) { help; exit $errors{"UNKNOWN"}};
    if (!defined $o_host ){
        print "hostname or ip missing\n"; 
        print_usage(); 
        exit $errors{"UNKNOWN"};
    }
    if (!defined $o_name ){ 
        print "esg name missing\n"; 
        print_usage(); 
        exit $errors{"UNKNOWN"};
    }

    if (!defined $o_login){ 
        print "User name missing\n"; 
        print_usage(); 
        exit $errors{"UNKNOWN"};
    }
    if (!defined $o_mdp ) {
        print "Password missing\n";
        print_usage();
        exit $errors{"UNKNOWN"};
    }

}

check_options();
my $url;
if (defined($o_ssl)) {
    $ua = LWP::UserAgent->new(
        timeout  => 30,
        ssl_opts => {
            verify_hostname => 0,
            SSL_verify_mode => IO::Socket::SSL::SSL_VERIFY_NONE,
        },
    );
    $client = REST::Client->new({useragent => $ua});
    $url = "https://" . $o_host . "/api/4.0/edges/";
} else {
    $client = REST::Client->new(timeout  => 30);
    $url = "http://" . $o_host . "/api/4.0/edges/";
}
my $b64_auth = encode_base64($o_login .':'. $o_mdp);
verb($b64_auth);
$client->addHeader('Content-Type', 'application/json;charset=utf8');
$client->addHeader('Accept', 'application/json');
$client->addHeader('Authorization','Basic ' . $b64_auth);
$client->addHeader('Accept-Encoding',"gzip, deflate, br");
verb($url);
$client->GET($url);
if( $client->responseCode() ne '200'){
    print "UNKNOWN response code : " . $client->responseCode() . " Error when executing query\n";
    print $client->{_res}->decoded_content;
    exit $errors{'UNKNOWN'};
}
my $rep = $client->{_res}->decoded_content;
my $response_lst_json = from_json($rep);
#verb(Dumper($response_lst_json));
my $i = 0;
while ((exists $response_lst_json->{'edgePage'}->{data}->[$i])&&($response_lst_json->{'edgePage'}->{data}->[$i]->{'name'} ne $o_name)){
   $i++;
}
if (!exists $response_lst_json->{'edgePage'}->{data}->[$i]){
    print "UNKNOWN " . $o_name . " Not found";
    exit $errors{'UNKNOWN'}; ;
}
my $edge = $response_lst_json->{'edgePage'}->{data}->[$i]->{'objectId'} ;
$url = $url . $edge . "/status?detailed";
verb($url);

$client->GET($url);
if( $client->responseCode() ne '200'){
    print "UNKNOWN response code : " . $client->responseCode() . " Error when executing query\n";
    print $client->{_res}->decoded_content;
    exit $errors{'UNKNOWN'};
}
$rep = $client->{_res}->decoded_content;
my $response_edge_json = from_json($rep);
verb(Dumper($response_edge_json));
#states 
my @criticals;
my @warnings;
my @ok ; 
#If edgeStatus is RED None of the appliances for this NSX Edge are in a serving state. we can exit now
if ($response_edge_json->{'edgeStatus'} eq 'RED') {
    #push @criticals, "edgeStatus is RED";
    print "CRITICAL " . $o_name . " edgeStatus is RED";
    exit $errors{'CRITICAL'};
}

if ($response_edge_json->{'edgeStatus'} eq 'YELLOW') {
    push @warnings, "edgeStatus is YELLOW";
}
if ($response_edge_json->{'edgeStatus'} eq 'GREEN') {
    push @ok, "edgeStatus is GREEN";
}
#if ($response_edge_json->{'activeVseHaIndex'} eq '1') {
#    push @warnings, "Active vm " . $response_edge_json->{'edgeVmStatus'}->[1]->{'name'};
#}

#Vm states
$i = 0;
while ((exists $response_edge_json->{'edgeVmStatus'}->[$i])){
    if ($response_edge_json->{'edgeVmStatus'}->[$i]->{edgeVMStatus} eq 'GREEN'){
        push @ok, "vm Name " . $response_edge_json->{'edgeVmStatus'}->[$i]->{'name'} . " OK";
    } elsif ($response_edge_json->{'edgeVmStatus'}->[$i]->{edgeVMStatus} eq 'YELLOW') {
        push @warnings, "vm Name " . $response_edge_json->{'edgeVmStatus'}->[$i]->{'name'} . " YELLOW State";
    } else {
        push @criticals, "vm Name " . $response_edge_json->{'edgeVmStatus'}->[$i]->{'name'} . "State " .$response_edge_json->{'edgeVmStatus'}->[1]->{edgeVMStatus};
    }
   $i++;
}
#esg services States
$i = 0;
my $service;
while ((exists $response_edge_json->{'featureStatuses'}->[$i])){
    $service = $response_edge_json->{'featureStatuses'}->[$i]->{'service'};
    if (exists $services{$service} ){
        #Not in blacklist
        if (index($o_blacklist,$service) == - 1) {
            if ($services{$service} ne $response_edge_json->{'featureStatuses'}->[$i]->{'status'}){
                push @criticals, "service " . $service  . " is " . $response_edge_json->{'featureStatuses'}->[$i]->{'status'};
            } else {
                push @ok, "service " . $service  . " is " . $response_edge_json->{'featureStatuses'}->[$i]->{'status'};
            }
        }
    }
$i++;
}
if (scalar @criticals > 0) {
    $tmp = join(', ', @criticals);
    print "CRITICAL $o_name $tmp\n";
    exit $errors{'CRITICAL'};
}
if (defined $o_fcritical){
    if (scalar @warnings > 0) {
        $tmp = join(", ", @warnings);
        print "CRITICAL $o_name $tmp\n";
        exit $errors{'CRITICAL'};
    }
} else {
    if (scalar @warnings > 0) {
        $tmp = join(", ", @warnings);
        print "WARNING  $o_name  $tmp\n";
        exit $errors{'WARNING'};;
    }
}

$tmp = join(", ", @ok);
print "OK $o_name  $tmp\n";

