#!/usr/local/bin/perl5.10.1

use v5.10.1;
use lib "/apps/perl/modules-1001/lib";
use lib "/apps/perl/modules-1308/lib";
use lib "/apps/share/skill/perl_code_utilities/Farm/v5.0/lib";
use strict;
use Getopt::Long;         # Cmd line processing
use Pod::Usage;           # Cmd usage output
use Cwd qw(getcwd abs_path);
use File::Path qw(make_path remove_tree);
use Excel::Writer::XLSX;  # Writes to .xlsx
use XML::Simple;          # Converts XML to Perl data structure
use Data::Dumper;         # Intelligent data printing
use LWP::UserAgent;       # Handles online data retrieval
use HTTP::Response;       # Grabs data from UserAgent
use Pod::Checker; # Check pod documents for syntax errors
use Test::More;   # Enables many useful unit_test subroutines for script self-testing
use Capture::Tiny qw( capture ); # provides a simple, portable way to capture almost anything sent to STDOUT or STDERR
use File::Slurp;
use Spreadsheet::ParseExcel;
use Spreadsheet::XLSX;

################################################################################
# Name: AssertsExtraction.pl
#
# Description: This script is to be used in extracting reliability asserts from a DV regression.
#
# Features:
#   - Regression to regression tracking
#   - Reviewer assignments
#   - Sequence filtering
#
# This script requires configuration before use on new projects. Please see configuration setup section;
#
# KNOWN LIMITATIONS
# This script is grabbing all asserts that return within bounds. If the assert never returns it will not be grabbed!
#
# Author: Ryan Geries (r-geries@ti.com)
# Contributors: ?
#
# Current Verison: 1.1
#
# Revision Tracking:
# 1.0 - Initial release.
# 1.1 - Added additional third data point for extraction.
#     - Added support for Vmanager flow (With some limitations). Also included template for future flows as well.
#     - Removed filtered tab from the output spreadsheet.
#     - Added regstat multi-tab support
#     - Added job filtering
#
# Comment status:
#   -This script has not been as well commented as I would like to have it.
#
# Optimization status:
#   -This script has yet to be optimized and most likely contains poor coding practices.
#
################################################################################
# Property of Texas Instruments -- For  Unrestricted  Internal  Use  Only --
# Unauthorized reproduction and/or distribution is strictly prohibited. This
# product  is  protected  under  copyright  law and  trade  secret law as an
# unpublished work.  Created 2005, (C) Copyright 2005 Texas Instruments.
# All rights reserved.
################################################################################

$| = 1; # set to disable buffering of output

##########################################################
#                    CONFIGURATION                       #
##########################################################

  #Define what the top level cell of your simulations is.
  my $Top_level = 'sim_TPS1HA08_TOP';

  my $Global_Primary_Reviewer;
  my $Location;
  my @Sequence_Filter_List;
  my $Filter;
  my $Select;
  my @List;
  my $List_Defined = 0;
  #Assert Value Filters
#  my $Filter_peak_limit = 0.1; # 10%
#  my $Filter_duration_limit = 0.000001; # 10%

  #############
  #  Filters  #
  #############

  # Create a filter list to avoid scanning unwanted sequences included in regstat file
  # 2 Available options
  # Option 1 - Filter list - Will filter out sequences in list (Be as broad or specific as you need)
  # Option 2 - Selection List - Will only grab sequences that match the list.
  sub Set_filter_list {
    #FILTER Option
    if ($Filter) {
      @Sequence_Filter_List = ("AUTOMOTIVE","BREAK", "CHECKS", "SCM_14", "SCM_14_HELLA", "FAULT");
    #SELECT Option
    } elsif ($Select) {
      @Sequence_Filter_List = ("SCM_1", "SCM_1_STDBY", "SCM_2", "SCM_2_XTALK", "SCM_3", "SCM_3_1", "SCM_3_XTALK", "SCM_4_1", "SCM_4_1_XTALK", "SCM_4_2", "SCM_4_MUX", "SCM_4_MUX_XTALK", "SCM_5", "SCM_6", "SCM_7", "SCM_7_ILIM", "SCM_7_XTALK", "SCM_7_XTALK_ILIM", "SCM_8", "SCM_8_1", "SCM_9", "SCM_10", "SCM_11", "SCM_12", "SCM_13");
    # @Sequence_Filter_List = ("DIAG_5");
    # My default option is to filter
    } else {
      @Sequence_Filter_List = ("AUTOMOTIVE","BREAK", "CHECKS", "SCM_14", "SCM_14_HELLA", "FAULT");
      $Filter = 1;
    }

    if (-e @List) {
      $List_Defined = 1;
    }

    if (@List) {
      undef @Sequence_Filter_List;
      @Sequence_Filter_List = @List;
    }
  }

  #Job filters
  # Within the following hash you can define specific jobs in specific sequence to filter out.
  # This will most likely get messy depending on how many you must filter.
  # If this option is used be set "filter_jobs" = 1 and if not = 0.
  # Please be very specific in the way you define jobs.
  
  my $filter_jobs = 0;
  my %Job_filter_hash;
  #               { Seq }   [------------Job list--------------]
  # Exclude jobs at Abs Max (6V)
  #$Job_filter_hash{PU_1} = ["Job_46.0", "Job_47.0"];

  #############
  # Reviewers #
  #############

  # Reviewers can be assigned using this subroutine.
  sub assign_reviewer {
      my $sub_location = shift(@_);
        if($sub_location =~ m/X_CHDRV/) { $Global_Primary_Reviewer = "Sualp Aras";}
        else {$Global_Primary_Reviewer = "Ryan Geries";}
    return $Global_Primary_Reviewer;
  }


##########################################################
#                 GLOBAL VARIABLES                       #
##########################################################
$SIG{'INT'}  = 'handler';
$SIG{'QUIT'} = 'handler';
$SIG{'KILL'} = 'handler';
$SIG{'TERM'} = 'handler';

my @args          = @ARGV;
my $cwd           = getcwd();
my $abs_path_self = abs_path($0);
my $Asserts_files;

# Ref to hash
my $asserts_hash = {};
my $job_hash = {};
my $history_hash = {};
my $gone_hash = {};
my $review_hash = {};
my $runtime_hash = {};
my $assert_trig = 0;
my $assert;
my $location;
my $lim_select;
my $assert_peak;
my $assert_peak_time;
my $upper_bound;
my $lower_bound;
my $assert_duration;
my $assert_limit;
my $count;
my $regression_count;
my $stimulus_count;
my $current_duration;
my $current_peak;
my $current_peaktolimit_ratio;
my $current_peaktoduration_ratio;
my $current_peak_relative_to_duration;
my $current_duration_relative_to_peak;
my $new_duration;
my $new_peak;
my $new_peak_relative_to_duration;
my $new_duration_relative_to_peak;
my $Debug = 0;
my $Total_Assert_Count = 0;
my $Stimulus_Assert_Count = 0;
my $Sequence_Assert_Count = 0;
my $Job_Assert_Count = 0;
my $regression;
my $sequence;
my $jobnum;
my $stimulus;
my $current_duration_time;
my $current_peak_time;
my $new_duration_time;
my $new_peak_time;
my $current_duration_seq;
my $current_duration_stim;
my $current_duration_job;
my $current_peak_seq;
my $current_peak_stim;
my $current_peak_job;
my $new_duration_seq;
my $new_duration_stim;
my $new_duration_job;
my $new_peak_seq;
my $new_peak_stim;
my $new_peak_job;

my $current_powercalc;
my $current_running_powercalc;
my $current_running_powercalc_count;
my $current_power_stored;

my $current_powercalc_wrt;
my $current_running_powercalc_wrt;
my $current_running_powercalc_count_wrt;
my $current_power_stored_wrt;

my $current_job_runtime;

my $NJ_Flag = 0;
my $Test_Flag = 0;

# Flow variables
my $Flow_type = 0;


# Output Xlsx formating variables
# Instantiating format objects
  my $light_green;
  my $title_format;
  my $green_format;
  my $yellow_format;
  my $red_format;
  my $black_format;
  my $info_format;
  my $info_red_format;
  my $info_green_format;
  my $info_yellow_format;


##########################################################
#                    GET CMlD LINE ARGS                  #
##########################################################
my @files = @ARGV;

my @Input_Sequences;
my @Filtered_Sequences;
my @assert_line;
my $all_lines;
my @assert_array;
my $space_assert_line;
my $parse_assert_line;
my $glJobFileRecord = {};
my $glSummaryRecord = {};
my $glGUITableRecord = {};

my $argJobfile;
my $argHelp;
my $OneJob;
my $argPastReg = 0;
my $argEnableRunTime = 0;
my $argRetainDoc = 0;
my $argFlow = "";
my $argCurrentReg;
my $Output_xlsx;
my $Review_xlsx;
my $glJobFileRecord;
my @jobs;
my @jobs_irunlog;
my @all_jobs;
my @all_jobs_irunlog;
my $No_track_file = 0;

(my $sec,my $min,my $hr,my $mday,my $mon,my $year,my $wday,my $yday,my $isdst) = localtime(time);
$mon++;
$year += 1900;

###########################################
#                    MAIN                 #
###########################################

ParseCommandLineArgs();
DetermineFlow();

#################################
# Read the defined Regstat file #
#################################

print "Reading Regstat File...\n";
$glJobFileRecord = read_job_file($argJobfile);


foreach my $Regstat_stim (sort keys %{$glJobFileRecord}) {
  foreach my $Regstat_seq (sort keys %{$glJobFileRecord->{$Regstat_stim}}) {
    if (defined $glJobFileRecord->{$Regstat_stim}->{$Regstat_seq}->{SimDir}) {
      push (@Input_Sequences, $glJobFileRecord->{$Regstat_stim}->{$Regstat_seq}->{SimDir});
    }
  }
}

####################################################
# Grab filter settings from configuration settings #
####################################################

Set_filter_list();
my $filter_stat = 0;

print "Reading filter/selection list...\n";

foreach my $Filter_Seq (@Input_Sequences) {
  foreach my $Filter_value (@Sequence_Filter_List) {
    #print "$Filter_value \n";
    #print "$Filter_Seq \n";
    if($Filter) {
      if ($Filter_Seq =~ m/$Filter_value/) {
        $filter_stat = 1;
        last;
      } else {
        $filter_stat = 0;
      }
    } elsif ($Select) {
      if ($Filter_Seq =~ m/$Filter_value/) {
        $filter_stat = 1;
        last;
      } else {
        $filter_stat = 0;
      }
    }
  }
  if($Filter) {
    if ($filter_stat == 1) { print "Filtered out $Filter_Seq \n"; }
    else {push (@Filtered_Sequences, $Filter_Seq);}
    $filter_stat = 0;
  } elsif ($Select) {
    if ($filter_stat == 1) { print "Selecting $Filter_Seq \n"; push (@Filtered_Sequences, $Filter_Seq);}
    $filter_stat = 0;
  }
}

