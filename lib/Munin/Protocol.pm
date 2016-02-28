#!/usr/bin/perl

=head1 NAME

Munin::Protocol - Stateful protocol handler for Munin

=head1 SYNOPSIS

    use Munin::Protocol;
    my $p   = Munin::Protocol->new();

    p->parse_request("list");
    p->parse_response("something foo bar zome otherplugin");

    $p->parse_request("config something");
    $p->parse_response(...);

    $p->parse_request("fetch something");
    $p->parse_response(...);

    # TODO: At this point, if all went well, $p should contain data for one or
    # more graphs provided by plugin "something". Add documentation for this.

=head1 DESCRIPTION

Munin::Protocol is a stateful protocol handler for a Munin master-node
connection.

It will keep the name of the last parsed request, and select the correct
parser for the response. It will also contain a data structure of the last
response.

=head2 State

The C<Munin::Protocol> object keeps state.  You probably should not share it
between connections.

In particular:

=over

=item hostname

The hostname of the munin node will be available as C<< $p->node->hostmame >>

=item capabilities

The capabilities common to the munin master and munin node will be available
as C<< $p->capabilities >>

=item graphs

The graph data retrieved after a successsful config, (with dirtyconfig), or a
pair of C<config> and C<fetch> statements. (or C<parse_request> and
C<parse_response>)

=back

=head2 Capabilities

If the "cap" request and response contains a capability, the protocol state
will store this.

TODO: Add awesome code example

=over

=item dirtyconfig

If the node and master has successfully negotiated the "dirtyconfig"
capability, the parser will look for values in the plugin response after
"config".

Hint: The caller should look for values after each "config", and skip the
"fetch" step for that plugin if present.

=item multigraph

If the "cap" request and response contains "multigraph", the parser accept a
multigraph response.

Hint: This means that the list of plugin responses will contain data for
multiple graphs.

=back

=head1 METHODS

An object of this class represents a connection between a munin master and a
munin node, on the protocol level. It keeps some state for this, in order to
successfully send a request, and parse a response.

L<Munin::Protocol> implements the following methods:

=head2 new

    my $p = Munin::Protocol->new();

=head2 parse_request

    my $r = $p->parse_request('cap dirtyconfig multigraph');
    my $r = $p->parse_request('list');
    my $r = $p->parse_request('config myplugin');
    my $r = $p->parse_request('fetch myplugin');

=head2 parse_response

    my $graphs = $p->parse_response('')

=head1 DEPENDENCIES

L<Munin::Protocol> depends on the following modules:

=over

=item Regexp::Grammar

This is the engine of this perl module.

=item Contextual::Return

This seemed like a good idea at the time.

=item Carp

This module is in perl core.

=back

=head1 BUGS AND LIMITATIONS

This module is not finished.  It is under development.  It is barely started.
The functionality in this documentation may be implemented poorly, or not at
all.  Everything here is also subject to change until an eventual 1.0 release.

Please report problems to Stig Sandbeck Mathisen <L<ssm@fnord.no>>
Patches are welcome.

=head1 AUTHOR

Stig Sandbeck Mathisen <ssm@fnord.no>

=head1 LICENCE AND COPYRIGHT

Copyright (c) 2016 Stig Sandbeck Mathisen <ssm@fnord.no>.
All rights reserved.

This module is free software; you can redistribute it and/or modify it under
the same terms as Perl itself. See L<perlartistic>.

This program is distributed in the hope that it will be useful, but WITHOUT
ANY WARRANTY; without even the implied warranty ofMERCHANTABILITY or FITNESS
FOR A PARTICULAR PURPOSE.

=cut

package Munin::Protocol;
use strict;
use warnings;
use Regexp::Grammars;
use Contextual::Return;
use Carp;

sub new {
    my $class = shift;

    my $self = {};
    bless $self;

    $self->_build_request;
    $self->_build_response_banner;
    $self->_build_response_nodes;
    $self->_build_response_cap;
    $self->_build_response_list;
    $self->_build_response_config;
    $self->_build_response_fetch;

    $self->{state}->{request}      = 'banner';
    $self->{state}->{response}     = '';
    $self->{state}->{capabilities} = [];
    $self->{state}->{node}         = '';
    $self->{state}->{nodes}        = [];

    $self->{dispatch} = {
        banner => sub { my $r = shift; $self->_parse_response_banner($r) },
        cap    => sub { my $r = shift; $self->_parse_response_cap($r) },
        nodes  => sub { my $r = shift; $self->_parse_response_nodes($r) },
        list   => sub { my $r = shift; $self->_parse_response_list($r) },
        config => sub { my $r = shift; $self->_parse_response_config($r) },
        fetch  => sub { my $r = shift; $self->_parse_response_fetch($r) },
        spoolfetch =>
          sub { my $r = shift; $self->_parse_response_spoolfetch($r) },
        DEFAULT => sub { confess "Not implemented" },
    };

    return $self;
}

sub parse_request {
    my $self    = shift;
    my $request = shift;

    if ( $request =~ $self->{grammar}->{request} ) {
        my $command   = $/{statement}->{command};
        my $arguments = $/{statement}->{arguments} // [];
        my $statement = $/{statement}->{''};

        $self->{state}->{request} = $command;

        return (
            BOOL   { 1 }
            LIST   { %/ }
            SCALAR { $statement }
            HASHREF {
                {
                    command   => $command,
                    arguments => $arguments,
                    statement => $statement
                };
            }
        );
    }
    else {
        return ( BOOL { 0 } );
    }
}

sub parse_response {
    my $self     = shift;
    my $response = shift;

    my $parser = $self->{state}->{request};

    return $self->{dispatch}->{$parser}->($response);
}

