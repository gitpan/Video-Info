##------------------------------------------------------------------------
##  Package: Info.pm
##   Author: Benjamin R. Ginter, Allen Day
##   Notice: Copyright (c) 2002 Benjamin R. Ginter, Allen Day
##  Purpose: Retrieve Video Properties
## Comments: None
##      CVS: $Id
##------------------------------------------------------------------------

package Video::Info;
use 5.006;
use strict;
use Symbol;

our %FIELDS = ( 
			   type        => '', #ASF,MPEG,RIFF,etc
			   title       => '', #ASF media title
			   author      => '', #ASF author
			   date        => '', #ASF date (units???)
			   copyright   => '', #ASF copyright
			   description => '', #ASF description (freetext)
			   rating      => '', #ASF MPA rating
			   packets     => '', #ASF something
			   comments    => '', #???

			   astreams    => 0,  #number of audio streams
			   acodec      => '', #audio codec
			   acodecraw   => '', #audio codec (numeric)
			   arate       => 0,  #audio bitrate
			   achans      => 0,  #number of audio channels
			   afrequency  => '', #audio sampling frequency

			   vstreams    => 0,  #number of video streams
			   vcodec      => '', #video codec
			   vrate       => 0,  #video bitrate
			   vframes     => 0,  #number of video frames

			   fps         => 0,  #number of video frames per second
			   scale       => 0,  #quoeth transcode: if(scale!=0) AVI->fps = (double)rate/(double)scale;
			   duration    => 0,  #express this in seconds

			   width       => 0,  #video width
			   height      => 0,  #video height

			   aspect      => '', ##how to handle this?  16:9 scalar, or 16/9 float?
			   aspect_raw  => 0,  ##not sure what this is.  from MPEG?
		
			   _handle     => gensym, #filehandle to the bitstream
			  );
					
use Video::Info::Magic;
require Exporter;

our @ISA = qw(Exporter);

##------------------------------------------------------------------------
## Items to export into callers namespace by default. Note: do not export
## names by default without a very good reason. Use EXPORT_OK instead.
## Do not simply export all your public functions/methods/constants.
##------------------------------------------------------------------------
## This allows declaration	use Video::Info ':all';
## If you do not need this, moving things directly into @EXPORT or 
## @EXPORT_OK will save memory.
##------------------------------------------------------------------------
our %EXPORT_TAGS = ( 'all' => [ qw() ] );

our @EXPORT_OK = ( @{ $EXPORT_TAGS{'all'} } );

our @EXPORT = qw( );
our $VERSION = '0.09';

for my $datum ( keys %FIELDS ) {
    no strict "refs"; ## to register new methods in package
    *$datum = sub {
	shift; ## XXX: ignore calling class/object
	$FIELDS{$datum} = shift if @_;

       if ( $datum eq 'acodec' ) {
            return acodec2str( $FIELDS{acodec} ) || $FIELDS{acodec};
        }
        elsif ( $datum eq 'acodecraw' ) {
            return $FIELDS{acodec};
        }

	return $FIELDS{$datum};
    } 
}   

1;


##------------------------------------------------------------------------
## Extra methods
##
##------------------------------------------------------------------------
sub minutes {
  my $self = shift;
  my $seconds = int($self->duration) % 60;
  my $minutes = (int($self->duration) - $seconds) / 60;
  return $minutes;
}

sub MMSS {
  my $self = shift;
  my $mm = $self->minutes;
  my $ss = int($self->duration) - ($self->minutes * 60);

  my $return = sprintf( "%02d:%02d",$mm,$ss );
}

sub dimensions {
  my $self = shift;
  return $self->width."x".$self->height;
}

#Hmm... should we deprecate this?
sub length {
  my $self = shift;
  return $self->duration;
}

##------------------------------------------------------------------------
## Override superclass constructor
##
##------------------------------------------------------------------------
sub new {
  my $proto = shift;
  my $class = ref($proto) || $proto;
  my $self = bless { @_, },$class;
  
  my %param = @_;
  
  if($param{-file}){
	my ( $filetype, $handler ) = @{ divine( $param{ -file } ) };
	if ( $handler ) {
	  my $class = $handler;# . '::Info';
	  my $has_class = eval "require $class"; #we shouldn't die here... -allen
	  $param{-subtype} = $filetype;
	  
	  #if we can manufacture the class, do it
	  if($has_class){

                #special case for MP3::Info, grr
                if($handler =~ /^MP3/){
                  $self = $class->new( $param{ -file } );
                }

                else {
		  $self = $class->new(%param);
		  $self->probe( $param{-file}, [ $filetype, $handler ] );
                }

		#otherwise return a dummy Video::Info
	  } else {
		my %nodash_param = ();
		foreach(keys %param){/^-(.+)/;$nodash_param{$1} = $param{$_}};
		$self->{$_} = $param{$_} foreach(keys %nodash_param);
	  }
	  return $self;				
	} else {
	  my %nodash_param = ();
	  foreach(keys %param){/^-(.+)/;$nodash_param{$1} = $param{$_}};
	  
	  ##if we really need to return a Video::Info object, we need to chop off these -'s.
	  $self->{$_} = $param{$_} foreach(keys %nodash_param);
	  
	  ## doesn't probe() just re-divine() the file and die?
	  $self->probe( $param{-file} );
	  return $self;
	}
  }
  
  return $self;
}

