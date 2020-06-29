#!/usr/bin/env perl

package UploadHandler {
  use Mojo::Base -base, -signatures;
  use Mojo::File;

  has 'dir';
  has files_dir => sub { Mojo::File->new(shift->dir) };

  sub list ($self) {
    $self->files_dir->list;
  }

  sub check ($self, $file) {
    -f $self->files_dir->child($file);
  }

  sub do_upload ($self, $file) {
    my $dest = $self->files_dir->child($file->filename);
    $file->move_to($dest);
    +[$dest->realpath];
  }

  sub delete_upload ($self, $file) {
    unlink $self->files_dir->child($file);
  }
}

use Mojolicious::Lite -signatures;

my $handler = UploadHandler->new(dir => app->home->child('files')->make_path);

helper files => sub ($self, $files) {
  +[
    map {
      +{
        name        => $self->b($_->basename)->decode,
        size        => -s $_,
        url         => $self->app->url_for("/download/@{[$_->basename]}"),
        delete_url  => $self->app->url_for("/delete/@{[$_->basename]}"),
        delete_type => 'DELETE'
      }
    } @$files
  ];
};

# enable receiving uploads up to 100GB
$ENV{MOJO_MAX_MESSAGE_SIZE} = 1_073_741_824 * 100;

# / (upload page)
get '/' => 'index';

# GET /upload (retrieves stored file list)
get '/upload' => sub ($self) {
  $self->render(json => $self->files($handler->list));
};

# POST /upload
post '/upload' => sub ($self) {
  my $file = $self->req->upload('files[]');
  $self->render(json => $self->files($handler->do_upload($file)));
};

# /download/files/foo.txt
get '/download/*key' => sub ($self) {
  my $key = $self->param('key');

  return $self->reply->not_found unless $handler->check($key);
  $self->reply->file($handler->files_dir->child($key));
};

# /delete/files/bar.tar.gz
del '/delete/*key' => sub ($self) {
  my $key = $self->param('key');

  $handler->delete_upload($key);
  $self->render(json => 1);
};

app->start;
