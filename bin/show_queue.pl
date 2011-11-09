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

!caller && &main;

sub main {
    my $resque = Resque->new;
    my $client = $resque->new_client;
    my $redis  = $resque->redis;
    my @queues = $redis->smembers($resque->key('queues'));
    print join "\n", @queues, q{};
}

