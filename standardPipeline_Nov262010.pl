#! /usr/bin/env perl
###########
# CHANGE LOG
#
#
# MALLAR - NOVEMBER 16,2010
# 1) Added mincANTS as an option
# 2) All prior are transformed back to native space before classification.
# 3) inormalize added to preprocessing
# 4) Exposed BET OPTIONS
# 5) choice of lin registration added
# 6) Volume extraction added
# 7) QC module added


use strict;

use MNI::Startup;
use Getopt::Tabular;
use File::Basename;
use File::Temp qw/ tempdir /;

##############
# Global Args
##############

my $modelDir          = "/home/tpaus/MODELS";
my $model             = "icbm_avg_152_t1_tal_nlin_symmetric_VI";
my $brainMask         = "/home/tpaus/MODELS/icbm_mask.mnc";
my $tagFileDir        = "/home/tpaus/opt/minc/data/CLASSIFY";
my $tagFile           = "ntags_1000_prob_90_nobg.tag";
my $atlasModel        = "/home/tpaus/MODELS/icbm152_lobes/atlas_labels_nomiddle.mnc";
my $subCorticalSeg    = 0;
my $colinDir          = "/home/tpaus/MODELS";
my $colinSubcortModel = "colin_bg_generous_0.3mm.mnc";
my $colinGlobal       = "colin27_t1_tal_lin";
my $subCorticalLabelsLeft  = "/home/tpaus/MODELS/mask_left_oncolinnl_7.mnc";
my $subCorticalLabelsRight = "/home/tpaus/MODELS/mask_right_oncolinnl_7.mnc";
my $bet_f                 = 0.5;
my $bet_g		          = 0;
my $mincANTS              = 0;
my $mni_autoreg           = 0;
my $mritotal              = 0;
my $bestlinreg            = 0; 
my $subCorticalMincAnts   = 0;
my $subCorticalMNIAutoreg = 0;
my $subCorticalMritotal   = 0;
my $subcorticalBestLinReg = 0;
my ($help, $Usage, $me);

##############
# Define usage and help stuff
##############

$me     = &basename($0);
$Usage  = "$me [options] <inputMRI> <outputDir> \n";

$help =
"| $me will take a single MRI volume, perform classification and basic lobe segmentation.\n ".
"| Both linear and nonlinear transformations will be output by the script in the specified\n ".
"| output directory.\n\n".
"| Note that for the time being subcortical segmentation will be performed with minctools\n\n";



#############
# Make TempDir
#############

my $tmpdir = &tempdir("$me-XXXXXXXXXXX", TMPDIR => 1, CLEANUP => 1);

##############
#Set up options
##############

&Getopt::Tabular::SetHelp($help, $Usage);


my @argTbl = 
	(
		["Many Options", "section"],
		["Model Options", "section"],
		["-modeldir", "string", 1, \$modelDir,
		"set the directory to search for model files."],
		["-model", "string", 1, \$model,
		"set the basename of the fit model files."],
		["-colindir", "string", 1, \$colinDir,
		"set directory to search for colin27 models required for subcortical segmentation"],
		["-colin_global", "string", 1, \$colinGlobal,
		"set filename for global colin27 model required for subcortical segmentation"],
		["-colin_subcortical", "string", 1, \$colinSubcortModel,
		"set filename for subcortical colin27 model required for subcortical segmentation"],
		["Classification Options", "section"],
		["-tagfiledir", "string", 1, \$tagFileDir,
		"set the directory for the tagfile."],
		["-tagfile", "string", 1, \$tagFile,
		"set the tagfile name for classification priors."],
		["Flag for subcortical segmentation", "section"],
		["-subcortical", "boolean", 0, \$subCorticalSeg,
		"do a subcortical segmentation."],
		["Set files for models", "section"],
		["-brainmask", "string", 1, \$brainMask,
		"set the brain mask name for estimating brain volume."],
		["-sub_cortical_labels_left", "string", \$subCorticalLabelsLeft,
		"set filename for left subcortical labels required for subcortical segmentation"],
		["-sub_cortical_labels_right", "string", \$subCorticalLabelsRight,
		"set filename for right subcortical labels required for subcortical segmentation"],
		["BET options", "section"],
		["-bet_f", "float", 1, \$bet_f,
		"BET fractional intesity threshold (0->1); smaller values give larger brain outline"],
		["-bet_g", "float", 1, \$bet_g,
		"BET vertical gradient in fractional intensity threshold (-1->1); positive values give larger brain outline at bottom and smaller at top"],	
		["nonlinear registration options", "section"],
		["-mincANTS", "boolean", 0, \$mincANTS,
		"use mincANTS symmetric nonlinear registration with greedy optimization for global nonlinear registration"],
		["-mni_autoreg", "boolean", 0, \$mni_autoreg,
		"use mni_autoreg software to do nonlinear registration"],
		["linear registration option if mni_autoreg is selected", "section",],
		["-mritotal", "boolean", 0, \$mritotal,
		"use mritotal for lsq9 linear registration - can only be used in -mni_autoreg mode"],
		["-bestlinreg", "boolean", 0, \$bestlinreg,
		"use bestlinreg for lsq9 linear registration - can only be used in -mni_autoreg mode"],
		["subcortical registration options", "section",],
		["-subcortical_mincANTS", "boolean", 0, \$subCorticalMincAnts,
		"use mincANTS for subcortical registration to colin27"],
		["-subcortical_mni_autoreg", "boolean", 0, \$subCorticalMNIAutoreg,
		"use mni_autoreg tool for subcortical registration to colin27"],
		["-subcortical_mritotal",  "boolean", 0, \$subCorticalMritotal,
		"use mritotal for initial linear registration to colin27 - can only be used in -sub_cortical_mni_autoreg mode"],
		["-subcortical_bestlinreg",  "boolean", 0, \$subcorticalBestLinReg,
		"use bestlinreg for initial linear registration to colin27 - can only be used in -sub_cortical_mni_autoreg mode"],	
			);



