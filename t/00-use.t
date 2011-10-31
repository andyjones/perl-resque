#!/usr/bin/perl

use strict;

use Test::More tests => 6;

use_ok('Resque');
use_ok('Resque::Client');
use_ok('Resque::Worker');
use_ok('Resque::Failure');
use_ok('Resque::Job');
use_ok('Resque::Queue');
