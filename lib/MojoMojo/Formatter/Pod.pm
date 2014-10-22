package MojoMojo::Formatter::Pod;

use parent qw/MojoMojo::Formatter/;
# Pod::Simple::HTML gives warnings for version_tag_comment()
# because $self->VERSION is empty in the sprintf.  We don't
# really care about this sub do we?  It's been monkey zapped.
BEGIN 
{
    use Pod::Simple::HTML;
    no warnings 'redefine';
    *{"Pod::Simple::HTML::version_tag_comment"} = sub { 
        my $self = shift;
        return;
    }
}


=head1 NAME

MojoMojo::Formatter::Pod - format part of content as POD

=head1 DESCRIPTION

This formatter will format content between {{pod}} and {{end}} as 
POD (Plain Old Documentation).

=head1 METHODS

=over 4

=item format_content_order

Format order can be 1-99. The Pod formatter runs on 10

=cut

sub format_content_order { 10 }

=item format_content

calls the formatter. Takes a ref to the content as well as the
context object.

=cut

sub format_content {
    my ( $class, $content, $c ) = @_;

    my @lines = split /\n/, $$content;
    my $pod;
    $$content = "";
    my $start_re=$class->gen_re(qr/pod/);
    my $end_re=$class->gen_re(qr/end/);
    foreach my $line (@lines) {
        if ($pod) {
            if ( $line =~ m/^(.*)$end_re(.*)$/ ) {
                $$content .= MojoMojo::Formatter::Pod->to_pod( $pod.$1, $c->req->base ).$2;
                $pod = "";
            }
            else { $pod .= $line . "\n"; }
        }
        else {
            if ( $line =~ m/^(.*)$start_re(.*)$/ ) {
                $$content .= $1;
                $pod = " ".$2;    # make it true :)
            }
            else { $$content .= $line . "\n"; }
        }
    }
}

=item to_pod <pod> <base>

takes some POD documentation, and a base url, and renders it as HTML.

=cut

sub to_pod {
    my ( $class, $pod, $base ) = @_;
    my $result;
    my $parser = MojoMojo::Formatter::Pod::Simple::HTML->new($base);
    $parser->output_string( \$result );
    eval { $parser->parse_string_document($pod); };
    return "<pre>\n$source\n$@\n</pre>\n"
        if $@ or not $result;
    $result =~ s/.*<body.*?>(.*)<\/body>.*/$1/s;
    return qq{<div class="formatter_pod">\n$result</div>};
}

package MojoMojo::Formatter::Pod::Simple::HTML;

# base class for doing links

use parent 'Pod::Simple::HTML';

=item Pod::Simple::HTML::new

extended for setting base

=cut

sub new {
    my ( $class, $base ) = @_;
    my $self = $class->SUPER::new;
    $self->{_base} = $base;
    return $self;
}

=item Pod::Simple::HTML::do_link

Set links based on base

=cut

sub do_link {
    my ( $self, $token ) = @_;
    my $link = $token->attr('to');

    #FIXME: This doesn't look right:
    return $self->SUPER::do_link($token) unless $link =~ /^$token+$/;
    my $section = $token->attr('section');
    $section = "#$section"
        if defined $section and length $section;
    $self->{base} . "$link$section";
}

=back

=head1 SEE ALSO

L<MojoMojo>,L<Module::Pluggable::Ordered>,L<POD::Tree::HTML>

=head1 AUTHORS

Marcus Ramberg <mramberg@cpan.org>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.

=cut

1;
