package Devel::Chitin::OpTree::METHOP;
use base 'Devel::Chitin::OpTree::UNOP';

our $VERSION = '0.07';

use strict;
use warnings;

sub pp_method_named {
    my $self = shift;

    my $sv = $self->op->meth_sv;
    $sv = $self->_padval_sv($self->op->targ) unless $$sv;  # happens in thread-enabled perls

    $sv->PV;
}

1;
