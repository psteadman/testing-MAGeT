#! /usr/bin/env perl

use strict;
use Getopt::Tabular;
use File::Basename;


# Global Arguments

my $in; # option variable with default value (false)
my $inputdir = "/home/pstead/INPUT_NU/";
my $template = "/home/pstead/INPUT_NU/nih_chp_00305_t1_nuc.mnc";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $outdir = ".";
my $iterations = "20x20x20";
my $rad = '4';
my $def = '0';
my $grad = '3';
my $step = '0.5';
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] \n";

$help =
"| $progname  \n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-infile","string", 1, \$in, "Input MINC file to be perform Image Registration"],
		["-indir","string", 1, \$inputdir, "Input MINC files directory"],
		["-template","string", 1, \$template, "Template that MINC files registered with"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
		["-out","string",1, \$outdir, "Output directory"],
		["mincANTs Options","section"],
		["-iter","string",1, \$iterations, "Iterations for registration; default: 20x20x20"],
		["-rad","float", 1, \$rad, "Radius option for mincANTS [1:5]"],
		["-def","float", 1, \$def, "Deformation sigma option for mincANTS[0:0.5:4]"],
		["-grad","float", 1, \$grad, "Gradient sigma option for mincANTS [0:0.5:4]"],
		["-step","float", 1, \$step, "Step size option for mincANTS [0.25, 0.5]"]
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;

# Create base name for future files produced
my $base = &basename(${in},".mnc");
mkdir("${outdir}/transformations");
mkdir("${outdir}/resampled-files");
mkdir("${outdir}/labels");
# Run mincANTS
do_cmd("mincANTS",
             	"3", "-m", "PR[${inputdir}/${in},${template},1,${rad}]",
               	"--use-Histogram-Matching",
               	"--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
               	"--MI-option", "32x16000",
               	"--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4",
              	"-r","Gauss[${grad},${def}]", "-t", "SyN[${step}]",
              	"-o", "${outdir}/transformations/${base}.xfm", "-i", "${iterations}",
              	"-clobber");
# Run mincresample                
do_cmd("mincresample",
				"${labeldir}/${base}.mnc","${outdir}/labels/${base}_label.mnc","-transform",
				"${outdir}/transformations/${base}.xfm","-like","${template}",
				"-keep_real_range","-nearest_neighbour","-clobber");
do_cmd("mincresample",
				"${inputdir}/${base}.mnc","${outdir}/resampled-files/${base}_resampled.mnc",
				"-transform","${outdir}/transformations/${base}.xfm",
				"-like","${template}","-clobber");
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