&GetOptions(\@argTbl, \@ARGV);

my $modelFull        = $modelDir."/".$model.".mnc";
my $modelMask        = $modelDir."/".$model."_mask.mnc";
##############
# Set up I/O
##############

my $inputMRI  = shift(@ARGV) or die "Need an input file!\n\n$Usage\n";
my $outputDir = shift(@ARGV) or die "Need an output direcory!\n\n$Usage\n";

if($mincANTS && $mni_autoreg){print "\nCannot use both -mincAnts and -mni_autoreg options\n"; die;}
if(!($mincANTS || $mni_autoreg)){print "\nMust choose one of -mincAnts and -mni_autoreg options\n"; die;}

if($mni_autoreg){
	if($mritotal && $bestlinreg){print "\n Cannot use both -bestlinreg and -mritotal options\n"; die;}
	if(!($mritotal || $bestlinreg)){ print "\n Must choose one of -bestlinreg and -mritotal options \n"; die;}
	}
	
if($subCorticalSeg){
	if($subCorticalMincAnts && $subCorticalMNIAutoreg){ "\nCannot use both -sub_cortical_mincANTS and -sub_cortical_mni_autoreg options\n"; die;}
	if(!($subCorticalMincAnts || $subCorticalMNIAutoreg)){print "\nMust choose one of -subcortical_mincAnts and -subcortical_mni_autoreg options\n"; die;}
	
	if($subCorticalMNIAutoreg){
		if($subCorticalMritotal && $subcorticalBestLinReg){print "\n Cannot use both -subcortical_bestlinreg and -subcortical_mritotal options\n"; die;}
		if(!($subCorticalMritotal || $subcorticalBestLinReg)){ print "\n Must choose one of -subcortical_bestlinreg and -subcortical_mritotal options \n"; die;}
		}
	}

 		
if(!(-e $inputMRI)){print "\n$inputMRI does not exist. \n $Usage \n"; die;}
if(!(-e $outputDir)){print "\n$outputDir does not exist. \n $Usage \n"; die;}
###############################
#Configure various output files
##############
###Config Dirs first

my $nucDir        = "$outputDir"."/NUC";
my $xfmDir        = "$outputDir"."/XFMS";
my $betDir        = "$outputDir"."/BET";
my $classifyDir   = "$outputDir"."/classify";
my $segmentDir    = "$outputDir"."/segment";
my $transformDir  = "$outputDir"."/transformed";
my $origDir       = "$outputDir"."/orig";
my $normalizedDir = "$outputDir"."/NORM";


my @newDirs = ($nucDir, $xfmDir, $betDir,
				$classifyDir, $segmentDir,
				$transformDir, $origDir, $normalizedDir);

foreach(@newDirs){
	do_cmd("mkdir -p $_");
}

do_cmd("cp", $inputMRI, $origDir."/");