##------------------------------------------------------------------------
## handle()
##
## Open a file handle or return an existing one
##------------------------------------------------------------------------
sub handle {
    my($self,$file) = @_;
    
    return $self->_handle unless defined $file;
    
    open(F,$file) or die "couldn't open $file: $!";
    return $self->_handle( \*F );
}

##------------------------------------------------------------------------
## probe()
##
## Open a video file and gather the stats
##------------------------------------------------------------------------
sub probe {
    my $self = shift;
    my $file = shift || die "probe(): A filename argument is required.\n";
    my $type = shift || divine($file) || die "probe(): Couldn't divine $file";

    my $warn;
    if ( $type->[1] ) {
	$warn .= "s of type $type->[1]\n";
    }
    else {
	$warn .= " type $type->[0]\n";
    }
    warn( ref( $self ),
	  '::probe() abstract method -- Create a child class for file',
	  $warn );
	  
}

__END__

=head1 NAME

Video::Info - Retrieve video properties
such as:
 height
 width
 codec
 fps

=head1 SYNOPSIS

  use Video::Info;

  my $info = Video::Info->new(-file=>'my.mpg');

  $info->fps();
  $info->aspect();
  ## ... see methods below

=head1 DESCRIPTION

Video::Info is a factory class for working with video files.
When you create a new Video::Info object (see methods), 
something like this will happen:
 1) open file, determine type. See L<Video::Info::Magic>.
 2) attempt to create object of appropriate class
    (ie, MPEG::Info for MPEG files, RIFF::Info for AVI
    files).
 3) Probe the file for various attributes
 4) return the created object, or a Video::Info object
    if the appropriate class is unavailable.

Currently, Video::Info can create objects for the
following filetypes:

  Module                 Filetype
  -------------------------------------------------
  ASF::Info              ASF
  MP3::Info              MPEG Layer 2, MPEG Layer 3
  MPEG::Info             MPEG1, MPEG2, MPEG 2.5
  RIFF::Info             AVI, DivX

And support is planned for:

  Module                 Filetype
  -------------------------------------------------
  Quicktime::Info        MOV, MOOV, MDAT, QT
  Real::Info             RealNetworks formats

=head1 METHODS

=head2 CONSTRUCTORS AND FRIENDS

new(): Constructor for a Video::Info object.  new() is called
with the following arguments:

  Argument    Default    Description
  ------------------------------------------------------------
  -file       none        path/to/file to create an object for
  -headersize 10240       how many bytes of -file should be
                          sysread() to determine attributes?

probe(): The core of each of the manufactured modules 
(with the exception of MP3::Info, which we manufacture 
only as courtesy), is in the probe() method.  probe() 
does a (series of) sysread() to determine various attributes 
of the file.  You don't need to call probe() yourself, it is 
done for you by the constructor, new().

=head2 METHODS

These methods should be available for all manufactured classes
(except MP3::Info):

=head2 Audio Methods

=over 4

=item achans()

Number of audio channels. 0 for no sound, 1 for mono,2 for 
stereo.  A higher value is possible, in principle.

=item acodec()

Name of the audio codec.

=item arate()

bits/second dedicated to an audio stream.

=item astreams()

Number of audio streams.  This is often >1 for files with 
multiple audio tracks (usually in different languages).

=item afrequency()

Sampling rate of the audio stream, in Hertz.

=back

=head2 Video Methods

=over 4

=item vcodec()

Name of the video codec.

=item vframes()

Number of video frames.

=item vrate()

average bits/second dedicated to a video stream.

=item vstreams()

Number of video streams.  0 for audio only.  This may be 
>1 for multi-angle video and the like, but I haven't seen
it yet.

=item fps()

How many frames/second are displayed.

=item width()

video frame width, in pixels.

=item height()

video frame height, in pixels.

=back

=head2 Other Methods

=over 4

=item type()

file type (RIFF, ASF, etc).

=item duration()

file length in seconds

=item minutes()

file length in minutes, rounded down

=item MMSS()

file length in minutes + seconds, in the format MM:SS

=item geometry()

Ben?

=item title()

Title of the file content.  Not the filename.

=item author()

Author of the file content.

=item copyright()

Copyright, if any.

=item description()

Freetext description of the content.

=item rating()

I think this is for an MPAA rating (PG, G, etc).

=item packets()

Number of data packets in the file.


=head2 EXPORT

None.

=head1 AUTHORS

 Copyright (c) 2002
 QPL Version 1.0
 Benjamin R. Ginter, <bginter@asicommunications.com>
 Allen Day, <allenday@ucla.edu>

=head1 SEE ALSO

L<Video::Info::Magic>
L<MPEG::Info>
L<MPEG::LibMPEG3>
L<RIFF::Info>
L<ASF::Info>

=cut
