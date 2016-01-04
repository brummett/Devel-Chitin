package Devel::Chitin::OpTree::SVOP;
use base 'Devel::Chitin::OpTree';

use Devel::Chitin::Version;

use strict;
use warnings;

sub pp_const {
    my $self = shift;
    my %params = @_;

    my $sv = $self->op->sv;
    if ($sv->isa('B::PV')) {
        my $string = $sv->PV;

        my $quote = $params{skip_quotes} ? '' : q(');
        if ($string =~ m/[\000-\037]/ and !$params{regex_x_flag}) {
            $quote = '"' unless $params{skip_quotes};
            $string = $self->_escape_for_double_quotes($string, %params);
        }

        return "${quote}${string}${quote}";
    } elsif ($sv->isa('B::NV')) {
        return $sv->NV;
    } elsif ($sv->isa('B::IV')) {
        return $sv->int_value;
    } elsif ($sv->isa('B::SPECIAL')) {
        '<???pp_const B::SPECIAL ' .  $B::specialsv_name[$$sv] . '>';

    } else {
        die "Don't know how to get the value of a const from $sv";
    }
}
*pp_method_named = \&pp_const;

sub pp_gv {
    my $self = shift;
    # An 'our' varaible or subroutine
    my $last_cop = $self->nearest_cop();
    my $curr_package = $last_cop->op->stashpv;
    my $gv_package = $self->op->gv->STASH->NAME;

    $curr_package eq $gv_package
        ? $self->op->gv->NAME
        : join('::', $gv_package, $self->op->gv->NAME);
}
*pp_gvsv = \&pp_gv;

1;
