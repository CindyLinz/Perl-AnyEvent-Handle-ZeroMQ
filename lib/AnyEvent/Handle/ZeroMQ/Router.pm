package AnyEvent::Handle::ZeroMQ::Router;

use 5.006;
use strict;
use warnings;

use base qw(AnyEvent::Handle::ZeroMQ);

=head1 SYNOPSIS

    use AnyEvent::Handle::ZeroMQ::Router;
    use AE;
    use ZeroMQ;

    my $ctx = ZeroMQ::Context->new;
    my $socket = $ctx->socket(ZMQ_XREP);
    $socket->bind('tcp://0:8888');

    my $hdl = AnyEvent::Handle::ZeroMQ::Router->new(
	socket => $socket,
	on_drain => sub { print "the write queue is empty\n" },
    );
    # or $hdl->on_drain( sub { ... } );
    $hdl->push_read( sub {
	my($hdl, $request, $cb) = @_;
	my @reply = ...
	$cb->(\@reply);
    } );

    AE::cv->recv;

=cut

sub new {
    my $class = shift;
    my $self = $class->SUPER::new(@_);
}

sub push_read {
    my($self, $cb) = @_;

    $self->SUPER::push_read( sub {
	my($self, $msgs) = @_;

	my $i = 0;
	++$i while( $msgs->[$i] ne '' );
	my @header = splice @$msgs, 0, $i;
	shift @$msgs if $msgs->[0] eq '';

	$cb->($self, $msgs, sub {
	    my($msgs) = @_;
	    unshift @$msgs, @header, '';
	    $self->SUPER::push_write($msgs);
	});
    } );
}

sub push_write {
    warn __PACKAGE__."::push_write shouldn't be called.";
}
1;
