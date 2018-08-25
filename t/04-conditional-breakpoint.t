use strict;
use warnings;

use Test2::V0; no warnings 'void';
use lib 't/lib';
use TestHelper qw(ok_set_breakpoint ok_location db_continue);
use SampleCode;

$DB::single=1;
SampleCode::takes_param(1);
SampleCode::takes_param(2);
SampleCode::takes_param(3);
$DB::single=1;
14;

sub __tests__ {
    plan tests => 6;

    my $file = 't/lib/SampleCode.pm';
    ok_set_breakpoint line => 19, file => $file, code => '0', 'Set conditional breakpoint that will never fire';
    ok_set_breakpoint line => 21, file => $file, code => '$a == 1', 'Set conditional breakpoint $a == 1';
    ok_set_breakpoint line => 20, file => $file, code => '$a == 2', 'Set conditional breakpoint $a == 2';

    db_continue;
    ok_location filename => $file, line => 21;

    db_continue;
    ok_location filename => $file, line => 20;

    db_continue;
    ok_location filename => __FILE__, line => 14;
}

