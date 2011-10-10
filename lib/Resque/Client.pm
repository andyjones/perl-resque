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
    my $task  = shift;

    my $connection = $self->connection();

    my $key = $connection->key( $queue );
    my $redis = $connection->redis();
    $redis->sadd( queues => $queue );
    return $redis->rpush( $key => JSON::encode_json($task) );
}

sub pop {
    my $self = shift;
    my $queue = shift;

    my $connection = $self->connection();
    my $key = $connection->key( $queue );
    my $obj = $connection->redis->lpop($key);
    return JSON::decode_json( $obj );
}

1;
