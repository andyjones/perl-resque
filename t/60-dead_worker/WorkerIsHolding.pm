package WorkerIsHolding;

use strict;

use Data::Dumper;

sub perform {
    my $class = shift;
    warn "Freezed Worker Job here.\n";
    sleep;
}

1;
