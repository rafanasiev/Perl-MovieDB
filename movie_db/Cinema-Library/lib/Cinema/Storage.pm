#
#===============================================================================
#
#         FILE:  Storage.pm
#
#  DESCRIPTION:
#
#        FILES:  ---
#         BUGS:  ---
#        NOTES:  ---
#       AUTHOR:  Ruslan A.Afanasiev (), <ruslan.afanasiev@gmail.com>
#      COMPANY:
#      VERSION:  0.02
#      CREATED:  25.09.2011 19:06:17 EEST
#  CHANGE DATE:  $Date: 2011-09-28 18:15:08 $
#     REVISION:  $Revision: 1.10 $
#===============================================================================
package Cinema::Storage;
use strict;
use warnings;
use Carp;
use Storable qw(lock_store lock_retrieve freeze thaw);
use Data::Dumper;
use Cwd;
use Cinema::Utils qw( :all );

use fields qw(cache dbh);

use constant { DBFILE => 'movie.db' };

=head1 NAME

Cinema::Storage - implementation of a model class to manage the movie data.

=head1 VERSION

Version 0.01

=cut

our $VERSION = '0.02';

=head1 SYNOPSIS

This module does: caching the data, inseting the data into the local DB file,
                  getting the data from the local DB file.

Perhaps a little code snippet.

    use Cinema::Storage;

    my $foo = Cinema::Storage->new();
    ...


=head1 SUBROUTINES/METHODS

=over 12

=item C<new>

Returns a new Cinema::Storage object.

=back

=cut

sub new {
    my $class = shift;
    my $self  = fields::new($class);
    $self->_init();
    return $self;

}

=over 12

=item C<_init>

A 'private' method to initialize fields.

=back

=cut

sub _init {
    caller eq __PACKAGE__ or croak "Can't invoke private method _init()";
    my $self   = shift;
    my $dbfile = getcwd . '/' . DBFILE;
    $self->{'dbh'} = $dbfile;

    if ( -e $dbfile ) {
        $self->retrieve;
    }
    else {
        carp "DB file does not exits. Forgot do import?";
    }
}

=over 12

=item C<cache>

A generic accessor/mutator to set/get a value of the field 'cache'.

=back

=cut

sub cache : lvalue {
    my $self = shift;
    $self->{'cache'};
}

=over 12

=item C<dbh>

A generic accessor to return a value of the field 'dbh'.

=back

=cut

sub dbh {
    my $self = shift;
    $self->{'dbh'};
}

=over 12

=item C<do_add>

do_add - add a new record into a storage. It returns status message or or will fail due to Storable error.