my @inputBase = split(/\./, &basename($inputMRI,"mnc"));


my $nucOut         = "$nucDir/".$inputBase[0]."_nuc.mnc";
my $normalizedOut  = "$normalizedDir/".$inputBase[0]."_normalized.mnc";
my $linXFM         = "$xfmDir/".$inputBase[0]."_lin.xfm";
my $linXFMInverse  = "$xfmDir/".$inputBase[0]."_lin_inverse.xfm";
my $bet            = "$betDir/".$inputBase[0]."_bet.mnc";
my $betMask        = "$betDir/".$inputBase[0]."_mask.mnc";
my $betMaskLin     = "$betDir/".$inputBase[0]."_lin_mask.mnc";
my $nlXFM          = "$xfmDir/".$inputBase[0]."_nl.xfm";
my $nlXFMInverse   = "$xfmDir/".$inputBase[0]."_nl_inverse.xfm";
my $linResample    = "$transformDir/".$inputBase[0]."_res_lin.mnc";
my $nlResample     = "$transformDir/".$inputBase[0]."_res_nl.mnc";
my $customTags     = "$classifyDir/".$inputBase[0]."_custom_priors.tag";
my $customTagsBase = $inputBase[0]."_custom_priors.tag";
my $classify	   = "$classifyDir/".$inputBase[0]."_classify.mnc";
my $classifyNative = "$classifyDir/".$inputBase[0]."_tal_classify.mnc";
my $segment        = "$segmentDir/".$inputBase[0]."_segment.mnc";
my $segmentNative  = "$segmentDir/".$inputBase[0]."_tal_segment.mnc";
my $headMask       = "$segmentDir/".$inputBase[0]."_headmask.mnc";

#Just in case;
my $subCorticalSegLeft; 
my $subCorticalSegRight;

my @newFiles = ($nucOut, $linXFM, $bet, $betMask, $betMaskLin, $nlXFM, $linResample, $nlResample,
	$classify, $classifyNative, $segment, $segmentNative, $headMask);

foreach(@newFiles){
	if(-e $_){print "\n\n$_ EXISTS!\n"; die;}
}


print "\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++ \n".
"Output files are the following: \n".
"nu_correct            ===> $nucOut \n".
"inormalize            ===> $normalizedOut \n".
"linear xfm            ===> $linXFM \n".
"brain extracted       ===> $bet \n".
"nonlinear xfm         ===> $nlXFM \n".
"transformed linear    ===> $linResample \n".
"transformed nonlinear ===> $nlResample \n".
"classified data       ===> $classify \n".
"classified native data===> $classifyNative \n".
"segmented data        ===> $segment \n".
"segmented native data ===> $segmentNative \n".
"head mask             ===> $headMask \n".
"++++++++++++++++++++++++++++++++++++++++++++++++++++ \n\n";

my $niiTmp      = "$tmpdir/$inputBase[0].nii";
my $betTmpOut   = "$tmpdir/$inputBase[0]_out";
my $mncMask     = "$tmpdir/$inputBase[0]"."_out_mask.mnc";
my $niiMask     = "$tmpdir/$inputBase[0]"."_out_mask.nii";
my $niiMask_gz  = "$tmpdir/$inputBase[0]"."_out_mask.nii.gz";
my $classifyTmp = "$tmpdir/$inputBase[0]"."_classtmp.mnc";


##############
# Do pipeline
###############



do_cmd("nu_correct", $inputMRI, $nucOut);
do_cmd("inormalize",
	"-const2", "0", "5000", "-range", "1",
	$nucOut, $normalizedOut);
	

# Do Bet

do_cmd("mnc2nii", $normalizedOut, $niiTmp);
do_cmd("bet2", $niiTmp, $betTmpOut, "-mv", "-f", $bet_f, "-g", $bet_g);
do_cmd("gunzip", $niiMask_gz);
do_cmd("nii2mnc", $niiMask, $mncMask);
do_cmd("mincresample", "-near", "-like", $nucOut, $mncMask, $betMask);
do_cmd("mincmath", "-byte", "-mult", $betMask, $nucOut, $bet);

# Do reg 

