package Devel::Chitin::OpTree::BINOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub last {
    shift->{children}->[1];
}

sub d_sassign {
    my $self = shift;
    return join(' = ', $self->last->deparse, $self->first->deparse);
}

1;
