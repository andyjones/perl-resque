package TestClass2;

use strict;

use Data::Dumper;

sub perform {
    my $class = shift;
    my @args = @_;

    die "$class: " . Dumper(\@args) . "\n";
}

1;