if($mincANTS){

#	do_cmd("mincANTS", 
#		"3", "-m", "MI[${bet},${modelFull},1,32]",
#		"-o", $linXFM, "-i", "0",
#		"--use-Histogram-Matching",
#		"--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
#		"--MI-option", "32x16000",
#		"--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4");
	
#	do_cmd("mincresample",
#		"-transformation", $linXFM,
#		"-like", $modelFull, 
#		"-sinc", "-width", "2",
#		$bet, $linResample);
					
	do_cmd("mincANTS", 
		#"3", "-m", "CC[${normalizedOut},${modelFull},1,4]",
		"3", "-m", "PR[${normalizedOut},${modelFull},1,4]",
		"--use-Histogram-Matching",
		"--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
		"--MI-option", "32x16000",
		"--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4",
		#"-r","Gauss[1,0]", "-t", "SyN[0.25]",
		"-r","Gauss[3,0]", "-t", "SyN[0.5]",
		"-o", $nlXFM, "-i", "20x20x20");
			
	do_cmd("mincresample",
		"-transformation", $nlXFM,
		"-like", $modelFull,
		"-sinc", "-width",  "2",
		$bet, $nlResample);
			
	do_cmd("mincresample",
		"-invert",
		"-transformation", $nlXFM,
		"-like", $bet,
		"-near",
		$brainMask, $headMask);
			
	
}

elsif($mni_autoreg){

	if($mritotal){
		do_cmd("mritotal", 
			$bet, 
			"-model", $model, "-modeldir", $modelDir, 
			$linXFM);
		}
		
	elsif($bestlinreg){
		do_cmd("bestlinreg", 
			"-lsq9", 
			$bet, $modelFull, $linXFM);
		}
		
	do_cmd("xfminvert", $linXFM, $linXFMInverse);
		
	do_cmd("nlfit_smr", 
		$bet, 
		"-model", $model, "-modeldir", 
		$modelDir."/", $linXFM, $nlXFM); 

	do_cmd("xfminvert", $nlXFM, $nlXFMInverse);


	do_cmd("mincresample",
				"-transformation", $linXFM,
				"-like", $modelFull, 
				"-sinc", "-width", "2",
				$bet, $linResample);
				
	do_cmd("mincresample",
			"-transformation", $nlXFM,
			"-like", $modelFull,
			"-sinc", "-width",  "2",
			$bet, $nlResample);
			
	do_cmd("mincresample",
		"-invert",
		"-transformation", $nlXFM,
		"-like", $bet,
		"-near",
		$brainMask, $headMask);
		
	 }
			
###########
#Start classification
###########

do_cmd("transformtags",
	"${tagFileDir}/${tagFile}", 
	"-transformation", $nlXFMInverse, $customTags);
	
do_cmd("classify",
	"-tagfile", $customTags,
	$bet, $classifyTmp);
	
do_cmd("minclookup",
	"-discrete", 
	"-lut_string", "2 1\; 3 2",
	$classifyTmp, $classify);
	
do_lobe_segment($tmpdir, $classify, $nlXFM, $segment);

