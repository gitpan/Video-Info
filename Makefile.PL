use 5.008003;
use ExtUtils::MakeMaker;
use Term::ANSIColor;

print colored("Video::Info is deprecated in favor of FFmpeg.  Use FFmpeg instead.",'red')."\n";

WriteMakefile(
    NAME              => 'Video::Info',
    VERSION_FROM      => 'lib/Video/Info.pm', # finds $VERSION
    PREREQ_PM         => {}, # e.g., Module::Name => 1.1
    ($] >= 5.005 ?     ## Add these new keywords supported since 5.005
      (ABSTRACT_FROM  => 'lib/Video/Info.pm', # retrieve abstract from module
       AUTHOR         => 'Allen Day <allenday@ucla.edu>') : ()),
);
