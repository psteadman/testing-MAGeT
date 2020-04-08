#! /usr/bin/env perl
# PROGRAM NAME: mANTS-optimization.pl
# Created by: Patrick Steadman 
# January 2011
# Purpose: To test a series of options using mincANTS which provide the best segmentation

use strict;
use File::Basename;
use Getopt::Tabular;


# My directories
my @directories;
my $file = "/home/pstead/Settings.csv";
my $inputdir = "/home/pstead/INPUT_NU";
my $template = "/home/pstead/INPUT_NU/nih_chp_00305_t1_nuc.mnc";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $mydir = "/scratch/pstead/mANTS-human-optimization/";
my $csv = 0;
my $scinet = 0; my $sge = 0;
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] \n";

$help =
"| $progname for each directory given with -file this program resamples the files in the subdirectory labels/ \n".
"| and resampled-files/ using the transformations in transformations/ \n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-indir","string", 1, \$inputdir, "Input MINC files directory"],
		["-mydir","string", 1, \$mydir, "Directory containing all directories which need to be resampled"],
		["-template","string", 1, \$template, "Template, MINC files registered with"],
		["-labeldir","string", 1, \$labeldir, "Directory where labels are stored"],
		["-scinet","boolean", 0, \$scinet, "Run registration on scinet submission format"],
		["-sge","boolean", 0, \$sge, "Run registration on sge submission format"],
		["-csv","boolean",0, \$csv, "Boolean option for csv file"],
		["-file","string",1, \$file, "CSV of directories containing mincfiles that need to be resampled"]
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;
if($csv==0){
	@directories = @ARGV;
	$mydir = "";
	}
if($csv){
	open(F, $file) || die ("dude can't open csv");	
	while (my $line = <F>)
	{
			(my $field1, my $setting) = split ',', $line;
			chomp($setting);
			print $setting, "\n";
			push(@directories,$setting);
		}
	}
my @input = split(/\n/, `ls -1 ${inputdir}`);
# Change to directory for output files
if($csv){
	mkdir($mydir);
	chdir($mydir);
	}
my @count = ("0","0");
my $set = 0;
if($scinet){
	mkdir("${mydir}/CALLS");
	open (FILE, '>', "${mydir}/CALLS/resampledir_${set}.sh");
	print FILE "#! /bin/bash \n \n";
	print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS_resampledir.pl \n\n";
	close (FILE);
}
foreach my $dir (@directories){
				foreach my $in (@input){
				my $tempbase = &basename(${template});
					if ($in ne $tempbase){
						my $base = &basename(${in},".mnc");
						if($scinet){
							open (FILE,'>>',"${mydir}/CALLS/resampledir_${set}.sh");
							++$count[0]; ++$count[1];
							my @tmp = ("(cd",
							"${mydir}/${dir};","perl",
							"/home/pstead/bin/mANTS-resampledir_call.pl",
							"-infile","${inputdir}/${in}",
							"-template","${template}",
							"-labeldir","${labeldir}",
							"-dir","${mydir}/${dir}",")","&");
							print FILE "@tmp \n";
							close (FILE);
							}
						if($sge){
							chdir("${mydir}/${dir}");
							my @tmp = ("perl",
							"/home/psteadman/Dropbox/Shared-Patrick/bin/perl/mANTS-resampledir_call.pl",
							"-infile","${inputdir}/${in}",
							"-template","${template}",
							"-labeldir","${labeldir}",
							"-dir", "${mydir}/${dir}");
							my $single = ${count}[0];
							do_cmd("sge_batch","-J","count_${single}",@tmp);
							++$count[0];
							if($count[0] == (scalar(@input) - 1)){ 
								$count[0] = 0;
								}
							}
						if($scinet){
							# 8 processes per node on SciNET
							if ($count[0] == 8){
								open (FILE,'>>',"${mydir}/CALLS/resampledir_${set}.sh");
								print FILE "wait \n";
								close (FILE);
								do_cmd("qsub","${mydir}/CALLS/resampledir_${set}.sh",
									"-l","nodes=1:ppn=8,walltime=2:00:00");
								$count[0] = 0;
								++$set;
								open (FILE,'>',"${mydir}/CALLS/resampledir_${set}.sh");
								print FILE "#! /bin/bash \n";
								print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS_resampledir.pl \n\n";
								}
							if ($count[1] >= 3000){ 
								$count[1] = 0;
								sleep(7200); # sleep for 2 hours
								}
							}
						}
					}
				}
if($scinet){
	open (FILE,'>>',"${mydir}/CALLS/resampledir_${set}.sh");
	print FILE "wait \n";
	close (FILE);
	do_cmd("qsub","${mydir}/CALLS/resampledir_${set}.sh",
			"-l","nodes=1:ppn=8,walltime=2:00:00");
	}
# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}