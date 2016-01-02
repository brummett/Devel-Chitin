package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_lineseq {
    my $self = shift;
    my %params = @_;

    my $deparsed;
    my $children = $self->children;

    my $start = $params{skip} || 0;
    for (my $i = $start; $i < @$children; $i++) {
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
    push(@_, '[', ']'),
    goto &_aslice_hslice_builder;
}

sub pp_hslice {
    push(@_, '{', '}');
    goto &_aslice_hslice_builder;
}

my %aslice_hslice_allowed_ops = map { $_ => 1 } qw( padav padhv rv2av rv2hv );
sub _aslice_hslice_builder {
    my($self, $open_paren, $close_paren) = @_;

    # first child is no-op pushmark, followed by slice elements, last is the array to slice
    my $children = $self->children;

    unless (@$children == 3
            and
            $children->[0]->op->name eq 'pushmark'
            and
            $children->[1]->op->name eq 'list'
            and
            $aslice_hslice_allowed_ops{ $children->[2]->op->name }
    ) {
        die "unexpected aslice/hslice for $open_paren $close_paren";
    }

    my $array_name = substr($self->children->[2]->deparse, 1); # remove the sigil
    "\@${array_name}" . $open_paren . $children->[1]->deparse(skip_parens => 1) . $close_paren;
}

sub pp_leavetry {
    my $self = shift;

    (my $inner = pp_lineseq($self, skip => 2)) =~ s/^/    /gm;
    "eval {\n$inner\n}";
}

foreach my $a ( [ pp_crypt  => 'crypt' ],
                [ pp_index  => 'index' ],
) {
    my($pp_name, $perl_name) = @$a;
    my $sub = sub {
        my $self = shift;
        my $children = $self->children;

        $self->_maybe_targmy
            . "${perl_name}("
            . join(', ', map { $_->deparse } @$children[1 .. $#$children]) # [0] is pushmark
            . ')';
    };
    no strict 'refs';
    *$pp_name = $sub;
}

1;