sub _parse_response_banner {
    my $self    = shift;
    my $request = shift;

    if ( $request =~ $self->{grammar}->{response}->{banner} ) {
        my $node = $/{banner}->{node};

        $self->{state}->{node} = $node;

        return ( BOOL { 1 } SCALAR { $node } );
    }
    else {
        return ( BOOL { 0 } );
    }
}

sub _parse_response_nodes {
    my $self    = shift;
    my $request = shift;

    if ( $request =~ $self->{grammar}->{response}->{nodes} ) {
        my $nodes = $/{NodeList}->{Node};
        $self->{state}->{nodes} = $nodes;

        return (
            BOOL { 1 }
            SCALAR { join( " ", @{$nodes} ) }
            LIST { @{$nodes} }
            );
    }
    else {
        return ( BOOL { 0 } );
    }
}

sub _build_request {
    my $self = shift;

    my $grammar = qr{
    \A
    <.ws>*
    <statement>
    <.ws>*
    \Z

    <rule: statement>
        <command= (cap)> <arguments=capabilities>
      | <command= (list)> <[arguments=hostname]>?
      | <command= (nodes)>
      | <command= (quit)>
      | <command= (help)>
      | <command= (config)> <arguments=plugin>
      | <command= (fetch)> <arguments=plugin>
      | <command= (spoolfetch)> <arguments=timestamp>

    <rule: capabilities>
        <[MATCH=capability]>* % <.ws>

    <token: capability>
        [[:alpha:]]+

    <token: plugin>
        [[:alpha:]]+

    <token: hostname>
        \S+

    <token: timestamp>
        \d+
    }xms;

    $self->{grammar}->{request} = $grammar;
    return $self;
}

sub _build_response_banner {
    my $self = shift;

    my $banner = qr{
         \A
         <banner>
         \Z

         <rule: banner>
         [#] munin node at <node>

         <rule: node>
         \S+           # this is a shortcut
    }smx;

    $self->{grammar}->{response}->{banner} = $banner;
    return $self;
}

sub _build_response_nodes {
    my $self = shift;

    my $nodes_grammar = qr{
         <NodeList>

         <rule: NodeList>
         \A
         <[Node]>+ % <Separator>
         <End>
         \Z

         <rule: Node>
         (?![.])\S+

         <rule: Separator>
         \n

         <rule: End>
         \n[.]\n
    }smx;

    $self->{grammar}->{response}->{nodes} = $nodes_grammar;
    return $self;
}

sub _build_response_list {
    my $self = shift;

    my $list = qr{
                     \A
                     <plugins>
                     \Z

                     <rule: plugins>
                     <[plugin]>* % <.ws>

                     <token: plugin>
                     [[:alpha:]][[:alnum:]]*
    }smx;
    $self->{grammar}->{response}->{list} = $list;
}

sub _build_response_cap {
    my $self = shift;

    my $cap = qr{
                    \A
                    cap <capabilities>
                    \Z

                    <rule: capabilities>
                    <[capability]> % <.ws>

                    <token: capability>
                    [[:alpha:]]+
            }smx;
    $self->{grammar}->{response}->{cap} = $cap;
    return $self;
}

sub _build_response_config {
    my $self = shift;

    my $config = qr{
                       \A
                       <lines>
                       \n\.\n
                       \Z

                       <rule: lines>
                       <[line]>+ % \n

                       <rule: line>
                       <[update_config]> | <[graph_config]> | <[ds_value]> | <[ds_config]>

                       <rule: update_config>
                       <update_rate>

                       <token: update_rate>
                       update_rate

                       <token: update_rate_seconds>
                       \d+

                       <rule: graph_config>
                       <graph_period> | <graph_scale> | <graph_info> | <graph_category> | <graph_vlabel> | <graph_args> | <graph_title>

                       <rule: graph_title>
                       graph_title <graph_title_arg=string>

                       <rule: graph_vlabel>
                       graph_vlabel <graph_vlabel_arg=string>

                       <rule: graph_args>
                       graph_args <graph_args_arg=string>

                       <rule: graph_category>
                       graph_category <graph_category_arg>

                       <token: graph_category_arg>
                       [[:word:]]+

                       <rule: graph_info>
                       graph_info <graph_info_arg=string>

                       <rule: graph_scale>
                       graph_scale <graph_scale_arg>

                       <token: graph_scale_arg>
                       yes | no

                       <rule: graph_period>
                       graph_period <graph_period_arg>

                       <token: graph_period_arg>
                       second | minute | hour

                       <rule: ds_config>
                       <ds_config_key> <ds_config_value=string>

                       <token: ds_config_key>
                       <ds_name>\.<ds_attr=string>

                       <token: ds_name>
                       [[:alpha:]_]+

                       <token: ds_value>
                       U | ^[-+]?\d*\.?\d+([eE][-+]?\d+)?$

                       <token: string>
                       [^\n]+
               }smx;
    $self->{grammar}->{response}->{config} = $config;
    return $self;
}

sub _build_response_fetch {
    my $self = shift;

    my $fetch = qr{
                      \A
                      <lines>
                      \n\.\n
                      \Z

                      <rule: lines>
                      <[line]>+

                      <rule: line>
                      ^
                      <ds_name>.value
                      <ds_value>
                      $

                      <token: ds_name>
                      [[:alnum:]_]+

                      <token: ds_value>
                      U | ^[-+]?\d*\.?\d+([eE][-+]?\d+)?$

              }smx;
    $self->{grammar}->{response}->{fetch} = $fetch;
    return $self;
}

1;
