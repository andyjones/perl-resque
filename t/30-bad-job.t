#!/usr/bin/perl

use strict;

use Test::More;

use Resque;
use Resque::Queue;

my $queue = 'resque-test-' . $$;

my $resque = Resque->new();
plan skip_all => "Tests require Redis server" unless $resque->ping();

plan skip_all => "Test not written yet";

__END__
# queue a job that will fail
my $client = $resque->new_client();
$client->push($queue, 'FakeClass', ['add', 'date']);

# start a worker to process the job

# check that the job is still in the failure queue

## cleanup
# remove the failed job & queue
