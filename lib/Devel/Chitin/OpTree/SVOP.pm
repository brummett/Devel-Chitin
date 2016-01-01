package Devel::Chitin::OpTree::SVOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_const {
    my $self = shift;
    my $sv = $self->op->sv;
    if ($sv->isa('B::IV')) {
        return $sv->int_value;
    } elsif ($sv->isa('B::PV')) {
        return q(') . $sv->PV . q(');
    } elsif ($sv->isa('B::SPECIAL')) {
        '<???pp_const B::SPECIAL ' .  $B::specialsv_name[$$sv] . '>';

    } else {
        die "Don't know how to get the value of a const from $sv";
    }
}

sub pp_gv {
    my $self = shift;
    # An 'our' varaible
    $self->op->gv->NAME;
}
*pp_gvsv = \&pp_gv;

1;
