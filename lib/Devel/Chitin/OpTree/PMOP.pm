package Devel::Chitin::OpTree::PMOP;
use base 'Devel::Chitin::OpTree::LISTOP';

use Devel::Chitin::Version;
use B qw(PMf_CONTINUE PMf_ONCE PMf_GLOBAL PMf_MULTILINE PMf_KEEP PMf_SINGLELINE
         PMf_EXTENDED RXf_PMf_KEEPCOPY PMf_FOLD OPf_KIDS);

use strict;
use warnings;

sub pp_qr {
    shift->_match_op('qr')
}

sub pp_match {
    my $self = shift;

    my($var, $re) = ('', '');
    my $children = $self->children;
    if ($self->_has_bound_variable) {
        $var = $children->[0]->deparse
                    . ( $self->parent->op->name eq 'not'
                          ? ' !~ '
                          : ' =~ ' );
    }

    $re = $self->_match_op('m');

    $var . $re;
}

sub _has_bound_variable {
    my $children = shift->children;

    @$children == 2
    or
    (@$children == 1 and $children->[0]->is_scalar_container)
}

sub pp_subst {
    my $self = shift;

    my @children = @{ $self->children };

    # children always come in this order, though they're not
    # always present: bound-variable, replacement, regex
    my $var = '';
    if ($children[0]->is_scalar_container) {
        $var = shift(@children)->deparse . ' =~ ';
    }

    my $re;
    if ($children[1] and $children[1]->op->name eq 'regcomp') {
        $re = $children[1]->deparse(in_regex => 1,
                                    regex_x_flag => $self->op->pmflags & PMf_EXTENDED);
    } else {
        $re = $self->op->precomp;
    }

    my $replacement = $children[0]->deparse(skip_quotes => 1);

    my $flags = _match_flags($self);
    "${var}s/${re}/${replacement}/${flags}";
}

sub _match_op {
    my($self, $operator) = @_;


    my $children = $self->children;

    my $re = $self->op->precomp;
    foreach my $child ( @$children ) {
        if ($child->op->name eq 'regcomp') {
            $re = $child->deparse(in_regex => 1,
                                  regex_x_flag => $self->op->pmflags & PMf_EXTENDED);
            last;
        }
    }

    my $flags = _match_flags($self);

    "${operator}/${re}/${flags}";
}

sub _match_flags {
    my $self = shift;

    my $match_flags = $self->op->pmflags;
    join('', map { $match_flags & $_->[0] ? $_->[1] : '' }
                (   [ PMf_CONTINUE,     'c' ],
                    [ PMf_ONCE,         'o' ],
                    [ PMf_GLOBAL,       'g' ],
                    [ PMf_FOLD,         'i' ],
                    [ PMf_MULTILINE,    'm' ],
                    [ PMf_KEEP,         'o' ],
                    [ PMf_SINGLELINE,   's' ],
                    [ PMf_EXTENDED,     'x' ],
                    [ RXf_PMf_KEEPCOPY, 'p' ],
                ));
}

1;
