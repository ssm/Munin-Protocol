#!/usr/bin/perl

use strict;
use warnings;
use Munin::Protocol;
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
