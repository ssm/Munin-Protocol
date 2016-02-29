package Munin::Protocol::Test;
use strict;
use warnings;
use base qw(Test::Class);
use Test::More;
use Munin::Protocol;

# setup methods are run before every test method.
sub class { 'Munin::Protocol' }

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
    is(
        $res,
        'list test1.example.com',
        'command: list <hostname>, scalar context'
    );
    is_deeply(
        \%{$res},
        {
            command   => 'list',
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
        {
            command   => 'cap',
            arguments => [ 'foo', 'bar' ],
            statement => 'cap foo bar'
        },
        'command: cap <capabilities>, hashref'
    );

}

##############################
# Response parsers
sub response_banner : Test(6) {
    my $p = shift->{protocol};

    ok( $p, 'protocol established' );
    ok( $p->_parse_response_banner("# munin node at test1.example.com"),
        'banner' );

    ok( $p->_parse_response_banner("# munin \nnode  at\ttest1.example.com"),
        'should accept any whitespace' );
    ok( !$p->_parse_response_banner("munin node at test1.example.com\n"),
        'should fail with missing #' );
    ok(
        !$p->_parse_response_banner(
            "# munin node at test1.example.com something extra"),
        'should fail with extra arguments'
    );
    ok( !$p->_parse_response_banner("a# munin node at test1.example.com"),
        'should fail with garbage in front' );
}

##############################
# Response parsers
sub response_nodes : Test(3) {
    my $p = shift->{protocol};

    my $nodes_response = <<'END_NODES';
node1.example.com
node2.example.com
.
END_NODES

    ok( $p,                                         'protocol established' );
    ok( $p->_parse_response_nodes($nodes_response), 'parse nodes' );
    is_deeply(
        $p->{state}->{nodes},
        [ 'node1.example.com', 'node2.example.com' ],
        'expected node list stored'
    );
}

##############################
# Response parsers
sub response_cap : Test(3) {
    my $p = shift->{protocol};

    my $cap_response = <<'END_CAP';
cap multigraph dirtyconfig
END_CAP

    ok( $p,                                     'protocol established' );
    ok( $p->_parse_response_cap($cap_response), 'parse capabilities' );
    is_deeply(
        $p->{state}->{capabilities},
        [ 'multigraph', 'dirtyconfig' ],
        'expected capability list stored'
    );
}

##############################
# Stateful tests
sub state : Test(11) {
    my $p = shift->{protocol};
    my $s = $p->{state};

    ok( $p, 'protocol established' );

    is( $s->{node}, '', 'node name empty' );
    is_deeply( $s->{nodes},        [], 'node list empty' );
    is_deeply( $s->{capabilities}, [], 'capabilities list empty' );
    is( $s->{request}, 'banner', 'initial paraser is "banner"' );

    # receive banner
    ok(
        $p->parse_response("# munin node at test1.example.com"),
        'parse_response for banner should return a true value'
    );

    # check state
    is( $s->{node}, 'test1.example.com', 'node name should be set' );

    # comand: "nodes"
    my $nodes_response = <<'EOF';
foo.example.com
bar.example.com
.
EOF
    ok( $p->parse_request('nodes'), 'parse request: nodes' );
    is( $s->{request}, 'nodes', 'check parser state for: nodes' );
    ok( $p->parse_response($nodes_response), 'parse response for: nodes' );
    is_deeply(
        $s->{nodes},
        [ 'foo.example.com', 'bar.example.com' ],
        'check session state for: nodes'
    );
}

1;
