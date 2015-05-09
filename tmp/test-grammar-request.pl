#!/usr/bin/perl

package Munin::Protocol;
use strict;
use warnings;
use Regexp::Grammars;

sub new {
    my $class = shift;
    my $self  = {};

    $self->{request_grammar} = &_build_request_grammar;

    bless $self;
    return $self;
}

sub _build_request_grammar {
    my $grammar = qr{
    \A
    <.ws>*
    <statement>
    <.ws>*
    \Z

    <rule: statement>
        <command= (cap)> <capabilities>
      | <command= (list)>
      | <command= (quit)>
      | <command= (help)>
      | <command= (config)> <plugin>
      | <command= (fetch)> <plugin>
      | <command= (spoolfetch)> <timestamp>

    <rule: capabilities>
        <[MATCH=capability]>* % <.ws>

    <token: capability>
        [[:alpha:]]+

    <token: plugin>
        [[:alpha:]]+

    <token: timestamp>
        \d+
    }xms;
    return $grammar;
}

sub parse_request {
    my $self = shift;
    my $request = shift;

    if ($request =~ $self->{request_grammar}) {
        return \%/;
    }
}

package main;
use strict;
use warnings;
use IO::Prompter;
use Data::Printer;

my $protocol = Munin::Protocol->new();

PROMPT:
while ( prompt 'munin> ' ) {
    next PROMPT if $_ eq '';
    if ( my $r = $protocol->parse_request($_) ) {
        p $r;
    }
    else {
        print "parse error\n";
    }
}
