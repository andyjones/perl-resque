package Resque::Client;

use strict;

use JSON;

sub new {
    my $class = shift;
    my $args_ref = shift || {};

    return bless { %$args_ref }, $class;
}

sub connection {
    return $_[0]->{connection} if @_ == 1;
    return $_[0]->{connection} = $_[1];
}

# Queues a job to a given queue to be run
sub push {
    my $self  = shift;
    my $queue = shift;
    my $class = shift;
    my $args_ref = shift || [];

    my $data = JSON::encode_json({
        class => $class,
        args  => $args_ref,
    });


    my $connection = $self->connection();
    my $redis = $connection->redis();
    $redis->sadd( $connection->key('queues') => $queue );
    return $redis->rpush( $connection->key('queue', $queue) => $data );
}

1;
