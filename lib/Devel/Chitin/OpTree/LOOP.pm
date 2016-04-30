package Devel::Chitin::OpTree::LOOP;
use base 'Devel::Chitin::OpTree::LISTOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_enterloop { '' } # handled inside pp_leaveloop

sub nextop {
    my $self = shift;
    $self->_obj_for_op($self->op->nextop);
}

sub redoop {
    my $self = shift;
    $self->_obj_for_op($self->op->redoop);
}

sub lastop {
    my $self = shift;
    $self->_obj_for_op($self->op->lastop);
}

1;
