#!/usr/bin/perl

use strict;

use Test::More tests => 1;

use Resque;
use Resque::Queue;
use lib t => "t/30-bad-job";
use Resque::Cleanup;

my $queue = 'resque-test-' . $$;
my $cleaner = Resque::Cleanup->new($queue);

my $resque = Resque->new();
SKIP: {
    skip "Tests require Redis server", 1 if ! $resque->ping();

    my $client = $resque->new_client;
    $client->push($queue, TestClass2 => [test => 1]);
    $client->push($queue, TestClass2 => [test => 2]);
    $client->push($queue, TestClass  => [test => 3]);

    my $worker = $resque->new_worker;

    $worker->queues($queue);

    my $total_process = 0;

    $worker->work(sub{
        my $idle = shift;
        return 1 if $idle;
        return ++$total_process == 3
    });

    is($total_process, 3);
}

__END__
# queue a job that will fail
my $client = $resque->new_client();
$client->push($queue, 'FakeClass', ['add', 'date']);

# start a worker to process the job

# check that the job is still in the failure queue

## cleanup
# remove the failed job & queue
