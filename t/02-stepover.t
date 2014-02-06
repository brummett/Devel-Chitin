#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;

run_test(
    2,
    sub {
        $DB::single = 1;
        foo();
        14;
        sub foo {
            16;
        }
    },
    loc(line => 13),
    'stepover',
    loc(line => 14),
    'done'
);

