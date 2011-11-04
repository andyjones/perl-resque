#!/usr/bin/perl

use strict;

use Test::More tests => 2;

use Resque;
use Resque::Queue;

!caller && &main;

sub main {
    my $resque = Resque->new;

    plan skip_all => "Tests require Redis server" if ! $resque->ping;

    my $worker = $resque->new_worker;

    $worker->queues("TestQ-$$");

    my $process = 0;

    $worker->work(sub{
        my $idle = shift;
        if ($idle) {
            if ($process == 0) {
                push_testq(1);
            }
            elsif ($process == 1) {
                push_testq(2);
            }
        }
        else {
            $process++;
            if ($process == 1) {
                is(test_result(1), "Apple");
            }
            elsif ($process == 2) {
                is(test_result(2), "Orange");
            }
        }
        return $process == 2;
    });
}

sub push_testq {
    my $t = shift;
    require($INC{"TestClass2.pm"} = "t/40-auto-reload/ClassFile$t.pm");
    my $resque = Resque->new;
    my $client = $resque->new_client;
    $client->push("TestQ-$$", TestClass2 => [$t]);
}

sub test_result {
    my $test = shift;
    open FH, '<', "t/40-auto-reload/test$test.txt";
    local $/;
    my $result = <FH>;
    close FH;
    return $result;
}
