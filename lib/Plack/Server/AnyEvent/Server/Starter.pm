
package Plack::Server::AnyEvent::Server::Starter;use strict;
use warnings;
use base qw(Plack::Server::AnyEvent);
use AnyEvent;
use AnyEvent::Util qw(fh_nonblocking guard);
use AnyEvent::Socket qw(format_address);
use Server::Starter qw(server_ports);

# Server::Starter requires us to perform fdopen on a descriptor NAME...
# that's what we do here
# This code is stolen from AnyEvent-5.24 AnyEvent::Socket::tcp_server
sub _create_tcp_server {
    my ( $self, $app ) = @_;

    my ($hostport, $fd) = %{Server::Starter::server_ports()};
    if ($hostport =~ /(.*):(\d+)/) {
        $self->{host} = $1;
        $self->{port} = $2;
    } else {
        $self->{host} ||= '0.0.0.0';
        $self->{port} = $hostport;
    }

    # /WE/ don't care what the address family, type of socket we got, just    # create a new handle, and perform a fdopen on it. So that part of
    # AE::Socket::tcp_server is stripped out

    my %state;
    $state{fh} = IO::Socket::INET->new(
        Proto => 'tcp',
        Listen => 128, # parent class returns, zero, so set to AE::Socket's default
    );

    $state{fh}->fdopen( $fd, 'w' ) or
        Carp::croak "failed to bind to listening socket: $!";
    fh_nonblocking $state{fh}, 1;

    my $accept = $self->_accept_handler($app);
    $state{aw} = AE::io $state{fh}, 0, sub {
        # this closure keeps $state alive
        while ($state{fh} && (my $peer = accept my $fh, $state{fh})) {
            fh_nonblocking $fh, 1; # POSIX requires inheritance, the outside world does not

            my ($service, $host) = AnyEvent::Socket::unpack_sockaddr($peer);
            $accept->($fh, format_address $host, $service);
        }
    };

    warn "Accepting requests at http://$self->{host}:$self->{port}/\n";
    defined wantarray
        ? guard { %state = () } # clear fh and watcher, which breaks the circular dependency
        : ()
}

1;
