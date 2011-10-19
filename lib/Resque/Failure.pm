package Resque::Failure;

use strict;

use overload qw{""} => \&name;
use JSON;
use Resque::Job;
use Resque::Worker;
use DateTime;
use Devel::StackTrace;

use base 'Class::Accessor::Fast';

__PACKAGE__->mk_accessors( qw/job stack worker/ );

sub queue {
    return $_[0]->{job}->{queue};
}

sub payload {
    return $_[0]->{job}->{payload};
}

sub worker_name {
    return $_[0]->{worker}->name();
}

sub json {
    my $self = shift;

    my $stack = $self->stack();

    return JSON::encode_json({
        'failed_at' => $self->now_time(),
        'payload'   => $self->payload(),
        'exception' => $stack->as_string(),
        'error'     => $stack->frame(0)->as_string(),
        'backtrace' => [$self->backtrace($stack)],
        'worker'    => $self->worker_name(),
        'queue'     => $self->queue(),
    });
}

sub connection {
    return $_[0]->{worker}->connection();
}

sub fail {
    my $self = shift;
    my $failure = $self->json();
    my $connection = $self->connection();
    my $redis = $connection->redis();
    return $redis->rpush( $connection->key('failed') => $failure );
}

sub dirty_fail {
    my $class = shift;
    my $worker = shift;

    my $json = $worker->redis()->get($worker->key('worker',$worker->name()));
    my $task = JSON::decode_json($json);
    my $stack = Devel::StackTrace->new( message => 'Worker killed unexpectedly' );

    $worker->log_info("Dirty Fail - %s",$worker->key('worker',$worker->name()));

    return $class->new({ 
        'job'       => $task,
        'worker'    => $worker,
        'stack'     => $stack
    });
    
}

sub backtrace {
    my $class = shift;
    my $stack = shift;
    my @trace = ();
    while (my $frame = $stack->next_frame) {
        push(@trace,"sub => ".$frame->subroutine()."\n".$frame->as_string);
    }

    return \@trace;
}

sub now_time{
    return DateTime->now()->strftime("%Y/%m/%d %H:%M:%S %Z");
}
1;
