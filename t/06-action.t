#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';
use Test::More tests => 4;

my $a = 1;
7;
is($a, 2, 'Action changed the value of $a to 2');

use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    ok(Devel::CommonDB::Action->new(
            file => $loc->filename,
            line => 7,
            code => '$a++',
        ), 'Set action on line 7');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 7,
            code => '$a++',
            inactive => 1,
        ), 'Set inactive action also on line 7');
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my $tester = shift;
    $tester->__done__;
}
    
