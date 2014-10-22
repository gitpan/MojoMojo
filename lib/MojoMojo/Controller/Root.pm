package MojoMojo::Controller::Root;

use parent 'Catalyst::Controller';

__PACKAGE__->config->{namespace} = '';

=head1 NAME

MojoMojo::Controller::Root

=head1 ACTIONS

=over 4

=item begin (builtin)

=cut

sub begin : Private {
    my ( $self, $c ) = @_;
    if($c->sessionid && $c->session->{lang}) {
        $c->languages([$c->session->{lang}]);
    }
    else {
        $c->languages([$c->pref('default_lang')]) if $c->pref('default_lang');
    }
    if ( $c->stash->{path} ) {
        my ( $path_pages, $proto_pages ) =
            $c->model('DBIC::Page')->path_pages( $c->stash->{path} );
        @{ $c->stash }{qw/ path_pages proto_pages /} = ( $path_pages, $proto_pages );
        $c->stash->{page} = $path_pages->[ @$path_pages - 1 ];
        $c->stash->{user} = $c->user->obj() if $c->user_exists && $c->user;
    }
}

=item default (global)

default action - serve the home node

=cut

sub default : Path {
    my ( $self, $c ) = @_;
    $c->res->status(404);
    $c->stash->{message} = $c->loc(
        'The requested URL was not found: x',
        '<span class="error_detail">' . $c->stash->{pre_hacked_uri} . '</span>'
    );
    $c->stash->{template} = 'message.tt';
}

=item set_lang

(Re)set language of current session.

=cut

sub set_lang :Global {
    my ($self,$c) = @_;
    $c->session->{lang}=$c->req->params->{lang};
    $c->res->redirect($c->req->params->{redir});
}

=item render

Finally use ActionClass RenderView to render the content.

=cut

sub render : ActionClass('RenderView') {
    my ($self) = shift;
    my ($c)    = @_;
    $c->stash->{path} ||= '/';
}

=item end (builtin)

At the end of any request, forward to view unless there is a template
or response, then render the template. If param 'die' is passed,
show a debug screen.

=cut

sub end : Private {
    my ( $self, $c ) = @_;

    my $theme=$c->pref('theme');
    # if theme doesn't exist
    if ( ! -d  $c->path_to('root','static','themes',$theme)) {
       $theme='default';
       $c->pref('theme',$theme);
    }
    $c->stash->{additional_template_paths} =
        [ $c->path_to('root','themes',$theme) ];

    $c->req->uri->path( $c->stash->{pre_hacked_uri}->path )
        if ref $c->stash->{pre_hacked_uri};
    $c->forward('render');
}

=item auto

Runs for all requests, checks if user is in need of validation, and
intercepts the request if so.

=cut

sub auto : Private {
    my ( $self, $c ) = @_;
    if ( $c->pref('enforce_login') ) {
        # allow a few actions
        if ( grep $c->action->name eq $_, qw/login logout recover_pass register/ ) {
            return 1;
        }
        if ( !$c->user_exists ) {
            $c->res->redirect( $c->uri_for('/.login') );
        }
    }

    return 1 unless $c->stash->{user};
    return 1 if $c->stash->{user}->active != -1;
    return 1 if $c->req->action eq 'logout';
    $c->stash->{template} = 'user/validate.tt';
}

sub exit : Local {
    my ($self, $c) = @_;
    if ($ENV{MOJOMOJO_EXIT_OK}) {
        exit(0);
    }
    else {
       # $c->stash( template => 'error.tt' );
        $c->res->status (403); # forbidden
        $c->res->body('EXIT NOT OK');
        $c->detach();
    }
}


=back

=head1 LICENSE

This library is free software. You can redistribute it and/or modify
it under the same terms as perl itself.

=cut

1;
