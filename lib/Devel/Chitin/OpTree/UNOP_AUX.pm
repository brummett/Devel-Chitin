package Devel::Chitin::OpTree::UNOP_AUX;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_multideref {
    my $self = shift;

    my @aux_list = $self->op->aux_list($self->cv);
    print "aux list is\n",join("\n",@aux_list),"\n";
exit;
}

1;
