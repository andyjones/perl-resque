#
#===============================================================================
#
#         FILE:  Cleanup.pm
#
#      COMPANY:  Broadbean
#      CREATED:  04/11/11 10:44:49
#     REVISION:  $Id$ 
#===============================================================================
package Resque::Cleanup;
use strict;
use warnings;
use Resque;

sub new {
    my $class = shift;
    my $qname = shift;
    my $self  = bless { parent_process => $$, queue_name => $qname }, $class;
    $self->set_cleaning_signals;
    return $self;
}

sub set_cleaning_signals {
    my $self = shift;
    foreach my $signame(qw(__DIE__ INT HUP KILL TERM)) {
        $SIG{$signame} = sub { $self->cleanup($signame) }
    }
    return;
}

sub cleanup {
    my $self = shift;
    my $signame = shift;
    if ($self->{verbose} || $ENV{VERBOSE}) {
        warn Carp::longmess(">> Triggered cleanup by SIG.$signame");
    }
    $self->DESTROY;
}

sub DESTROY {
    my $self = shift;
    if ($$ == $self->{parent_process}) {
        if (!$self->{cleaned}++) {
            if ($self->{verbose} || $ENV{VERBOSE}) {
                warn qq/>> Cleaning up queue <$self->{queue_name}>.\n/;
            }
            Resque->new->new_queue->remove_queue($self->{queue_name});
        }
    }
    else {
        warn ">> Ignored cleanup request from child process.\n" if $self->{verbose} || $ENV{VERBOSE};
    }
}
1;
