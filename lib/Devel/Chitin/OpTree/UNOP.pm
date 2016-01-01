package Devel::Chitin::OpTree::UNOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub first {
    shift->{children}->[0];
}

sub pp_leavesub {
    my $self = shift;
    $self->first->deparse;
}

sub pp_null {
    my $self = shift;
    my $bounce = $self->_ex_name();
    $self->$bounce();
}

# Normally, pp_list is a LISTOP, but this happens when a pp_list is turned
# into a pp_null by the optimizer, and it has one child
sub pp_list {
    my $self = shift;
    $self->first->deparse;
}

sub pp_srefgen {
    my $self = shift;
    '\\' . $self->first->deparse;
}

sub pp_rv2sv {
    my $self = shift;
    '$' . $self->first->deparse;
}

sub pp_rv2av {
    my $self = shift;
    '@' . $self->first->deparse;
}

sub pp_rv2hv {
    my $self = shift;
    '%' . $self->first->deparse;
}

sub pp_rv2cv {
    my $self = shift;
    $self->first->deparse;
}

sub pp_entersub {
    my $self = shift;
    # first is a pp_list containing a pushmark, followed by the arg
    # list, followed by the sub name
    my $params_ops = $self->first->children;

    return $params_ops->[-1]->deparse . '( '
            . join(', ', map { $_->deparse } @$params_ops[1 .. $#$params_ops-1])
            . ' )';
}

1;
