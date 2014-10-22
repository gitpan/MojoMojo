package MojoMojo::Schema::Result::Attachment;

use strict;
use warnings;

use parent qw/MojoMojo::Schema::Base::Result/;

__PACKAGE__->load_components(
    qw/DateTime::Epoch TimeStamp UTF8Columns Core/);
__PACKAGE__->table("attachment");
__PACKAGE__->add_columns(
    "id",
    {
        data_type         => "INTEGER",
        is_nullable       => 0,
        size              => undef,
        is_auto_increment => 1
    },
    "uploaded",
    {
        data_type        => "BIGINT",
        is_nullable      => 0,
        size             => undef,
        inflate_datetime => 'epoch',
        set_on_create    => 1
    },
    "page",
    { data_type => "INTEGER", is_nullable => 0, size => undef },
    "name",
    { data_type => "VARCHAR", is_nullable => 0, size => 100 },
    "size",
    { data_type => "INTEGER", is_nullable => 1, size => undef },
    "contenttype",
    { data_type => "VARCHAR", is_nullable => 1, size => 100 },
);
__PACKAGE__->set_primary_key("id");
__PACKAGE__->belongs_to(
    "page",
    "MojoMojo::Schema::Result::Page",
    { id => "page" }
);
__PACKAGE__->might_have( "photo", "MojoMojo::Schema::Result::Photo" );
__PACKAGE__->utf8_columns(qw/name/);

=head1 NAME

MojoMojo::Schema::Result::Attachment

=head1 METHODS

=over 4

=cut

sub delete {
    my ($self) = @_;

# we'll delete the inline and thumbnail versions but keep the original version (->filename)
    unlink( $self->inline_filename ) if -f $self->inline_filename;
    unlink( $self->thumb_filename )  if -f $self->thumb_filename;
    $self->next::method();
}

=item filename

Full path to this attachment.

=cut

sub filename {
    my $self           = shift;
    my $attachment_dir = $self->result_source->schema->attachment_dir;
    die(
"MojoMojo::Schema->attachment must be set to a writeable directory (Current:$attachment_dir)\n"
    ) unless -d $attachment_dir && -w $attachment_dir;
    return ( $attachment_dir . '/' . $self->id );
}

sub inline_filename { shift->filename . '.inline'; }

sub thumb_filename { shift->filename . '.thumb'; }

sub make_photo {
    my $self  = shift;
    my $photo = $self->result_source->related_source('photo')->resultset->new(
        {
            id    => $self->id,
            title => $self->name,
        }
    );
    $photo->description('Set your description');
    $photo->extract_exif($self) if $self->contenttype eq 'image/jpeg';
    $photo->insert();
}

1;
