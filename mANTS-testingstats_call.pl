#! /usr/bin/env perl
# Created by: Patrick Steadman 
# January 2011

# Called by mANTS-stats.pl

use strict;
use Getopt::Tabular;
use File::Basename;

# Global Arguments
my @labels = (1..8);
my $set = '';
my $template = "/projects/souris/psteadman/multitemplate_segmentation/template_label/nih_chp_00305_t1_nuc.mnc";
my $base = '';

my @argTbl =
	(
		["-set","string", 1, \$set, "The set number this is for stats (max 8)"],
	);

&GetOptions(\@argTbl, \@ARGV);

my @directories = @ARGV; print @directories, "\n";
open (FILE, '>', "/projects/souris/psteadman/multitemplate_segmentation/analysis/stats_${set}.csv");
print FILE "Settings, Label, Voxel Count\n";
foreach my $dir (@directories){
	chdir($dir);
	mkdir("sums");
	mkdir("single-labels");
# first check if there are 19 labels and if not then gunzip to get 19
# remove the rest of the .gz files
	my @reg_labels = split(/\n/, `ls -1 labels/*.mnc`);
	push(@reg_labels,"$template");
	#print "@reg_labels \n";
	foreach my $label (@labels){
		foreach my $input (@reg_labels){
	#steps will require iteration for each label (8 in total)
	#create file with only 1 label data
			print "$input \n";
			if ($input eq $template){
				$base = &basename(${input},".mnc");
			} else {
				$base = &basename(${input},"_label.mnc");
			}
			print "$base \n";
			do_cmd("minclookup","-lut_string","${label} 1","-discrete","${input}","single-labels/${base}_label_${label}.mnc","-clobber"); 
		}
	my @individual_labels = split(/\n/, `ls -1 single-labels/*_label_${label}.mnc`);
	# sum all voxels for that label
	do_cmd("minccalc","-expression","A[0]+A[1]+A[2]+A[3]+A[4]+A[5]+A[6]+A[7]+A[8]+A[9]+A[10]+A[11]+A[12]+A[13]+A[14]+A[15]+A[16]+A[17]+A[18]+A[19]",@individual_labels,"sums/label_${label}.mnc","-clobber"); 
	#how many voxels are that label in all 20 images
	my @cmd = ("mincstats","sums/label_${label}.mnc","-binvalue","20","-quiet","-count");
	print STDERR @cmd, "\n";
	my $value20 = `@cmd`; 
	print $value20;
	chomp($value20);
	print "Value 20 is : ${value20} \n";
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
	# gzip label and other files?
	# gzip label files?
	}
}
close (FILE);

# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}