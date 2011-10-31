#!/usr/bin/perl

use strict;

use Test::More tests => 1;

use Resque;
use Resque::Queue;

my $queue = 'resque-test-' . $$;

my $resque = Resque->new();
SKIP: {
    skip "Tests require Redis", 1 unless $resque->ping();

    # queue 2 jobs
    my $client = $resque->new_client();
    $client->push($queue, 'TestClass', ['add', 'date']);
    $client->push($queue, 'TestClass', ['add', 'date']);

    # start a worker to process the job
    my $worker = $resque->new_worker();
    $worker->queues($queue);

    my $jobs_processed = 0;
    $worker->work(sub {
        my $idle = shift;
        if ( $idle ) {
            return 1;
        }

        $jobs_processed++;

        return 0;
    });

    is($jobs_processed, 2, "we processed two jobs");

    # cleanup
    my $q = $resque->new_queue();
    $q->remove_queue($queue);
};
