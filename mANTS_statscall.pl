#! /usr/bin/env perl
# Created by: Patrick Steadman 
# January 2011

# Called by mANTS-stats.pl

use strict;
use Getopt::Tabular;
use File::Basename;

# Global Variables
my @labels = (1..8);
my $set; my $base;
my $mydir = "/scratch/pstead/mANTS-human-optimization/";
my $template = "/scratch/pstead/mANTS-human-optimization/template_label/nih_chp_00305_t1_nuc.mnc";
my $inputdir = "/home/pstead/INPUT_NU";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $descriptor = "opt_settings";
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] directory1 directory2 ...\n";

$help =
"| $progname \n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-set","string", 1, \$set, "The set number this is for stats (max 8)"],
		["-dir","string", 1, \$mydir, "Directory to output csv file"],
		["-template","string", 1, \$template, "Template labels which will not be in a setting's directory"],
		["-inputdir","string", 1, \$inputdir, "Directory where input files are stored"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
		["-descriptor","string", 1, \$descriptor, "Discriptor of registration - NOT USED"],
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;

my @directories = @ARGV;
# mkdir("${mydir}/analysis");
open (FILE, '>', "${mydir}/analysis/stats_${set}.csv");
print FILE "Settings, Label, Voxel Count 20, Voxel Count 19, Voxel Count 18, Voxel Count 17\n";
my $tempbase = &basename($template, ".mnc");
foreach my $dir (@directories){
	chdir($dir); mkdir("sums"); mkdir("single-labels");
	print "The directory is: $dir \n";
# First check if there are 19 labels and if not then gunzip to get 19
	my @num_labels = split(/\n/, `ls -1 labels/*.mnc`);
	if (scalar(@num_labels) < 19) { 
		print "Not enough labels, must gunzip dude! \n";
		my @required_labels = split(/\n/, `ls -1 ${labeldir}`);
		foreach my $req_l (@required_labels){
			$base = &basename($req_l,".mnc");
			if ($base ne ${tempbase}){
				unless (-e "labels/${base}_label.mnc"){
					do_cmd("gunzip","labels/${base}_label.mnc.gz");
				}
			}
		}
		my @num_labels = split(/\n/, `ls -1 labels/*.mnc`);
		if (scalar(@num_labels) != 19){ 
			die "STILL not enough labels in ${dir} \n";
		}
		print "Now we have just enough labels :) \n";
	} elsif (scalar(@num_labels) == 19){
		print "Just enough labels :) \n";
	}
	my @reg_labels = split(/\n/, `ls -1 labels/*.mnc`);
	push(@reg_labels,$template);
	#my $template_base = &basename(${template},".mnc");
	foreach my $label (@labels){
		foreach my $input (@reg_labels){
# steps will require iteration for each label (8 in total)
# create file with only 1 label data
			if ($input eq ${template}){
				$base = &basename(${input},".mnc");
			} else {
				$base = &basename(${input},"_label.mnc");
			}
			do_cmd("minclookup","-lut_string","${label} 1","-discrete",$input,"single-labels/${base}_label_${label}.mnc","-clobber"); 
		}
		my @individual_labels = split(/\n/, `ls -1 single-labels/*_label_${label}.mnc`);
		#print "The individual files array is: @individual_labels \n";
		# sum all voxels for that label
		do_cmd("minccalc","-expression","A[0]+A[1]+A[2]+A[3]+A[4]+A[5]+A[6]+A[7]+A[8]+A[9]+A[10]+A[11]+A[12]+A[13]+A[14]+A[15]+A[16]+A[17]+A[18]+A[19]",@individual_labels,"sums/label_${label}.mnc","-clobber"); 
		#how many voxels are that label in all 20 images, and in 19, 18, and 17 of the images
		my @cmd = ("mincstats","sums/label_${label}.mnc","-binvalue","20","-quiet","-count");
		print STDERR @cmd, "\n";
		my $value20 = `@cmd`; 
		chomp($value20);
		my @cmd = ("mincstats","sums/label_${label}.mnc","-binvalue","19","-quiet","-count");
		print STDERR @cmd, "\n";
		my $value19 = `@cmd`; 
		chomp($value19);
		my @cmd = ("mincstats","sums/label_${label}.mnc","-binvalue","18","-quiet","-count");
		print STDERR @cmd, "\n";
		my $value18 = `@cmd`;
		chomp($value18);
		my @cmd = ("mincstats","sums/label_${label}.mnc","-binvalue","17","-quiet","-count");
		print STDERR @cmd, "\n";
		my $value17 = `@cmd`;  
		chomp($value17); 
		# get this output and assemble into a csv file
		print FILE "${dir}, ${label}, ${value20}, ${value19}, ${value18}, ${value17}\n";
		# gzip label and other files
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
	}
}
close (FILE);
print "Done :) \n";

# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}