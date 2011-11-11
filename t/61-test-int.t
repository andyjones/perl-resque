#
#===============================================================================
#
#         FILE:  60-test-graceful.t
#
#      COMPANY:  Broadbean
#      CREATED:  11/11/11 16:14:06
#     REVISION:  $Id$
#===============================================================================

use strict;
use warnings;

use Test::More tests => 1;                      # last test to print

use lib "t";
use Resque::TestQuit;

my $test = Resque::TestQuit->new_test;
$test->try_int;
