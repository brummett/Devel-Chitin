package Devel::Chitin::OpTree::UNOP_AUX;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_multideref {
    my $self = shift;

    my @aux_list = $self->op->aux_list($self->cv);

    my $deparsed = '';
    while(@aux_list) {
        my $aux = shift @aux_list;
        next if ($aux & B::MDEREF_ACTION_MASK == B::MDEREF_reload);

        my $action = $aux & B::MDEREF_ACTION_MASK;
        if ($action == B::MDEREF_AV_padav_aelem) {
            $deparsed .= '$' . substr( $self->_padname_sv( shift @aux_list )->PVX, 1);

        }

        $deparsed .= '[';

        my $index = $aux & B::MDEREF_INDEX_MASK;
        if ($index == B::MDEREF_INDEX_padsv) {
            $deparsed .= $self->_padname_sv(shift @aux_list)->PV;
        }

        $deparsed .= ']';
    }

    $deparsed;
}

1;
