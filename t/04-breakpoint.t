#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;

run_test(
    7,
    sub {
        $DB::single=1; 12;
        13;
        14;
        15;
        16;
    },
    \&set_breakpoints,
    'continue',
    loc(line => 13),
    'continue',
    loc(line => 16),
    'done'
);

sub set_breakpoints {
    my($db, $loc) = @_;

    Test::More::ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 13,
        ), 'Set unconditional breakpoint on line 13');
    Test::More::ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 14,
            code => 0,
        ), 'Set breakpoint that will never fire on line 14');
    Test::More::ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 15,
            code => 1,
            inactive => 1,
        ), 'Set unconditional, inactive breakpoint on line 15');
    Test::More::ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 16,
            code => 0,
        ), 'Set breakpoint that will never fire on line 16');
    Test::More::ok(Devel::CommonDB::Breakpoint->new(
            file => $loc->filename,
            line => 16,
        ), 'Set second unconditional breakpoint line 16');
}

