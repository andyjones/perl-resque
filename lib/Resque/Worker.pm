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

    $self->register_signal_handlers();
    $self->prune_dead_workers();
    $self->register_worker();
}

# Registers the various signal handlers a worker responds to.
#
# TERM: Shutdown immediately, stop processing jobs.
#  INT: Shutdown immediately, stop processing jobs.
# QUIT: Shutdown after the current job has finished processing.
# USR1: Kill the forked child immediately, continue processing jobs.
# USR2: Don't process any new jobs
# CONT: Start processing jobs again after a USR2
#
# Perl gotcha: you must unregister the signal handlers
# or the worker will not be destroyed correctly
# TODO: explain this quirk better :)
sub register_signal_handlers {
    my $self = shift;
}

sub prune_dead_workers {
    my $self = shift;
}

sub paused {
    return 0;
}

sub reserve {
    my $self = shift;

    my @queues = $self->watched_queues()
        or return;

    my $redis = $self->redis();
    foreach my $queue ( @queues ) {
        if ( my $job = $self->reserve_job( $queue ) ) {
            $self->log_debug("Found job on %s", $queue);
            return $job;
        }
    }
    return;
}

sub reserve_job {
    my $self = shift;
    my $queue = shift;

    my $json_payload = $self->redis->lpop( $self->key('queue', $queue) );

}

sub queues {
    my $self = shift;
    if ( @_ ) {
        $self->{queues} = [ @_ ];
    }
    my $queues_ref = $self->{queues} ||= [ '*' ];
    if ( !@$queues_ref ) {
        return '*';
    }

    return @$queues_ref;
}

sub watched_queues {
    my $self = shift;
    my @queues = $self->queues();
    if ( !@queues || $queues[0] eq '*' ) {
        return $self->all_queues();
    }

    return @queues;
}

sub all_queues {
    my $self = shift;

    return $self->redis->smembers(
        $self->key( 'queues' ),
    );
}

sub process_job {
    my $self = shift;
    my $job  = shift;

    $self->log_debug("Processing job: [%s]", $job);
    # fork
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

__END__

=head1 Resque::Worker

perl clone of the awesome Resque library for Ruby

=head1 TODO

 * fork before taking a job
 * undef the signal handlers on END so our objects are destroyed in the correct order
 * clear dead workers when we start
 * put the job back in the queue if it fails
