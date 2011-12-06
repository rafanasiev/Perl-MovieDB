#
#===============================================================================
#
#         FILE:  Library.pm
#
#  DESCRIPTION:
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Ruslan A.Afanasiev (), <ruslan.afanasiev@gmail.com>
#      COMPANY:
#      VERSION:  0.03
#      CREATED:  23.09.2011 20:14:51 EEST
#  CHANGE DATE:  $Date: 2011-09-28 18:15:08 $
#     REVISION:  $Revision: 1.19 $
#===============================================================================
package Cinema::Library;

use warnings;
use strict;
use Carp;
use Storable qw(lock_store lock_retrieve);
use Data::Dumper;
use Cinema::Utils qw( :all );
use Cinema::Prompt;
use Cinema::Storage;

use fields qw(title release_year format stars storage);

## turn a Cinema::Library object into a string
use overload q("") => sub {
    my $self = shift;
    my $result;
    if ( $self->isa('Cinema::Library') ) {
        while ( my ( $key, $val ) = each %{$self} ) {
            $key = ucfirst($key);
            $key =~ s/_/ /;
            if ( ref($val) eq 'ARRAY' ) {
                $result .= "$key:\n";
                $result .= "\t- $_\n" foreach ( @{$val} );
            }
            else {
                $result .= "$key:\t$val\n";
            }
        }
    }
    return $result;
};

=head1 NAME

Cinema::Library - implementation of a controller class

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.03';

=head1 SYNOPSIS

This module interacts with GUI and Model. 

Perhaps a little code snippet.

    use Cinema::Library;

    my $foo = Cinema::Library->new();
    ...


=head1 SUBROUTINES/METHODS

=over 12

=item C<new>

Returns a new Cinema::Library object.

=back

=cut

sub new {
    my $class = shift;
    my $self  = fields::new($class);
    ## initializing
    $self->_init(@_);
    return $self;
}

=over 12

=item C<_init>

A 'private' method to initialize fields.

=back

=cut

sub _init {
    caller eq __PACKAGE__ or croak "Can't invoke private method _init()";
    my $self = shift;
    if (@_) {
        my %fields = @_;
        @{$self}{ keys %fields } = values %fields;
        ## WORKAROUND: to have access to a storage
        $self->{'storage'} = Cinema::Storage->new;
    }
    else {
        $self->{'title'}        = undef;
        $self->{'release_year'} = undef;
        $self->{'format'}       = undef;
        $self->{'stars'}        = [];
        $self->{'storage'}      = Cinema::Storage->new;
    }
}

=over 12

=item C<title>

A generic accessor/mutator to keep/return a value of the field 'title'.

=back

=cut

sub title {
    my $self = shift;
    if (@_) { $self->{'title'} = shift; }
    else    { return $self->{'title'}; }
}

=over 12

=item C<release_year>

A generic accessor/mutator to keep/return a value of the field 'year'.

=back

=cut

sub release_year {
    my $self = shift;
    if (@_) { $self->{'release_year'} = shift; }
    else    { return $self->{'release_year'}; }
}

=over 12

=item C<format>

A generic accessor/mutator to keep/return a value of the field 'format'.

=back

=cut

sub format {
    my $self = shift;
    if (@_) { $self->{'format'} = shift; }
    else    { return $self->{'format'}; }
}

=over 12

=item C<stars>

A generic accessor/mutator to keep/return a value of the field 'stars'.

=back

=cut

sub stars {
    my $self = shift;
    if (@_) { push @{ $self->{'stars'} }, @_; }
    else    { return $self->{'stars'}; }
}

=over 12

=item C<dispatch>

dispatch - generic method to handle user interface events

=back

=cut

sub dispatch {
    my $self = shift;
    my $action = shift;
    my $arg  = shift;

    my $actions = {
        'add'            => sub { $self->{'storage'}->do_add(bless($arg)) if keys %$arg; },
        'delete'         => sub { $self->{'storage'}->do_delete($arg) if $arg =~ /\d+/; },
        'display'        => sub { $self->{'storage'}->select_by_id($arg) if $arg =~ /\d+/; },
        'get_list_by'    => sub { $self->{'storage'}->select_all_by($arg) if $arg; },
        'find_by_title'  => sub { $self->{'storage'}->select_by_title($arg) if $arg; },
        'find_by_star'   => sub { $self->{'storage'}->select_by_star($arg) if $arg; },
        'import'         => sub { $self->{'storage'}->do_import($arg) if $arg; },
        'menu'           => sub { Cinema::Prompt->new->menu($self); },        
    };

    return $actions->{$action}->($arg);
}

=head1 AUTHOR

Ruslan Afanasiev, C<< <ruslan.afanasiev at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<ruslan.afanasiev at gmail.com>.  


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Cinema::Library



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Ruslan Afanasiev.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Cinema::Library
