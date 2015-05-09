#!/usr/bin/perl

use strict;
use warnings;
use Regexp::Grammars;

my $request = qr{
  <debug: step>
  <command>
  <debug: off>

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
  <[capabilities]>

<rule: list_command>
  list

<rule: config_command>
  config <plugin>

<rule: fetch_command>
  fetch <plugin>

<rule: spoolfetch_command>
  spoolfetch <timestamp>

<rule: capabilities>
  <capability>
  (?:
    <.ws>
    <capability>
  )*

<token: capability>
  [[:alpha:]]+

<token: plugin>
  [[:alpha:]]+

<token: timestamp>
  \d+

};


my @commands = (
    'cap dirtyconfig',
    'cap spoolfetch',
    'cap dirtyconfig multigraph spoolfetch',
    'list',
    'config foo',
    'fetch foo',
);


foreach my $command (@commands) {
    $command =~ $request;
}
