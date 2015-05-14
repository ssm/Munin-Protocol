package Munin::Protocol::Test;
use strict;
use warnings;
use base qw(Test::Class);
use Test::More;
use Munin::Protocol;

# setup methods are run before every test method.
sub class {'Munin::Protocol'}

sub startup : Tests(startup => 1) {
    my $test = shift;
    use_ok( $test->class );
}

sub constructor : Tests(3) {
    my $test  = shift;
    my $class = $test->class;

    can_ok $class, 'new';
    ok my $protocol = $class->new, '... and the constructor should succeeed';
    isa_ok $protocol, $class, '... and the object it returns';
}

# Fixtures
sub protocol : Test(setup) {
    my $self = shift;
    $self->{protocol} = $self->class->new;
}

##############################
# Object tests

sub object_grammars : Test(5) {
    my $p = shift->{protocol};

    ok( $p->{grammar}->{request},            'request grammar' );
    ok( $p->{grammar}->{response}->{banner}, 'banner response grammar' );
    ok( $p->{grammar}->{response}->{cap},    'cap response grammar' );
    ok( $p->{grammar}->{response}->{config}, 'config response grammar' );
    ok( $p->{grammar}->{response}->{fetch},  'fetch response grammar' );
}

sub object_methods : Test(1) {
    my $p = shift->{protocol};

    can_ok( $p, qw(parse_request parse_response) );
}

sub object_private_methods : Test(1) {
    my $p = shift->{protocol};

    can_ok(
        $p, qw{ _parse_response_banner _parse_response_cap
            _parse_response_nodes _parse_response_list
            _parse_response_config _parse_response_fetch
            _parse_response_spoolfetch }
    );
}

sub object_dispatch : Test(9) {
    my $p = shift->{protocol};
    my $d = $p->{dispatch};

    ok( $d, 'dispatch table exists' );
    isa_ok( $d->{DEFAULT},      'CODE', 'dispatch DEFAULT entry' );
    isa_ok( $d->{'banner'},     'CODE', 'dispatch table for banner' );
    isa_ok( $d->{'cap'},        'CODE', 'dispatch table for cap' );
    isa_ok( $d->{'nodes'},      'CODE', 'dispatch table for nodes' );
    isa_ok( $d->{'list'},       'CODE', 'dispatch table for list' );
    isa_ok( $d->{'config'},     'CODE', 'dispatch table for config' );
    isa_ok( $d->{'fetch'},      'CODE', 'dispatch table for fetch' );
    isa_ok( $d->{'spoolfetch'}, 'CODE', 'dispatch table spoolfetch' );
}

##############################
# Command tests

sub command_list : Test(3) {
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

sub command_list_node : Test(3) {
    my $p = shift->{protocol};

    my $res = $p->parse_request('list test1.example.com');

    ok( $res, 'command: list <hostname>, boolean context' );
    is( $res,
        'list test1.example.com',
        'command: list <hostname>, scalar context'
    );
    is_deeply(
        \%{$res},
        {   command   => 'list',
            arguments => ['test1.example.com'],
            statement => 'list test1.example.com'
        },
        'command: list <hostname>, hashref'
    );
}

sub command_cap : Test(3) {
    my $p = shift->{protocol};

    my $res = $p->parse_request('cap foo bar');

    ok( $res, 'command: cap <capabilities>, boolean context' );
    is( $res, 'cap foo bar', 'command: cap <capabilities>, scalar context' );
    is_deeply(
        \%{$res},
        {   command   => 'cap',
            arguments => [ 'foo', 'bar' ],
            statement => 'cap foo bar'
        },
        'command: cap <capabilities>, hashref'
    );

}

##############################
# Stateful tests
sub state : Test(6) {
    my $p = shift->{protocol};
    my $s = $p->{state};

    ok( $p, 'protocol established' );

    is( $s->{node}, '', 'node name empty' );
    is_deeply( $s->{nodes},        [], 'node list empty' );
    is_deeply( $s->{capabilities}, [], 'capabilities list empty' );

    # receive banner
    ok( $p->parse_response("# munin node at test1.example.com\n") );

    # check state
    is( $s->{node}, 'test1.example.com', 'node name should be set' );
}
1;
