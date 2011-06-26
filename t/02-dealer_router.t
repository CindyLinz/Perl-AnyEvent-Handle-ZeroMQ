#!perl -T

use Test::More tests => 2;
use AnyEvent::Handle::ZeroMQ::Dealer;
use AnyEvent::Handle::ZeroMQ::Router;
use AE;
use ZeroMQ qw(:all);
use strict;
use warnings;

my $ctx = ZeroMQ::Context->new;
my $socket_a = $ctx->socket(ZMQ_XREP);
my $socket_b = $ctx->socket(ZMQ_XREQ);

$socket_a->bind("inproc://t");
$socket_b->connect("inproc://t");

my $hdl_a = AnyEvent::Handle::ZeroMQ::Router->new( socket => $socket_a );
my $hdl_b = AnyEvent::Handle::ZeroMQ::Dealer->new( socket => $socket_b );

my $done = AE::cv;

$hdl_a->push_read(sub {
    my($hdl, $data, $cb) = @_;
    my $data_str = [ map { $_->data } @$data ];
    is_deeply($data_str, ["", 'a', '123']);

    $cb->(["", 'b', '345']);
});

$hdl_b->push_write(["", 'a', '123'], sub {
    my($hdl, $data) = @_;

    my $data_str = [ map { $_->data } @$data ];
    is_deeply($data_str, ['', 'b', '345']);
    $done->send;
});

$done->recv;
