#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

foo();
sub foo {
    $DB::single=1;
    8;
    Bar::bar();
}
sub Bar::bar {
    $DB::single=1;
    13;
    Bar::baz();
}
package Bar;
sub baz {
    $DB::single=1;
    19;
}

package main;

use Test::More tests => 7;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    is_deeply($loc,
            {   filename    => __FILE__,
                'package'   => 'main',
                subroutine  => 'MAIN',
                line        => 5 },
            'Stopped at first executable line');
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is_deeply($loc,
            {   filename    => __FILE__,
                'package'   => 'main',
                subroutine  => 'main::foo',
                line        => 8 },
            'Stopped inside foo()');
    ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    is_deeply($loc,
            {   filename    => __FILE__,
                'package'   => 'main',
                subroutine  => 'Bar::bar',
                line        => 13 },
            'Stopped inside Bar::bar()');
    ok($tester->continue(), 'continue');
}

sub test_4 {
    my($tester, $loc) = @_;
    is_deeply($loc,
            {   filename    => __FILE__,
                'package'   => 'Bar',
                subroutine  => 'Bar::baz',
                line        => 19 },
            'Stopped inside Bar::baz()');
    $tester->__done__;
}
