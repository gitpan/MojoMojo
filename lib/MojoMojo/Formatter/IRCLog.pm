package MojoMojo::Formatter::IRCLog;

use parent qw/MojoMojo::Formatter/;

=head1 NAME

MojoMojo::Formatter::IRCLog - format part of content as an IRC log

=head1 DESCRIPTION

This formatter will format content between {{irc}} and {{end}} as 
an IRC log

=head1 METHODS

=over 4

=item format_content_order

Format order can be 1-99. The IRC log formatter runs on 14, so
just before the Textile formatter.

=cut

sub format_content_order { 14 }

=item format_content

calls the formatter. Takes a ref to the content as well as the
context object.

=cut

sub format_content {
    my ( $class, $content ) = @_;
    my ( $in_log, %nicks, $longline, @newlines );

    my @lines = split( /\n/, $$content );
    $$content = "";
    my $start_re=$class->gen_re(qr/irc/);
    my $end_re=$class->gen_re(qr/end/);

    foreach my $line (@lines) {
        if ($in_log) {
            if ( $line =~ $end_re ) {
                $in_log = 0;
                if ($longline) {
                    $longline .= "</dd>";
                    push( @newlines, $longline );
                    $longline = "";
                }
                push @newlines, $line;
            }
            elsif ( $line =~ /^[\d:]*\s*<[+\%\@ ]?(.*?)>\s*(.*)/ ) {
                if ($longline) {
                    $longline .= "</dd>";
                    push( @newlines, $longline );
                    $longline = "";
                }
                $nicks{$1} = 1;
                $longline = "<dt>$1</dt>\n<dd>$2";
            }
            else {
                $line =~ s/^\s*/ /;
                $longline .= $line;
            }
        }
        else {
            if ( $line =~ $start_re ) {
                push @newlines, $line;
                $in_log = 1;
            }
            else {
                push( @newlines, $line );
            }
        }
    }
    foreach my $line (@newlines) {
        if ($in_log) {
            if ( $line =~ $end_re ) {
                $in_log = 0;

                # end the dl and the section not handled by textile
                $$content .= "</dl>\n==\n";
            }
            else {
                my $count = 0;
                foreach my $nick ( keys %nicks ) {
                    $count += ( $line =~ s/$nick/[[$nick]]/g );
                }
                $$content .= "$line\n";
            }
        }
        else {
            if ( $line =~ $start_re ) {
                $in_log = 1;

                # start a definition list in a section not handled by
                # textile
                $$content .= "==\n<dl>\n";
            }
            else {
                $$content .= "$line\n";
            }
        }
    }
}

=back

=head1 SEE ALSO

L<MojoMojo> and L<Module::Pluggable::Ordered>,

=head1 AUTHORS

Martijn van Beers <martijn@eekeek.org>

=head1 LICENSE

This module is licensed under the same terms as Perl itself.

=cut

1;
