package Resque;

use strict;

# Perl port of the coffeescript port of resque ;)
# https://github.com/technoweenie/coffee-resque/blob/master/src/index.coffee

our $VERSION = 0.03;

use Redis;

our $DEFAULT_SERVER = 'localhost:6379';
our $DEFAULT_NAMESPACE = 'resque';

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
    my $self = ref($_[0]) ? shift : shift->new(@_);

    require Resque::Client;
    return Resque::Client->new({ connection => $self });
}

sub new_worker {
    my $self = ref($_[0]) ? shift : shift->new(@_);

    require Resque::Worker;
    return Resque::Worker->new({ connection => $self });
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
    return $_[0]->{server} || $DEFAULT_SERVER # getter
}

sub redis {
    return $_[0]->{redis} = $_[1] if @_ > 1;
    return $_[0]->{redis} ||= $_[0]->connect_to_redis();
}

sub connect_to_redis {
    my $self = shift;
    return Redis->new( server => $self->server(), debug => 0 );
}

1;
