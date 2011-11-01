#!/usr/bin/perl

use Test::More;
plan skip_all => "Author tests only" unless $ENV{RELEASE_TESTING};
eval "use Test::Synopsis";
plan skip_all => "Test::Synopsis required" if $@;
all_synopsis_ok();
