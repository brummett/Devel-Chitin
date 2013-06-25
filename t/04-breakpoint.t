#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
6;
7;
8;
9;
10;

use Test::More tests => 9;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 7,
            code => 1,
        ), 'Set unconditional breakpoint on line 7');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 8,
            code => 0,
        ), 'Set breakpoint that will never fire on line 8');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 9,
            code => 1,
            inactive => 1,
        ), 'Set unconditional, inactive breakpoint on line 9');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 10,
            code => 0,
        ), 'Set breakpoint that will never fire on line 10');
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 10,
            code => 1,
        ), 'Set second unconditional breakpoint line 10');


    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 7, 'Stopped on line 7');
    ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 10, 'Stopped on line 10');
    $tester->__done__;
}
    
