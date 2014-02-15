#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use Devel::Chitin::TestRunner;

run_test(
    19,
    sub {
        sub foo {
            13;
        }
        sub Bar::bar {
            16;
        }
        package Bar;
        sub baz {
            20;
        }
        $DB::single=1;
    },
    \&check_subroutine_location,
    'done',
);

sub check_subroutine_location {
    my($db, $loc) = @_;

    my $check_expected = sub {
        my($got, $expected, $msg) = @_;
        my $ok = 1;
        foreach my $k ( qw( package filename subroutine line end code ) ) {
            Test::More::is($got->$k, $expected->{$k}, "$msg $k");
        }
    };

    Test::More::ok(! $db->subroutine_location('not::there'),
        'subroutine_location() with non-existant sub returns undef');

    $check_expected->(
        $db->subroutine_location('main::foo'),
        {
            package => 'main',
            subroutine => 'foo',
            filename => __FILE__,
            line => 12,
            end => 14,
            code => \&main::foo,
        },
        'main::foo location');

    $check_expected->(
        $db->subroutine_location('Bar::bar'),
        {
            package => 'Bar',
            subroutine => 'bar',
            filename => __FILE__,
            line => 15,
            end => 17,
            code => \&Bar::bar,
        },
        'Bar::bar location');

    $check_expected->(
        $db->subroutine_location('Bar::baz'),
        {
            package => 'Bar',
            subroutine => 'baz',
            filename => __FILE__,
            line => 19,
            end => 21,
            code => \&Bar::baz,
        },
        'Bar::baz location');


            
}

