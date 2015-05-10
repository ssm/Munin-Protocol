#!/usr/bin/perl

package Munin::Protocol;
use strict;
use warnings;
use Regexp::Grammars;
use Contextual::Return;

sub new {
    my $class = shift;
    my $self  = {};

    $self
      ->_build_request_grammar
      ->_build_response_grammar;


    $self->{request}      = '';
    $self->{capabilities} = [];

    bless $self;
    return $self;
}

sub _build_request_grammar {
    my $self = shift;

    my $grammar = qr{
    \A
    <.ws>*
    <statement>
    <.ws>*
    \Z

    <rule: statement>
        <command= (cap)> <arguments=capabilities>
      | <command= (list)>
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

    <token: timestamp>
        \d+
    }xms;

    $self->{grammar}->{request} = $grammar;
    return $self;
}

sub _build_response_grammar {
    my $self = shift;

    my $banner = qr{
         \A
         <banner>
         \Z

         <rule: banner>
         \\#
         munin node at
         <hostname>

         <rule: hostname>
         [[:word:]]       # this is a shortcut
    }smx;

    $self->{grammar}->{response}->{banner} = $banner;

    my $list = qr{
                     \A
                     <plugins>
                     \Z

                     <rule: plugins>
                     <[plugin]>* % <.ws>

                     <token: plugin>
                     [[:alpha:]][[:alnum:]]*
    }smx;

    my $cap = qr{
                    \A
                    cap <capabilities>
                    \Z

                    <rule: capabilities>
                    <[capability]> % <.ws>

                    <token: capability>
                    [[:alpha:]]+
    }smx;

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
    $self->{response}->{fetch} = $fetch;

    my $spoolfetch = qr{smx};

}

sub parse_request {
    my $self    = shift;
    my $request = shift;

    if ( $request =~ $self->{grammar}->{request} ) {
        my $command   = $/{statement}->{command};
        my $arguments = $/{statement}->{arguments} // [];
        my $statement = $/{statement}->{''};

        return (
            BOOL   { 1 }
            LIST   { %/ }
            SCALAR { $statement }
            HASHREF {
                {
                    command   => $command,
                    arguments => $arguments,
                    statement => $statement
                }
            }
        );
    }
    else {
        return ( BOOL { 0 } );
    }
}

package main;
use strict;
use warnings;
use IO::Prompter;
use Data::Printer;
use feature 'say';

my $protocol = Munin::Protocol->new();

PROMPT:
while ( prompt 'munin> ' ) {
    next PROMPT if $_ eq '';
    if ( my $r = $protocol->parse_request($_) ) {
        say $r;
    }
    else {
        print STDERR "error: parse error\n";
    }
}
