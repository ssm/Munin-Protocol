#!/usr/bin/perl

package Munin::Protocol;
use strict;
use warnings;
use Regexp::Grammars;
use Contextual::Return;

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
    return $grammar;
}

sub parse_request {
    my $self    = shift;
    my $request = shift;

    if ( $request =~ $self->{request_grammar} ) {
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
