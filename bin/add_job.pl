#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  add_job.pl
#
#        USAGE:  ./add_job.pl  
#
#      COMPANY:  Broadbean
#      CREATED:  09/11/11 15:37:41
#     REVISION:  $Id$ 
#===============================================================================

use strict;
use warnings;
use Resque;
use Getopt::Long;

!caller && &main;

sub main {
    my %args = &args;
    my $client = $args{client};
    $client->push($args{qname}, $args{class_name} => [$args{data}]);
}

sub args {
    my $resque = Resque->new;
    my %args = (
          resque => $resque
        , client => $resque->new_client
        , qname  => "UntitledQueue" 
        , data   => 1
    );
    GetOptions(
          "qname=s" => \$args{qname}
        , "cname=s" => \$args{class_name}
        , "data=s"  => \$args{data}
    ); 
    return %args;
}
