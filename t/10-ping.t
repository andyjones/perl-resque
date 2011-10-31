#!/usr/bin/perl

use strict;

use Test::More tests => 1;

use Resque;

my $resque = Resque->new({ server => 'localhost:81' }); # something that doesn't run a redis server

my $ok = eval { $resque->ping(); 1; };
ok( $ok, "ping does not die" )
    or diag( "error message was: $@" );
