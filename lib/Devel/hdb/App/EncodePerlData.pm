package Devel::hdb::App::EncodePerlData;

use strict;
use warnings;

use Scalar::Util;

use Exporter qw(import);
our @EXPORT_OK = qw( encode_perl_data );

sub encode_perl_data {
    my $value = shift;

    if (ref $value) {
        my $reftype     = Scalar::Util::reftype($value);
        my $refaddr     = Scalar::Util::refaddr($value);
        my $blesstype   = Scalar::Util::blessed($value);

        if ($reftype eq 'HASH') {
            $value = { map { $_ => encode_perl_data($value->{$_}) } keys(%$value) };

        } elsif ($reftype eq 'ARRAY') {
            $value = [ map { encode_perl_data($_) } @$value ];

        } elsif ($reftype eq 'GLOB') {
            my %tmpvalue = map { $_ => encode_perl_data(*{$value}{$_}) }
                           grep { *{$value}{$_} }
                           qw(HASH ARRAY SCALAR);
            if (*{$value}{CODE}) {
                $tmpvalue{CODE} = *{$value}{CODE};
            }
            if (*{$value}{IO}) {
                $tmpvalue{IO} = 'fileno '.fileno(*{$value}{IO});
            }
            $value = \%tmpvalue;
        } elsif (($reftype eq 'REGEXP')
                    or ($reftype eq 'SCALAR' and defined($blesstype) and $blesstype eq 'Regexp')
        ) {
            $value = $value . '';
        } elsif ($reftype eq 'SCALAR') {
            $value = encode_perl_data($$value);
        } elsif ($reftype eq 'CODE') {
            (my $copy = $value.'') =~ s/^(\w+)\=//;  # Hack to change CodeClass=CODE(0x123) to CODE=(0x123)
            $value = $copy;
        } elsif ($reftype eq 'REF') {
            $value = encode_perl_data($$value);
        }

        $value = { __reftype => $reftype, __refaddr => $refaddr, __value => $value };
        $value->{__blessed} = $blesstype if $blesstype;

    } elsif (ref(\$value) eq 'GLOB') {
        # It's an actual typeglob (not a glob ref)
        my $globref = \$value;
        my %tmpvalue = map { $_ => encode_perl_data(*{$globref}{$_}) }
                       grep { *{$globref}{$_} }
                       qw(HASH ARRAY SCALAR);
        if (*{$globref}{CODE}) {
            $tmpvalue{CODE} = *{$globref}{CODE};
        }
        if (*{$globref}{IO}) {
            $tmpvalue{IO} = 'fileno '.fileno(*{$globref}{IO});
        }
        $value = {  __reftype => 'GLOB',
                    __refaddr => Scalar::Util::refaddr($globref),
                    __value => \%tmpvalue,
                };
    }


    return $value;
}

1;

=pod

=head1 NAME

Devel::hdb::App::EncodePerlData - Encode Perl values in a -friendly way

=head1 SYNOPSIS

  use Devel::hdb::App::EncodePerlData qw(encode_perl_data);

  my $val = encode_perl_data($some_data_structure);
  $io->print( JSON::encode_json( $val ));

=head1 DESCRIPTION

This utility module is used to take an artitrarily nested data structure, and
return a value that may be safely JSON-encoded.

=head2 Functions

=over 4

=item encode_perl_data

Accepts a single value and returns a value that may be safely passed to
JSON::encode_json().  encode_json() cannot handle Perl-specific data like
blessed references or typeglobs.  Non-reference scalar values like numbers
and strings are returned unchanged.  For all references, encode_perl_data()
returns a hashref with these keys
  __reftype     String indicating the type of reference, as returned
                by Scalar::Util::reftype()
  __refaddr     Memory address of the reference, as returned by
                Scalar::Util::refaddr()
  __blessed     Package this reference is blessed into, as reurned
                by Scalar::Util::blessed.
  __value       Reference to the unblessed data.

If the reference was not blessed, then the __blessed key will not be present.
__value is generally a copy of the underlying data.  For example, if the input
value is an hashref, then __value will also be a hashref containing the input
value's kays and values.  For typeblobs, __value will be a hashref with the
keys SCALAR, ARRAY, HASH, IO and CODE.  For coderefs, __value will be the
stringified reference, like "CODE=(0x12345678)"

encode_perl_data() handles arbitrarily neste data strucures, meaning that
values in the __values slot may also be encoded this way.

=back

=head1 SEE ALSO

Devel::hdb

=head1 AUTHOR

Anthony Brummett <brummett@cpan.org>

=head1 COPYRIGHT

Copyright 2013, Anthony Brummett.  This module is free software. It may
be used, redistributed and/or modified under the same terms as Perl itself.