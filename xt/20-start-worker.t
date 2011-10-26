#!/usr/bin/perl

use strict;

use Test::More tests => 1;

use lib qw(../lib);

use Resque;

! caller && &main;

sub main {
    my $worker = Resque->new_worker;
    $worker->work(\&test);
}

sub test {
    my $switch = shift;

    if ($switch eq "job_done") {
        ok(1);
        return "last";
    }
}
