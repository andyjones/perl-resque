#!/usr/bin/perl 
#===============================================================================
#
#         FILE:  remove_queue.pl
#
#        USAGE:  ./remove_queue.pl  
#
#      COMPANY:  Broadbean
#      CREATED:  09/11/11 14:57:33
#     REVISION:  $Id$ 
#===============================================================================

use strict;
use warnings;
use lib 't';
use Resque::Cleanup;

$ENV{VERBOSE} = 1;

Resque::Cleanup->new(shift @ARGV);
