#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;

run_test(
    4,
    sub {
        one();
        sub one {
            $DB::single=1;
            15;
        }
        two(); # 17
        sub subtwo {
            $DB::single=1;
            20;
        }
        sub two {
            subtwo();
            24;
        }
        26;
    },
    loc(subroutine => 'main::one', line => 15),
    'stepout',
    loc(line => 17),
    'continue',
    'stepout',
    loc(subroutine => 'main::two', line => 24),
    'stepout',
    loc(line => 26),
    'done'
);
