use strict;
use warnings;

use ExtUtils::MakeMaker;

WriteMakefile(
  NAME         => 'Daje::Model::User',
  VERSION_FROM => 'lib/Daje/Model/Companies.pm',
  AUTHOR       => 'Jan Eskilsson <nospam@cpan.org>',
  PREREQ_PM    => {
    'Try::Tiny' => 0,    
    },
  test         => {TESTS => 't/*.t'}
);
