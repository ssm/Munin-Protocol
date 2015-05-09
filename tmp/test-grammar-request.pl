#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;
use IO::Prompter;
use Data::Printer;

my $request = qr{
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

PROMPT:
while (prompt 'munin> ') {
    next PROMPT if $_ eq '';
    if ($_ =~ $request) {
        p %/;
    }
    else {
        print "parse error\n";
    }
}
