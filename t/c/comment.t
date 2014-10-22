#!/usr/bin/perl -w
use Test::More tests => 4;
BEGIN{
    $ENV{CATALYST_CONFIG} = 't/var/mojomojo.yml';
    $ENV{CATALYST_DEBUG} = 0;
};
use_ok( Catalyst::Test, 'MojoMojo' );
use_ok('MojoMojo::Controller::Comment');

ok( request('/.comment')->is_success,'get .comment');
ok( request('/.comment/login')->is_success,'get .comment/login' );
