package AnyEvent::Handle::ZeroMQ::Dealer;

use 5.006;
use strict;
use warnings;

use AnyEvent::Handler::ZeroMQ qw(:constant);
use base qw(AnyEvent::Handle::ZeroMQ);

=head1 SYNOPSIS

    use AnyEvent::Handle::ZeroMQ::Dealer;
    use AE;
    use ZeroMQ;

    my $ctx = ZeroMQ::Context->new;
    my $socket = $ctx->socket(ZMQ_XREP);
    $socket->bind('tcp://0:8888');

    my $hdl = AnyEvent::Handle::ZeroMQ::Dealer->new(
	socket => $socket,
	on_drain => sub { print "the write queue is empty\n" },
    );
    # or $hdl->on_drain( sub { ... } );
    my @request = ...;
    $hdl->push_write( \@request, sub {
	my($hdl, $reply) = @_;
	...
    } );

    AE::cv->recv;

=cut

use constant {
    SLOT => 0,
};

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);

    $self->[DEALER] = [];
    $self->[DEALER][SLOT] = [];
}

sub _dealer_read_cb {
    my($self, $msgs) = @_;

    my $n = unpack 'V', shift @$msgs;

    my $cb = delete $self->[DEALER][SLOT][$n];
    if( !$cb ) {
	$self->push_read(\&_dealer_read_cb);
	return;
    }

    0 while( @$msgs && '' ne shift @$msgs );
    $cb->($self, $msgs);
}

sub push_write {
    my($self, $msgs, $cb) = @_;

    my $n = 0;
    ++$n while $self->[DEALER][SLOT][$n];
    $self->[DEALER][SLOT][$n] = $cb;

    unshift @$msgs, pack('V', $n), '';

    $self->SUPER::push_write($msgs);
    $self->SUPER::push_read(\&_dealer_read_cb);
}

sub push_read {
    warn __PACKAGE__."::push_read shouldn't be called.";
}

1;