if($subCorticalSeg){


	print "Initializing subcortical segmentation part of the program .... \n\n";
	
	my $subCorticalSegDir = $outputDir."/subcortical";
	my $subCorticalXFMSDir = $outputDir."/subcortical_XFMS";
	do_cmd("mkdir -p $subCorticalSegDir");
	do_cmd("mkdir -p $subCorticalXFMSDir");
	
	my $linXFMColin        = $subCorticalXFMSDir."/".$inputBase[0]."_lin_colin.xfm";
	my $nlXFMColin         = $subCorticalXFMSDir."/".$inputBase[0]."_nl_colin.xfm";
	my $linResampleColin   = $transformDir."/".$inputBase[0]."_res_lin_colin.mnc";
	my $nlResampleColin    = $transformDir."/".$inputBase[0]."_res_nl_colin.mnc";
	

	$subCorticalSegLeft  = $subCorticalSegDir."/".$inputBase[0]."_subcortical_seg_left.mnc";
	$subCorticalSegRight = $subCorticalSegDir."/".$inputBase[0]."_subcortical_seg_right.mnc";
	
	print "\n\n++++++++++++++++++++++++++++++++++++++++++++++++++++ \n".
	"Output files are the following: \n".
	"linear xfm to colin				===> $linXFMColin \n".
	"nonlinear xfm to colin				===> $nlXFMColin \n".
	"transformed linear					===> $linResampleColin \n".
	"transformed nonlinear				===> $nlResampleColin \n".
	"subcortical segmented data         ===> $subCorticalSegLeft\t $subCorticalSegRight \n".
	"++++++++++++++++++++++++++++++++++++++++++++++++++++ \n\n";
	
	my $colinGlobalFull      = "${colinDir}/${colinGlobal}.mnc";
	my $colinSubcorticalFull = "${colinDir}/${colinSubcortModel}";
	
	if($subCorticalMincAnts){

#		do_cmd("mincANTS", 
#			"3", "-m", "MI[${normalizedOut},${colinGlobalFull},1,64]",
#			"-o", $linXFMColin, "-i", "0");
			
		do_cmd("mincANTS", 
				#"3", "-m", "CC[${normalizedOut},${colinGlobalFull},1,4]",
				"3", "-m", "PR[${normalizedOut},${colinGlobalFull},1,4]",
				#"-r","Gauss[1,0]", "-t", "SyN[0.25]",
				"-r","Gauss[3,0]", "-t", "SyN[0.5]",
				"--use-Histogram-Matching",
				"--number-of-affine-iteratons", "10000x10000x10000x10000x10000",
				"--MI-option", "32x16000",
				"--affine-gradient-descent-option", "0.5x0.95x1.e-4x1.e-4",
				"-o", $nlXFMColin, "-i", 
				"20x20x20"); 
				
#		do_cmd("mincresample",
#				"-transformation", $linXFM,
#				"-like", $colinGlobalFull, 
#				"-sinc", "-width", "2",
#				$bet, $linResampleColin);
				
		do_cmd("mincresample",
				"-transformation", $nlXFMColin,
				"-like", $colinGlobalFull,
				"-sinc", "-width",  "2",
				$bet, $nlResampleColin);
		
		do_cmd("mincresample", 
				"-near", "-invert",
				"-transformation", $nlXFMColin,
				"-like", $bet, '-keep_real_range',
				$subCorticalLabelsLeft, $subCorticalSegLeft);
		
		do_cmd("mincresample", 
				"-near", "-invert",
				"-transformation", $nlXFMColin,
				"-like", $bet, '-keep_real_range',
				$subCorticalLabelsRight, $subCorticalSegRight);
					
	}


	if($subCorticalMNIAutoreg){
		if($subCorticalMritotal){
		
			do_cmd("mritotal", 
				$bet, 
				"-model", $colinGlobal, "-modeldir", $colinDir, 
				$linXFMColin);
		}
		
		elsif($subcorticalBestLinReg){
			do_cmd("bestlinreg", 
				$bet, $colinGlobalFull, "-lsq9", $linXFMColin);
			
		}
		
		my @minctraccArgs    = qw(-weight 1 -stiff 1 -simi 0.3 -debug -nonlinear corrcoeff -iter 15);
		
		do_cmd("mincresample",
			"-transformation", $linXFMColin,
			"-sinc", "-width", "2",
			"-like", $colinGlobalFull,
			$bet, $linResampleColin);
			
		do_cmd('minctracc',
			'-step', '4', '4', '4',
			'-sub_lattice', '8',
			'-lattice_diam', '12', '12', '12',
			'-ident',
			@minctraccArgs,
			$linResampleColin, $colinSubcorticalFull, "${tmpdir}/nl0.xfm");
			
		
		do_cmd('minctracc',
			'-step', '2', '2', '2',
			'-sub_lattice', '6',
			'-lattice_diam', '6', '6', '6',
			'-transformation', "${tmpdir}/nl0.xfm",
			@minctraccArgs,
			$linResampleColin, $colinSubcorticalFull, "${tmpdir}/nl1.xfm");
			
		
		do_cmd('minctracc',
			'-step', '1', '1', '1',
			'-sub_lattice', '6',
			'-lattice_diam', '3', '3', '3',
			'-transformation', "${tmpdir}/nl1.xfm",
			@minctraccArgs,
			$linResampleColin, $colinSubcorticalFull, "${tmpdir}/nl2.xfm");
			
		do_cmd('xfmconcat', $linXFMColin, "${tmpdir}/nl2.xfm", $nlXFMColin);
			
			
		do_cmd('mincresample',
			'-transformation', $nlXFMColin,
			'-like', $colinGlobalFull,
			'-sinc', '-width', '2',
			$bet, $nlResampleColin);
			
		do_cmd('mincresample',
			'-transformation', $nlXFMColin,
			'-like', $bet, '-invert', 
			'-near', '-keep_real_range',
			$subCorticalLabelsLeft, $subCorticalSegLeft);
			
		do_cmd('mincresample',
			'-transformation', $nlXFMColin,
			'-like', $bet, '-invert', 
			'-near', '-keep_real_range',
			$subCorticalLabelsRight, $subCorticalSegRight);
		
	}
}

