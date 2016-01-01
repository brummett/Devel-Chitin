package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_lineseq {
    my $self = shift;
    my $deparsed;
    my $children = $self->children;
    for (my $i = 0; $i < @$children; $i++) {
        if ($children->[$i]->isa('Devel::Chitin::OpTree::COP')) {
            if ($i) {
                $deparsed .= ";\n";
            }
            next;
        }
        $deparsed .= $children->[$i]->deparse;
    }
    $deparsed;
}

sub pp_anonhash {
    my $self = shift;
    my @children = @{$self->children};
    shift @children; # skip pushmark

    my $deparsed = '{ ';
    for (my $i = 0; $i < @children; $i+=2) {
        (my $key = $children[$i]->deparse) =~ s/^'|'$//g; # remove quotes around the key
        $deparsed .= $key
                     . ' => '
                     . $children[$i+1]->deparse;
        $deparsed .= ', ' unless ($i+2) >= @children;
    }
    $deparsed . ' }';
}

sub pp_anonlist {
    my $self = shift;
    my @children = @{$self->children};
    shift @children;  # skip pushmark
    '[ ' . join(', ', map { $_->deparse } @children) . ' ]';
}

sub pp_list {
    my $self = shift;
    my %params = @_;

    my $children = $self->children;

    ($params{skip_parens} ? '' : '( ')
        . join(', ', map { $_->deparse } @$children[1 .. $#$children]) # skip the first op: pushmark
        . ($params{skip_parens} ? '' :' )');
}

sub pp_aslice {
    my $self = shift;

    # first child is no-op pushmark, followed by slice elements, last is the array to slice
    my $children = $self->children;

    unless (@$children == 3
            and
            $children->[0]->op->name eq 'pushmark'
            and
            $children->[1]->op->name eq 'list'
            and
            ( $children->[2]->op->name eq 'padav'
                or
              $children->[2]->op->name eq 'rv2av'
            )
    ) {
        die "unexpected aslice";
    }

    my $array_name = substr($self->children->[2]->deparse, 1); # remove the sigil
    "\@${array_name}[" . $children->[1]->deparse(skip_parens => 1) . ']';
}

1;
