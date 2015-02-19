#!/usr/bin/env perl

{
    package UploadHandler;
    use Mojo::Base -base;

    use IO::All;

    has app       => sub { Mojolicious::Controller->new };
    has files_dir => sub { io( $_[0]->app->home )->catdir('files') };

    sub list {
        my $self = shift;

        my $list;
        for my $file ( $self->files_dir->all ) {
            next if $file->name =~ /.htaccess/;
            my $download_url =
              $self->app->url_for("/download/@{[ $file->filename ]}");
            my $delete_url =
              $self->app->url_for("/delete/@{[ $file->filename ]}");
            push @$list,
              {
                name        => $file->filename,
                size        => $file->size,
                url         => $download_url,
                delete_url  => $delete_url,
                delete_type => 'DELETE'
              };
        }
        return $list;
    }

    sub do_upload {
        my ( $self, $upload ) = @_;
        my $dest = $self->files_dir->catfile( $upload->filename );
        $upload->move_to( $dest->name );
        return $self->list;
    }

    sub download {
        my ( $self, $file ) = @_;
        return $self->files_dir->catfile($file)->all;
    }

    sub delete_upload {
        my ( $self, $file ) = @_;
        $self->files_dir->catfile($file)->unlink;
        return $self->list;
    }
}

use Mojolicious::Lite;
use Try::Tiny;

my $handler = UploadHandler->new( app => app );

plugin 'PODRenderer';    # for /perldoc

# enable receiving uploads up to 1GB
$ENV{MOJO_MAX_MESSAGE_SIZE} = 1_073_741_824;

# / (upload page)
get '/' => 'index';

# GET /upload (retrieves stored file list)
get '/upload' => sub { shift->render( json => $handler->list ) };

# POST /upload (push one or more files to app)
post '/upload' => sub {
    my $self    = shift;
    my $uploads = $self->req->every_upload('files[]');

    # Use Mojo::Base K combinator
    $handler->tap( do_upload => @$uploads );

    # return JSON list of uploads
    $self->render( json => $handler->list );
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
