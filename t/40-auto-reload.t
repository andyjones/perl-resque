#!/usr/bin/perl

use strict;

use Test::More tests => 2;

use Resque;
use Resque::Queue;
use lib "t/40-auto-reload";

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
    reload_test_class(shift);
    my $resque = Resque->new;
    my $client = $resque->new_client;
    $client->push("TestQ-$$", TestClass2 => [14]);
}

sub reload_test_class {
    my $test = shift;
    if (open my $READ, "<:encoding(UTF-8)", "t/40-auto-reload/ClassFile$test.txt") {
        local $/;
        my $code = <$READ>;
        close $READ;
        if (open my $WRITE, ">:encoding(UTF-8)", "t/40-auto-reload/TestClass2.pm") {
            print $WRITE $code;
            close $WRITE;
            unlink "t/40-auto-reload/test$test.txt";
        }
        else {
            die "unable to replace test class.";
        }
    }
    else {
        die "unable to load class file.";
    }
}

sub test_result {
    my $test = shift;
    open FH, "<:encoding(UTF-8)", "t/40-auto-reload/test$test.txt";
    local $/;
    my $result = <FH>;
    close FH;
    return $result;
}
