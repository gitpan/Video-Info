##------------------------------------------------------------------------
##  Package: Magic.pm
##   Author: Allen Day
##   Notice: Copyright (c) 2002 Allen Day
##  Purpose: Attempt to determine video file type.  Based on /usr/share/magic
## Comments: None
##      CVS: $Header: /cvsroot/Video-Info/Info/Magic.pm,v 1.15 2002/03/06 22:39:41 allenday Exp $
##------------------------------------------------------------------------

package Video::Info::Magic;
use 5.006;
use strict;
use warnings;

require Exporter;

our @ISA = qw(Exporter);
our $VERSION = '1.01';

#we're going to use a enhexable string as the constant value
#that matches the first four bytes of that filetype.  For lack
#of better values.
use constant VIDEO_UNKNOWN_FORMAT     => 0x00000001;
use constant VIDEO_MPEG1              => 0x00000002;
use constant VIDEO_MPEG2              => 0x00000003;
use constant VIDEO_MPEG_LAYER_2       => 0x00000004;
use constant VIDEO_MPEG_LAYER_3       => 0x00000005;
use constant VIDEO_MPEG_VIDEO_STREAM  => 0x000001b3;
use constant VIDEO_MPEG_SYSTEM_STREAM => 0x000001ba;
use constant VIDEO_RIFF               => 0x52494646;
use constant VIDEO_REALAUDIO          => 0x2e7261fd;
use constant VIDEO_REALMEDIA          => 0x2e524d46;
use constant VIDEO_QUICKTIME_MOOV     => 0x6d6f6f76;
use constant VIDEO_QUICKTIME_MDAT     => 0x6d646174;
use constant VIDEO_ASF1               => 0x75b22630;
use constant VIDEO_DV_PAL             => 0x1f0700bf;
use constant VIDEO_DV_NTSC            => 0x1f07003f;
use constant AUDIO_WAV                => 0x00000016;
use constant VIDEO_CDXA               => 0x00000016;
use constant VIDEO_VDR                => 0x00000021;

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

our @EXPORT = qw( MPEG1
		  VIDEO_MPEG2
		  VIDEO_MPEG_LAYER_2
		  VIDEO_MPEG_LAYER_3
		  VIDEO_MPEG_VIDEO_STREAM
		  VIDEO_MPEG_SYSTEM_STREAM
		  VIDEO_RIFF
		  VIDEO_REALAUDIO
		  VIDEO_REALMEDIA
		  VIDEO_QUICKTIME_MOOV
		  VIDEO_QUICKTIME_MDAT
		  VIDEO_UNKNOWN_FORMAT
		  VIDEO_ASF1
		  divine	
		  acodec2str
		  );

##------------------------------------------------------------------------
## Preloaded methods go here.
##------------------------------------------------------------------------
1;

sub divine {
    # warn "caller: ", caller, "\n";
    my $filename = shift || die "divine(): please provide path/to/file";
    
    open(F,$filename) || die "divine(): couldn't open $filename: $!";
    my($four1,$four2,$four3) = (undef,undef,undef);
    sysread(F,$four1,4) == 4 or die "divine(): sysread() 1\n";
    sysread(F,$four2,4) == 4 or die "divine(): sysread() 2\n";
    sysread(F,$four3,4) == 4 or die "divine(): sysread() 3\n";
    close(F);

    ## convert the four bytes to an unsigned long
    my $two = unpack( 'n', substr($four1,0,2) );
    $four1    = unpack( 'N', $four1 );
    $four2    = unpack( 'N', $four2 );
    $four3    = unpack( 'N', $four3 );
#warn $four1;

#TODO: MPEG1 MPEG2
    
    ## try to match the big, specific ones first
    my %table4 = (
		  0x1f0700bf    =>  [VIDEO_DV_PAL,                'DV::PAL'], #doesn't exist
		  0x1f07003f    =>  [VIDEO_DV_NTSC,              'DV::NTSC'], #doesn't exist
		  0x000001b3    =>  [VIDEO_MPEG_VIDEO_STREAM,  'MPEG::LibMPEG3'],
		  0x000001e0    =>  [VIDEO_MPEG_VIDEO_STREAM,  'MPEG::LibMPEG3'],
		  0x00000300    =>  [VIDEO_MPEG_VIDEO_STREAM,  'MPEG::LibMPEG3'],
		  0x000001ba    =>  [VIDEO_MPEG_SYSTEM_STREAM, 'MPEG::LibMPEG3'],
		  0x52494646    =>  [VIDEO_RIFF,               'RIFF::Info'],
		  0x41564920    =>  [VIDEO_RIFF,               'RIFF::Info'],
		  0x2e7261fd    =>  [VIDEO_REALAUDIO,          'Real::Info'], #doesn't exist
		  0x2e524d46    =>  [VIDEO_REALMEDIA,          'Real::Info'], #doesn't exist
		  0x6d6f6f76    =>  [VIDEO_QUICKTIME_MOOV,'QuickTime::Info'],
		  0x6d646174    =>  [VIDEO_QUICKTIME_MDAT,'QuickTime::Info'],
		  0x3026b275    =>  [VIDEO_ASF1,                'ASF::Info'],
        	  0x00000021    =>  [VIDEO_VDR,                'MPEG::LibMPEG3'], #dunno about this one
        	  #these are for subtyping RIFF files
		  0x57415645    =>  [AUDIO_WAV,                'Audio::Wav'],
        	  0x43445841    =>  [VIDEO_CDXA,               'RIFF::Info'], #MPEG after RIFF header... weird
		  );

#		  0x75b22630    =>  [VIDEO_ASF1,                'ASF::Info'],
    
    ## there may be more possible second bits (f0-f9) for MPEG I audio layers
    my %table2 = (
		  0x4944       =>  [VIDEO_MPEG_LAYER_3,        'MP3::Info'], #THIS HAS AN ID3 TAG
		  0xfffa       =>  [VIDEO_MPEG_LAYER_3,        'MP3::Info'], #11111010 MP3
		  0xfffb       =>  [VIDEO_MPEG_LAYER_3,        'MP3::Info'], #11111011 MP3
		  0xfffc       =>  [VIDEO_MPEG_LAYER_2,        'MP3::Info'], #11111100 MP2_FC
		  0xfffd       =>  [VIDEO_MPEG_LAYER_2,        'MP3::Info'], #11111101 MP2
		  0xfffe       =>  [VIDEO_MPEG_LAYER_3,        'MP3::Info'], #11111110 probably
		  0xffff       =>  [VIDEO_MPEG_LAYER_3,        'MP3::Info'], #11111111 not yet
		  );

#warn "2\t".$table4{$four1};
	if($table4{$four1} == VIDEO_RIFF){
		#try to catch RIFF subtypes
		$table4{$four3} ? return $table4{$four3} : 0;

		#or default to RIFF
		return $table4{$four1};
	}
	elsif($table4{$four1}){
		return $table4{$four1};
	}

    $table2{$two}  ? return $table2{$two} : 0;
    
    return [VIDEO_UNKNOWN_FORMAT,undef];
}

