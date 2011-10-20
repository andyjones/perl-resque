package TestClass;

use strict;

use Data::Dumper;

sub perform {
    my $class = shift;
    my @args = @_;

    sleep 2;

    warn "$class: " . Dumper(\@args) . "\n";
}

1;
