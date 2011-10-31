package Resque;

use strict;

# Perl port of the coffeescript port of resque ;)
# https://github.com/technoweenie/coffee-resque/blob/master/src/index.coffee

our $VERSION = 0.03;

use Redis;

our $DEFAULT_PORT = 6379;
our $DEFAULT_SERVER = 'localhost:'.$DEFAULT_PORT;
our $DEFAULT_NAMESPACE = 'resque';

sub _get_obj {
    if ( ref($_[0]) ) {
        # passed an object
        my $self = shift;
        my $args_ref = shift || {};
        $args_ref->{connection} = $self;
        return ($self, $args_ref);
    }

    # passed a class
    return shift->_new(@_);
}

sub _new {
    my $class = shift;
    my $args_ref = shift || {};

    # grab the args that are for us
    # so we can pass all unknown args back to the caller
    my %options = map {
        $_ => delete $args_ref->{$_}
    } qw(server namespace redis);

    my $self = $class->new( \%options );
    $args_ref->{connection} = $self;
    return ($self, $args_ref);
}

sub new {
    my $class = shift;
    my $args_ref = shift || {};
    
    $args_ref->{'workers'} = {};

    return bless { %$args_ref }, $class;
}

sub workers {
    return $_[0]->{'workers'} if @_ == 1;
    return $_[0]->{'workers'}->{$_[1]} = 1;
}

sub remove_worker {
    return 0 if @_ == 1;
    return delete($_[0]->{'workers'}->{$_[1]});
}

sub new_client {
    my ($self, $args_ref) = shift->_get_obj(@_);

    require Resque::Client;
    return Resque::Client->new($args_ref);
}

sub new_worker {
    my ($self, $args_ref) = shift->_get_obj(@_);

    require Resque::Worker;
    return Resque::Worker->new($args_ref);
}

sub new_queue {
    my ($self, $args_ref) = shift->_get_obj(@_);

    require Resque::Queue;
    return Resque::Queue->new($args_ref);
}

sub key {
    my $self = shift;
    return join(':', $self->namespace(), @_);
}

# accessors/setters
sub namespace {
    $_[0]->{namespace} = $_[1] if @_ > 1;            # setter
    return $_[0]->{namespace} || $DEFAULT_NAMESPACE; # getter
}
sub server {
    $_[0]->{server} = $_[1] if @_ > 1;        # setter
    my $server = $_[0]->{server}
                || (exists($ENV{REDIS_SERVER}) && $ENV{REDIS_SERVER})
                || $DEFAULT_SERVER; # getter
    if ( $server !~ m/:/ ) {
        $server .= ':' . $DEFAULT_PORT;
    }
    return $server;
}

sub redis {
    return $_[0]->{redis} = $_[1] if @_ > 1;
    return $_[0]->{redis} ||= $_[0]->connect_to_redis();
}

sub connect_to_redis {
    my $self = shift;
    return Redis->new( server => $self->server(), debug => 0 );
}

sub ping {
    return $_[0]->redis()->ping();
}

1;
