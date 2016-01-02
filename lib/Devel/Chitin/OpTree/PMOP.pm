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
    if (@$children == 2
        or
        ( @$children == 1 and $children->[0]->is_scalar_container)
    ) {
        $var = $children->[0]->deparse . ' =~ ';
    }

    $re = $self->_match_op('m');

    $var . $re;
}

sub _match_op {
    my($self, $operator) = @_;

    my $match_flags = $self->op->pmflags;
    my $flags = join('', map { $match_flags & $_->[0] ? $_->[1] : '' }
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

    my $children = $self->children;

    my $re = $self->op->precomp;
    foreach my $child ( @$children ) {
        if ($child->op->name eq 'regcomp') {
            $re = $child->deparse;
            last;
        }
    }

    "${operator}/${re}/${flags}";
}

1;
