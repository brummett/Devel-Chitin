package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub d_leavesub {
    my $self = shift;
    return join('', $self->_deparsed_children);
}

1;
