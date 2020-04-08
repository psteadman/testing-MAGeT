#! /usr/bin/env perl
# Created by: Patrick Steadman 
# January 2011
# Purpose: To determine the voxel counts for labels created through mANTS-optimization.pl scripts


####### TO DO  ########
# 1. DONE Make everything full paths and check other two scripts for full paths
# 2. Run one by hand to make sure all commands work; on my own computer perhaps
# 3. Remember all Display commands
# 4. Instead of long string on minccalc call maybe create for loop which builds the string
# 5. Add label calculation for template too!

use strict;
use File::Basename;

# Global Variables
my $mydir = "/projects/souris/psteadman/multitemplate_segmentation";
my @directories = split(/\n/, `ls -1d /projects/souris/psteadman/multitemplate_segmentation/opt*`);
my $template = "/projects/souris/mallar/nih_validation/GOLD_STANDARDS/nih_chp_00305_t1_nuc.mnc";

# Begin!
chdir($mydir);
my $dirnum = scalar(@directories);
print "@directories \n";
#print "There are ${dirnum}*8 directories to analyze \n";
my $base = &basename($template,".mnc");
# do_cmd("mincresample",
# 				$template,"template_label/${base}.mnc","-like","/projects/souris/mallar/nih_validation/INPUT/nih_chp_00305_t1_nuc.mnc",
# 				"-keep_real_range","-nearest_neighbour",-"clobber");
mkdir("analysis");
open (FILE, '>', "${mydir}/stats.sh");
print FILE "#! /bin/bash \n \n";
print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-stats.pl \n\n";
for my $i (1..1){
	my $max = $dirnum * $i; print "Max ${max} \n";
	my $min = $dirnum * ($i - 1); print "Min ${min} \n";
	my @tmp = (${min}..${max}); print @tmp, "\n";
	my @stat_dir = @directories[@tmp]; print @stat_dir, "\n";
	my @tmp = ("(cd","${mydir};","perl",
				"/home/psteadman/Dropbox/Shared-Patrick/bin/perl/mANTS-testingstats_call.pl",
				"-set","${i}","@{stat_dir})","&");
	print FILE "@tmp \n";
	}
print FILE "wait\n";
close (FILE);
do_cmd("bash","${mydir}/stats.sh");

# now join 8 csv together

# Subroutines
sub do_cmd {
   	print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}