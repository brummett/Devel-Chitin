#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

one();
sub one {
    $DB::single=1;
    8;
}
two();
sub subtwo {
    $DB::single=1;
    13;
}
sub two {
    subtwo();
    17;
}
19;

use Test::More tests => 10;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 8, 'Stopped on line 8');
    ok($tester->stepout(), 'stepout');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 10, 'Stopped on line 10, after one()');
    ok($tester->continue(), 'continue');
}

sub test_4 {
    my($tester, $loc) = @_;
    is($loc->line, 13, 'Stopped on line 13');
    ok($tester->stepout, 'stepout');
}

sub test_5 {
    my($tester, $loc) = @_;
    is($loc->line, 17, 'Stopped on line 17');
    ok($tester->stepout, 'stepout');
}

sub test_6 {
    my($tester, $loc) = @_;
    is($loc->line, 19, 'Stopped on line 19');
    $tester->__done__;
}
