#! /usr/bin/env perl
# Created by: Patrick Steadman 
# January 2011
# Purpose: To determine the voxel counts for labels created through mANTS-optimization.pl scripts

use strict;
use File::Basename;
use Getopt::Tabular;

# Global Variables
my $mydir = "/scratch/pstead/mANTS-human-optimization/";
my $template = "/scratch/pstead/mANTS-human-optimization/template_label/nih_chp_00305_t1_nuc.mnc";
my $inputdir = "/home/pstead/INPUT_NU";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $descriptor = "opt_settings";
my $walltime = "24:00:00";
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] \n";

$help =
"| $progname for each label determines the overlap amongst all the files \n".
"| within one directory matching /[dir]/[descriptor]* where [ ] represents an option. \n\n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-dir","string", 1, \$mydir, "Output directory and path with all directories to perform stats on"],
		["-template","string", 1, \$template, "Template (label version), image all other images were registered to"],
		["-inputdir","string", 1, \$inputdir, "Directory where input files are stored"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
		["-descriptor","string", 1, \$descriptor, "Discriptor of registration"],
 		["-w","string", 1, \$walltime, "Wall time for each registration"]
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;
### Directory list which stats will be run on
my @directories = split(/\n/, `ls -1d ${mydir}/${descriptor}-*`);
####### Begin!
chdir($mydir); mkdir("analysis");
my $dirnum = scalar(@directories) / 24;
print "There are ${dirnum}*24 directories to analyze \n";
#my $base = &basename($labeltemplate,".mnc");
#mkdir("template_label");
#do_cmd("mincresample", $labeltemplate,"template_label/${base}.mnc","-like",
#		"$template","-keep_real_range","-nearest_neighbour",-"clobber");
open (FILE, '>', "${mydir}/CALLS/stats1.sh");
print FILE "#! /bin/bash \n\n";
print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-stats.pl \n\n";
for my $i (1..8){ my $f = $i;
	my $max = $dirnum * $f; print "Max ${max} \n";
	my $min = $dirnum * ($f - 1); print "Min ${min} \n";
	my @tmpr = (${min}..${max}); print @tmpr, "\n";
	my @stat_dir = @directories[@tmpr]; print @stat_dir, "\n";
	my @tmp = ("(cd","${mydir};","perl",
				"/home/pstead/bin/mANTS_statscall.pl",
				"-set","${i}","@{stat_dir}","-dir","${mydir}",
				"-template","${template})","&");
	print FILE "@tmp \n";
	}

print FILE "wait \n";
close (FILE);
print "Done stats 1 \n";

do_cmd("qsub","${mydir}/CALLS/stats1.sh",
		"-l","nodes=1:ppn=8,walltime=${walltime}");
		
open (FILE, '>', "${mydir}/CALLS/stats2.sh");
print FILE "#! /bin/bash \n\n";
print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-stats.pl \n\n";
for my $i (9..16){ my $f = $i;
	my $max = $dirnum * $f; print "Max ${max} \n";
	my $min = $dirnum * ($f - 1); print "Min ${min} \n";
	my @tmpr = (${min}..${max}); print @tmpr, "\n";
	my @stat_dir = @directories[@tmpr]; print @stat_dir, "\n";
	my @tmp = ("(cd","${mydir};","perl",
				"/home/pstead/bin/mANTS_statscall.pl",
				"-set","${i}","@{stat_dir}","-dir","${mydir}",
				"-template","${template})","&");
	print FILE "@tmp \n";
	}

print FILE "wait \n";
close (FILE);
print "Done stats 2 \n";
do_cmd("qsub","${mydir}/CALLS/stats2.sh",
		"-l","nodes=1:ppn=8,walltime=${walltime}");
		
				
open (FILE, '>', "${mydir}/CALLS/stats3.sh");
print FILE "#! /bin/bash \n\n";
print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-stats.pl \n\n";
for my $i (17..24){ my $f = $i;
	my $max = $dirnum * $f; print "Max ${max} \n";
	my $min = $dirnum * ($f - 1); print "Min ${min} \n";
	my @tmpr = (${min}..${max}); print @tmpr, "\n";
	my @stat_dir = @directories[@tmpr]; print @stat_dir, "\n";
	my @tmp = ("(cd","${mydir};","perl",
				"/home/pstead/bin/mANTS_statscall.pl",
				"-set","${i}","@{stat_dir}","-dir","${mydir}",
				"-template","${template})","&");
	print FILE "@tmp \n";
	}

print FILE "wait \n";
close (FILE);
print "Done stats 2 \n";
do_cmd("qsub","${mydir}/CALLS/stats3.sh",
		"-l","nodes=1:ppn=8,walltime=${walltime}");

# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}