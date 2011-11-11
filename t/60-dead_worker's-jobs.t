#
#===============================================================================
#
#         FILE:  60-dead_worker's-jobs.t
#
#      COMPANY:  Broadbean
#      CREATED:  09/11/11 09:03:43
#     REVISION:  $Id$
#===============================================================================

use strict;
use warnings;

use JSON::XS;
use Resque;
use lib t => qw(t/60-dead_worker);
use Resque::Cleanup;

use Test::More tests => 2;                      # last test to print

!caller && &main;

sub main {
    my $test = __PACKAGE__->new;
    ## Graceful Stop
    {
        $test->new_job(TwentySecJob => "Test QUIT");
        $test->stop_worker(3);
    }
    {
        my $worker = $test->new_worker;
        $worker->work(sub {1});
        my $error = $test->get_errors;
        is($error, 0, "Test graceful stop.");
    }
    ## INT Workder
    {
        $test->new_job(WorkerIsHolding => "Test INT");
        $test->stop_worker(2);
    }
    {
        my $worker = $test->new_worker;
        $worker->work(sub {1});
        my $error = $test->get_errors;
        is($error, 1, "Test int kill.");
    }
    ## Force Quit 
    {
        $test->new_job(WorkerIsHolding => "Test KILL");
        $test->stop_worker(9);
    }
    {
        my $worker = $test->new_worker;
        $worker->work(sub {1});
        my $error = $test->get_errors;
        is($error, 1, "Test force quit");
    }
}

sub pause {
    my $self = shift;
    my %args = @_;
    require DateTime;
    printf "Paused %s\n", DateTime->now;
    require Data::Dumper;
    while (my $a = <STDIN>) {
        if ($a) {
            chomp $a;
            if ($a eq "q") {exit(0)}
            eval $a;
            print $@ if $@
        }
        print "\n> ";
        sleep 1;
    }
}

sub stop_worker {
    my $self = shift;
    my $signal = shift;
    my $child = fork;
    if ($child) {
        sleep 2;
        kill($signal, $child);
    }
    else {
        $self->new_worker->work(\&worker_home);
        exit(0);
    }
    waitpid($child, 0);
}

sub new {
    my $package = shift;
    plan skip_all => "Forking is not avilable for this system." if ! &has_forking;
    my $queue = "TestQ-$$";
    return bless {
          queue_name => $queue
        , cleaner    => Resque::Cleanup->new($queue)
    }, $package;
}

sub new_worker {
    my $self   = shift;
    my $sub    = shift;
    my $worker = $self->new_resque->new_worker;
    $worker->queues($self->{queue_name});
    return $worker;
}

sub worker_home {
    my $idle = shift;
    return 1 if $idle;
    return 1;
}

sub new_job {
    my $self  = shift;
    my $class = shift;
    my $label = shift;
    $self->new_resque->new_client->push($self->{queue_name}, $class => [$label]);
}

sub get_errors {
    my $self        = shift;
    my $resque      = $self->new_resque;
    my $redis       = $resque->redis;
    my $failure_key = $resque->key("failed");
    my $n_failures  = $redis->llen($failure_key);
    my @failures    = $redis->lrange($failure_key, 0, $n_failures);
    my @errors      = grep {$_->{queue} eq $self->{queue_name}} @{decode_json(sprintf "[%s]", join ",", @failures)};
    return wantarray ? @errors : $#errors + 1;
}

sub has_forking {
    my $pid = fork;
    if (! defined $pid) {
        return 0;
    }
    elsif ($pid == 0) {
        exit(0);
    }
    else {
        waitpid($pid, 0);
    }
    return 1;
}

sub new_resque {
    my $self = shift;
    my $resque = Resque->new;
    plan skip_all => "Tests require Redis server" if ! $resque->ping;
    return $resque;
}

sub DESTROY {
    shift->{cleaner}->DESTROY;
}
