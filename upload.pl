#!/usr/bin/env perl

package UploadHandler;
use Mojo::Base -base;

use File::Basename 'dirname';
use File::Spec;
use IO::All;

has app => sub { Mojolicious::Controller->new };
has files_dir =>
  sub { join '/', File::Spec->splitdir(dirname(__FILE__)), 'files' };
has upload => sub { Mojo::Upload->new };

sub list {
  my $self = shift;

  my $list;
  for my $file (io($self->files_dir)->all) {
    next if $file->name =~ /.htaccess/;
    my $download_url =
      $self->app->url_for(join '/', '/download', $file->name);
    my $delete_url = $self->app->url_for(join '/', '/delete', $file->name);
    push @$list,
      {
      name        => $file->name,
      size        => $file->size,
      url         => $download_url,
      delete_url  => $delete_url,
      delete_type => 'DELETE'
      };
  }
  return $list;
}

sub do_upload {
  my $self = shift;
  $self->upload->move_to(join '/', $self->files_dir, $self->upload->filename);
  return $self->list;
}

sub download {
  my ($self, $file) = @_;
  return io($file)->all;
}

sub delete_upload {
  my ($self, $file) = @_;
  io($file)->unlink;
  return $self->list;
}

package main;

use Mojolicious::Lite;
use Try::Tiny;

my $handler = UploadHandler->new(app => app);

plugin 'pod_renderer';    # for /perldoc

# enable receiving uploads up to 1GB
$ENV{MOJO_MAX_MESSAGE_SIZE} = 1_073_741_824;

# / (upload page)
get '/' => 'index';

# GET /upload (retrieves stored file list)
get '/upload' => sub { shift->render(json => $handler->list) };

# POST /upload (push one or more files to app)
post '/upload' => sub {
  my $self    = shift;
  my @uploads = $self->req->upload('files[]');

  for my $upload (@uploads) {
    $handler->upload($upload) && $handler->do_upload;
  }

  # return JSON list of uploads
  $self->render(json => $handler->list);
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
  $self->render(json => 1);
};

app->start;
