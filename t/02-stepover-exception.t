#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

eval {
    do_die();
};
wrap_die();
1;
sub wrap_die {
    eval { do_die() };
}
sub do_die {
    die "in do_die";
}

use Test::More tests => 10;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    # step over the eval
    ok($tester->stepover(), 'Step over first eval');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 6, 'Stopped on line 6');
    ok($tester->stepover(), 'Step over do_die');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 8, 'Stopped on line 8');
    ok($tester->step(), 'Step into wrap_die()');
}

sub test_4 {
    my($tester, $loc) = @_;
    is($loc->line, 11, 'Stopped on line 11');
    ok($tester->stepover(), 'Step over eval do_die within wrap_die');
}

sub test_5 {
    my($tester, $loc) = @_;
    is($loc->line, 11, 'Still stopped on line 11, inside the eval');
    ok($tester->stepover(), 'Step over do_die within wrap_die');
}
    
sub test_6 {
    my($tester, $loc) = @_;
    is($loc->line, 9, 'Stopped on line 9, right after wrap_die');
    $tester->__done__;
}
    
