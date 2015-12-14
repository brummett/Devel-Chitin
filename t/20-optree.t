use strict;
use warnings;

use Devel::Chitin::OpTree;
use Devel::Chitin::Location;
use Test::More tests => 1;

subtest construction => sub {
    plan tests => 3;

    sub scalar_assignment {
        my $a = 1;
    }

    my $ops = Devel::Chitin::OpTree->build_from_location(
                    Devel::Chitin::Location->new(
                        package => 'main',
                        subroutine => 'scalar_assignment',
                        filename => __FILE__,
                        line => 1,
                    )
                );
    ok($ops, 'create optree');
    my $count = 0;
    $ops->walk_inorder(sub { $count++ });
    ok($count > 1, 'More than one op is part of scalar_assignment');

    is($ops->deparse, 'my $a = 1', 'scalar_assignment');
};