##------------------------------------------------------------------------
## acodec2str()
##
## Return the common name for a hexadecimal codec.
##------------------------------------------------------------------------
sub acodec2str {
  my $numeric = shift;

  my %codec = (
	       0x1        => 'Uncompressed PCM',
	       0x2        => 'MS ADPCM',
	       0x4        => 'Windows Media Audio', #is this right?
	       0x6        => 'aLaw',
	       0x7        => 'uLaw',
	       0xa        => 'DivX audio (WMA)',
	       0x11       => 'IMA ADPCM',
	       0x31       => 'MS GSM 6.10',
	       0x32       => 'MS GSM 6.10',  # MSN Audio
	       0x50       => 'MPEG Layer 1/2',
	       0x55       => 'MPEG Layer 3',
	       0x61       => 'Duck DK4 ADPCM (rogue format number)',
	       0x62       => 'Duck DK3 ADPCM (rogue format number)',
	       0x75       => 'VoxWare',
	       0x85       => 'MPEG Layer 3',
	       0x111      => 'Vivo G.723',
	       0x112      => 'Vivo G.723/Siren',
	       0x130      => 'ACELP.net Sipro Lab Audio Decoder',
	       0x160      => 'DivX audio (WMA1)',
	       0x161      => 'DivX audio (WMA2)',
	       0x270      => 'Sony ATRAC3',
	       0x401      => 'Intel Music Coder',
	       0x2000     => 'AC3',
	       0xfffe     => 'OggVorbis Audio Decoder',
	       0x1fc4     => 'ALF2',

## Hrm, we only grab a 2-byte short so these can't exist
#	       0x20776172 => 'PCM',          # raw (MOV files)
#	       0x736f7774 => 'PCM',          # twos (MOV files)
#	       0x33706d2e => 'MPEG Layer 3', # ".mp3" CBR/VBR MP3 (MOV files)
#	       0x5500736d => 'MPEG Layer 3', # "ms\0\x55" older mp3 fcc (MOV files)
#	       0x77616c75 => 'uLaw',         # "ulaw" (MOV files)
#	       0x10001    => 'Uncompressed DVD PCM',
  );

#warn "num: $numeric , cod: $codec{$numeric}";
  if ( defined $numeric && defined $codec{$numeric} ) {
      return $codec{$numeric};
  }

}


__END__

=head1 NAME

Video::Info::Magic - Resolve video filetype if possible.

=head1 SYNOPSIS

  use strict;
  use Video::Info::Magic qw(:all);

  my $type = divine('/path/to/video.mpg' );

  print $type; #MPEG system stream data (maybe)

  ## ... see methods below

=head2 EXPORT

various constants related to video file formats.  All are prefixed with
"VIDEO_".

divine(): Employs /usr/share/magic entries to determine a file's type,
as well as GUID and other info from Microsoft, mplayer, transcode...

=head1 AUTHOR

Allen Day <allenday@ucla.edu>

=head1 SEE ALSO

L<Video::Info>.
L<magic>.


=cut
