package Devel::Chitin::OpTree::METHOP;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_method_named {
    my $self = shift;
    $self->op->meth_sv->PV;
}

1;