Arguments: 1

    $data - a data structure blessed by Cinema::Library (movie's object)

=back

=cut

sub do_add {
    my $self = shift;
    my $data = shift;

    my $id = $self->get_new_id;
    $self->{'cache'}->{$id} = $data;
    ## store data into the file
    $self->store;
    return "Record has been added under ID $id.";
}

=over 12

=item C<do_delete>

do_delete - delete a record from a storage. It returns status a message.

Arguments: 1
    
    $id - movie's ID (numeric)

=back

=cut

sub do_delete {
    my $self = shift;
    my $id   = shift;

    if ( exists( $self->{'cache'}->{$id} ) ) {
        delete( $self->{'cache'}->{$id} );
        $self->store;
        return "Record ID $id has been deleted.";
    }
    else {
        return "Can't delete a record. Invalid ID or record does not exist.";
    }

}

=over 12

=item C<select_by_id>

select_by_id - returns existing movie object by id or undef

Arguments: 1
    
    $id - movie's ID (numeric)

=back

=cut

sub select_by_id {
    my $self = shift;
    my $id   = shift;

    return exists( $self->{'cache'}->{$id} ) ? $self->{'cache'}->{$id} : undef;
}

=over 12

=item C<select_by_star>

select_by_star - returns list of movies by star's name or empty list

Arguments: 1
    
    $substr - a substring to search by pattern

=back

=cut

sub select_by_star {
    my $self     = shift;
    my $substr   = shift;
    my $ids_objs = $self->get_ids_objs;
    my $res      = [];

    foreach my $r ( @{$ids_objs} ) {
        foreach my $star ( @{ $r->{'obj'}->stars } ) {
            if ( $star =~ /\b$substr/i ) {
                push @$res,
                  {
                    id    => $r->{'id'},
                    star  => $star,
                    title => $r->{'obj'}->title
                  };
            }
        }
    }

    return $res;
}

=over 12

=item C<select_by_title>

select_by_title - returns list of movies by title or empty list

Arguments: 1
    
    $substr - a substring to search by pattern

=back

=cut

sub select_by_title {
    my $self     = shift;
    my $substr   = shift;
    my $ids_objs = $self->get_ids_objs;
    my $res      = [];

    foreach my $r ( @{$ids_objs} ) {
        if ( $r->{'obj'}->title =~ /$substr/i ) {
            push @$res, { id => $r->{'id'}, title => $r->{'obj'}->title };
        }
    }

    return $res;
}

=over 12

=item C<select_all_by>

select_all_by - returns a list of all movies by an attribute or empty list

Arguments: 1
    
    $attr - attribute, e.g. title

=back

=cut

sub select_all_by {
    my $self = shift;
    my $attr = shift;
    my $res  = [];

    ## -----------------------------------------------------------------------------
    ## Generic sorting subroutine:
    ## it analyzes an attribute (numeric or string), after that sorts by <=> or cmp
    ## -----------------------------------------------------------------------------
    my $by_attr = sub {
        ( $a->{'obj'}->$attr() =~ /^\d+$/ && $b->{'obj'}->$attr() =~ /^\d+$/ )
          ? $a->{'obj'}->$attr() <=> $b->{'obj'}->$attr()
          : uc( $a->{'obj'}->$attr() ) cmp uc( $b->{'obj'}->$attr() );
    };

    my $ids_objs = $self->get_ids_objs;

    foreach my $r ( sort { $by_attr->() } @{$ids_objs} ) {
        if ( $attr eq 'title' ) {
            push @$res, { title => $r->{'obj'}->title, id => $r->{'id'} };
        }
        else {
            push @$res,
              {
                title => $r->{'obj'}->title,
                id    => $r->{'id'},
                $attr => $r->{'obj'}->$attr()
              };
        }
    }
    return $res;
}

=over 12

=item C<store>

store - save the data into a storage

=back

=cut

sub store {
    my $self = shift;
    lock_store $self->cache, $self->dbh;
}

=over 12

=item C<retrieve>

retrieve - retrieve the data from a storage 

=back

=cut

sub retrieve {
    my $self = shift;
    $self->cache = lock_retrieve( $self->dbh );
}

=over 12

=item C<do_import>

do_import - 

Arguments: 1
    
    $file - flat text file

=back

=cut

sub do_import {
    my $self = shift;
    my $file = shift;

    croak "ERROR: file $file does not exist or it isn't an ASCII text file."
      unless ( -e $file );
    my $data = {};

    open( my $fh, '<', $file ) or croak "ERROR: $!";
    my @tmp = grep { $_ !~ /^$/ } <$fh>;
    close $fh;
    chomp(@tmp);

    my $id = 0;
    while (@tmp) {
        my ( $t_key, $title, @rest ) = split /:/, shift @tmp;
        my ( $y_key, $year )   = split /:/, shift @tmp;
        my ( $f_key, $format ) = split /:/, shift @tmp;
        my ( $s_key, $stars )  = split /:/, shift @tmp;

        # :WORKAROUND:24.09.2011:: to process title like '2001: A Space Odyssey'
        $title .= ':' . shift(@rest) if (@rest);
        $title .= join( ': ', @rest ) if ( scalar(@rest) );

        ## compose the data, make all keys lovercase and s/ /_/, remove leading space
        ## every movie's record will saved as the Cinema::Library object
        $data->{$id} = bless(
            {
                rename_key($t_key) => trim($title),
                rename_key($y_key) => trim($year),
                rename_key($f_key) => trim($format),
                rename_key($s_key) => [ map { ltrim($_) } split /,/, $stars ],
            },
            'Cinema::Library'
        );
        ++$id;
    }
    ## serialize the data using Storable method (with locking)
    lock_store $data, $self->dbh or croak "Can't serialize the data: $!";
    ## put the data into the cache
    $self->cache = $data;
    return 1;

}

=over 12

=item C<get_new_id>

get_new_id - find max id and returns next one

=back

=cut

sub get_new_id {
    my $self = shift;
    my $max  = undef;
    map { $max = $_ if ( !$max || $_ > $max ) } keys %{ $self->{'cache'} };
    ++$max;
    return $max;
}

=over 12

=item C<get_ids_objs>

get_ids_objs - returns couple of id and object into the list

=back

=cut

sub get_ids_objs {
    my $self   = shift;
    my $couple = [];

    while ( my ( $id, $obj ) = each %{ $self->{'cache'} } ) {
        push @$couple, { id => $id, obj => $obj };
    }
    return $couple;
}

=over 12

=item C<rename_key>

rename_key - turns every key as uppercase first + underscore sign is changed to space

=back

=cut

sub rename_key {
    my $key = shift;
    $key =~ s/\s/_/;
    return lc $key;
}

=head1 AUTHOR

Ruslan Afanasiev, C<< <ruslan.afanasiev at gmail.com> >>

=head1 BUGS

Please report any bugs or feature requests to C<ruslan.afanasiev at gmail.com>.  


=head1 SUPPORT

You can find documentation for this module with the perldoc command.

    perldoc Cinema::Storage



=head1 ACKNOWLEDGEMENTS


=head1 LICENSE AND COPYRIGHT

Copyright 2011 Ruslan Afanasiev.

This program is free software; you can redistribute it and/or modify it
under the terms of either: the GNU General Public License as published
by the Free Software Foundation; or the Artistic License.

See http://dev.perl.org/licenses/ for more information.


=cut

1;    # End of Cinema::Storage
