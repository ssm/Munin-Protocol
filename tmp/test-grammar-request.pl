#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;

my $request = qr{
    <command>

    <rule: command>
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
        <debug: step>
        <[capabilities]>+
        <debug: off>

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


my @commands = (
    'cap dirtyconfig',
    'cap dirtyconfig multigraph spoolfetch',
    'list',
    'config foo',
    'fetch foo',
);


use Data::Dumper;

foreach my $command (@commands) {
    $command =~ $request;

    print Dumper $/{command};

}
