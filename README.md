# JQuery File Upload - Perl handler example

This is just a quick example of how to do a file upload handler for
[jQuery File Upload with Perl][jfu].  I made this years ago, but it is
still a good example.

[jfu]: https://github.com/blueimp/jQuery-File-Upload

To run this, you'll need a recent Perl (at least 5.14.2) with
[cpanminus][cpanm]:

    cpanm --installdeps .
    mkdir files
    morbo upload.pl

[cpanm]: https://metacpan.org/pod/App::cpanminus

Then open your browser to http://localhost:3000 .
