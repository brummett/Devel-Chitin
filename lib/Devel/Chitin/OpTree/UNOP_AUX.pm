package Devel::Chitin::OpTree::UNOP_AUX;
use base 'Devel::Chitin::OpTree::UNOP';

use Devel::Chitin::Version;

use strict;
use warnings;

my @open_bracket = qw( [ { );
my @close_bracket = qw( ] } );

my %hash_actions = map { $_ => 1 }
                    ( B::MDEREF_HV_pop_rv2hv_helem, B::MDEREF_HV_gvsv_vivify_rv2hv_helem,
                      B::MDEREF_HV_padsv_vivify_rv2hv_helem, B::MDEREF_HV_vivify_rv2hv_helem,
                      B::MDEREF_HV_padhv_helem, B::MDEREF_HV_gvhv_helem );
sub pp_multideref {
    my $self = shift;

    my @aux_list = $self->op->aux_list($self->cv);

    my $deparsed = '';
    while(@aux_list) {
        my $aux = shift @aux_list;
        next if (($aux & B::MDEREF_ACTION_MASK) == B::MDEREF_reload);

        my $action = $aux & B::MDEREF_ACTION_MASK;
        my $is_hash = $hash_actions{$action};

        if ($action == B::MDEREF_AV_padav_aelem) {
            $deparsed .= '$' . substr( $self->_padname_sv( shift @aux_list )->PVX, 1);

        } elsif ($action == B::MDEREF_HV_gvhv_helem
                 or $action == B::MDEREF_AV_gvav_aelem
        ) {
            $deparsed .= '$' . $self->_gv_name(shift @aux_list);
        }

        $deparsed .= $open_bracket[$is_hash];

        my $index = $aux & B::MDEREF_INDEX_MASK;
        if ($index == B::MDEREF_INDEX_padsv) {
            $deparsed .= $self->_padname_sv(shift @aux_list)->PV;

        } elsif ($index == B::MDEREF_INDEX_const) {
            my $sv = shift(@aux_list);
            $deparsed .= $self->_quote_sv($sv);
        }

        $deparsed .= $close_bracket[$is_hash];
    }

    $deparsed;
}

1;
