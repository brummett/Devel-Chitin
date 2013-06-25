#!/usr/bin/env perl -d:CommonDB
use strict;
use warnings; no warnings 'void';

5;
for(my $i = 0; $i < 10; $i++) {
    7;
}
$DB::single=1;
10;

use Test::More tests => 6;
use lib 't/lib';
use TestDB;

my $break;
sub test_1 {
    my($tester, $loc) = @_;
    
    $break = Devel::CommonDB::Breakpoint->new(
                    file => $loc->filename,
                    line => 7,
                    code => 1 );
    ok($break, 'Set unconditional breakpoint on line 7');
    ok($tester->continue(), 'continue');
}

sub test_2 {
    my($tester, $loc) = @_;
    is($loc->line, 7, 'Stopped on line 7');
    ok($break->delete, 'Delete breakpoint');
    ok($tester->continue(), 'continue');
}

sub test_3 {
    my($tester, $loc) = @_;
    is($loc->line, 10, 'Stopped on line 10');
    $tester->__done__;
}
    
