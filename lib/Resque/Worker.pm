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
        parent_pid => $$,
        child_pid  => 0,
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

sub child_pid {
    return $_[0]->{child_pid} if @_ == 1;
    return $_[0]->{child_pid} = $_[1];
}

sub is_child {
    return $_[0]->{child_pid} == $$;
}

sub is_parent {
    return $_[0]->{parent_pid} == $$;
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

    $SIG{INT} = $SIG{TERM} = sub { $self->shutdown_now(); };
    $SIG{QUIT} = sub { $self->shutdown(); };
    $SIG{USR1} = sub { $self->kill_child(); };
    $SIG{USR2} = sub { $self->pause_processing(); };
    $SIG{CONT} = sub { $self->resume_processing(); };

    $self->log_debug('Registered signals');
}

# typically used as a class method
sub unregister_signal_handlers {
    delete @SIG{ qw/INT TERM QUIT USR1 USR2 CONT/ };
}

sub shutdown {
    my $self = shift;
    $self->log_info('Exiting...');
    $self->{shutdown} = 1;
}

sub shutdown_now {
    my $self = shift;
    $self->shutdown();
    $self->kill_child();
}

sub kill_child {
    # TODO
}

sub pause_processing {
    my $self = shift;
    $self->log_info('USR2 received; pausing job processing');
    $self->{paused} = 1;
}

sub resume_processing {
    my $self = shift;
    $self->log_info('CONT received; resuming job processing');
    $self->{paused} = 0;
}



sub prune_dead_workers {
    my $self = shift;
}

sub paused {
    return $_[0]->{paused};
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
    if ( $self->is_parent() && $self->{registered} ) {
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
    my $msg  = @_ ? sprintf($mask, @_) : $mask;
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
    my $msg  = @_ ? sprintf($mask, @_) : $mask;
    $0 = 'resque: ' . $msg;
}

END {
    __PACKAGE__->unregister_signal_handlers();
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