########################
# QC bit
########################

#my $qcCommand = "./qc_individual.pl $outputDir";
#if($subCorticalMincAnts){$qcCommand = $qcCommand." -subcortical";}

#do_cmd($qcCommand);


########################
# Extract volumes
########################

open (OUTPUT_VOL,">${outputDir}/volumes.csv");

print OUTPUT_VOL "Brain,";
print OUTPUT_VOL "frontal_right_grey,frontal_right_white,parietal_right_grey,pariental_right_white,";
print OUTPUT_VOL "temporal_right_grey,temporal_right_white,occipital_right_grey,occipital_right_white,";
print OUTPUT_VOL "cerebellum_right_grey,cerebellum_right_white,";
print OUTPUT_VOL "frontal_left_grey,frontal_left_white,parietal_left_grey,pariental_left_white,";
print OUTPUT_VOL "temporal_left_grey,temporal_left_white,occipital_left_grey,occipital_left_white,";
print OUTPUT_VOL "cerebellum_left_grey,cerebellum_left_white,";

if($subCorticalSeg){
	print OUTPUT_VOL "striatum_right,globus_pallidus_right,thalamus_right,";
	print OUTPUT_VOL "striatum_left,globus_pallidus_left,thalamus_left";
	}
	
print OUTPUT_VOL "\n";
my  $vol;
chomp($vol = `mincstats -mask $headMask $headMask -quiet -mask_binvalue 1 -volume`); 
print OUTPUT_VOL "$vol";
my @brain_labels = (1..20);

foreach(@brain_labels){
	chomp($vol = `mincstats $segment -quiet -mask $segment -mask_binvalue $_ -volume`);
	print OUTPUT_VOL ",$vol";
	}
if($subCorticalSeg){	
	my @subcortical_labels = (1..3);
	my @subs = ($subCorticalSegRight, $subCorticalSegLeft);
	foreach (@subs){
		my $sub = $_;
		foreach(@subcortical_labels){
			chomp($vol = `mincstats $sub -quiet -mask $sub -mask_binvalue $_ -volume`);
			print OUTPUT_VOL ",$vol";
			}
		}
	}
	
print OUTPUT_VOL "\n";
close(OUTPUT_VOL);


#this bit is a rather simplified version of Louis Collins' stxsegment
#1. Extract grid file from the nl xfm
#2. apply to model
#3. Find intersection  ween GM/WM of classified data

sub do_lobe_segment
{
	my ($tmpdir, $classify, $nlXFM, $segment) = @_;
	
	my $atlasRes  = $tmpdir."/"."atlasRes.mnc";
	my $grey      = "${tmpdir}/grey.mnc";
	my $white     = "${tmpdir}/white.mnc";
	my $grey_lobes  = "${tmpdir}/grey_lobes.mnc";
	my $white_lobes = "${tmpdir}/white_lobes.mnc";
	my $grey_clean  = "${tmpdir}/grey_clean.mnc";
	my $white_clean = "${tmpdir}/white_clean.mnc";
		
	do_cmd("mincresample", "-like", $classify, "-invert", 
		"-keep_real_range",
		"-transform", $nlXFM, 
		"-near", $atlasModel, $atlasRes);
	do_cmd("minclookup", "-discrete", "-lut_string", "1 1",
		$classify, $grey);
	do_cmd("minclookup", "-discrete", "-lut_string", "2 1",
		$classify, $white);
		
	do_cmd("minccalc", "-expression", "A[0]*A[1]", $atlasRes, $grey, $grey_lobes);
	do_cmd("minccalc", "-expression", "A[0]*A[1]", $atlasRes, $white, $white_lobes);	
	do_cmd("minclookup", "-discrete",
		"-lut_string", "1 1; 2 3; 3 5; 4 7; 12 9; 5 11; 6 13; 7 15; 8 17; 9 19",
		$grey_lobes, $grey_clean);
	do_cmd("minclookup", "-discrete",
		"-lut_string", "1 2; 2 4; 3 6; 4 8; 12 10; 5 12; 6 14; 7 16; 8 18; 9 20",
		$white_lobes, $white_clean);	
	
	do_cmd("mincmath", "-add", $grey_clean, $white_clean, $segment);
	
}

sub do_cmd
{
	print STDERR "@_ \n";
	system(@_) ==0 or die;
}



