package Devel::Chitin::OpTree::LISTOP;
use base Devel::Chitin::OpTree::BINOP;

use Devel::Chitin::Version;

use Fcntl qw(:DEFAULT :flock SEEK_SET SEEK_CUR SEEK_END);
use Socket ();

use strict;
use warnings;

sub pp_lineseq {
    my $self = shift;
    my %params = @_;

    my $deparsed = '';
    my $children = $self->children;

    my $start = $params{skip} || 0;
    for (my $i = $start; $i < @$children; $i++) {
        $deparsed .= $children->[$i]->deparse;
    }
    $deparsed;
}

sub pp_leave {
    my $self = shift;
    $self->_enter_scope;
    my $deparsed = $self->pp_lineseq(@_, skip => 1) || ';';
    $self->_leave_scope;

    my $parent = $self->parent;
    my $do = ($parent->is_null and $parent->op->flags & B::OPf_SPECIAL)
                ? 'do '
                : '';

    my $block_declaration = '';
    if ($parent->is_null and $parent->op->flags & B::OPf_SPECIAL) {
        $block_declaration = 'do ';
    } elsif ($self->op->name eq 'leavetry') {
        $block_declaration = 'eval ';
    }

    $deparsed = $self->_indent_block_text($deparsed);

    $block_declaration . "{$deparsed}";
}
*pp_scope = \&pp_leave;
*pp_leavetry = \&pp_leave;

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
    _deparse_sortlike(shift, 'sort', @_);
}

sub pp_print {
    _deparse_sortlike(shift, 'print', is_printlike => 1, @_);
}

sub pp_prtf {
    _deparse_sortlike(shift, 'printf', is_printlike => 1, @_);
}

sub pp_say {
    _deparse_sortlike(shift, 'say', is_printlike => 1, @_);
}

