#!/usr/bin/perl

use strict;

use Test::More;

use lib qw(../lib);

use Resque;

my $worker = Resque->new_worker();

$worker->work();
