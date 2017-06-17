#!/usr/bin/env perl

{
    package UploadHandler;
    use Mojo::Base -base;

    use Mojo::File;

    has 'dir';
    has files_dir => sub { Mojo::File->new( shift->dir ) };

    sub list {
        my $self = shift;
        $self->files_dir->list;
    }

    sub check {
        my ( $self, $file ) = @_;
        -f $self->files_dir->child($file);
    }

    sub do_upload {
        my ( $self, $file ) = @_;
        my $dest = $self->files_dir->child( $file->filename );
        $file->move_to($dest);
        +[ $dest->realpath ];
    }

    sub download {
        my ( $self, $file ) = @_;
        $self->files_dir->child($file)->slurp;
    }

    sub delete_upload {
        my ( $self, $file ) = @_;
        unlink $self->files_dir->child($file);
    }
}

use Mojolicious::Lite;

my $handler
    = UploadHandler->new( dir => app->home->child('files')->make_path );

helper files => sub {
    my ( $self, $files ) = @_;
    +[  map {
            +{  name => $self->b( $_->basename )->decode,
                size => -s $_,
                url  => $self->app->url_for("/download/@{[ $_->basename ]}"),
                delete_url =>
                    $self->app->url_for("/delete/@{[ $_->basename ]}"),
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

    return $self->reply->not_found
        unless $handler->check($key);
    $self->render(
        data   => $handler->download($key),
        format => 'application/octet-stream'
    );
};

# /delete/files/bar.tar.gz
del '/delete/*key' => sub {
    my $self = shift;
    my $key  = $self->param('key');

    $handler->delete_upload($key);
    $self->render( json => 1 );
};

app->start;
