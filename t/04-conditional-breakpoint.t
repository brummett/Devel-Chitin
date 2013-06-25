#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

my $a = 1;
6;
$a = 2;
8;
$a = 3;
10;
$DB::single=1;
12;

use Test::More tests => 8;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 6,
            code => '$a == 2',
        ), 'Set conditional breakpoint on line 6');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 8,
            code => '$a == 2',
        ), 'Set conditional breakpoint that will fire on line 8');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 10,
            code => '$a == 2',
        ), 'Set conditional breakpoint on line 10');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 10,
            code => 0,
        ), 'Set breakpoint that will never fire on line 10');

    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 8, 'Stopped on line 8');
    ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 12, 'Stopped on line 12');
    $tester->__done__;
}
