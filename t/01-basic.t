#!perl -T

use Test::More tests => 2;
use AnyEvent::Handle::ZeroMQ;
use AE;
use ZeroMQ qw(:all);

my $ctx = ZeroMQ::Context->new;
my $socket_a = $ctx->socket(ZMQ_XREP);
my $socket_b = $ctx->socket(ZMQ_XREQ);

$socket_a->bind("inproc://t");
$socket_b->connect("inproc://t");

my $hdl_a = AnyEvent::Handle::ZeroMQ->new( socket => $socket_a );
my $hdl_b = AnyEvent::Handle::ZeroMQ->new( socket => $socket_b );

my $done = AE::cv;

$hdl_a->push_read(sub{
    my($hdl, $data) = @_;
    my $data_str = [ map { $_->data } @$data ];
    my $peer = $data_str->[0];
    is_deeply($data_str, [$peer, "", 'a', '123'], 'recv1');

    $hdl->push_write([$peer, "", 'b', '345']);
});

$hdl_b->push_read(sub{
    my($hdl, $data) = @_;
    my $data_str = [ map { $_->data } @$data ];
    is_deeply($data_str, ["", 'b', '345'], 'recv2');

    $done->send;
});

$hdl_b->push_write(["", 'a', '123']);

$done->recv;
