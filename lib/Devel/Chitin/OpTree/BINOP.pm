package Devel::Chitin::OpTree::BINOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub d_sassign {
    my $self = shift;
    my($first, $last) = @{$self->children};
    return join(' = ', $last->deparse, $first->deparse);
}

1;
