#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

for(my $i = 0; $i < 10; $i++) {
    6;
}
$DB::single = 1;
9;

use Test::More tests => 5;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 6,
            code => 1,
            once => 1,
        ), 'Set one-time, unconditional breakpoint on line 6');
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 6, 'Stopped on line 6');
    ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 9, 'Stopped on line 9');
    $tester->__done__;
}
    
