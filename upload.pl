#!/usr/bin/env perl

{
    package UploadHandler;
    use Mojo::Base -base;

    use IO::All;

    has 'dir';
    has files_dir => sub { io( shift->dir ) };

    sub list {
        my $self = shift;

        my $list;
        for my $file ( $self->files_dir->all ) {
            next if $file->name =~ /.htaccess/;
            push @$list, $file;
        }
        return $list;
    }

    sub do_upload {
        my ( $self, $file ) = @_;
        my $dest = $self->files_dir->catfile( $file->filename );
        $file->move_to( $dest->name );
        return +[$file];
    }

    sub download {
        my ( $self, $file ) = @_;
        return $self->files_dir->catfile($file)->all;
    }

    sub delete_upload {
        my ( $self, $file ) = @_;
        $self->files_dir->catfile($file)->unlink;
    }
}

use Mojolicious::Lite;
use Try::Tiny;

my $handler = UploadHandler->new( dir => app->home->child('files') );

helper files => sub {
    my ( $self, $files ) = @_;
    +[  map {
            +{  name => $_->filename,
                size => $_->size,
                url  => $self->app->url_for("/download/@{[ $_->filename ]}"),
                delete_url =>
                    $self->app->url_for("/delete/@{[ $_->filename ]}"),
                delete_type => 'DELETE'
                }
        } @$files
    ];
};

plugin 'PODRenderer';    # for /perldoc

# enable receiving uploads up to 1GB
$ENV{MOJO_MAX_MESSAGE_SIZE} = 1_073_741_824;

# / (upload page)
get '/' => 'index';

# GET /upload (retrieves stored file list)
get '/upload' => sub {
    my $self = shift;
    $self->render( json => $self->files( $handler->list ) );
};

# POST /upload
post '/upload' => sub {
    my $self = shift;
    my $file = $self->req->upload('files[]');
    $self->render( json => $self->files( $handler->do_upload($file) ) );
};

# /download/files/foo.txt
get '/download/*key' => sub {
    my $self = shift;
    my $key  = $self->param('key');

    try {
        $self->render(
            data   => $handler->download($key),
            format => 'application/octet-stream'
        );
    }
    catch {
        $self->render_not_found;
    }
};

# /delete/files/bar.tar.gz
del '/delete/*key' => sub {
    my $self = shift;
    my $key  = $self->param('key');

    $handler->delete_upload($key);
    $self->render( json => 1 );
};

app->start;
