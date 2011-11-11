package TwentySecJob;

use strict;

use Data::Dumper;

sub perform {
    my $class = shift;
    for (my $i = 1; $i <= 10; $i+=2) {
        warn "Wait $i/10 ... \n";
        sleep 2;
    }
}

1;
