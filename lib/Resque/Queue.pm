package Resque::Queue;

use strict;

sub new {
    my $class = shift;
    my $args_ref = shift || {};

    return bless { %$args_ref }, $class;
}

# ACCESSORS
sub connection {
    return $_[0]->{connection} if @_ == 1;
    return $_[0]->{connection} = $_[1];
}

sub key   { return shift->{connection}->key(@_); }
sub redis { return shift->{connection}->redis(@_); }

# INSTANCE METHODS
# returns all known resque queues
sub all_queues {
    my $self = shift;
    my $redis = $self->redis();
    return $redis->smembers( $self->key('queues') );
}

# completey deletes the given queue
sub remove_queue {
    my $self = shift;
    my $queue = shift
        or die "Which queue would you like to remove?";

    my $redis = $self->redis();
    $redis->srem( $self->key('queues'), $queue );
    $redis->del( $self->key('queue', $queue) );
}

1;
