package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_lineseq {
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

sub pp_anonlist {
    my $self = shift;
    my @children = @{$self->children};
    shift @children;  # skip pushmark
    '[ ' . join(', ', map { $_->deparse } @children) . ' ]';
}

sub pp_list {
    my $self = shift;
    my @children = @{$self->children};
    shift @children;  # skip pushmark

    return '( ' . join(', ', map { $_->deparse } @children) . ' )';
}

1;
