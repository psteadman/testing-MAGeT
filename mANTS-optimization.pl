#! /usr/bin/env perl
# PROGRAM NAME: mANTS-optimization.pl
# Created by: Patrick Steadman 
# January-March 2011
# Purpose: To test a series of options using mincANTS which provide the best segmentation

use strict;
use File::Basename;
use Getopt::Tabular;

# Global Arguments

my $mydir = "/scratch/pstead/mANTS-human-optimization/";
my $template = "/home/pstead/INPUT_NU/nih_chp_00305_t1_nuc.mnc";
my $inputdir = "/home/pstead/INPUT_NU";
my $labeldir = "/home/pstead/GOLD_STANDARDS";
my $descriptor = "opt_settings";
my $iterations = "20x20x20";
my @radiusrange = (3, 1, 5);
my @defsigmarange = (0, 1, 5);
my @gradientsigmarange = (0, 1, 5);
my @steprange = (0.25, 0.25, 0.5);
my @radius; my @step; my @gradientsigma; my @defsigma;
my $walltime = "14:00:00";
my $scinet = 0; my $sge = 0;
my ($help, $Usage, $progname);

$progname     = &basename($0);
$Usage  = "$progname [options] \n";

$help =
"| $progname registers images using mincANTS to the given template and the resamples the images \n".
"| and corresponding labels after using the determined transformations. \n\n".
"| BE CAREFUL AS THERE IS CURRENTLY VERY LITTLE ERROR CHECKING IN THIS PROGRAM. \n";

&Getopt::Tabular::SetHelp($help, $Usage);

my @argTbl =
	(
		["Input Options","section"],
		["-outputdir","string", 1, \$mydir, "Output directory"],
		["-template","string", 1, \$template, "Template, image all other images are registered to"],
		["-inputdir","string", 1, \$inputdir, "Directory where input files are stored"],
		["-labeldir","string",1, \$labeldir, "Directory where labels are stored"],
		["-descriptor","string",1, \$descriptor, "Discriptor of registration"],
		["-scinet","boolean", 0, \$scinet, "Run registration on scinet submission format"],
		["-sge","boolean", 0, \$sge, "Run registration on sge submission format"],
 		["mincANTS Options","section"],
 		["-step","float", 3, \@steprange, "Step size option for mincANTS; format: min step max"],
 		["-rad","float", 3, \@radiusrange, "Radius option for PR in mincANTS; format: min step max"],
 		["-grad","float", 3, \@gradientsigmarange, "Gradient sigma option for mincANTS; format: min step max"],
 		["-def","float", 3, \@defsigmarange, "Deformation sigma option for mincANTS; format: min step max"],
 		["-iter","string",1, \$iterations, "Iterations for registration"],
 		["-w","string",1, \$walltime, "Wall time for each registration"]
	);

&GetOptions(\@argTbl, \@ARGV) or exit 1;

if($sge){
	#do_cmd("export","SGE_BATCH_OPTIONS='OS=hardy'");
	}

##### Get My Test Values
@step = do_settings(@steprange);
@radius = do_settings(@radiusrange);
@gradientsigma = do_settings(@gradientsigmarange);
@defsigma = do_settings(@defsigmarange);

##### Take Inputs and split into 8s and send each set of 8 to grid as a shell script ####
my @input = split(/\n/, `ls -1 ${inputdir}`);
mkdir($mydir); chdir($mydir);
if($scinet){
	mkdir("${mydir}/CALLS");
	}
# Count and set help with splitting and tracking
my @count = (0,0);
my $set = 0;
open (FILE, '>', "${mydir}/CALLS/${descriptor}_${set}.sh");
print FILE "#! /bin/bash \n \n";
print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-optimization.pl \n\n";
close (FILE);
foreach my $step (@step){
	foreach my $rad (@radius){
		foreach my $grad (@gradientsigma){
			foreach my $def (@defsigma){
				# Make directory for settings
				mkdir("${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}");
				print "${mydir}/${descriptor}-${step}-${rad}-${grad}-${def} \n";
				mkdir("${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}/labels");
				mkdir("${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}/transformations");
				mkdir("${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}/resampled-files");
				foreach my $in (@input){
				my $tempbase = &basename(${template});
					if ($in ne $tempbase){
						my $base = &basename(${in},".mnc");
						my $exist = "${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}/labels/${base}_label.mnc";
						my $exist2 = "${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}/labels/${base}_label.mnc.gz";
						unless (-e $exist || -e $exist2){
							++$count[0]; ++$count[1];
							if($sge){
								chdir("${mydir}/${descriptor}-${step}-${rad}-${grad}-${def}");
								my @tmp = ("perl",
								"/home/psteadman/Dropbox/Shared-Patrick/bin/perl/mANTS_call.pl",
								"-infile","${in}",
								"-template","${template}","-rad","${rad}",
								"-grad","${grad}","-def","${def}","-step","${step}",
								"-labeldir","${labeldir}","-indir","${inputdir}","-iter","${iterations}");
								my $single = $count[0];
								do_cmd("sge_batch","-J","${step}-${rad}-${grad}-${def}-${single}",@tmp);
								if($count[0] == (scalar(@input) - 1)){ 
									$count[0] = 0;
								}
							}
							if($scinet){
								open (FILE,'>>',"${mydir}/CALLS/${descriptor}_${set}.sh");
								my @tmp = ("(cd",
								"${mydir}/${descriptor}-${step}-${rad}-${grad}-${def};","perl",
								"/home/pstead/bin/mANTS_call.pl",
								"-infile","${in}",
								"-template","${template}","-rad","${rad}",
								"-grad","${grad}","-def","${def}","-step","${step}",
								"-labeldir","${labeldir}","-indir","${inputdir}","-iter","${iterations})","&");
								print FILE "@tmp \n";
								close (FILE);
							}
							# 8 processes per node on SciNET
							if ($count[0] == 8 && $scinet){
								open (FILE,'>>',"${mydir}/CALLS/${descriptor}_${set}.sh");
								print FILE "wait \n";
								close (FILE);
							   do_cmd("qsub","${mydir}/CALLS/${descriptor}_${set}.sh",
								   "-l","nodes=1:ppn=8,walltime=${walltime}");
								$count[0] = 0;
								++$set;
								open (FILE,'>',"${mydir}/CALLS/${descriptor}_${set}.sh");
								print FILE "#! /bin/bash \n";
								print FILE "# Created by Patrick Steadman and /home/pstead/bin/mANTS-optimization.pl \n\n";
							}
							if ($count[1] >= 1500){ # if 1500 jobs submitted wait 5 hours before submitting more
								$count[1] = 0;
								sleep(18000); # sleep for 5 hours
							}
						}
					}
				}
			}
		}
	}
}
if($scinet){
	open (FILE,'>>',"${mydir}/CALLS/${descriptor}_${set}.sh");
	print FILE "wait \n";
	close (FILE);
	do_cmd("qsub","${mydir}/CALLS/${descriptor}_${set}.sh",
			"-l","nodes=1:ppn=8,walltime=${walltime}");
}


# Subroutines
sub do_cmd {
    print STDERR "@_ \n";
	system(@_) == 0 or die "Dude must quit";
}
sub do_settings {
	my @tmp; my $i = @_[0]; my $inc = @_[1]; my $max = @_[2];
	if ($inc == 0){ die "A mincANTS setting's step size is 0, creates infinite loop. Must quit!"}
	while ($i <= $max) { push(@tmp, $i); $i = $i + $inc; }
	return @tmp;
}