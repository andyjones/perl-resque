package Resque::Job;

use strict;

use overload q{""} => \&to_string;

sub new {
    my $class = shift;
    my $args_ref = shift || {};

    my $self = bless { %$args_ref }, $class;
    return $self;
}

sub worker {
    return $_[0]->{worker} if @_ == 1;
    return $_[0]->{worker} = $_[1];
}

sub queue {
    return $_[0]->{queue} if @_ == 1;
    return $_[0]->{queue} = $_[1];
}

sub payload {
    return $_[0]->{payload} if @_ == 1;
    return $_[0]->{payload} = $_[1];
}

sub payload_class {
    return $_[0]->payload()->{class};
}

sub payload_args {
    return @{ $_[0]->payload()->{args} || [] };
}

sub perform {
    my $self = shift;
    my $class = $self->payload_class();

    local $@;
    my $loaded_class = eval "use $class; 1";
    if ( $loaded_class ) {
        return $class->perform( $self->payload_args() );
    }

    return die "Unable to load $class: $@";
}

sub to_string {
    my $self = shift;
    return sprintf "(Job{%s} | %s | [%s]",
       $self->queue(),
       $self->payload_class(),
       join(',',$self->payload_args());
}

1;
