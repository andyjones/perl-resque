#!/usr/bin/perl

use strict;

use Test::More;

use lib qw(../lib);

use Resque;

my $client = Resque->new_client();

$client->push('high', 'TestClass', ['add', 'date']);
$client->push('high', 'FakeClass', ['add', 'date']);
