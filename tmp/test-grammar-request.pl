#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;
use IO::Prompter;

my $request = qr{
    \A
    <.ws>? <statement> <.ws>?
    \Z

    <rule: statement>
        <command= (cap)>
        <[capabilities=capability]>+ % <.ws>
        |
        <command= (list)>
        |
        <command= (config)> <plugin>
        |
        <command= (fetch)> <plugin>
        |
        <command= (spoolfetch)> <timestamp>

    <token: capability>
        [[:alpha:]]+

    <token: plugin>
        [[:alpha:]]+

    <token: timestamp>
        \d+
}xms;

use Data::Dumper;

PROMPT:
while (prompt 'munin> ') {
    next PROMPT if $_ eq '';
    $_ =~ $request && print Dumper $/{statement};
}
