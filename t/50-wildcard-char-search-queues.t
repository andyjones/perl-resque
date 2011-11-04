#
#===============================================================================
#
#         FILE:  50-wildcard-char-search-queues.t
#
#      COMPANY:  Broadbean
#      CREATED:  04/11/11 15:04:51
#     REVISION:  $Id$
#===============================================================================

use strict;
use warnings;

use Test::More tests => 2;                      # last test to print

use Resque;
use lib t => "t/30-bad-job";
use Resque::Cleanup;

my @cleaner;
my $resque = Resque->new;
SKIP: {
    skip "Tests require Redis server", 1 if ! $resque->ping;

    my $total_jobs = int(rand 5) || 1;

    foreach my $qnum(1..5) {
        my $qname = "TestQ-$qnum-$$";
        $cleaner[$qnum] = Resque::Cleanup->new($qname);
        my $client = $resque->new_client;
        for my $jnum(1..$total_jobs) {
            $client->push($qname, TestClass => ["Q$qnum-J$jnum"]);
        }
    }

    {
        my $worker = $resque->new_worker;
        $worker->queues("TestQ-1-$$");
        my $total_process = 0;
        $worker->work(sub{
            my $idle = shift;
            return 1 if $idle;
            $total_process++;
            return 0;
        });
        is($total_process, $total_jobs);
    }
    {
        my $worker = $resque->new_worker;
        my $total_process = 0;
        $worker->work(sub{
            my $idle = shift;
            return 1 if $idle;
            $total_process++;
            return 0;
        });
        is($total_process, (5 - 1) * $total_jobs);
    }
}

