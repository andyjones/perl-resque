#!/usr/bin/perl

use strict;

use Test::More tests => 3;

use lib qw(../lib);

use_ok('Resque');
use_ok('Resque::Client');
use_ok('Resque::Worker');
