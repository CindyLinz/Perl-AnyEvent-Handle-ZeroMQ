#!perl -T

use Test::More tests => 4;
use AnyEvent::Handle::ZeroMQ;
use AE;
use ZeroMQ qw(:all);

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
my $ctx = ZeroMQ::Context->new;
print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
my $socket_a = $ctx->socket(ZMQ_XREP);
print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
my $socket_b = $ctx->socket(ZMQ_XREQ);
print STDERR "@{[__FILE__]} @{[__LINE__]}\n";

$socket_a->bind("inproc://t");
$socket_b->connect("inproc://t");

my $a_on_drain = 0;

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
my $hdl_a = AnyEvent::Handle::ZeroMQ->new( socket => $socket_a, on_drain => sub { ++$a_on_drain } );
my $hdl_b = AnyEvent::Handle::ZeroMQ->new( socket => $socket_b );

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
my $done = AE::cv;

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
$hdl_a->push_read(sub{
    my($hdl, $data) = @_;
    my $data_str = [ map { $_->data } @$data ];
    my $peer = $data_str->[0];
    is_deeply($data_str, [$peer, "", 'a', '123'], 'recv1');

    $hdl->push_write([$peer, "", 'b', '345']);
});

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
$hdl_b->push_read(sub{
    my($hdl, $data) = @_;
    my $data_str = [ map { $_->data } @$data ];
    is_deeply($data_str, ["", 'b', '345'], 'recv2');

    $done->send;
});

print STDERR "@{[__FILE__]} @{[__LINE__]}\n";
is($a_on_drain, 1, 'on_drain 1');

$hdl_b->push_write(["", 'a', '123']);

$done->recv;

is($a_on_drain, 2, 'on_drain 2');
