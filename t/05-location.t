#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::CommonDB::TestRunner;

run_test(
    4,
    sub { $DB::single=1;
        foo(); 12;
        sub foo {
            $DB::single=1;
            15;
            Bar::bar();
        }
        sub Bar::bar {
            $DB::single=1;
            20;
            Bar::baz();
        }
        package Bar;
        sub baz {
            $DB::single=1;
            26;
        }
    },
    loc(filename => __FILE__, package => 'main', line => 12),
    'continue',
    loc(filename => __FILE__, package => 'main', subroutine => 'main::foo', line => 15),
    'continue',
    loc(filename => __FILE__, package => 'main', subroutine => 'Bar::bar', line => 20),
    'continue',
    loc(filename => __FILE__, package => 'Bar', subroutine => 'Bar::baz', line => 26),
    'done',
);

