use strict;
use warnings;

use Test2::V0; no warnings 'void';
use lib 't/lib';
use TestHelper qw(ok_location db_continue db_stepout ok_sub_return);

my $one_rv = one();

sub one {
    $DB::single=1;
    12;
}

sub __tests__ {
    plan tests => 5;

    ok_location subroutine => 'main::one', line => 12;
    db_stepout(cb => sub {
        my $loc = shift;
        is $loc->subroutine, 'main::one', "stepout callback subroutine";
        is $loc->line, 12, "stepout callback line";
        is $loc->rv, 12, "steoput callback rv";
        is $loc->wantarray, 0, "stepout callback wantarray";
        $loc->rv('it was changed');
    });
}
