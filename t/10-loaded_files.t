#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
eval "use TestModule;";  # In t/lib
8;

use Test::More tests => 7;
use lib 't/lib';
use TestDB;
use File::Basename;

sub test_1 {
    my($tester, $loc) = @_;
    ok($tester->is_loaded($INC{'Devel/CommonDB.pm'}), 'Devel::CommonDB is_loaded');
    ok(! $tester->is_loaded('Non/Loaded/Module.pm'), 'Non::Loaded::Module not is_loaded');

    my @files = $tester->loaded_files();
    ok(scalar(@files), 'Get list of loaded_files');
    ok(scalar(grep { $_ eq $INC{'Devel/CommonDB.pm'} } @files), 'Devel::CommonDB is in the list');

    my $was_called = 0;
    $tester->postpone($INC{'Devel/CommonDB.pm'},
                    sub { $was_called = 1 });
    ok($was_called, 'posponed() on an already loaded file fires immediately');

    my $expected = File::Basename::dirname(__FILE__).'/lib/TestModule.pm';
    # Strange! using is($f, $expected,..) in the sub causes a segfault on perl 5.10.1
    $tester->postpone($expected,
                    sub {   my $f = shift;
                            ok($f eq $expected, 'postponed called for TestModule') 
                    });
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my $tester = shift;
    $tester->__done__;
}
    
