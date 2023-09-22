## check_esg_health

check vmware esg health via nsx rest api [PERL]

### prerequisites

This script uses theses libs : REST::Client,Data::Dumper,Getopt::Long,MIME::Base64,LWP::UserAgent,IO::Socket::SSL 

to install them you can use cpan :

```
sudo cpan REST::Client Data::Dumper Getopt::Long MIME::Base64 LWP::UserAgent IO::Socket::SSL
```

### Use case

```Shell
check_esg_health 1.1.0
Usage: check_esg_health.pl [-v] -U <User> -P <Password> -H <Host> -N <Name> [-S] [-F] [-B <List>]
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
```

sample :

```Shell
check_esg_health.pl  -U Username -P Password -H MYNSX_IP_OR_FQDN -S -N EDGENAME -B sslvpn,ipsec,nat
```

you may get :

```Shell
OK EDGENAME vm Name EDGENAME-1 OK, vm Name EDGENAME-2 OK, service routing is Applied, service syslog is up, service highAvailability is up, service firewall is Applied
```

