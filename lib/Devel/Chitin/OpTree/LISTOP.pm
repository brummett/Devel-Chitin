package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use strict;
use warnings;

sub d_lineseq {
    my $self = shift;
    return join(' ', $self->_deparsed_children);
}

1;
