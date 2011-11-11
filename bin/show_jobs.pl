#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  show_queue.pl
#
#        USAGE:  ./show_queue.pl  
#
#      COMPANY:  Broadbean
#      CREATED:  09/11/11 14:18:21
#     REVISION:  $Id$ 
#===============================================================================

use strict;
use warnings;
use Resque;
use JSON::XS;
use XML::Simple;
use Getopt::Long;

!caller && &main;

sub main {
    my %args       = &args;
    my $queue_name = $args{qname};
    my $from       = $args{from};
    my $resque     = Resque->new;
    my $client     = $resque->new_client;
    my $redis      = $resque->redis;
    my $key        = "resque:$queue_name";
    my $till       = $args{till} || $redis->llen($key);
    my @jobs_json  = $redis->lrange($key, $from, $till);
    my $jobs_hash  = decode_json(sprintf "[%s]", join ",", @jobs_json);
    print XMLout($jobs_hash, rootname => "Jobs", xmldecl => '<?xml version="1.0" encoding="iso-8859-1"?>', NoEscape => 0);
}

sub args {
    my %args = (
          qname => "failed"
        , from  => 0
        , till  => 999 
    );
    GetOptions(
          "qname=s" => \$args{qname}
        , "from=i"  => \$args{from}
        , "to=i"    => \$args{till}
    );
    return %args;
}
