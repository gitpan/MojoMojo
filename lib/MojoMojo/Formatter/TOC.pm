package MojoMojo::Formatter::TOC;

use parent qw/MojoMojo::Formatter/;

use HTML::Entities;
use Encode;

eval "use HTML::Toc;use HTML::TocInsertor;";
my $eval_res = $@;
sub module_loaded { $eval_res ? 0 : 1 }

=head1 NAME

MojoMojo::Formatter::TOC - generate table of contents

=head1 DESCRIPTION

This formatter will replace C<{{toc}}> with a table of contents, using
HTML::GenToc. If you don't want an element to be included in the TOC,
make it have C<class="notoc">

=head1 METHODS

=head2 format_content_order

The TOC formatter expects HTML input so it needs to run after the main
formatter. Since comment-type formatters (order 91) could add a heading
for the comment section, the TOC formatter will run with a priority of 95.

=cut

sub format_content_order { 95 }

=head2 format_content

Calls the formatter. Takes a ref to the content as well as the context object.
The syntax for the TOC plugin invocation is:

  {{toc M- }}     # start from Header level M
  {{toc -N }}     # stop at Header level N
  {{toc M-N }}    # process only header levels M..N

where M is the minimum heading level to include in the TOC, and N is the
maximum level (depth). For example, suppose you only have one H1 on the page
so it doesn't make sense to add it to the TOC; also, assume you and don't want
to include any headers smaller than H3. The {{toc}} markup to achieve that would be:

  {{toc 2-3}}

Defaults to 1-6.

=cut

sub format_content {
    my ( $class, $content ) = @_;
    return unless $class->module_loaded;
    my $toc_params_RE = qr/\s+ (\d+)? \s* - \s* (\d+)?/x;
    while (
        # replace the {{toc ..}} markup tag and parse potential parameters
        $$content =~ s[
            {{ toc (?:$toc_params_RE)? \s* \/? }}
        ][<div class="toc">\n<!--mojomojoTOCwillgohere-->\n</div>]ix) {
        my ($toc_h_min, $toc_h_max);
        $toc_h_min = $1 || 1;
        $toc_h_max = $2 || 9;  # in practice, there are no more than 6 heading levels
        $toc_h_min = 9 if $toc_h_min > 9;  # prevent TocGenerator error for headings >= 10
        $toc_h_max = 9 if $toc_h_max > 9 or $toc_h_max < $toc_h_min;  # {{toc 3-1}} is wrong; make it {{toc 3-9}} instead

        my $toc = HTML::Toc->new();
        my $tocInsertor = HTML::TocInsertor->new();

        $toc->setOptions({
            header => '',  # by default, \n<!-- Table of Contents generated by Perl - HTML::Toc -->\n
            footer => '',
            insertionPoint => 'replace <!--mojomojoTOCwillgohere-->',
            doLinkToId => 0,
            levelToToc => "[$toc_h_min-$toc_h_max]",
            templateAnchorName => \&assembleAnchorName,
        });

        # http://search.cpan.org/dist/HTML-Toc/Toc.pod#HTML::TocInsertor::insert()
        $tocInsertor->insert($toc, $$content, {output => $content});

        return 1;
    }
}

=head2 SEO-friendly anchors

Anchors should be generated with SEO- (and human-) friendly names, i.e. out of the entire
token text, instead of being numeric or reduced to the first word(s) of the token.
In the spirit of http://seo2.0.onreact.com/top-10-fatal-url-design-mistakes, compare:

  http://beachfashion.com/photos/Pamela_Anderson#In_red_swimsuit_in_Baywatch
    vs.
  http://beachfashion.com/photos/Pamela_Anderson#in

"Which one speaks your language more, which one will you rather click?"

The anchor names generated are compliant with XHTML1.0 Strict. Also, per the
HTML 4.01 spec, anchor names should be restricted to ASCII characters and
anchors that differ only in case may not appear in the same document. In
particular, an anchor name may be defined only once in a document (logically,
because otherwise the user agent wouldn't know which #foo to scroll to).
This is currently a problem with L<HTML::Toc> v1.11, which doesn't have
support for passing the already existing anchors to the C<templateAnchorName>
sub.

=cut


# http://search.cpan.org/dist/HTML-Toc/Toc.pod#templateAnchorName
sub assembleAnchorName {
    my ($aFile, $aGroupId, $aLevel, $aNode, $text, $children) = @_;

    if ($text !~ /^\s*$/) {
        # generate a SEO-friendly anchor right from the token content
        # The allowed character set is limited first by the URI specification for fragments, http://tools.ietf.org/html/rfc3986#section-2: characters
        # then by the limitations of the values of 'id' and 'name' attributes: http://www.w3.org/TR/REC-html40/types.html#type-name
        # Eventually, the only punctuation allowed in id values is [_.:-]
        # Unicode characters with code points > 0x7E (e.g. Chinese characters) are allowed (test "<h1 id="????">header</h1>" at http://validator.w3.org/#validate_by_input+with_options), except for smart quotes (!), see http://www.w3.org/Search/Mail/Public/search?type-index=www-validator&index-type=t&keywords=[VE][122]+smart+quotes&search=Search+Mail+Archives
        # However, that contradicts the HTML 4.01 spec: "Anchor names should be restricted to ASCII characters." - http://www.w3.org/TR/REC-html40/struct/links.html#h-12.2.1
        # ...and the [A-Za-z] class of letters mentioned at http://www.w3.org/TR/REC-html40/types.html#type-name
        # Finally, note that pod2html fails miserably to generate XHTML-compliant anchor links. See http://validator.w3.org/check?uri=http%3A%2F%2Fsearch.cpan.org%2Fdist%2FCatalyst-Runtime%2Flib%2FCatalyst%2FRequest.pm&charset=(detect+automatically)&doctype=XHTML+1.0+Transitional&group=0&user-agent=W3C_Validator%2F1.606
        $text =~ s/\s/_/g;
        decode_entities($text);  # we need to replace [#&;] only when they are NOT part of an HTML entity. decode_entities saves us from crafting a nasty regexp
        $text = encode('utf-8', $text);  # convert to UTF-8 because we need to output the UTF-8 bytes
        $text =~ s/([^A-Za-z0-9_:.-])/sprintf('.%02X', ord($1))/eg;  # MediaWiki also uses the period, see http://en.wikipedia.org/wiki/Hierarchies#Ethics.2C_behavioral_psychology.2C_philosophies_of_identity
        $text = 'L'.$text if $text =~ /\A\W/; # "ID and NAME tokens must begin with a letter ([A-Za-z])" -- http://www.w3.org/TR/html4/types.html#type-name
    }
    $text = 'id' if $text eq '';

    # check if the anchor already exists; if so, add a number
    # NOTE: there is no way currently to do this easily in HTML-Toc-1.10.

    #my $anch_num = 1;
    #my $word_name = $name;
    ## Reference: http://www.w3.org/TR/REC-html40/struct/links.html#h-12.2.1
    ## Anchor names must be unique within a document. Anchor names that differ only in case may not appear in the same document.
    #while (grep {lc $_ eq lc $name} keys %{$args{anchors}}) {
    #    # FIXME (in caller sub): to avoid the grep above, the $args{anchors} hash
    #    # should have as key the lowercased anchor name, and as value its actual value (instead of '1')
    #    $name = $word_name . "_$anch_num";
    #    $anch_num++;
    #}

    return $text;
}


=head1 SEE ALSO

L<MojoMojo> and L<Module::Pluggable::Ordered>.

=head1 AUTHORS

Dan Dascalescu, L<http://dandascalescu.com>

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as Perl itself.

=cut

1;
