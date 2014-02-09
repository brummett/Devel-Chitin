#!/usr/bin/env perl
use strict;
use warnings; no warnings 'void';

use lib 'lib';
use lib 't/lib';
use File::Basename;
use Devel::CommonDB::TestRunner;

run_test(
    3,
    sub {
        $DB::single=1;
        14;
        eval 'use Devel::CommonDB::TestModule'; # in t/lib
        16;
    },
    \&test_1,
    'continue',
    'at_end',
    'done',
);
    
sub test_1 {
    my($db, $loc) = @_;

    my $was_called = 0;
    $db->postpone($INC{'Devel/CommonDB.pm'},
                    sub { $was_called = 1 });
    Test::More::ok($was_called, 'posponed() on an already loaded file fires immediately');

    my $expected = File::Basename::dirname(__FILE__).'/lib/Devel/CommonDB/TestModule.pm';
    $db->postpone($expected,
                    sub {   my $f = shift;
                            Test::More::ok($f eq $expected, 'postponed called for TestModule') 
                    });
}

