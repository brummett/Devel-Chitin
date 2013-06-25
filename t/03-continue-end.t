#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
6;
7;
$DB::single=1;
9;
10;

use lib 't/lib';
use TestDB;
use Test::Builder;

my $tb;
BEGIN {
    $tb = Test::Builder->new();
    $tb->plan(tests => 6);
    # We're testing that the Debugger's END block is run correctly
    # which interferes with the way Test::Builder reports retsults.
    # This hack disables Test::Builder's reporting in its own END block.
    # We'll call it's reporting mechanism in the final test function
    $tb->{Ending} = 1;
}

sub test_1 {
    my($tester, $loc) = @_;
    $tb->ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    $tb->is_eq($loc->line, 9, 'Stopped on line 9, breakpoint in code');
    $tb->ok(! $loc->at_end, 'Not at the end of the program');
    $tb->ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    $tb->is_eq($loc->subroutine, 'Devel::CommonDB::exiting::at_exit', 'in the "at_exit" subroutine');
    $tb->ok($loc->at_end, 'At the end of the program');
    $tester->__done__;
    $tb->finalize;

    # Here's where we make Test::Builder report results
    $tb->{Ending} = 0;
    $tb->_ending();
}

