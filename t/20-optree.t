use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin;#::Location;
use Test::More tests => 1;

subtest basic => sub {
    plan tests => 2;

    sub simple_assignment {
        my $a = 1;
    }

    my $ops = Devel::Chitin::OpTree->build_from_location(
                    Devel::Chitin::Location->new(
                        package => 'main',
                        subroutine => 'simple_assignment',
                        filename => __FILE__,
                        line => 1,
                    )
                );
    ok($ops, 'create optree');
    my $count = 0;
    $ops->walk_inorder(sub { $count++ });
    ok($count > 1, 'More than one op is part of simple_assignment');
};