# deparse something that may have a block or expression as
# its first arg:
#     sort { ... } @list
#     print $f @messages;
sub _deparse_sortlike {
    my($self, $function, %params) = @_;

    my $children = $self->children;

    my $is_stacked = $self->op->flags & B::OPf_STACKED;

    if ($params{is_printlike}
        and
        ! $is_stacked
        and
        @$children == 2  # 0th is pushmark
        and
        $children->[1]->deparse eq '$_'
    ) {
        return 'print()';
    }

    # Note the space:
    # sort (items, in, list)
    # print(items, in, list)
    my $block = $function eq 'sort' ? ' ' : '';
    my $first_value_child_op_idx = 1; # skip pushmark
    if ($is_stacked) {
        my $block_op = $children->[1]; # skip pushmark
        $block_op = $block_op->first if $block_op->is_null;

        if ($block_op->op->name eq 'const') {
            # it's a function name
            $block = ' ' . $block_op->deparse(skip_quotes => 1) . ' ';

        } else {
            # a block or some other expression
            $block = ' ' . $block_op->deparse(skip_sigil => 1) . ' ';
        }
        $first_value_child_op_idx = 2;  # also skip block

    } elsif ($function eq 'sort') {
        # using some default sort sub
        my $priv_flags = $self->op->private;
        if ($priv_flags & B::OPpSORT_NUMERIC) {
            $block = $priv_flags & B::OPpSORT_DESCEND
                            ? ' { $b <=> $a } '
                            : ' { $a <=> $b } ';
        } elsif ($priv_flags & B::OPpSORT_DESCEND) {
            $block = ' { $b cmp $a } ';  # There's no $a cmp $b because it's the default sort
        }

    } elsif (@$children == 2) {
        # a basic print "string\n":
        $block = ' ' ;
    }

    my @values = map { $_->deparse }
                    @$children[$first_value_child_op_idx .. $#$children];

    # now handled by aassign
    #if ($self->op->private & B::OPpSORT_INPLACE) {
    #    $assignment = $sort_values[0] . ' = ';
    #}

    "${function}${block}"
        . ( @values > 1 ? '(' : '' )
        . join(', ', @values )
        . ( @values > 1 ? ')' : '' );
}

sub pp_dbmopen {
    my $self = shift;
    my $children = $self->children;
    'dbmopen('
        . $children->[1]->deparse . ', '   # hash
        . $children->[2]->deparse . ', '   # file
        . sprintf('0%3o', $children->[3]->deparse)
    . ')';
}

sub pp_flock {
    my $self = shift;
    my $children = $self->children;

    my $target = $self->_maybe_targmy;

    my $flags = $self->_deparse_flags($children->[2]->deparse(skip_quotes => 1),
                                      [ LOCK_SH => LOCK_SH,
                                        LOCK_EX => LOCK_EX,
                                        LOCK_UN => LOCK_UN,
                                        LOCK_NB => LOCK_NB ]);
    "${target}flock("
        . $children->[1]->deparse
        . ", $flags)";
}

sub pp_seek { shift->_deparse_seeklike('seek') }
sub pp_sysseek { shift->_deparse_seeklike('sysseek') }

my %seek_flags = (
        SEEK_SET() => 'SEEK_SET',
        SEEK_CUR() => 'SEEK_CUR',
        SEEK_END() => 'SEEK_END',
    );
sub _deparse_seeklike {
    my($self, $function) = @_;
    my $children = $self->children;

    my $whence = $children->[3]->deparse(skip_quotes => 1);

    "${function}(" . join(', ', $children->[1]->deparse,
                         $children->[2]->deparse,
                         (exists($seek_flags{$whence}) ? $seek_flags{$whence} : $whence))
        . ')';
}

sub _generate_flag_list {
    map { my $val = eval "$_";
          $val ? ( $_ => $val ) : ()
    } @_
}

my @sysopen_flags = _generate_flag_list(
                         qw( O_RDONLY O_WRONLY O_RDWR O_NONBLOCK O_APPEND O_CREAT
                             O_TRUNC O_EXCL O_SHLOCK O_EXLOCK O_NOFOLLOW O_SYMLINK
                             O_EVTONLY O_CLOEXEC));
sub pp_sysopen {
    my $self = shift;
    my $children = $self->children;

    my $mode = $self->_deparse_flags($children->[3]->deparse(skip_quotes => 1),
                                     \@sysopen_flags);
    $mode ||= 'O_RDONLY';
    my @params = (
            # skip pushmark
            $children->[1]->deparse,  # filehandle
            $children->[2]->deparse,  # file name
            $mode,
        );

    if ($children->[4]) {
        # perms
        push @params, $self->_as_octal($children->[4]->deparse(skip_quotes => 1));
    }
    'sysopen(' . join(', ', @params) . ')';
}

sub pp_truncate {
    my $self = shift;
    my $children = $self->children;

    my $fh;
    if ($self->op->flags & B::OPf_SPECIAL) {
        # 1st arg is a bareword filehandle
        $fh = $children->[1]->deparse(skip_quotes => 1);

    } else {
        $fh = $children->[1]->deparse;
    }

    "truncate(${fh}, " . $children->[2]->deparse . ')';
}

sub pp_chmod {
    my $self = shift;
    my $children = $self->children;
    my $mode = $self->_as_octal($children->[1]->deparse);
    my $target = $self->_maybe_targmy;
    "${target}chmod(${mode}, " . join(', ', map { $_->deparse } @$children[2 .. $#$children]) . ')';
}

sub pp_mkdir {
    my $self = shift;
    my $children = $self->children;
    my $target = $self->_maybe_targmy;
    my $dir = $children->[1]->deparse;  # 0th is pushmark
    if (@$children == 2) {
        if ($dir eq '$_') {
            "${target}mkdir()";
        } else {
            "${target}mkdir($dir)";
        }
    } else {
        my $mode = $self->_as_octal($children->[2]->deparse);
        "${target}mkdir($dir, $mode)";
    }
}

# strange... glob is a LISTOP, but always has 3 children
# 1. ex-pushmark
# 2. arg containing the pattern
# 3. a gv SVOP refering to a bogus glob in no package with no name
# There's no way to distinguish glob(...) from <...>
sub pp_glob {
    my $self = shift;
    'glob(' . $self->children->[1]->deparse . ')';
}

sub pp_split {
    my $self = shift;

    my $children = $self->children;

    my $regex_op = $children->[0];
    my $regex = ( $regex_op->op->flags & B::OPf_SPECIAL
                  and
                  ! @{$regex_op->children}
                )
                    ? $regex_op->deparse(delimiter => "'") # regex was given as a string
                    : $regex_op->deparse;

    my @params = (
            $regex,
            $children->[1]->deparse,
        );
    if (my $n_fields = $children->[2]->deparse) {
        push(@params, $n_fields) if $n_fields > 0;
    }

    'split(' . join(', ', @params) . ')';
}

foreach my $d ( [ pp_exec => 'exec' ],
                [ pp_system => 'system' ],
) {
    my($pp_name, $function) = @$d;
    my $sub = sub {
        my $self = shift;

        my @children = @{ $self->children };
        shift @children; # skip pushmark

        my $exec = $function;
        if ($self->op->flags & B::OPf_STACKED) {
            # has initial non-list agument
            my $program = shift(@children)->first;
            $exec .= ' ' . $program->deparse . ' ';
        }
        my $target = $self->_maybe_targmy;
        $target . $exec . '(' . join(', ', map { $_->deparse } @children) . ')'
    };

    no strict 'refs';
    *$pp_name = $sub;
}

my %addr_types = map { my $val = eval "Socket::$_"; $@ ? () : ( $val => $_ ) }
                    qw( AF_802 AF_APPLETALK AF_INET AF_INET6 AF_ISO AF_LINK
                        AF_ROUTE AF_UNIX AF_UNSPEC AF_X25 );
foreach my $d ( [ pp_ghbyaddr => 'gethostbyaddr' ],
                [ pp_gnbyaddr => 'getnetbyaddr' ],
) {
    my($pp_name, $perl_name) = @$d;
    my $sub = sub {
        my $children = shift->children;
        my $addr = $children->[1]->deparse;
        my $type = $addr_types{ $children->[2]->deparse(skip_quotes => 1) }
                    || $children->[2]->deparse;
        "${perl_name}($addr, $type)";
    };
    no strict 'refs';
    *$pp_name = $sub;
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
                [ pp_binmode    => 'binmode',   0 ],
                [ pp_die        => 'die',       0 ],
                [ pp_warn       => 'warn',      0 ],
                [ pp_read       => 'read',      0 ],
                [ pp_sysread    => 'sysread',   0 ],
                [ pp_syswrite   => 'syswrite',  0 ],
                [ pp_seekdir    => 'seekdir',   0 ],
                [ pp_syscall    => 'syscall',   0 ],
                [ pp_select     => 'select',    0 ],
                [ pp_sselect    => 'select',    0 ],
                [ pp_vec        => 'vec',       0 ],
                [ pp_chown      => 'chown',     1 ],
                [ pp_fcntl      => 'fcntl',     1 ],
                [ pp_ioctl      => 'ioctl',     1 ],
                [ pp_open       => 'open',      0 ],
                [ pp_open_dir   => 'opendir',   0 ],
                [ pp_rename     => 'rename',    0 ],
                [ pp_link       => 'link',      1 ],
                [ pp_symlink    => 'symlink',   1 ],
                [ pp_unlink     => 'unlink',    1 ],
                [ pp_utime      => 'utime',     1 ],
                [ pp_formline   => 'formline',  0 ],
                [ pp_gpbynumber => 'getprotobynumber', 0 ],
                [ pp_gsbyname   => 'getservbyname', 0 ],
                [ pp_gsbyport   => 'getservbyport', 0 ],
                [ pp_return     => 'return', 0 ],
                [ pp_kill       => 'kill',      1 ],
                [ pp_pipe_op    => 'pipe',      0 ],
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
