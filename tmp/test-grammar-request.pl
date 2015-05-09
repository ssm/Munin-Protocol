#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;
use IO::Prompter;
use feature 'say';

my $request = qr{
    ^
    # <debug: step>
    <statement>

    <rule: statement>
        <cap_command>
        |
        <list_command>
        |
        <config_command>
        |
        <fetch_command>
        |
        <spoolfetch_command>

    <rule: cap_command>
        cap
        <[capabilities]>+

    <rule: list_command>
        list

    <rule: config_command>
        config <plugin>

    <rule: fetch_command>
        fetch <plugin>

    <rule: spoolfetch_command>
        spoolfetch <timestamp>

    <rule: capabilities>
        <MATCH=capability>
        |
        <.ws>
        <MATCH=capability>

    <token: capability>
        [[:alpha:]]+

    <token: plugin>
        [[:alpha:]]+

    <token: timestamp>
        \d+

    <token: delimiter>
        \s+
};

use Data::Dumper;

PROMPT:
while (prompt 'munin> ') {
    if ($_ eq '') {
        next PROMPT
    }
    $_ =~ $request && print Dumper $/{statement};
}
