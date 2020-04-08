#! /usr/bin/env perl

use strict;
use Getopt::Tabular;
use File::Basename;


# Global Arguments

my $in;
my $template = "/home/pstead/INPUT_NU/nih_chp_00305_t1_nuc.mnc";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $dir;
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] -infile file2resample.mnc -dir directory/with/transforms/ \n";

$help =
"| $progname for each label determines the overlap amongst all the files \n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-infile","string", 1, \$in, "Input MINC file to be perform resampling on"],
		["-dir","string",1, \$dir, "Directory to resample"],
		["-template","string", 1, \$template, "Template, MINC files registered with"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;
# Create base name for future files produced
my $base = &basename(${in},".mnc");
chdir($dir);
# Run mincresample                
do_cmd("mincresample",
				"${labeldir}/${base}.mnc","${dir}/labels/${base}_label.mnc","-transform",
				"${dir}/transformations/${base}.xfm","-like","${template}",
				"-keep_real_range","-nearest_neighbour","-clobber");
do_cmd("mincresample",
				"${in}","${dir}/resampled-files/${base}_resampled.mnc",
				"-transform","${dir}/transformations/${base}.xfm","-like",
				"${template}","-clobber");
# Zip files for space savings
my @labels = split(/\n/, `ls -1 labels/*.mnc`);
if (scalar(@labels) == 19){
	foreach my $i (@labels){
		do_cmd("gzip","-f","${i}");
	}
}
my @resampledfiles = split(/\n/, `ls -1 resampled-files/*.mnc`);
if (scalar(@resampledfiles) == 19){
	foreach my $f (@resampledfiles){
		do_cmd("gzip","-f","${f}");
	}
}
	
# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
    system(@_) == 0 or die "Dude must quit";
}