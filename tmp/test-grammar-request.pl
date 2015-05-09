#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;
use IO::Prompter;
use feature 'say';

my $request = qr{
    ^
    <statement>
    $

    <rule: statement>
        <command= (cap)>
        <[arguments=capabilities]>+
        |
        <command= (list)>
        |
        <command= (config)> <arguments=plugin>
        |
        <command= (fetch)> <arguments=plugin>
        |
        <command= (spoolfetch)> <argument=timestamp>

    <rule: capabilities>
        <.ws>?
        <MATCH=capability>

    <token: capability>
        [[:alpha:]]+

    <token: plugin>
        [[:alpha:]]+

    <token: timestamp>
        \d+
};

use Data::Dumper;

PROMPT:
while (prompt 'munin> ') {
    if ($_ eq '') {
        next PROMPT
    }
    $_ =~ $request && print Dumper $/{statement};
}
