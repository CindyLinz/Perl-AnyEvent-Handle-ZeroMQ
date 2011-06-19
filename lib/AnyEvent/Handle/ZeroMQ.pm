package AnyEvent::Handle::ZeroMQ;

use 5.006;
use strict;
use warnings;

=head1 NAME

AnyEvent::Handle::ZeroMQ - Integrate AnyEvent and ZeroMQ with AnyEvent::Handle like ways.

=head1 VERSION

Version 0.02

=cut

our $VERSION = '0.02';


=head1 SYNOPSIS

    use AnyEvent::Handle::ZeroMQ;
    use AE;
    use ZeroMQ;

    my $ctx = ZeroMQ::Context->new;
    my $socket = $ctx->socket(ZMQ_XREP);
    $socket->bind('tcp://0:8888');

    my $hdl = AnyEvent::Handle::ZeroMQ->new($socket);
    $hdl->push_read( sub {
	my($hdl, $data) = @_;

	my @out;
	while( my $msg = shift @$data) {
	    push @out, $msg;
	    last if $msg->size == 0;
	}
	while( my $msg = shift @$data ) {
	    print "get: ",$msg->data,$/;
	}
	push @out, "get!";
	$hdl->push_write(\@out);
    } );

    AE::cv->recv;

=cut

use strict;
use warnings;

use AE;
use ZeroMQ qw(:all);
use Scalar::Util qw(weaken);
use constant {
    SOCKET => 0,
    RQUEUE => 1,
    WQUEUE => 2,
    RWATCHER => 3,
    WWATCHER => 4,
};


=head1 SUBROUTINES/METHODS

=head2 new( socket => $zmq_socket )

=cut

sub new {
    my $class = shift;
    my %args = @_;
    my $socket = $args{socket};

    my $fd = $socket->getsockopt(ZMQ_FD);

    my($self, $wself);

    $self = $wself = bless [
	$socket,
	[],
	[],
	AE::io($fd, 0, sub { _consume_read($wself) }),
	AE::io($fd, 0, sub { _consume_write($wself) }),
    ], $class;

    weaken $wself;

    return $self;
}

=head2 push_read( cb($hdl, $data (array_ref) )
=cut

sub _consume_read {
    my $self = shift;

    my $socket = $self->[SOCKET];
    my $rqueue = $self->[RQUEUE];

    while( @$rqueue && $socket->getsockopt(ZMQ_EVENTS) & ZMQ_POLLIN ) {
	my @msgs;
	{
	    push @msgs, $socket->recv;
	    redo if $socket->getsockopt(ZMQ_RCVMORE);
	}
	my $cb = shift @$rqueue;
	$cb->($self, \@msgs);
    }
}

sub push_read {
    my $self = shift;
    push @{$self->[RQUEUE]}, pop;
    _consume_read($self);
}

=head2 push_write( $data (array_ref) )
=cut

sub _consume_write {
    my $self = shift;

    my $socket = $self->[SOCKET];
    my $wqueue = $self->[WQUEUE];

    while( @$wqueue && $socket->getsockopt(ZMQ_EVENTS) & ZMQ_POLLOUT ) {
	my $msgs = shift @$wqueue;
	while( defined( my $msg = shift @$msgs ) ) {
	    $socket->send($msg, @$msgs ? ZMQ_SNDMORE : 0);
	}
    }
}

sub push_write {
    my $self = shift;
    push @{$self->[WQUEUE]}, shift;
    _consume_write($self);
}

if( !exists(&ZeroMQ::Socket::DESTROY) ) {
    *ZeroMQ::Socket::DESTROY = sub {
	my $self = shift;
	print STDERR "AAA\n";
	eval { $self->close };
    };
}

=head1 AUTHOR

Cindy Wang (CindyLinz)

=head1 BUGS

Please report any bugs or feature requests to C<bug-anyevent-handle-zeromq at rt.cpan.org>, or through
the web interface at L<http://rt.cpan.org/NoAuth/ReportBug.html?Queue=AnyEvent-Handle-ZeroMQ>.  I will be notified, and then you'll
automatically be notified of progress on your bug as I make changes.




=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc AnyEvent::Handle::ZeroMQ


You can also look for information at:

=over 4

=item * RT: CPAN's request tracker (report bugs here)

L<http://rt.cpan.org/NoAuth/Bugs.html?Dist=AnyEvent-Handle-ZeroMQ>

=item * AnnoCPAN: Annotated CPAN documentation

L<http://annocpan.org/dist/AnyEvent-Handle-ZeroMQ>

=item * CPAN Ratings

L<http://cpanratings.perl.org/d/AnyEvent-Handle-ZeroMQ>

=item * Search CPAN

L<http://search.cpan.org/dist/AnyEvent-Handle-ZeroMQ/>

=back


=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Cindy Wang (CindyLinz).

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1; # End of AnyEvent::Handle::ZeroMQ
