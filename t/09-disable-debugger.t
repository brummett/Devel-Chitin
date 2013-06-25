#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
$DB::single=1;
7;
9;
10;

use Test::More tests => 4;
use lib 't/lib';
use TestDB;

sub test_1 {
    my($tester, $loc) = @_;
    
    { no warnings 'once';
        *TestDB::notify_trace = sub {
            ok(0, 'notify_trace was called');
            die "notify_trace was called";
        };
    }
    ok($tester->trace(1), 'turn on trace');
    ok($tester->disable_debugger, 'Disable debugger');
    ok(Devel::CommonDB::Breakpoint->new(
        file => __FILE__,
        line => 7,
        code => 1),
        'Set unconditional breakpoint on line 7');

    ok($tester->continue(), 'continue');
}

