package Devel::Chitin::OpTree::SVOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub d_const {
    my $self = shift;
    my $sv = $self->op->sv;
    if ($sv->isa('B::IV')) {
        return $sv->int_value;
    } elsif ($sv->isa('B::PV')) {
        return $sv->PV;
    } else {
        die "Don't know how to get the value of a const from $sv";
    }
}

1;
