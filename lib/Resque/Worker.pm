package Resque::Worker;

use strict;

use JSON;
use Time::HiRes;
use DateTime;
use Sys::Hostname;

my $DEFAULT_INTERVAL = 5.0;

sub new {
    my $class = shift;
    my $args_ref = shift || {};

    return bless {
        interval => $DEFAULT_INTERVAL,
        %$args_ref
    }, $class;
}

sub name {
    return $_[0]->{name} ||= $_[0]->generate_name();
}

sub generate_name {
    my $self = shift;
    my $queues = join(',', $self->queues());
    return join(':', Sys::Hostname::hostname(), $$, $queues);
}

sub connection {
    return $_[0]->{connection} if @_ == 1;
    return $_[0]->{connection} = $_[1];
}

sub key   { return shift->{connection}->key(@_); }
sub redis { return shift->{connection}->redis(@_); }

sub interval {
    return $_[0]->{interval} if @_ == 1;
    return $_[0]->{interval} = $_[1];
}



# main work loop
sub work {
    my $self = shift;
    my $block_ref = shift; # optional code block that is passed the job

    $self->procline('Starting');

    $self->startup();

    my $interval = $self->interval();

    while ( !$self->{shutdown} ) {
        my $idle = 0;
        if ( $self->paused() ) {
            $idle = 1;
            $self->procline('Paused');
        }
        elsif ( my $job = $self->reserve() ) {
            $self->process_job( $job );
        }
        else {
            $idle = 1;
            $self->procline( 'Waiting for %s', join(',',$self->queues()) );
        }

        if ( $idle && $interval ) {
            $self->log_debug("Sleeping for %.2f seconds", $interval);
            Time::HiRes::sleep( $interval );
        }
    }

    $self->unregister_worker();
}

sub startup {
    my $self = shift;
    $self->register_worker();
}

sub paused {
    return 0;
}

sub reserve {
}

sub queues {
    return qw(high medium low);
}

sub process_job {
    # fork
}

sub pop {
    my $self = shift;
    my $queue = shift;

    my $connection = $self->connection();
    my $key = $connection->key( $queue );
    my $obj = $connection->redis->lpop($key);
    return JSON::decode_json( $obj );
}

# methods to notify redis of our presence
sub register_worker {
    my $self = shift;

    my $redis = $self->redis();
    my $name = $self->name();
    $self->{registered} = 1;
    $redis->sadd($self->key('workers') => $name);
    $redis->set($self->key('worker', $name, 'started') => $self->now() ); 
}

sub unregister_worker {
    my $self = shift;

    # TODO: log unfinished jobs

    my $redis = $self->redis();
    my $name  = $self->name();

    $redis->srem($self->key('workers') => $name);
    $redis->del($self->key('worker', $name));
    $redis->del($self->key('worker', $name, 'started'));

    # clear processed, $name stats
    # clear failed, $name stats
    $self->{registered} = 0;
}

sub DESTROY {
    my $self = shift;
    if ( $self->{registered} ) {
        $self->unregister_worker();
    }
}

# utility methods
sub log_info {
    goto &log_debug;
}

sub log_debug {
    my $self = shift;
    my $mask = shift;
    my $msg  = @_ ? sprintf($mask, @_) : shift;
    $msg =~ s/\n?$/\n/; # make sure it ends with a new line

    my $now = $self->now();

    warn "[$$] - $now - $msg";
}

sub now {
    return DateTime->now()->strftime("%Y/%m/%d %H:%M:%S %Z");
}

sub procline {
    my $self = shift;
    my $mask = shift;
    my $msg  = @_ ? sprintf($mask, @_) : shift;
    $0 = 'resque: ' . $msg;
}

1;
