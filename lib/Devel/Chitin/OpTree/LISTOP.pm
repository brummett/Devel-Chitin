package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use strict;
use warnings;

sub d_lineseq {
    my $self = shift;
    my($deparsed, $seen_cop);
    foreach my $child ( @{ $self->children } ) {
        if ($child->isa('Devel::Chitin::OpTree::COP')) {
            if ($seen_cop++) {
                $deparsed .= ";\n";
            }
            next;
        }
        $deparsed .= $child->deparse;
    }
    $deparsed;
}

1;