##############################################
# Find all Assert files from filter Seq list #
##############################################

print "Finding all assert files...\n";
foreach my $Seq_path (@Filtered_Sequences) {
  if ($Flow_type == 0) { @jobs = glob ("$Seq_path"."Job*.0/psf/asserts.out"); }
  elsif ($Flow_type == 1) { @jobs = glob ("$Seq_path"."run_*/asserts.out"); }
  elsif ($Flow_type == 2) { @jobs = glob ("$Seq_path"."Job*.0/psf/asserts.out"); }
  else { @jobs = glob ("$Seq_path"."Job*.0/psf/asserts.out"); }

  @jobs_irunlog = glob ("$Seq_path"."Job*.0/psf/irun.log");

  push (@all_jobs, @jobs);
  push (@all_jobs_irunlog, @jobs_irunlog);
  if ($OneJob) {last;}
}

############################
# Filter out specific Jobs #
############################
my @Job_Array;
my $filter_flag;

if ($filter_jobs) {
  print "Attention: You have specified to filter out specific jobs in specifc sequences.\n";
  print "Filtering specific jobs now... \n";

  foreach my $spec_job (@all_jobs) {

    foreach my $Seq_filt_pt (sort keys %{Job_filter_hash}) {
      foreach my $Seq_job_pt (@{$Job_filter_hash{$Seq_filt_pt}}) {
        if ($spec_job =~ m/\/$Seq_filt_pt\// && $spec_job =~ m/\/$Seq_job_pt\//) {
          print "$Seq_filt_pt - $Seq_job_pt has been removed from scanning list \n";
          $filter_flag = 1;
          last;
        } 


      }
      if ($filter_flag) {last;}
    }
    if ($filter_flag) {$filter_flag = 0;}
    else {push(@Job_Array, $spec_job);}
  }
undef @all_jobs;
@all_jobs = @Job_Array;
}

print "Assert files found...\n";

if ($argEnableRunTime) {
  print "Additional data point for Power/Sim_time has been selected...\n";
  print "Scanning all jobs to determine each transisent run time\n";
  FindRunTimes();
}

#print Dumper($runtime_hash);

print "Parsing assert files...\n";
if ($OneJob) { print "One Job Option Selected! Scanning first job found\n";}


if(-e $argPastReg) {
  ReadRegTrackFile();
} else {
  print "No regression was given for tracking info...\n";
  $No_track_file = 1;
}

if (!$No_track_file) {
  print "Reading previous regression review comments...\n";
  ReadRegReviewFile();
}

grab_asserts();
print "Creating Output Summary...\n";
CreateOutputFile();
print "Success! Output file generated\n";
print "Output File: $Output_xlsx \n";

if (!$argRetainDoc && !$OneJob) {
  CreateRegTrackFile();
}

##########################################################
#                    SUBROUTINES                         #
##########################################################
# Interrupt handler for kill calls
sub handler
{
  #local($sig) = @_;

  print "\n\n  AAAARG! You caught me with a signal - I'm fading fast\n\n";
#  $BREAK = 1;
  CreateOutputFile();
  exit;
} # end handler



##########################################################
#                    SUBROUTINES                         #
##########################################################


################ ParseCommandLineArgs ##################
sub ParseCommandLineArgs {
  GetOptions( 'help' => \$argHelp,
              "xls=s"       => \$argJobfile,     # <string>
              "output=s"       => \$Output_xlsx,     # <string>
              'onejob' => \$OneJob,
              'filter' => \$Filter,
              'select' => \$Select,
              'list=s' => \@List,
              'debug' => \$Debug,
              'Reg=s' => \$argCurrentReg,
              'LastReg=s' => \$argPastReg,
              'retain' => \$argRetainDoc,
              'enableruntime' => \$argEnableRunTime,
              'flow=s' => \$argFlow,
  ) or pod2usage(2);
  pod2usage(1) if $argHelp;
}

################ Run command ##################
sub run { # Run system command
  my $cmd = shift;
  return !system($cmd);
}

################ Determine the type of regression flow ##################
sub DetermineFlow {

if($argFlow =~ m/farmEXE/) {$Flow_type = 0;}
elsif($argFlow =~ m/Vman/) {$Flow_type = 1;}
elsif($argFlow =~ m/Gfarm/) {$Flow_type = 2;}
elsif($argFlow =~ m/ADEXL/) {$Flow_type = 3;}
else {$Flow_type = 0;}

}


