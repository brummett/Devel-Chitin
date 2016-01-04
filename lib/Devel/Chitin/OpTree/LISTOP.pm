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
#*pp_scope = \&pp_lineseq;
sub pp_scope {
    push @_, skip => 1;  # skip nextstate
    goto &pp_lineseq;
}
#*pp_leave = \&pp_lineseq;
sub pp_leave {
    push @_, skip => 2;  # skip enter, nextstate
    goto &pp_lineseq;
}

sub pp_anonhash {
    my $self = shift;
    my @children = @{$self->children};
    shift @children; # skip pushmark

    my $deparsed = '{';
    for (my $i = 0; $i < @children; $i+=2) {
        (my $key = $children[$i]->deparse) =~ s/^'|'$//g; # remove quotes around the key
        $deparsed .= $key
                     . ' => '
                     . $children[$i+1]->deparse;
        $deparsed .= ', ' unless ($i+2) >= @children;
    }
    $deparsed . '}';
}

sub pp_anonlist {
    my $self = shift;
    my @children = @{$self->children};
    shift @children;  # skip pushmark
    '[' . join(', ', map { $_->deparse } @children) . ']';
}

sub pp_list {
    my $self = shift;
    my %params = @_;

    my $children = $self->children;
    my $joiner = exists($params{join_with}) ? $params{join_with} : ', ';

    ($params{skip_parens} ? '' : '(')
        . join($joiner, map { $_->deparse(%params) } @$children[1 .. $#$children]) # skip the first op: pushmark
        . ($params{skip_parens} ? '' :')');
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
            ( $children->[1]->op->name eq 'list'
                or
              $children->[1]->op->name eq 'padav'
            )
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

sub pp_unpack {
    my $self = shift;
    my $children = $self->children;
    my @args = map { $_->deparse } @$children[1, 2];
    pop @args if $args[1] eq '$_';
    'unpack('
        . join(', ', @args)
        . ')';
}

sub pp_sort {
    my $self = shift;

    my @sort_values;
    my($sort_fcn, $assignment) = ('', '');

    my $children = $self->children;
    my $first_sort_value_child = 1; # skip pushmark
    if ($self->op->flags & B::OPf_STACKED) {
        my $sort_fcn_op = $children->[1]; # skip pushmark
        $sort_fcn_op = $sort_fcn_op->first if $sort_fcn_op->is_null;

        $sort_fcn = $sort_fcn_op->deparse;
        if ($sort_fcn_op->op->name eq 'const') {
            # it's a function name
            $sort_fcn = $sort_fcn_op->deparse(skip_quotes => 1) . ' ';

        } elsif ($sort_fcn_op->is_scalar_container) {
            # a coderef
            $sort_fcn = $sort_fcn_op->deparse . ' ';

        } else {
            # otherwise, it's a sort block
            my $sort_fcn_contents = $sort_fcn_op->deparse || ';';
            $sort_fcn = "{ $sort_fcn_contents } ";
        }
        $first_sort_value_child = 2;

    } else {
        # using some default sort sub
        my $priv_flags = $self->op->private;
        if ($priv_flags & B::OPpSORT_NUMERIC) {
            $sort_fcn = $priv_flags & B::OPpSORT_DESCEND
                            ? '{ $b <=> $a } '
                            : '{ $a <=> $b } ';
        } elsif ($priv_flags & B::OPpSORT_DESCEND) {
            $sort_fcn = '{ $b cmp $a } ';  # There's no $a cmp $b because it's the default sort
        }

    }

    @sort_values = map { $_->deparse }
                    @$children[$first_sort_value_child .. $#$children];

    # now handled by aassign
    #if ($self->op->private & B::OPpSORT_INPLACE) {
    #    $assignment = $sort_values[0] . ' = ';
    #}

    "${assignment}sort ${sort_fcn}"
        . ( @sort_values > 1 ? '(' : '' )
        . join(', ', @sort_values )
        . ( @sort_values > 1 ? ')' : '' );
}

#                 OP name           Perl fcn    targmy?
foreach my $a ( [ pp_crypt      => 'crypt',     1 ],
                [ pp_index      => 'index',     1 ],
                [ pp_rindex     => 'rindex',    1 ],
                [ pp_pack       => 'pack',      0 ],
                [ pp_reverse    => 'reverse',   0 ],
                [ pp_substr     => 'substr',    0 ],
                [ pp_sprintf    => 'sprintf',   0 ],
                [ pp_atan2      => 'atan2',     1 ],
                [ pp_push       => 'push',      1 ],
                [ pp_unshift    => 'unshift',   1 ],
                [ pp_splice     => 'splice',    1 ],
                [ pp_join       => 'join',      1 ],
) {
    my($pp_name, $perl_name, $targmy) = @$a;
    my $sub = sub {
        my $self = shift;
        my $children = $self->children;

        my $target = $targmy ? $self->_maybe_targmy : '';
        "${target}${perl_name}("
            . join(', ', map { $_->deparse } @$children[1 .. $#$children]) # [0] is pushmark
            . ')';
    };
    no strict 'refs';
    *$pp_name = $sub;
}

1;
