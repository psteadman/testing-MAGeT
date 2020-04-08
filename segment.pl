#! /usr/bin/env perl
# Created by: Patrick Steadman 
# January 2011
# Purpose: To register input file to a given template and then use the output transform to create labels for input file
# Program name: segment.pl

use strict;
use Getopt::Tabular;
use File::Basename;


# Global Arguments

my $in = ''; # option variable with default value (false)
my $inputdir = "/home/pstead/INPUT_NU";
my $template = "nih_chp_00305_t1_nuc.mnc";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
# Default are optimized parameters (TBD)
my $rad = 0;
my $def = 0;
my $grad = 0;
my $step = 0;

my @argTbl =
	(
		["Input Options","section"],
		["-infile","string", 1, \$in, "Input MINC file to be perform Image Registration"],
		["-indir","string", 1, \$inputdir, "Input MINC files directory"],
		["-template","string", 1, \$template, "Template, MINC files registered with"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
		["mincANTs Options","section"],
		["-rad","float", 1, \$rad, "Radius option for mincANTS [1:5]"],
		["-def","float", 1, \$def, "Deformation sigma option for mincANTS[0:0.5:4]"],
		["-grad","float", 1, \$grad, "Gradient sigma option for mincANTS [0:0.5:4]"],
		["-step","float", 1, \$step, "Step size option for mincANTS [0.25, 0.5]"]
	);

&GetOptions(\@argTbl, \@ARGV);

# Create base name for future files produced
my $base = &basename(${in},".mnc");
# Run mincANTS
do_cmd("mincANTS",
              "3", "-m", "PR[${inputdir}/${in},${inputdir}/${template},1,${rad}]",
               "--use-Histogram-Matching",
               "--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
               "--MI-option", "32x16000",
               "--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4",
               "-r","Gauss[${grad},${def}]", "-t", "SyN[${step}]",
               "-o", "transformations/${base}.xfm", "-i", "20x20x20","-clobber");
# ORRRR
do_cmd("mincANTS",
              "3", "-m", "PR[${inputdir}/${template},${inputdir}/${in},1,${rad}]",
               "--use-Histogram-Matching",
               "--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
               "--MI-option", "32x16000",
               "--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4",
               "-r","Gauss[${grad},${def}]", "-t", "SyN[${step}]",
               "-o", "transformations/${base}.xfm", "-i", "20x20x20","-clobber");
# Run mincresample                
do_cmd("mincresample",
				"${labeldir}/${base}.mnc","labels/${base}_label.mnc","-transform",
				"transformations/${base}.xfm","-like","${inputdir}/${template}",
				"-keep_real_range","-nearest_neighbour",-"clobber");
do_cmd("mincresample",
				"${inputdir}/${in}","resampled-files/${base}_resampled.mnc",
				"-transform","transformations/${base}.xfm","-like",
				"${inputdir}/${template}",-"clobber");

# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}