sub grab_asserts {

foreach my $file (@all_jobs) {

#  print "File: $file \n";

  if ($Flow_type == 0) {
    $file =~ /\/\S+?\/\S+?\/\S+?\/(.+?)\/create\/(.+?)\/(.+?)\/(.+?)\/psf\/asserts.out/;
    $regression = $1;
    $stimulus = $2;
    $sequence = $3;
    $jobnum = $4;
  } elsif ($Flow_type == 1) {
    $file =~ /\/\S+?\/\S+?\/\S+?\/vmanager_workarea\/(.+?)\/.+?\/(.+?)\/(.+?)\/(.+?)\/asserts.out/;
    $regression = "RA?_?";
    $stimulus = $2;
    $sequence = $3;
    $jobnum = $4;
  } elsif ($Flow_type == 2) {
     $file =~ /\/\S+?\/\S+?\/(.+?)\/(.+?)\/(.+?)\/.+?\/asserts.out/;
    $regression = "$1";
    $stimulus = "";
    $sequence = $2;
    $jobnum = $3;
  } else {
    $file =~ /\/\S+?\/\S+?\/\S+?\/(.+?)\/create\/(.+?)\/(.+?)\/(.+?)\/psf\/asserts.out/;
    $regression = $1;
    $stimulus = $2;
    $sequence = $3;
    $jobnum = $4;
  }

  if(defined $argCurrentReg) {
    $regression = $argCurrentReg;
  }

  # farmEXE Example: sim/TPS2HA08_OA_DS_2/regressions/RA0_4p0/create/POWERUP/PU_1/Job_18.0/psf/asserts.out
  # Vman Example: /sim/PCU12ESC_OA_DS_DV/a0226379/vmanager_workarea/model_validation_LinearRegs.a0226379.15_07_09_17_03_50_7673/chain_0/linear_regs_models/PVCC5_validation/run_20
  # Gfarm Example: /sim/DILLON_OA_DS/Regression_4_3/REG_VCORE2_FUNC/Job_0.0/psf/asserts.out


#  print "Regression: $regression \n";
#  print "Stimulus: $stimulus \n";
#  print "Sequence: $sequence \n";
#  print "Job#: $jobnum \n";

  print "Scanning: $stimulus, $sequence, $jobnum... \n";


  #$job_hash->{$regression}->{$stimulus}->{$sequence}->{$jobnum} = $new_duration;

  open(INFILE, $file) || die "\nERROR\nCan't read file '$file'\n"; 
  my @lines = <INFILE>;
  close(INFILE);

  foreach (@lines)
  {
    $space_assert_line = $_;
    if($space_assert_line =~ /WARNING/) {
      $all_lines = join("", @assert_line);
      $all_lines =~ s/\n//g;
      push (@assert_array,$all_lines);
      undef @assert_line;
      push (@assert_line,$space_assert_line);
    } elsif ($space_assert_line =~ /Warning/) {
        next;
    } else {
        push (@assert_line,$space_assert_line);
    }
  }

  my $found_flag;
  my $example1 = 0;
  my $example2 = 0;

  foreach (@assert_array) {
    $parse_assert_line = $_;

    # Example 1
    #
    #    WARNING (SPECTRE-4108): NCH_A_5_5p5_VDB_LBC8, instance
    #    sim_TPS2HA08_TOP.X_DUT.X_CONTROL_IC.X_DIAGNOSTICS.XISNS.XOUTFET.OR0.MN2:
    #    Expression `( (2.29<=l) * V(D,B) )' having value -305.814e-03 has
    #    returned to within bounds [-306e-03, 5.61]. Peak value was -576.026e-03
    #    at time 1.00275e-03. Total duration of overshoot was 7.38965e-06.
    #
    # Example 2
    #
    #    WARNING (SPECTRE-4119): RES_PVH_VAP_LBC8, instance
    #    dv_top_main.top_dut.ITM.R11: V(ResP,Backgate) limits exceeded.
    #    Expression `V(PLUS,BN)' exceeds its upper bound `25.5' . Peak value was
    #    39.5427 at time 107.251e-06. Total duration of overshoot was
    #    4.96306e-03.

    if ($parse_assert_line =~ /WARNING \S+ (\w+?)_LBC.{1,150}?$Top_level\.(.+?):.{1,150}?having\s+?value.+?has\s+?returned\s+?to\s+?within\s+?bounds\s+?\[(.+?),(.+?)\]\.\s+?Peak\s+?value\s+?was\s+?(\S+?)\s+?at\s+?time\s+?(\S+?)\. .{1,150}?overshoot\s+?was (.+?)\.$/) {

      $found_flag = 1;
      $assert = $1;
      $location = $2;
      $lower_bound= $3;
      $upper_bound= $4;
      $assert_peak = $5;
      $assert_peak_time = $6;
      $assert_duration = $7;

      if($assert_peak<=$lower_bound){
        $lim_select="lower";
        $assert_limit = $lower_bound;
      } elsif ($assert_peak>=$upper_bound) {
        $lim_select="upper";
        $assert_limit = $upper_bound;
      }

    } elsif ($parse_assert_line =~ /WARNING \S+ (\w+?)_LBC.{1,150}?$Top_level\.(.+?):.{1,150}exceeds its\s+?(upper|lower)\s+?bound\s+?`(\S+?)'.+?Peak\s+?value\s+?was\s+?(\S+?)\s+?at\s+?time\s+?(\S+?).\s+?Total.+?was\s+?(\S+?).$/) {

      $found_flag = 1;
      $assert = $1;
      $location = $2;
      $lim_select = $3;
      $assert_limit = $4;
      $assert_peak = $5;
      $assert_peak_time = $6;
      $assert_duration = $7;

    } else { $found_flag = 0; }

    if($found_flag) {

      $location =~ s/\|/\./g;

      if($lower_bound =~ /(\S+?)e(\S+?)$/) {
        $lower_bound = $1*10**$2;
      }
      if($upper_bound =~ /(\S+?)e(\S+?)$/) {
        $upper_bound = $1*10**$2;
      }
      if($assert_limit =~ /(\S+?)e(\S+?)$/) {
        $assert_limit = $1*10**$2;
      }
      if($assert_peak =~ /(\S+?)e(\S+?)$/) {
        $assert_peak = $1*10**$2;
      }
      if($assert_peak_time =~ /(\S+?)e(\S+?)$/) {
        $assert_peak_time = $1*10**$2;
      }
      if($assert_duration =~ /(\S+?)e(\S+?)$/) {
        $assert_duration = $1*10**$2;
      }

      if ($Debug) {
      print "Assert: $assert \n";
      print "Location: $location \n";
      print "Lower: $lower_bound \n";
      print "Upper: $upper_bound \n";
      print "Peak: $assert_peak \n";
      print "PeakTime: $assert_peak_time \n";
      print "Duration: $assert_duration \n";
      }

    $Total_Assert_Count = $Total_Assert_Count + 1;
    $Job_Assert_Count =  $Job_Assert_Count + 1;

    if ($assert =~ /xNULLx/ || $location =~ /xNULLx/ || $lower_bound =~ /xNULLx/ || $upper_bound =~ /xNULLx/ || $assert_peak =~ /xNULLx/ || $assert_peak_time =~ /xNULLx/ || $assert_duration =~ /xNULLx/) {
    print "xNULLx FOUND \n";
    print "Assert: $assert \n";
    print "Location: $location \n";
    print "Lower: $lower_bound \n";
    print "Upper: $upper_bound \n";
    print "Peak: $assert_peak \n";
    print "PeakTime: $assert_peak_time \n";
    print "Duration: $assert_duration \n";
    }

    if ($argEnableRunTime) {
      undef $current_job_runtime;
      $current_job_runtime = $runtime_hash->{$stimulus}->{$sequence}->{$jobnum};
      if (!defined $current_job_runtime) {print "Runtime for $stimulus $sequence $jobnum not found. \n";}
    }

    if (defined $asserts_hash->{$assert}->{$location}->{$lim_select}) {

        if (defined $asserts_hash->{$assert}->{$location}->{$lim_select}->{New_Job_Flag}) {
          $NJ_Flag = $asserts_hash->{$assert}->{$location}->{$lim_select}->{New_Job_Flag};
        } else {
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{New_Job_Flag} = $Test_Flag;
          $NJ_Flag = $Test_Flag;
        }

        if ($NJ_Flag != $Test_Flag ) {
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power} = 0;
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power_count} = 0;
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{New_Job_Flag} = $Test_Flag;
        }

        $count = $asserts_hash->{$assert}->{$location}->{$lim_select}->{count};
        $current_duration = $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_duration};
        $current_peak = $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_peak};
        $current_peak_relative_to_duration = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_peak};
        $current_duration_relative_to_peak = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_duration};
        $current_duration_time = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_duration};
        $current_peak_time = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_peak};
        $current_duration_seq = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_duration};
        $current_peak_seq = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_peak};
        $current_duration_job = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_duration};
        $current_peak_job = $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_peak};

        #"Assert Power"
        $current_powercalc = abs($assert_peak - $assert_limit)*$assert_duration;
        $current_running_powercalc = $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power};
        $current_running_powercalc_count = $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power_count};
        $current_running_powercalc = $current_running_powercalc + $current_powercalc;
        $current_running_powercalc_count = $current_running_powercalc_count + 1;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power} = $current_running_powercalc;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power_count} = $current_running_powercalc_count;

      if($lim_select =~ /lower/) {
        #Duration
        if($assert_duration>$current_duration) {
          $new_duration = $assert_duration; 
          $new_peak_relative_to_duration = $assert_peak;
          $new_duration_time = $assert_peak_time;
          $new_duration_seq = $sequence;
          $new_duration_job = $jobnum;
        }
        else {
          $new_duration = $current_duration; 
          $new_peak_relative_to_duration = $current_peak_relative_to_duration;
          $new_duration_time = $current_duration_time;
          $new_duration_seq = $current_duration_seq;
          $new_duration_job = $current_duration_job;
        }
        #Peak
        if($assert_peak<$current_peak) {
          $new_peak = $assert_peak; 
          $new_duration_relative_to_peak = $assert_duration;
          $new_peak_time = $assert_peak_time;
          $new_peak_seq = $sequence;
          $new_peak_job = $jobnum;
        }
        else {
          $new_peak = $current_peak;
          $new_duration_relative_to_peak = $current_duration_relative_to_peak;
          $new_peak_time = $current_peak_time;
          $new_peak_seq = $current_peak_seq;
          $new_peak_job = $current_peak_job;
        }

      } elsif($lim_select =~ /upper/) {
        #Duration
        if($assert_duration>$current_duration) {
          $new_duration = $assert_duration; 
          $new_peak_relative_to_duration = $assert_peak;
          $new_duration_time = $assert_peak_time;
          $new_duration_seq = $sequence;
          $new_duration_job = $jobnum;
        }
        else {
          $new_duration = $current_duration; 
          $new_peak_relative_to_duration = $current_peak_relative_to_duration;
          $new_duration_time = $current_duration_time;
          $new_duration_seq = $current_duration_seq;
          $new_duration_job = $current_duration_job;
        }
        #Peak
        if($assert_peak>$current_peak) {
          $new_peak = $assert_peak; 
          $new_duration_relative_to_peak = $assert_duration;
          $new_peak_time = $assert_peak_time;
          $new_peak_seq = $sequence;
          $new_peak_job = $jobnum;
        }
        else {
          $new_peak = $current_peak;
          $new_duration_relative_to_peak = $current_duration_relative_to_peak;
          $new_peak_time = $current_peak_time;
          $new_peak_seq = $current_peak_seq;
          $new_peak_job = $current_peak_job;
        }
      }
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_duration} = $new_duration;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_peak} = $new_peak;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_duration} = $new_duration_relative_to_peak;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_peak} = $new_peak_relative_to_duration;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_duration} = $new_duration_time;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_peak} = $new_peak_time;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_duration} = $new_duration_seq;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_duration} = $new_duration_job;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_peak} = $new_peak_seq;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_peak} = $new_peak_job;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{count} = $count + 1;
    } else {
        $current_powercalc = abs($assert_peak - $assert_limit)*$assert_duration;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_duration} = $assert_duration;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_peak} = $assert_peak;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_duration} = $assert_duration;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_peak} = $assert_peak;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_duration} = $assert_peak_time;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_time_peak} = $assert_peak_time;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_duration} = $sequence;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_peak} = $sequence;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_duration} = $jobnum;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_peak} = $jobnum;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{limit} = $assert_limit;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{count} = 1;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power} = $current_powercalc;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_count} = 1;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_power} = $sequence;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_power} = $jobnum;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power} = $current_powercalc;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{running_power_count} = 1;
        $asserts_hash->{$assert}->{$location}->{$lim_select}->{New_Job_Flag} = $Test_Flag;

        if ($argEnableRunTime) {
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_wrt} = $current_powercalc/$current_job_runtime;
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_count_wrt} = 1;
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_power_wrt} = $sequence;
          $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_power_wrt} = $jobnum;
        }
    }

    $current_power_stored = $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power};
    if($current_running_powercalc>$current_power_stored) {
         $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power} = $current_running_powercalc;
         $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_count} = $current_running_powercalc_count;
         $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_power} = $sequence;
         $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_power} = $jobnum;
    }

    if ($argEnableRunTime) {
      $current_power_stored_wrt = $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_wrt};
      $current_running_powercalc_wrt = $current_running_powercalc/$current_job_runtime;
      if($current_running_powercalc_wrt>$current_power_stored_wrt) {
           $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_wrt} = $current_running_powercalc_wrt;
           $asserts_hash->{$assert}->{$location}->{$lim_select}->{max_power_count_wrt} = $current_running_powercalc_count;
           $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_seq_power_wrt} = $sequence;
           $asserts_hash->{$assert}->{$location}->{$lim_select}->{relative_job_power_wrt} = $jobnum;
      }
    }

  }

    $assert = "xNULLx";
    $location = "xNULLX";
    $lower_bound= "xNULLX";
    $upper_bound= "xNULLX";
    $assert_peak = "xNULLX";
    $assert_peak_time = "xNULLX";
    $assert_duration = "xNULLX";
    undef $current_power_stored;
    undef $current_powercalc;
    undef $current_running_powercalc;
    undef $current_running_powercalc_count;

    undef $current_power_stored_wrt;
    undef $current_powercalc_wrt;
    undef $current_running_powercalc_wrt;
    undef $current_running_powercalc_count_wrt;
    $found_flag = 0;
#    $Test_Flag = $Test_Flag + 1;
  }

  $job_hash->{$regression}->{$stimulus}->{$sequence}->{$jobnum}->{count} = $Job_Assert_Count;
  $Job_Assert_Count = 0;
    $Test_Flag = $Test_Flag + 1;

  undef @assert_array;

  if ($OneJob) {
    last;
  }

}

########################
## Filtering Section  ##
########################

my $fitler_limit;
my $fitler_max_duration;
my $fitler_max_peak;
my $fitler_relative_peak;
my $fitler_relative_duration;
my $max_percent_overshoot;
my $relative_percent_overshoot;

  foreach my $Filter_ASSERT (sort keys %{$asserts_hash}) {
    foreach my $Filter_Location (sort keys(%{$asserts_hash->{$Filter_ASSERT}})) {
      foreach my $Filter_Bound (sort keys %{$asserts_hash->{$Filter_ASSERT}{$Filter_Location}}) {
        $fitler_limit = $asserts_hash->{$Filter_ASSERT}{$Filter_Location}{$Filter_Bound}{limit};
        if ($fitler_limit == 0) { $fitler_limit = 1;}
        $fitler_max_duration =$asserts_hash->{$Filter_ASSERT}{$Filter_Location}{$Filter_Bound}{max_duration};
        $fitler_max_peak = $asserts_hash->{$Filter_ASSERT}{$Filter_Location}{$Filter_Bound}{max_peak};
        $fitler_relative_peak = $asserts_hash->{$Filter_ASSERT}{$Filter_Location}{$Filter_Bound}{relative_peak};
        $fitler_relative_duration =$asserts_hash->{$Filter_ASSERT}{$Filter_Location}{$Filter_Bound}{relative_duration};
        $max_percent_overshoot = abs(1-($fitler_max_peak/$fitler_limit));
        $relative_percent_overshoot = abs(1-($fitler_relative_peak/$fitler_limit));
        $asserts_hash->{$Filter_ASSERT}->{$Filter_Location}->{$Filter_Bound}->{relative_percent_overshoot} = $relative_percent_overshoot;
        $asserts_hash->{$Filter_ASSERT}->{$Filter_Location}->{$Filter_Bound}->{max_percent_overshoot} = $max_percent_overshoot;
      }
    }
  }

    if ($Debug) {
      print Dumper($asserts_hash);
      print Dumper($job_hash);
    }
}


########################################################################
##################         CreateOutputFile          ###################
########################################################################

sub CreateOutputFile {
# Create compare_asserts.xlsx spreadsheet
  #my $file = $argXlsxPath;
  my $r = 0;    #row
  my $c = 0;    #column

# Instantiating workbook and worksheet objects

  my $time = `date +%G_%m_%d_%H%M`; chomp($time);
  if (!defined ($Output_xlsx)) {$Output_xlsx = "Regression_asserts_$time.xlsx";}

  my $workbook = Excel::Writer::XLSX -> new ("$Output_xlsx");
  if (!defined ($workbook)) { error("Cannot save compare_asserts.xlsx to specified path: NA"); }
  my $worksheet2 = $workbook->add_worksheet ("$regression General Summary");
  my $worksheet3 = $workbook->add_worksheet ("$regression Job Breakdown");
  my $worksheet1 = $workbook->add_worksheet ("$regression Asserts");
#  my $worksheet4 = $workbook->add_worksheet ("$regression Sequence Filter Summary");
#  my $worksheet5 = $workbook->add_worksheet ("$regression Filtered Asserts");
  my $worksheet6 = $workbook->add_worksheet ("Asserts No Longer Seen");


# Instantiating format objects
  $light_green = $workbook->set_custom_color (8, 143, 188, 143);
  $title_format = $workbook->add_format (bold => 1, align => 'center', border => 1, size => 14);
  $green_format = $workbook->add_format (bold => 1, bg_color => $light_green, border => 1, size => 12);
  $yellow_format = $workbook->add_format (bold => 1, bg_color => 'yellow', border => 1, size => 12);
  $red_format = $workbook->add_format (bold => 1, bg_color => 'red', border => 1, size => 12);
  $black_format = $workbook->add_format (bold => 1, bg_color => '23', border => 1, size => 12);

  $info_format = $workbook->add_format (bold => 0, align => 'left', border => 0, size => 14);
  $info_red_format = $workbook->add_format (bold => 0, bg_color => 'red', align => 'left', border => 0, size => 14);
  $info_green_format = $workbook->add_format (bold => 0, bg_color => 'green', align => 'left', border => 0, size => 14);
  $info_yellow_format = $workbook->add_format (bold => 0, bg_color => 'yellow', align => 'left', border => 0, size => 14);

  my $bold_format = $workbook->add_format (bold => 1, align => 'left', border => 0, size => 14);
  my $bold_cent_format = $workbook->add_format (bold => 1, align => 'center', border => 0, size => 14);
  my $large_format = $workbook->add_format (bold => 1, align => 'center', border => 0, size => 15);

# Setting column widths

################################
#####     Summary Tab      #####
################################

  $worksheet2 -> set_column(0, 0, 100);
  $worksheet2 -> set_column(1, 1, 20);
  $worksheet2 -> set_column(2, 2, 50);

  $worksheet3 -> set_column(0, 0, 30);
  $worksheet3 -> set_column(1, 1, 30);

  $worksheet6 -> set_column(0, 0, 30);
  $worksheet6 -> set_column(1, 1, 60);
  $worksheet6 -> set_column(2, 2, 30);
  $worksheet6 -> set_column(3, 3, 30);


  my $Summary_row = 0;
  my $Summary_col = 0;
  my $JobSummary_row = 0;
  my $JobSummary_col = 0;
  my $Summary_Count_row = 0;
  my $Seq_Total_row = 0;
  my $Seq_Total_row_2 = 0;
  my $Stim_Total_row = 0;

  my $Summary_count = 0;
  my $Summary_Stim_total = 0;
  my $Summary_Seq_total = 0;

  my $Number_of_stim = 0;
  my $Number_of_seq = 0;
  my $Number_of_jobs = 0;
  my $ranvar;


  $worksheet2 -> write($Summary_row, $Summary_col, "Regression Asserts Summary Generated on $time", $title_format);
  $Summary_row++;
  $Summary_Count_row = $Summary_row;
  $Summary_row++;
  $Summary_row++;
  $Summary_row++;
  $worksheet2 -> write($Summary_row, $Summary_col, "Total Regression Assert Count: $Total_Assert_Count", $title_format);
  $Summary_row++;
  $Summary_row++;
  $worksheet2 -> write($Summary_row, $Summary_col, "General Breakdown:", $title_format);
  $Summary_row++;

  $worksheet3 -> write($JobSummary_row, 0, "Sequence:", $title_format);
  $worksheet3 -> write($JobSummary_row, 1, "Job:", $title_format);
  $JobSummary_row++;

#  $job_hash->{$regression}->{$stimulus}->{$sequence}->{$jobnum}->{count} = $Job_Assert_Count;
  foreach my $Summary_regression (sort keys %{$job_hash}) {
    foreach my $Summary_stimulus (sort keys %{$job_hash->{$Summary_regression}}) {
      $Number_of_stim = $Number_of_stim + 1;
      $worksheet2 -> write($Summary_row, $Summary_col, "$Summary_stimulus", $title_format);
      $Stim_Total_row = $Summary_row;
      $Summary_row++;
      foreach my $Summary_sequence (sort keys %{$job_hash->{$Summary_regression}->{$Summary_stimulus}}) {
        $Number_of_seq = $Number_of_seq + 1;
        $Summary_col = 1;
        $JobSummary_col = 0;
        $worksheet2 -> write($Summary_row, $Summary_col, "$Summary_sequence", $title_format);
        $worksheet3 -> write($JobSummary_row, $JobSummary_col, "$Summary_sequence", $title_format);
        $Summary_col = 2;
        $JobSummary_col = 1;
        #$worksheet2 -> write($Summary_row, $Summary_col, "Total: NA", $title_format);
        $Seq_Total_row = $Summary_row;
        $Seq_Total_row_2 = $JobSummary_row;
        $Summary_row++;
        $JobSummary_row++;
        foreach my $Summary_job (sort keys %{$job_hash->{$Summary_regression}->{$Summary_stimulus}->{$Summary_sequence}}) {
          $Number_of_jobs = $Number_of_jobs + 1;
          $Summary_count = $job_hash->{$Summary_regression}{$Summary_stimulus}{$Summary_sequence}{$Summary_job}{count};
          #$worksheet2 -> write($Summary_row, $Summary_col, "$Summary_job: $Summary_count", $title_format);
          $worksheet3 -> write($JobSummary_row, $JobSummary_col, "$Summary_job: $Summary_count", $title_format);

          $Summary_Stim_total = $Summary_Stim_total + $Summary_count;
          $Summary_Seq_total = $Summary_Seq_total + $Summary_count;
          $JobSummary_row++;
        }
        $worksheet2 -> write($Seq_Total_row, $Summary_col, "Total: $Summary_Seq_total", $red_format);
        $worksheet3 -> write($Seq_Total_row_2, $JobSummary_col, "Total: $Summary_Seq_total", $red_format);
        $Summary_Seq_total = 0;
      }
      $worksheet2 -> write($Stim_Total_row, 1, "Total: $Summary_Stim_total", $red_format);
      $Summary_Stim_total =0;
      $Summary_col = 0;
    }
  }

  $worksheet2 -> write($Summary_Count_row, $Summary_col, "Number of Stimulus in Regression: $Number_of_stim", $title_format);
  $Summary_Count_row++;
  $worksheet2 -> write($Summary_Count_row, $Summary_col, "Number of Sequences in Regression: $Number_of_seq", $title_format);
  $Summary_Count_row++;
  $worksheet2 -> write($Summary_Count_row, $Summary_col, "Number of Jobs in Regression: $Number_of_jobs", $title_format);


######################################
#####    End of Summary Tab      #####
######################################


  #Details
  my $col_int = 0;
  my $Assert_Title_Column = $col_int;               $col_int++;
  my $Assert_Title_SpFr_Column = $col_int;          $col_int++;
  my $Instance_Column = $col_int;                   $col_int++;
  my $Review_Stat_Column = $col_int;                $col_int++;
  my $Reviewer_Column = $col_int;                   $col_int++;
  my $Bound_Column = $col_int;                      $col_int++;
  my $Count_Column = $col_int;                      $col_int++;
  my $Limit_Column = $col_int;                      $col_int++;
  my $Max_Duration_Column = $col_int;               $col_int++;
  my $MP_rel2_MD_Column = $col_int;                 $col_int++;
  my $MP_rel2_MD_Column_Overshoot = $col_int;       $col_int++;
  my $Time_rel2_MD_Column = $col_int;               $col_int++;
  my $Seq_rel2_MD_Column = $col_int;                $col_int++;
  my $Job_rel2_MD_Column = $col_int;                $col_int++;
  my $Max_Peak_Column = $col_int;                   $col_int++;
  my $Max_Peak_Column_Overshoot = $col_int;         $col_int++;
  my $MD_rel2_MP_Column = $col_int;                 $col_int++;
  my $Time_rel2_MP_Column = $col_int;               $col_int++;
  my $Seq_rel2_MP_Column = $col_int;                $col_int++;
  my $Job_rel2_MP_Column = $col_int;                $col_int++;
  my $Max_Power_Column = $col_int;                  $col_int++;
  my $Max_Power_Count_Column = $col_int;            $col_int++;
  my $Seq_rel2_MPow_Column = $col_int;              $col_int++;
  my $Job_rel2_MPow_Column = $col_int;              $col_int++;

  my $Max_Power_Column_RT;
  my $Max_Power_Count_Column_RT;
  my $Seq_rel2_MPow_Column_RT;
  my $Job_rel2_MPow_Column_RT;

if ($argEnableRunTime) {
  $Max_Power_Column_RT = $col_int;                  $col_int++;
  $Max_Power_Count_Column_RT = $col_int;            $col_int++;
  $Seq_rel2_MPow_Column_RT = $col_int;              $col_int++;
  $Job_rel2_MPow_Column_RT = $col_int;              $col_int++;
}

  my $Review_Comments = $col_int;                   $col_int++;
  my $Regression_Found_Column = $col_int;           $col_int++;

  my $Regression_History_Column = $col_int;         $col_int++;
  my $Regression_History_Max_Dur = $col_int;        $col_int++;
  my $Regression_History_Rel_Peak = $col_int;       $col_int++;
  my $Regression_History_Max_Peak = $col_int;       $col_int++;
  my $Regression_History_Rel_Dur = $col_int;        $col_int++;


  my $Primary_Reviewer;
  my $Assert_Title_Spacer;
  my $Regression_Found = "";
  my $Assert_type_count;


# Setting column widths set_column( $first_col, $last_col, $width, $format, $hidden, $level, $collapsed )
  $worksheet1 -> set_column($Assert_Title_Column, $Assert_Title_Column, 50);                          #Assert
  $worksheet1 -> set_column($Assert_Title_SpFr_Column, $Assert_Title_SpFr_Column, 20, undef,1);       #Hidden Assert Spotfire Column
  $worksheet1 -> set_column($Instance_Column, $Instance_Column, 120);                                 #Instance
  $worksheet1 -> set_column($Review_Stat_Column, $Review_Stat_Column, 30);                            #Review Status
  $worksheet1 -> set_column($Reviewer_Column, $Reviewer_Column, 30);                                  #Reviewer
  $worksheet1 -> set_column($Bound_Column, $Bound_Column, 30);                                        #Bound
  $worksheet1 -> set_column($Count_Column, $Count_Column, 20);                                        #Count
  $worksheet1 -> set_column($Limit_Column, $Limit_Column, 20);                                        #Limit
  $worksheet1 -> set_column($Max_Duration_Column, $Max_Duration_Column, 30);                          #Duration
  $worksheet1 -> set_column($MP_rel2_MD_Column, $MP_rel2_MD_Column, 50);                              #Relative Peak
  $worksheet1 -> set_column($MP_rel2_MD_Column_Overshoot, $MP_rel2_MD_Column_Overshoot, 50);          #Relative Peak Overshoot Ratio
  $worksheet1 -> set_column($Time_rel2_MD_Column, $Time_rel2_MD_Column, 50);                          #Relative Time
  $worksheet1 -> set_column($Seq_rel2_MD_Column, $Seq_rel2_MD_Column, 50);                            #Relative Sequence
  $worksheet1 -> set_column($Job_rel2_MD_Column, $Job_rel2_MD_Column, 50);                            #Relative Job
  $worksheet1 -> set_column($Max_Peak_Column, $Max_Peak_Column, 30);                                  #Peak
  $worksheet1 -> set_column($Max_Peak_Column_Overshoot, $Max_Peak_Column_Overshoot, 50);              #Peak Overshoot ratio
  $worksheet1 -> set_column($MD_rel2_MP_Column, $MD_rel2_MP_Column, 50);                              #Relative Duration
  $worksheet1 -> set_column($Time_rel2_MP_Column, $Time_rel2_MP_Column, 50);                          #Relative Time
  $worksheet1 -> set_column($Seq_rel2_MP_Column, $Seq_rel2_MP_Column, 50);                            #Relative Sequence
  $worksheet1 -> set_column($Job_rel2_MP_Column, $Job_rel2_MP_Column, 50);                            #Relative Job
  $worksheet1 -> set_column($Max_Power_Column, $Max_Power_Column, 30);                                #Power
  $worksheet1 -> set_column($Max_Power_Count_Column, $Max_Power_Count_Column, 30);                    #Power_Count
  $worksheet1 -> set_column($Seq_rel2_MPow_Column, $Seq_rel2_MPow_Column, 50);                        #Relative Sequence
  $worksheet1 -> set_column($Job_rel2_MPow_Column, $Job_rel2_MPow_Column, 50);                        #Relative Job

if ($argEnableRunTime) {
  $worksheet1 -> set_column($Max_Power_Column_RT, $Max_Power_Column_RT, 30);                                #Power / Runtime
  $worksheet1 -> set_column($Max_Power_Count_Column_RT, $Max_Power_Count_Column_RT, 30);                    #Power_Count_RT
  $worksheet1 -> set_column($Seq_rel2_MPow_Column_RT, $Seq_rel2_MPow_Column_RT, 50);                        #Relative Sequence
  $worksheet1 -> set_column($Job_rel2_MPow_Column_RT, $Job_rel2_MPow_Column_RT, 50);                        #Relative Job
}

  $worksheet1 -> set_column($Review_Comments, $Review_Comments, 150);                                 #Review Comments
  $worksheet1 -> set_column($Regression_Found_Column, $Regression_Found_Column, 20, undef,1);         #Hidden Regression Found Column
  $worksheet1 -> set_column($Regression_History_Column, $Regression_History_Column, 20, undef,1);     #Hidden Regression Found Column

  $worksheet1 -> set_column($Regression_History_Max_Dur, $Regression_History_Max_Dur, 50);            #Hist Max Duration
  $worksheet1 -> set_column($Regression_History_Rel_Dur, $Regression_History_Rel_Dur, 50);            #Hist Rel Duration
  $worksheet1 -> set_column($Regression_History_Max_Peak, $Regression_History_Max_Peak, 50);          #Hist Max Peak
  $worksheet1 -> set_column($Regression_History_Rel_Peak, $Regression_History_Rel_Peak, 50);          #Hist Rel Peak

  my $title1;
  my $title2;
  my $title3;

  my $i = 0;
  my $x = 0;
  my $z = 0;

  #First Row Formating
#print "FIRST ROW $r \n";
  $worksheet1 -> write($r, $Assert_Title_Column, "ASSERT", $title_format);
  $worksheet1 -> write($r, $Assert_Title_SpFr_Column, "Spotfire Assert", $title_format);
  $worksheet1 -> write($r, $Instance_Column, "Instance", $title_format);
  $worksheet1 -> write($r, $Review_Stat_Column, "Review Status", $title_format);
  $worksheet1 -> write($r, $Reviewer_Column, "Primary Reviewer", $title_format);
  $worksheet1 -> write($r, $Bound_Column, "Bound Broken", $title_format);
  $worksheet1 -> write($r, $Count_Column, "Count", $title_format);
  $worksheet1 -> write($r, $Limit_Column, "Limit", $title_format);
  $worksheet1 -> write($r, $Max_Duration_Column, "Max Duration", $title_format);
  $worksheet1 -> write($r, $MP_rel2_MD_Column, "Peak Relative to Max Duration", $title_format);
  $worksheet1 -> write($r, $MP_rel2_MD_Column_Overshoot, "Relative Peak Overshoot Ratio", $title_format);
  $worksheet1 -> write($r, $Time_rel2_MD_Column, "Time Relative to Max Duration", $title_format);
  $worksheet1 -> write($r, $Seq_rel2_MD_Column, "Sequence Relative to Max Duration", $title_format);
  $worksheet1 -> write($r, $Job_rel2_MD_Column, "Job Relative to Max Duration", $title_format);
  $worksheet1 -> write($r, $Max_Peak_Column, "Max Peak", $title_format);
  $worksheet1 -> write($r, $Max_Peak_Column_Overshoot, "Max Peak Overshoot Ratio", $title_format);
  $worksheet1 -> write($r, $MD_rel2_MP_Column, "Duration Relative to Max Peak", $title_format);
  $worksheet1 -> write($r, $Time_rel2_MP_Column, "Time Relative to Max Peak", $title_format);
  $worksheet1 -> write($r, $Seq_rel2_MP_Column, "Sequence Relative to Max Peak", $title_format);
  $worksheet1 -> write($r, $Job_rel2_MP_Column, "Job Relative to Max Peak", $title_format);
  $worksheet1 -> write($r, $Max_Power_Column, "Max Assert Power", $title_format);
  $worksheet1 -> write($r, $Max_Power_Count_Column, "Assert Power Count", $title_format);
  $worksheet1 -> write($r, $Seq_rel2_MPow_Column, "Sequence Relative to Max Power", $title_format);
  $worksheet1 -> write($r, $Job_rel2_MPow_Column, "Job Relative to Max Power", $title_format);

if ($argEnableRunTime) {
  $worksheet1 -> write($r, $Max_Power_Column_RT, "Max Assert Power WRT Runtime", $title_format);
  $worksheet1 -> write($r, $Max_Power_Count_Column_RT, "Assert Power WRT Runtime Count", $title_format);
  $worksheet1 -> write($r, $Seq_rel2_MPow_Column_RT, "Sequence Relative to Max Power WRT Runtime", $title_format);
  $worksheet1 -> write($r, $Job_rel2_MPow_Column_RT, "Job Relative to Max Power WRT Runtime", $title_format);
}

  $worksheet1 -> write($r, $Review_Comments, "Reviewer Comments", $title_format);
  $worksheet1 -> write($r, $Regression_Found_Column, "Regression Found", $title_format);

  $worksheet1 -> write($r, $Regression_History_Max_Dur, "Past_Reg_MaxDuration", $title_format);
  $worksheet1 -> write($r, $Regression_History_Rel_Peak, "Past_Reg_RelPeak", $title_format);
  $worksheet1 -> write($r, $Regression_History_Max_Peak, "Past_Reg_MaxPeak", $title_format);
  $worksheet1 -> write($r, $Regression_History_Rel_Dur, "Past_Reg_RelDuration", $title_format);

  $r++;
#print "THIRD ROW $r \n";
  #Second Row Formating
  $worksheet1 -> write($r, $Assert_Title_Column, "String", $title_format);
  $worksheet1 -> write($r, $Assert_Title_SpFr_Column, "String", $title_format);
  $worksheet1 -> write($r, $Instance_Column, "String", $title_format);
  $worksheet1 -> write($r, $Review_Stat_Column, "String", $title_format);
  $worksheet1 -> write($r, $Reviewer_Column, "String", $title_format);
  $worksheet1 -> write($r, $Bound_Column, "String", $title_format);
  $worksheet1 -> write($r, $Count_Column, "Real", $title_format);
  $worksheet1 -> write($r, $Limit_Column, "Real", $title_format);
  $worksheet1 -> write($r, $Max_Duration_Column, "Real", $title_format);
  $worksheet1 -> write($r, $MP_rel2_MD_Column, "Real", $title_format);
  $worksheet1 -> write($r, $Max_Peak_Column, "Real", $title_format);
  $worksheet1 -> write($r, $MD_rel2_MP_Column, "Real", $title_format);
  $worksheet1 -> write($r, $Review_Comments, "String", $title_format);
  $worksheet1 -> write($r, $Regression_Found_Column, "String", $title_format);

  $worksheet1 -> write($r, $Regression_History_Max_Dur, "String", $title_format);
  $worksheet1 -> write($r, $Regression_History_Rel_Peak, "String", $title_format);
  $worksheet1 -> write($r, $Regression_History_Max_Peak, "String", $title_format);
  $worksheet1 -> write($r, $Regression_History_Rel_Dur, "String", $title_format);

  $r++;

  my $current_max_duration;
  my $current_max_peak;
  my $current_rel_duration;
  my $current_rel_peak;

  my $hist_max_duration;
  my $hist_max_peak;
  my $hist_rel_duration;
  my $hist_rel_peak;

  my $max_duration_format;
  my $max_peak_format;
  my $rel_duration_format;
  my $rel_peak_format;
  my $test_var = 0;
  my $duration_ratio_var = 0;
  my $rel_duration_ratio_var = 0;
  my $peak_ratio_var = 0;
  my $rel_peak_ratio_var = 0;
  my $MP_OS;
  my $RMP_OS;

  my $Comp_max_duration = 0;
  my $Comp_max_peak = 0;
  my $Comp_rel_duration = 0;
  my $Comp_rel_peak = 0;

  my $Comp_var = 0;
  my $Temp_Comp_var = 0;

  my $review_var;
  my $review_format;
  my $comment_var;


  foreach my $ASSERT (sort keys %{$asserts_hash}) {
    $worksheet1 -> write($r, $Assert_Title_Column, "$ASSERT", $info_format);
    $Assert_Title_Spacer = $r;
    $r++;

  # Do 'natural' sort
  #my @loCategories= grep {s/(^|\D)0+(\d)/$1$2/g,1} sort
  #grep {s/(\d+)/sprintf"%06.6d",$1/ge,1} keys(%{$glJobFileRecord});    

    #foreach my $Location (sort keys %{$asserts_hash->{$ASSERT}}) {
    foreach $Location (grep {s/(^|\D)0+(\d)/$1$2/g,1} sort grep {s/(\d+)/sprintf"%06.6d",$1/ge,1} keys(%{$asserts_hash->{$ASSERT}})) {
      $worksheet1 -> write($r, $Instance_Column, "$Location", $info_format);
      $worksheet1 -> write($r, $Assert_Title_SpFr_Column, "$ASSERT", $info_format);
      $worksheet1 -> write($r, $Regression_Found_Column, "$Regression_Found", $info_format);
      $worksheet1 -> write($r, $Regression_History_Column, "$argPastReg", $info_format);
#      $worksheet1 -> write($r, $Review_Stat_Column, "Not Reviewed", $red_format);


      #Reviewers
      $Primary_Reviewer = assign_reviewer($Location);

      foreach my $Bound (sort keys %{$asserts_hash->{$ASSERT}{$Location}}) {
        $worksheet1 -> write($r, $Bound_Column, "$Bound", $info_format);
        $worksheet1 -> write($r, $Reviewer_Column, "$Primary_Reviewer", $info_format);

          $current_max_duration = $asserts_hash->{$ASSERT}{$Location}{$Bound}{max_duration};
          $current_max_peak = $asserts_hash->{$ASSERT}{$Location}{$Bound}{max_peak};
          $current_rel_duration = $asserts_hash->{$ASSERT}{$Location}{$Bound}{rel_duration};
          $current_rel_peak = $asserts_hash->{$ASSERT}{$Location}{$Bound}{rel_peak};

          if (exists $history_hash->{$ASSERT}{$Location}{$Bound}{max_duration}) {

            $hist_max_duration = $history_hash->{$ASSERT}{$Location}{$Bound}{max_duration};
            $hist_max_peak = $history_hash->{$ASSERT}{$Location}{$Bound}{max_peak};
            $hist_rel_duration = $history_hash->{$ASSERT}{$Location}{$Bound}{rel_duration};
            $hist_rel_peak = $history_hash->{$ASSERT}{$Location}{$Bound}{rel_peak};

            $test_var = $current_max_duration/$hist_max_duration;

            $duration_ratio_var = $current_max_duration/$hist_max_duration;
            $rel_duration_ratio_var = $current_rel_duration/$hist_rel_duration;
            $peak_ratio_var = $current_max_peak/$hist_max_peak;
            $rel_peak_ratio_var = $current_rel_peak/$hist_rel_peak;

            $Temp_Comp_var = AssignCompValue($duration_ratio_var);
            $max_duration_format = AssignCompFormat($duration_ratio_var);
            $Comp_var = $Comp_var + $Temp_Comp_var;

            $Temp_Comp_var = AssignCompValue($rel_duration_ratio_var);
            $rel_duration_format = AssignCompFormat($rel_duration_ratio_var);
            $Comp_var = $Comp_var + $Temp_Comp_var;

            $Temp_Comp_var = AssignCompValue($peak_ratio_var);
            $max_peak_format = AssignCompFormat($peak_ratio_var);
            $Comp_var = $Comp_var + $Temp_Comp_var;

            $Temp_Comp_var = AssignCompValue($rel_peak_ratio_var);
            $rel_peak_format = AssignCompFormat($rel_peak_ratio_var);
            $Comp_var = $Comp_var + $Temp_Comp_var;
            $Temp_Comp_var = 0;

            if ($Comp_var > 50) { $review_var = "Review Again"; $review_format = $info_red_format; }
            elsif ($Comp_var > 20) { $review_var = $review_hash->{$Location}{$ASSERT}{$Bound}{status}; $review_format = $info_yellow_format; }
            else { 
              $review_var = $review_hash->{$Location}{$ASSERT}{$Bound}{status};
              if($review_var =~ m/No Issue/i) {$review_format = $info_green_format;}
              elsif($review_var =~ m/Waived/i) {$review_format = $info_green_format;}
              elsif($review_var =~ m/Pending/i) {$review_format = $info_yellow_format;}
              else {$review_format = $info_red_format;}
            }

            $comment_var = $review_hash->{$Location}{$ASSERT}{$Bound}{comments};

          } elsif (!$No_track_file) {
              $max_duration_format = $info_red_format;
              $max_peak_format = $info_red_format;
              $rel_duration_format = $info_red_format;
              $rel_peak_format = $info_red_format;
              $review_var = "New Assert";
              $review_format = $info_red_format;
              $comment_var = "";
          } else {
              $max_duration_format = $info_format;
              $max_peak_format = $info_format;
              $rel_duration_format = $info_format;
              $rel_peak_format = $info_format;
              $comment_var = "";
          }

          $worksheet1 -> write($r, $Max_Duration_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_duration}", $max_duration_format);
          $worksheet1 -> write($r, $Max_Peak_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_peak}", $max_peak_format);
          $worksheet1 -> write($r, $Max_Power_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_power}", $info_format);

          $worksheet1 -> write($r, $MD_rel2_MP_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_duration}", $rel_duration_format);
          $worksheet1 -> write($r, $MP_rel2_MD_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_peak}", $rel_peak_format);

          $worksheet1 -> write($r, $Time_rel2_MD_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_time_duration}", $info_format);
          $worksheet1 -> write($r, $Seq_rel2_MD_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_seq_duration}", $info_format);
          $worksheet1 -> write($r, $Job_rel2_MD_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_job_duration}", $info_format);
          $worksheet1 -> write($r, $Time_rel2_MP_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_time_peak}", $info_format);
          $worksheet1 -> write($r, $Seq_rel2_MP_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_seq_peak}", $info_format);
          $worksheet1 -> write($r, $Job_rel2_MP_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_job_peak}", $info_format);

          $worksheet1 -> write($r, $Max_Power_Count_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_power_count}", $info_format);
          $worksheet1 -> write($r, $Seq_rel2_MPow_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_seq_power}", $info_format);
          $worksheet1 -> write($r, $Job_rel2_MPow_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_job_power}", $info_format);

          my $current_assert_limit = ($asserts_hash->{$ASSERT}{$Location}{$Bound}{limit});
          if ($current_assert_limit != 0) {
            $MP_OS = ($asserts_hash->{$ASSERT}{$Location}{$Bound}{max_peak})/$current_assert_limit;
            $RMP_OS = ($asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_peak})/$current_assert_limit;
          } else {
            $MP_OS = 0;
            $RMP_OS = 0;
          }

          $worksheet1 -> write($r, $Max_Peak_Column_Overshoot, "$MP_OS", $info_format);
          $worksheet1 -> write($r, $MP_rel2_MD_Column_Overshoot, "$RMP_OS", $info_format);

          $worksheet1 -> write($r, $Count_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{count}", $info_format); 
          $Assert_type_count = $Assert_type_count + $asserts_hash->{$ASSERT}{$Location}{$Bound}{count};

          $worksheet1 -> write($r, $Limit_Column, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{limit}", $info_format);

          if ($No_track_file) {
            $worksheet1 -> write($r, $Review_Stat_Column, "Not Reviewed", $red_format);
            $worksheet1 -> write($r, $Review_Comments, "", $info_format);
          } else {
            $worksheet1 -> write($r, $Review_Stat_Column, $review_var, $review_format);
            $worksheet1 -> write($r, $Review_Comments, $comment_var, $info_format);
            $worksheet1 -> write($r, $Regression_History_Max_Dur, "$history_hash->{$ASSERT}{$Location}{$Bound}{max_duration}", $info_format);
            $worksheet1 -> write($r, $Regression_History_Max_Peak, "$history_hash->{$ASSERT}{$Location}{$Bound}{max_peak}", $info_format);
            $worksheet1 -> write($r, $Regression_History_Rel_Dur, "$history_hash->{$ASSERT}{$Location}{$Bound}{rel_duration}", $info_format);
            $worksheet1 -> write($r, $Regression_History_Rel_Peak, "$history_hash->{$ASSERT}{$Location}{$Bound}{rel_peak}", $info_format);
          }

        if ($argEnableRunTime) {
          $worksheet1 -> write($r, $Max_Power_Column_RT, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_power_wrt}", $info_format);
          $worksheet1 -> write($r, $Max_Power_Count_Column_RT, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{max_power_count_wrt}", $info_format);
          $worksheet1 -> write($r, $Seq_rel2_MPow_Column_RT, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_seq_power_wrt}", $info_format);
          $worksheet1 -> write($r, $Job_rel2_MPow_Column_RT, "$asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_job_power_wrt}", $info_format);
        }

      }
      undef $current_max_duration;
      undef $current_max_peak;
      undef $current_rel_duration;
      undef $current_rel_peak;
      undef $hist_max_duration;
      undef $hist_max_peak;
      undef $hist_rel_duration;
      undef $hist_rel_peak;
      undef $max_duration_format;
      undef $max_peak_format;
      undef $rel_duration_format;
      undef $rel_peak_format;
      $Comp_max_duration = 0;
      $Comp_max_peak = 0;
      $Comp_rel_duration = 0;
      $Comp_rel_peak = 0;
      $Comp_var = 0;
      $worksheet1 -> write($r, $Assert_Title_Column, "", $black_format); #Black out rows
      $r++;
    }
    ###### Grey Rows ######
    $worksheet1 -> write($Assert_Title_Spacer, $Instance_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Assert_Title_SpFr_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Review_Stat_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Max_Duration_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Max_Peak_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Max_Peak_Column_Overshoot, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Max_Power_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Max_Power_Count_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $MP_rel2_MD_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $MP_rel2_MD_Column_Overshoot, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Time_rel2_MD_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Seq_rel2_MD_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Job_rel2_MD_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $MD_rel2_MP_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Time_rel2_MP_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Seq_rel2_MP_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Job_rel2_MP_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Seq_rel2_MPow_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Job_rel2_MPow_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Limit_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Count_Column, "$Assert_type_count", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Bound_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Reviewer_Column, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Review_Comments, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Regression_History_Max_Dur, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Regression_History_Rel_Peak, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Regression_History_Max_Peak, "", $black_format); #Black out cols
    $worksheet1 -> write($Assert_Title_Spacer, $Regression_History_Rel_Dur, "", $black_format); #Black out cols
    if ($argEnableRunTime) {
      $worksheet1 -> write($Assert_Title_Spacer, $Max_Power_Column_RT, "", $black_format); #Black out cols
      $worksheet1 -> write($Assert_Title_Spacer, $Max_Power_Count_Column_RT, "", $black_format); #Black out cols
      $worksheet1 -> write($Assert_Title_Spacer, $Seq_rel2_MPow_Column_RT, "", $black_format); #Black out cols
      $worksheet1 -> write($Assert_Title_Spacer, $Job_rel2_MPow_Column_RT, "", $black_format); #Black out cols
    }

    ######################
    $Assert_type_count = 0;
  }

###################################################################################
# Create list of asserts that were in the last regression but are no longer seen. #
###################################################################################

CompRegToReg(); #Note using the exist function defines an empty key. If checked and not needed undef that key to avoid problems. Might be better to use defined function and not exists function.

my $row_var_comp_asserts = 0;

  $worksheet6 -> write($row_var_comp_asserts, 0, "ASSERT", $title_format);
  $worksheet6 -> write($row_var_comp_asserts, 1, "Instance", $title_format);
  $worksheet6 -> write($row_var_comp_asserts, 2, "Bound", $title_format);
  $worksheet6 -> write($row_var_comp_asserts, 3, "Regression", $title_format);

  $row_var_comp_asserts = $row_var_comp_asserts + 1;

  foreach my $create_comp_assert (sort keys %{$gone_hash}) {
    foreach my $create_comp_location (sort keys(%{$gone_hash->{$create_comp_assert}})) {
      foreach my $create_comp_bound (sort keys %{$gone_hash->{$create_comp_assert}{$create_comp_location}}) {
          $worksheet6 -> write($row_var_comp_asserts, 0, "$create_comp_assert", $info_format);
          $worksheet6 -> write($row_var_comp_asserts, 1, "$create_comp_location", $info_format);
          $worksheet6 -> write($row_var_comp_asserts, 2, "$create_comp_bound", $info_format);
          $worksheet6 -> write($row_var_comp_asserts, 3, "$argPastReg", $info_format);

          $row_var_comp_asserts = $row_var_comp_asserts + 1;
      }
    }
  }


#print Dumper(@assert_reported);
}


#######################################################################################
##################         Create Regression Tracking File          ###################
#######################################################################################

sub CreateRegTrackFile {

  my $track_max_duration;
  my $track_max_peak;
  my $track_rel_duration;
  my $track_rel_peak;
  my $New_location;

  if (!-d "${regression}" ) {
    run("mkdir -p ${regression}");
  }

  my $Reg_Track_File = "${regression}/Assert_History_Tracker.txt";

    print "Documentating asserts found in regression into Assert_History_Tracker.txt \n";
    open(CreatTrackingFILE, ">$Reg_Track_File") || die "\nERROR\nCan't read file '$Reg_Track_File'\n"; 

  foreach my $ASSERT (sort keys %{$asserts_hash}) {
#    print CreatTrackingFILE "${ASSERT}, ";
    foreach $Location (grep {s/(^|\D)0+(\d)/$1$2/g,1} sort grep {s/(\d+)/sprintf"%06.6d",$1/ge,1} keys(%{$asserts_hash->{$ASSERT}})) {
#      print CreatTrackingFILE "${ASSERT}, ${Location}, \n";
      foreach my $Bound (sort keys %{$asserts_hash->{$ASSERT}{$Location}}) {
        $track_max_duration = $asserts_hash->{$ASSERT}{$Location}{$Bound}{max_duration};
        $track_max_peak = $asserts_hash->{$ASSERT}{$Location}{$Bound}{max_peak};
        $track_rel_duration = $asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_duration};
        $track_rel_peak = $asserts_hash->{$ASSERT}{$Location}{$Bound}{relative_peak};

        $New_location = ${Location};

        $New_location =~ s/\|/\./g;

        print CreatTrackingFILE "${ASSERT}, ${New_location}, ${Bound}, ${track_max_duration}, ${track_max_peak}, ${track_rel_duration}, ${track_rel_peak}, \n";
      }
    }
  }

    close(CreatTrackingFILE);
}

#######################################################################################
##################         Create Regression Tracking File          ###################
#######################################################################################

sub ReadRegTrackFile {

  my $Past_Reg_Track_File = "${argPastReg}/Assert_History_Tracker.txt";

  print "Parsing last regression tracking file \n";
  open(ReadTrackingFILE, "$Past_Reg_Track_File") || die "\nERROR\nCan't read file '$Past_Reg_Track_File'\n"; 
  my @Past_Reg_Tracking_lines = <ReadTrackingFILE>;
  close(ReadTrackingFILE);

  #Create Hash from History File

  foreach my $Hist_Line (@Past_Reg_Tracking_lines) {
    $Hist_Line =~ /(\S+?), (\S+?), (\S+?), (\S+?), (\S+?), (\S+?), (\S+?),/;
    #1 - Assert
    #2 - Location
    #3 - Bound
    #4 - Max duration
    #5 - Max peak
    #6 - Rel duration
    #7 - Rel peak
    $history_hash->{$1}->{$2}->{$3}->{max_duration} = $4;
    $history_hash->{$1}->{$2}->{$3}->{max_peak} = $5;
    $history_hash->{$1}->{$2}->{$3}->{rel_duration} = $6;
    $history_hash->{$1}->{$2}->{$3}->{rel_peak} = $7;
  }

#  print "Past regression parsed \n";
#  print Dumper($history_hash);

}

###########################################################################################
##################         Review previous asserts spreadsheet          ###################
##########################################################################################

sub ReadRegReviewFile {

my $hash_data  = build_hash(parse_excel_file("${argPastReg}/${argPastReg}_Asserts.xlsx"));

my $review_assert;
my $review_instance;
my $review_status;
my $review_comments;
my $review_bound;

  foreach (sort {$a <=> $b} keys %{$hash_data->{"${argPastReg} Asserts"}}) {
    $review_assert = $hash_data->{"${argPastReg} Asserts"}{$_}{"Spotfire Assert"};
    $review_instance = $hash_data->{"${argPastReg} Asserts"}{$_}{"Instance"};
    $review_status = $hash_data->{"${argPastReg} Asserts"}{$_}{"Review Status"};
    $review_comments = $hash_data->{"${argPastReg} Asserts"}{$_}{"Reviewer Comments"};
    $review_bound = $hash_data->{"${argPastReg} Asserts"}{$_}{"Bound Broken"};

    $review_hash->{$review_instance}->{$review_assert}->{$review_bound}->{status} = $review_status;
    $review_hash->{$review_instance}->{$review_assert}->{$review_bound}->{comments} = $review_comments;

    undef $review_assert;
    undef $review_instance;
    undef $review_status;
    undef $review_comments;
  }

undef $hash_data;

}

###########################################################################################
##################         Review previous asserts spreadsheet          ###################
##########################################################################################

sub CompRegToReg {

my $rand_hash = {};
my $test_hash = {};

  $rand_hash = $history_hash;
  $test_hash = $asserts_hash;

  foreach my $comp_assert (sort keys %{$rand_hash}) {
    foreach my $comp_location (sort keys(%{$rand_hash->{$comp_assert}})) {
      foreach my $comp_bound (sort keys %{$rand_hash->{$comp_assert}{$comp_location}}) {
        if(exists $test_hash->{$comp_assert}{$comp_location}{$comp_bound}) {}
        else {$gone_hash->{$comp_assert}->{$comp_location}->{$comp_bound} = "Not Seen";}
      }
    }
  }

}

###############################################################################
##################         Assign a compare value           ###################
###############################################################################

sub AssignCompValue {

  my $local_comp_ratio = shift;
  my $new_comp_value = 0;

  if ($local_comp_ratio > 2) { $new_comp_value = 100;}
  elsif ($local_comp_ratio > 1.9) {$new_comp_value = 90;}
  elsif ($local_comp_ratio > 1.8) {$new_comp_value = 80;}
  elsif ($local_comp_ratio > 1.7) {$new_comp_value = 70;}
  elsif ($local_comp_ratio > 1.6) {$new_comp_value = 60;}
  elsif ($local_comp_ratio > 1.5) {$new_comp_value = 50;}
  elsif ($local_comp_ratio > 1.4) {$new_comp_value = 40;}
  elsif ($local_comp_ratio > 1.3) {$new_comp_value = 30;}
  elsif ($local_comp_ratio > 1.2) {$new_comp_value = 20;}
  elsif ($local_comp_ratio > 1.1) {$new_comp_value = 10;}
  elsif ($local_comp_ratio > 1.05) {$new_comp_value = 5;}
  else {$new_comp_value = 0;}

return $new_comp_value;

}

sub AssignCompFormat {

  my $local_comp_ratio = shift;
  my $new_comp_value = 0;

  if ($local_comp_ratio > 1.1) { $new_comp_value = $info_red_format;}
  elsif ($local_comp_ratio > 1.05) {$new_comp_value = $info_yellow_format;}
  else {$new_comp_value = $info_green_format;}

return $new_comp_value;

}


###################################################################################
##################           Determine Job Run Times            ###################
###################################################################################

sub FindRunTimes {

  foreach my $log_file (@all_jobs_irunlog) {

    $log_file =~ /\/\S+?\/\S+?\/\S+?\/(.+?)\/create\/(.+?)\/(.+?)\/(.+?)\/psf\/irun.log/;
    my $runtime_regression = $1;
    my $runtime_stimulus = $2;
    my $runtime_sequence = $3;
    my $runtime_jobnum = $4;

    my $runtime_val;

    print "Scanning $runtime_sequence - $runtime_jobnum IRUN log \n";

    open(INFILE, $log_file) || die "\nERROR\nCan't read file '$log_file'\n"; 
    my @log_lines = <INFILE>;
    close(INFILE);

    foreach my $log_line (@log_lines)
    {
      # Example #
      # Simulation stopped via transient analysis stoptime at time 15028043 NS
      if($log_line =~ /Simulation stopped via transient analysis stoptime at time (\S+?) (\S+?)$/) {
          my $Store_runtime = $1;
          if    ($2 =~ /FS/) {$runtime_val = $Store_runtime * 0.000000000000001;}
          elsif ($2 =~ /PS/) {$runtime_val = $Store_runtime * 0.000000000001;}
          elsif ($2 =~ /NS/) {$runtime_val = $Store_runtime * 0.000000001;}
          elsif ($2 =~ /US/) {$runtime_val = $Store_runtime * 0.000001;}
          elsif ($2 =~ /MS/) {$runtime_val = $Store_runtime * 0.001;}
          else               {$runtime_val = 0;}
          $runtime_hash->{$runtime_stimulus}->{$runtime_sequence}->{$runtime_jobnum} = $runtime_val;
      }
    }

  if (!defined $runtime_hash->{$runtime_stimulus}->{$runtime_sequence}->{$runtime_jobnum}) {
    print "Warning - $runtime_sequence - $runtime_jobnum did not record transisent run time. \n";
    print "\t Setting runtime equal to 1 to avoid skewing results. \n";
    $runtime_hash->{$runtime_stimulus}->{$runtime_sequence}->{$runtime_jobnum} = 1;
  }

  }
}


################################################################################
## EXCEL data manipulation
################################################################################
sub parse_excel_file { # Excel file parse into a workbook object hash
  my ($filename) = @_; # Subroutine arguments
  my $workbook;
  my $parser = Spreadsheet::ParseExcel->new(); # Creates parser object for XLS files
  if (!(-e $filename)) {
    error(__LINE__,"Excel workbook does not exist: $filename");
  }
  elsif ($filename =~ /^\S+\.xls$/ ) { # Parses XLS  file into a workbook object hash
    $workbook = $parser->parse($filename);
  }
  elsif ($filename =~ /^\S+\.xlsx$/) { # Parses XLSX file into a workbook object hash
    $workbook = Spreadsheet::XLSX->new($filename);
  }
  else {
    error(__LINE__,"Not a valid Excel workbook: $filename is not an Excel workbook");
  }
  return $workbook; # Returns workbook hash reference pointer
}

sub build_hash { # Build 3-level deep hash using Excel parsed hash
  my ($workbook) = @_; # Subroutine arguments
  my %data;
  foreach my $sheet (@{$workbook->{Worksheet}}) {
    my $key1 = $sheet->{Name}; # KEY1: Worksheets (TAB) within a workbook are keys
    foreach my $row (1 .. $sheet->{MaxRow}) {
      my $key2;
      if ($key1 eq "config") {
        $key2 = $sheet->{Cells}[$row][0]->{Val}; # KEY2: Each row cell in column 0 (1st column of worksheet) are keys
      }
      else {
        $key2 = $row; # KEY2: Each row number are keys starting with 1
      }
      foreach my $col (0 .. $sheet->{MaxCol}) {
        my $key3 = $sheet->{Cells}[0][$col]->{Val}; # KEY3: Each column cell in row 0 (1st row of worksheet) are keys
        $data{$key1}{$key2}{$key3} = trim_ws($sheet->{Cells}[$row][$col]->{Val}); # HASH: 3-level {worksheet}{column 0}{row 0} deep hash
      }
    }
  }
  #dprint(2,Dumper \%data);
  return \%data; # Returns 3-level deep hash reference pointer
}

sub trim_ws { # Trim leading & trailing whitespace around any input
  my ($path) = @_;
  $path =~ s/^\s+|\s+$//g;
  return $path;
}

sub defined_cell { # Check if cell is valid
  my ($cell) = @_;
  my $valid = $cell =~ /^.*\S+.*$/ ? 1 : 0;
  return $valid;
}



#############################################################
#############################################################
#############################################################
#############################################################


sub error {
  my $err_msg    = shift;
  my $fatal_bool = shift;

  print "ERROR: ", $err_msg, " ($!)\n";    # Calls and prints CPU error message
  if ($fatal_bool) { die; }   # handle fatal error
}

#############################################################
#############################################################

###################################
# Read Regstat config spreadsheet #
###################################

# Original Subroutine taken from Regstat
# Tweaked to support different flows

sub read_job_file {
  my ($loJobFileName) = @_;

  $loJobFileName = "$loJobFileName";

  # Verify XLSPath and file 
  unless (-e "$loJobFileName") { die "Could not find $loJobFileName\n"; }

  # Open regression management XLS
  my $parser   = Spreadsheet::ParseExcel->new();
  my $workbook = $parser->parse($loJobFileName);

  if ( !defined $workbook ) {
    die $parser->error(), ".\n";
  }

  my $jobsheet;

  if (defined $argCurrentReg) {
    $jobsheet = $workbook->worksheet("${argCurrentReg}");
  }
  else {
    $jobsheet = $workbook->worksheet('Sheet1');
  }

  if ( !defined $jobsheet ) {
    die $parser->error(), ".\n";
  }

  my $cur_row = 0;
  my $locurrCategory = 1;
  my $loLastCategory = 0;
  my $locurrCDSJob;
  my $locurrLocation;
  my $loJobFileRecord = {};  # create a hash reference for job records
  #share($loJobFileRecord);
  my $loCategory;
  my $loCdsJobName;
  my $loCdsPath;
  my $currCell = "";
  $currCell = $jobsheet->get_cell(++$cur_row,0);

  print "\nReading input XLS...\n";

  while(defined $currCell)
  {
    #Skip blank cells
    if ($jobsheet->get_cell($cur_row,1)->unformatted() eq "") {
      $currCell = $jobsheet->get_cell(++$cur_row,0);
      next;
    }
    
    #These vars are used to build the path to the job irun.log files
    $locurrCategory = $jobsheet->get_cell($cur_row,1)->unformatted();
    $locurrCDSJob   = $jobsheet->get_cell($cur_row,2)->unformatted();
    $locurrLocation = $jobsheet->get_cell($cur_row,3)->unformatted();
      
    print "$locurrCategory->$locurrCDSJob->$locurrLocation\n";

    # New category
    if($locurrCategory ne $loLastCategory) {
      $loCategory = $locurrCategory;

      # Add new category record to hash
      #$loJobFileRecord->{$loCategory} = &share({});
      #$glSummaryRecord->{$loCategory} = &share({});
      $glSummaryRecord->{$loCategory}->{"UpdateGUI"} = 0;
      $glGUITableRecord->{$loCategory} = {};
      $glSummaryRecord->{$loCategory}->{"NumPending"} = 0;
      $glSummaryRecord->{$loCategory}->{"NumRunning"} = 0;
      $glSummaryRecord->{$loCategory}->{"NumFailed"} = 0;
      $glSummaryRecord->{$loCategory}->{"NumComplete"} = 0;
      $glSummaryRecord->{$loCategory}->{"NumTotal"} = 0;
    }

    $loCdsJobName = $locurrCDSJob;

    # Add new CdsJob record to hash
    #$loJobFileRecord->{$loCategory}->{$loCdsJobName} = &share({});
    #$glSummaryRecord->{$loCategory}->{$loCdsJobName} = &share({});
    $glGUITableRecord->{$loCategory}->{$loCdsJobName} = {};
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"UpdateGUI"} = 0;
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"NumPending"} = 0;
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"NumRunning"} = 0;
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"NumFailed"} = 0;
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"NumComplete"} = 0;
    $glSummaryRecord->{$loCategory}->{$loCdsJobName}->{"NumTotal"} = 0;


    if ($Flow_type == 0) {$loCdsPath = $locurrLocation."/create/".$locurrCategory."/".$locurrCDSJob."/";}
    elsif ($Flow_type == 1) {$loCdsPath = $locurrLocation."/".$locurrCDSJob."/";}
    elsif ($Flow_type == 2) {$loCdsPath = $locurrLocation."/".$locurrCategory."/".$locurrCDSJob."/";}
    else {$loCdsPath = $locurrLocation."/create/".$locurrCategory."/".$locurrCDSJob."/";}

    $loJobFileRecord->{$loCategory}->{$loCdsJobName}->{"SimDir"} = $loCdsPath;
    $loJobFileRecord->{$loCategory}->{$loCdsJobName}->{"MonFileName"} = $loCdsPath."sweep_map.txt";
    $loJobFileRecord->{$loCategory}->{$loCdsJobName}->{"MonStatus"} = "netlist";
    $loLastCategory = $locurrCategory;

    $currCell = $jobsheet->get_cell(++$cur_row,0);
  }

  return $loJobFileRecord;
}


__END__

=head1 NAME

LBC_Asserts_RegressParse.pl - Scans assert.out files in a regression specified by a regstat file.

=head1 SYNOPSIS

LBC_Asserts_RegressParse.pl [options] 

    ***This script requires configuration on a project by project basis. Please update the configuration section within the script.***

     Options:
       -help                Brief help message
       -xls <string>        Re-use existing jobfile.
       -output <string>     Specify a unique name for the corresponding output XLSX file
       -onejob              Onejob option will parse only the first assert.out file found
       -debug               Debug option for detailed print output (Ignore)
       -filter              Filter option will filter OUT any sequences specified in the configuration section of the script (Filter takes precedence over select)
       -select              Select option will select any sequences specified int he configuration section of the script 
       -list                Option define your own list of sequences to scan for. (Filter or select options still apply)
       -Reg                 Specify the current regression tag. (Regstat xls tabs should be named by this tag)
       -LastReg <string>    Specify the tag of the last regression ran to compare against (Be sure the updated asserts document is in tagged directory as well)
       -retain              Retain option will not create/overwrite the Asserts_History_Tracking file.
       -flow                Specify what type of regression flow (Not specified\typo default farmEXE) -> [Available options: farmEXE, ADEXL, Vman, Gfarm]

       Example basic command:     ../bin/AssertsExtraction.pl -xls ../xls/regstat_968N.xls -Reg RA0_1p2 -LastReg RA0_1p1
       Example advanced command:  ../bin/AssertsExtraction.pl -xls ../xls/regstat_968N.xls -filter -list SCM_1 SCM_2 -Reg RA0_1p2 -LastReg RA0_1p1 -retain -flow farmEXE

       ***Please also note that the config file must be in an acceptable format based on flow type.

=head1 DESCRIPTION

B<LBC_Asserts_RegressParse>  Scans assert.out files in a regression specified by a regstat file.

=cut

