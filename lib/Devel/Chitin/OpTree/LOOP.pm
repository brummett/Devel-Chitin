package Devel::Chitin::OpTree::LOOP;
use base 'Devel::Chitin::OpTree::LISTOP';

our $VERSION = '0.07';

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
