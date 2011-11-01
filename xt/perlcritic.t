#!/usr/bin/perl

use strict;
use Test::More;
plan skip_all => "Author tests only" unless $ENV{RELEASE_TESTING};
eval q{ use Test::Perl::Critic };
plan skip_all => "Test::Perl::Critic is not installed." if $@;
all_critic_ok("lib");
