package Munin::Protocol::Test;
use strict;
use warnings;
use base qw(Test::Class);
use Test::More;
use Munin::Protocol;

# setup methods are run before every test method.
sub make_fixture : Test(setup) {
    my $protocol = Munin::Protocol->new;
    shift->{protocol} = $protocol;
}

sub test_object : Test {
    my $p = shift->{protocol};
    ok($p);
}

sub test_object_grammars : Test(5) {
    my $p = shift->{protocol};

    ok( $p->{grammar}->{request},            'request grammar' );
    ok( $p->{grammar}->{response}->{banner}, 'banner response grammar' );
    ok( $p->{grammar}->{response}->{cap},    'cap response grammar' );
    ok( $p->{grammar}->{response}->{config}, 'config response grammar' );
}

sub test_command_list : Test(3) {
    my $p = shift->{protocol};

    my $res = $p->parse_request('list');

    ok( $res, 'command: list, boolean context' );
    is( $res, 'list', 'command: list, scalar context' );
    is_deeply(
        \%{$res},
        { command => 'list', arguments => [], statement => 'list' },
        'command: list, hashref'
    );
}

sub test_command_cap : Test(3) {
    my $p = shift->{protocol};

    my $res = $p->parse_request('cap foo bar');

    ok( $res, 'command: cap <capabilities>, boolean context' );
    is( $res, 'cap foo bar', 'command: cap <capabilities>, scalar context' );
    is_deeply(
        \%{$res},
        {
            command   => 'cap',
            arguments => [ 'foo', 'bar' ],
            statement => 'cap foo bar'
        },
        'command: cap <capabilities>, hashref'
    );
}

1;
