#!/usr/bin/perl


use Env;
use Cwd;
use Getopt::Long;
use File::Basename;
use File::Copy;
#oc use Verilog::Readmem qw(parse_readmem);
&Getopt::Long::Configure("pass_through","no_getopt_compat");

#oc #a2i2 add current scripts dir to @INC so that partcode module can be found
#oc use File::Basename qw(dirname);
#oc use Cwd qw(abs_path);
#oc use lib dirname(abs_path $0);
#oc use partcode qw(Bin2Mem);
#oe another way of adding current scripts dir to @INC
use FindBin;
use lib $FindBin::Bin;

require "utils.pl";

use strict;

$SIG{INT} = \&CatchCtrlC;

# Save off command used to invoke script
my $cmdline = GetCmdLine();

my $usage = <<"HELP";

################################################################################
# Usage:
#  Use the following for simulating your verilog or AMS testcase with/wo a UVM testcase
#  sim_ams [<verilog_or_ams_testcase>] [-uvm <uvm_testcase>] <config> <sim switch options> <switch options> [-passthru "<pass-thru args>"]
#          <config> Choose and config given in the lib/tb cadence library view.  config_dig is chosen by default if the
#          -config switch option is not provided, for digital sims.
#
# Key: [] = optional, <> = specify
#
################################################################################
#
# sim switch options:                
# -help                   : print this message
# -clean                  : remove all contents from config/netlist directory and build from scratch
# -clean_after            : remove all contents from sim directory except irun log and coverage db
# -defparam <name=value>  : Redefine a parameter value (this option can be invoked multiple times)
# -define <name=value>    : Pass a macro definition to the simulator (this option can be invoked multiple times)
# -plusarg <name=value>   : Pass a plusarg to the simulator (this option can be invoked multiple times)
# -gates                  : prepares the simulation database using the netlist version of the dut instead of rtl
# -sdf  <sdf corner>      : used for selectting fast or slow delays for sdf annotation. Expected to be used with the
#                           -gates switch or the -scan switch
# -scan <test>            : Run scan sims. Choose from <first5,full,parallel,shift>
# -dir <rel. path>        : specify results directory in project dv directory (sim_results)
# -cov                    : Enable code & functional coverage data generation (uses cov.ccf configuration file to control instrumentation)
# -vrb <verbosity>        : Set verbosity level of vmm_log messages to <my %vrbLevel = UVM_NONE,UVM_LOW,UVM_MEDIUM,UVM_HIGH,UVM_FULL>
# -uvm_db                 : Turn on tracing of UVM resource and config db accesses
# -breakon <level>        : Set the exception level at which the simulation will exit <WARNING|ERROR|FATAL(default)>
# -breakafter <#>         : Set the number of exceptions to reach before the simulation will exit
# -svseed <random|#>      : If arg is "random", the a random seed will be automatically
#                           generated. Otherwise, the argument value will be used as the
#                           seed value for the SystemVerilog RNG. The seed value used
#                           will be stored in the file 'svseed.txt'. If -svseed is not specified
#                           a seed value of '1' will be used.
# -gui                    : opens SimVision with simulation attached at time 0.
# -shm                    : causes waveforms to be dumped to an SHM database (for SimVision)
# -fsdb                   : causes fsdb waves to be dumped (for nWave)
# -vcd                    : causes vcd waves to be dumped  (for tester input & conversion to .wgl)
# -raw_otp                : causes OTP to act as if unprogrammed (raw) by not populating the burn check bits with the proper value
# -dump <filename>        : specify location of verilog module to replace the default waveform dumping
#                           in dv/harness/wave.v.  the module should contain one or more verilog initial
#                           blocks which specify a list of waveform dumping system tasks. the module may
#                           also specify timing controls that allow wave dumping to occur during
#                           a user-specified interval.
#
# -config                 : name of configuration to run. Must match one of the configurations created in lib/tb cell
#
# -p [process]            : specify which process models to use.  Choose from {nominal, strong, weak, skewnp, skewpn}.
#                           if no process is given, the sim will default to nominal if nothing is entered.
#
# -vin [voltage]          : specify what VIN voltage to use.  If non is selected, then testbench default is used
#
# -v1p8 [voltage]          : specify what V1P8 voltage to use.  If non is selected, then testbench default is used
#
# -v [voltage]            : specify what the LDO voltage is (default is 1.3) used to link the correct sdf.Choose from {1.3, 1.4 & 1.5}  
#
# -float_check            : places spectre control file in models for floating node check
#
# -temp [temp in *C]      : Specify the simulation temperature.  Defaults to 27*C.
# -setd setd_file_name    : Option allows to pull in a setd file different than the default.
# -skipcount [#]            This tells the analog simulator to skip the given number sim points when saving
#                           waveforms.  This is useful for speeding up long sims and reducing the size of
#                           the results, but sacrices wavefrom quality.
# -debug                    This switch envokes some spectre settings that spit out more information that can
#                           can be used to debug sim time and convergence issues.  This switch also sets the
#                           +define+SIM_TIMER option so that the sim_timer module is activated.
# -loose                  : sets analog simulator to very liberal settings.  Sometimes useful to speed up sims
#                           at the expense of less accuracy
#                           The default time is set in the default state. This switch overrides the default time
# -errpreset              : Set the analog solver setting errpreset (liberal conservative moderate)
#
# -stash                  : This option is to point to alternative simulation directories.  Meant to be a number 1,2,3, etc.
#
# -psfxl                  : Set waveform format to psfxl
#
# -sim_num                : Used to organize results directory.  Putting in number here adds "SIM#" to the results path
#
# <pass-thru args>        : any options placed here will be blindly passed to simv during run.
#
# -passthru                 Pass-thru args are here...commonly used ones are:
#                             +max_delay    : use maximum delays from sdf and delay specifications
#                                             * requires -gates option
#                             +min_delay    : use minimum delays from sdf and delay specifications
#                                             * requires -gates option
#                             +vcs+lic+wait : wait for vcs license
#
# -netlist                : Create a top-level netlist.  Does not have to run simulation.  If -config is not specified, dig
#                           netlist is created and placed into abm area.
# -asserts                : Turn on spice assert checking and output to psf only
# -asserts_full           : Turn on spice assert checking and send to log file (asserts.out)
# -tparam  <filename>     : Use paramset file  given by <filename> to control temperature in a spectre only transient sim 
#                           Assumes <filename> location is in dv/paramsets and paramset variable name is "pset1"
# -tcl <filename>         : TCL file containing simulation setup instructions is passed-in
#
# ---------------------------------------------------------------------------------------------------
# Switch options:
#
# -uvm <uvm_tc>                  : Include a uvm testcase
# -mbist                         : Run mbist sims.
# -id <name>                     : append an additional unique suffix to simulation directory. (default = none)
# -noabv                         : Turn off assertion-based verification statements, which must be encapsulated
#                                  in a `ifdef ABV_ON...`endif define block
# -noabvclk                      : Turn off assertion-based verification statements only for clocks, which must be encapsulated
#                                  in a `ifdef ABV_ON_CLK...`endif define block
# -nousecase                     : Turn off assertion-based verification statements only for use cases, which must be encapsulated
#                                  in a `ifdef USE_CASE_ON...`endif define block
#
# ---------------------------------------------------------------------------------------------------

HELP

my $script_status = <<"SCRIPT_STATUS";

################################################################################
# sim_ams status:
#
# SUMMARY: 
#
# Status of command line options:
#
# -gates                  : use with -sdf option, not yet tested
# -sdf  <sdf corner>      : annotate netlist, not yet tested
# -scan <test>            : not yet tested
# -dir <rel. path>        : not yet tested
# -mbist                  : not yet tested
#
# ---------------------------------------------------------------------------------------------------

SCRIPT_STATUS


#-------------------------------------------------------------------------
# Parse the command line
#-------------------------------------------------------------------------
my $help;
my $gates;
my $sdf  = "";
my $sdfset = 0;
my $scan = "";
my $scanset = 0;
my $clean;
my $clean_after;
my $svseed;
my $rsltsDir;
my $config = "config_dig";
my $configsDir = "configs";
#bcm my $vrbLvl = "UVM_LOW";
my $vrbLvl = "UVM_NONE";
my %vrbLevel = ('UVM_NONE',-1,'UVM_LOW',0,'UVM_MEDIUM',1,'UVM_HIGH',2,'UVM_FULL',3,
                'NONE',    -1,'NOTE',   0,'TRACE',     1,'DEBUG',   2,'VERBOSE' ,3);
my $breakonTyp;
my %breakonTyp = ('INFO',-1,'WARNING',0,'ERROR',1,'FATAL',2);
my $breakafter;
my $buildopts;
my @defparam;
my @define;
my @plusarg;
my $id;
my $coverage = 0;
my $covfile = "cov.ccf";
my $shm;
my $fsdb;
my $vcd;
my $gui = 0;
my %process = ('nominal',1,'weak',2,'skewpn',3,'skewnp',4,'strong',5);
my $p = 'nominal';
my $vin = 0.0;
my $v1p8 = 0.0;
my $volt= '0';
my $scalefactor = 1;
my $temp = 27;
my $setd = "";
my $errpreset = 'liberal';
my $stash;
my $psfxl;
my $corner;
my $float_check;
my $skipcount = 0;
my $debug;
my $passthru;
my $incr;
my $loose;
my $maxstep;
my $netlist;
my $asserts;
my $asserts_full;
my $tparam;
my $ida = 0;
my $tcl = "";
my $tcf = 0;
my $raw_otp = 0;

# From RunIK
my $uvm            = 0;
my $uvm_db         = 0;
#g Removed use of uvm test case for Gusto
#g my $uvm_testname   = "";
my $mbist          = 0;
my $noabv          = 0;
my $no_abvclk      = 0;
my $nousecase      = 0;
#my $runid          = "";
my @cdefs;
my $simopts = "";
my $tcopts = "";
my $simopts_cov = "";
my $sim_num;



$svseed="";
$rsltsDir  = "sim_results";
#x $vrbLvl = "NOTE";
$breakonTyp = "FATAL";
$breakafter = 1;

#x print "xxx Command is @ARGV \n";

&GetOptions(
            "tcl=s"       => \$tcl,
            "ida"         => \$ida,
            "raw_otp"     => \$raw_otp,
            "sdf=s"       => \$sdf,
            "clean"       => \$clean,
            "clean_after" => \$clean_after,
            "help"        => \$help,
            "svseed=s"    => \$svseed,
            "dir=s"       => \$rsltsDir,
            "config=s"    => \$config,
            "cfgdir=s"    => \$configsDir,
            "vrb=s"       => \$vrbLvl,
            "breakon=s"   => \$breakonTyp,
            "breakafter=s"=> \$breakafter,
            "gates"       => \$gates,
            "scan=s"      => \$scan,
            "buildopts=s"     => \$buildopts,
            "defparam=s@" => \@defparam,
            "define=s@"   => \@define,
            "plusarg=s@"  => \@plusarg,
            "id=s"        => \$id,
            "cov"         => \$coverage,
            "fsdb"        => \$fsdb,
            "vcd"         => \$vcd,
            "gui"         => \$gui,
            "shm"         => \$shm,
            "p=s"         => \$p,
            "vin=s"       => \$vin,
            "v1p8=s"       => \$v1p8,
            "v=s"         => \$volt,
            "float_check" => \$float_check,
            "temp=s"      => \$temp,
            "setd=s"      => \$setd,
            "errpreset=s" => \$errpreset,
            "stash=s"     => \$stash,
            "psfxl"       => \$psfxl,
            "skipcount=s" => \$skipcount,
            "debug"       => \$debug,
            "passthru=s"  => \$passthru,
            "incr"        => \$incr,
            "loose"       => \$loose,
            "netlist"     => \$netlist,
            "asserts"     => \$asserts,
            "asserts_full"=> \$asserts_full,
            "tparam=s"    => \$tparam,
            "sim_num=s"   => \$sim_num,
#from RunIK
            "uvm_db"      => \$uvm_db,
#g             "uvm=s"       => \$uvm_testname,
            "mbist"       => \$mbist,
#            "id=s"        => \$runid,
            "noabv",      => \$noabv,
            "noabvclk",   => \$no_abvclk,
            "nousecase",  => \$nousecase

           ) or die "Could not parse command line arguments:\n\n$usage";

if ($help) {
  print "$usage\n";
  exit;
}

print "$script_status\n";


################################################################################
# Usage Checks
################################################################################

#dls ($#ARGV >= 1) or die "$usage";

#-------------------------------------------------------------------------
# scan usage checks
#-------------------------------------------------------------------------
unless ($scan eq "") {
    $scan = lc($scan);
    if (($scan eq "first5") or ($scan eq "full") or ($scan eq "parallel") or ($scan eq "shift")) {
        $scanset = 1;
    } else {
        die "Unrecognized argument for -scan option.  -scan option must be followed with first5 or full or parallel or shift.";
    }
}

###TODO...what corners to support? Get this going later...we need to support multiple temperature/voltage/process corners
###       mimic what was done for directory names using $corner

#-------------------------------------------------------------------------
# sdf usage checks
#-------------------------------------------------------------------------
my $sdf_delay = "";
my $sdf_type = "";
my $vldo = "";

unless ($sdf eq "") {
    $sdf = lc($sdf);
    if (($sdf eq "fast") or ($sdf eq "min") or ($sdf eq "slow") or ($sdf eq "max") or ($sdf eq "nom") or ($sdf eq "cw") or ($sdf eq "typ")) {
        $sdfset = 1;
        if (($sdf eq "fast") or ($sdf eq "min")) {
            $sdf_delay = "min"; $sdf_type = "min"; }
        if (($sdf eq "slow") or ($sdf eq "max")) {
            $sdf_delay = "max"; $sdf_type = "max"; }
        if (($sdf eq "nom") or ($sdf eq "typ")) {
            $sdf_delay = "typ"; $sdf_type = "typ"; }
        if ($sdf eq "cw")   {
            $sdf_delay = "max"; $sdf_type = "cw" ; }
        if ($volt eq "1.5") { $vldo = "1_5";
        } elsif($volt eq "1.4") { $vldo = "1_4";
        } else {$vldo = "1_3";
        }
    } else {
        die "Unrecognized argument for -sdf option";
    }
}

die "SDF timing annotation can only be used with '-gates', '-scan' or '-gates -mbist' command line options" if (($sdfset == 1) and ($gates == 0 && $scanset == 0));


#-------------------------------------------------------------------------
# temperature range usage check
#-------------------------------------------------------------------------
  (-50 <= $temp  && $temp <= 150) or die "$temp is an invalid temperature entry . \n    Choose a temperature between -50 to +125\n";

#-------------------------------------------------------------------------
# voltage range usage check
#-------------------------------------------------------------------------
  
#checking for number range and adding +/- if needed
#oe change $volt to whatever is needed for the analog catz(vin and vio)
#oe  if ($volt=~ /[.0-9]+/) {
#oe    if($volt!~ /[+]/ ){
#oe      if($volt!~ /[-]/ ){
#oe        $volt= "+" . $volt;
#oe      }
#oe    }
#oe    if(-99 <= $volt&& $volt<=99) {
#oe      $scalefactor = 1 + $volt*0.01;
#oe    }
#oe    else {
#oe      die "INVALID percentage for voltage\n";
#oe    }
#oe  }
#oe  else {
#oe      die "INVALID input for voltage\n";
#oe  }
    
#-------------------------------------------------------------------------
# process usage check. ## check process matches one of the options
#-------------------------------------------------------------------------
#TODO...define other corners like cold_weak and strong_fast and voltages
($process{$p}) or die "Invalid process corner $p. \n    Choose from : {nominal, strong, weak, skewnp, skewpn}\n";


$vrbLvl = uc($vrbLvl);

#-------------------------------------------------------------------------
# grab testcase name
#-------------------------------------------------------------------------
my $sim = shift;

################################################################################
# Directory name parsing and creation
################################################################################

#-----------------------------------------------------
# Set up directory and file pointers
#-----------------------------------------------------
# Get Project Name
# Assumes that the project name is the 2nd level of the
# directory structure and workspace is 4th level, as is
# typical of SANC projects (ie /data/<projname>/<user>/<workspace>)
my $volume;
my $progdir;
my $filename;
($volume, $progdir, $filename)= File::Spec->splitpath(File::Spec->rel2abs(__FILE__));
my @dirsplit  = split('\/', $progdir);
my $projname  = $dirsplit[2];
my $user      = $ENV{USER};

#-------------------------------------------------------------------------
# Find the path to this executable and use it as a path to the
# project information
#-------------------------------------------------------------------------
my $dvdir;
#$dvdir = Cwd::abs_path($0);
$dvdir = File::Spec->rel2abs(__FILE__);
$dvdir =~ s/\/scripts\/sim_ams$//;
#oe above 2 lines work when using FindBin
#bcm $dvdir = Cwd::getcwd;
#bcm $dvdir =~ s/\/scripts//;
(-d $dvdir) or die "cannot determine project directory $dvdir";
my $tcdir = $dvdir . "/digital/stimulus";
(-d $tcdir) or die "cannot determine project test case directory $tcdir";
  
#---------------------------------------------------------------------------
# All project specific information is put in a file called project_setup.pm
# which is located in the scripts directory
# The constants could probably be used directly instead of assigning to
# variables and then using the variables elsewhere, but I thought this is
# a little cleaner such that someone could find where the constants are
# coming from a little easier.
#---------------------------------------------------------------------------
use project_setup;

#x use constant LOCAL_MODELS  => '-modelfile \'./svn/abm/spice/WLEDapple.scs\' -modelfile \'./svn/abm/spice/nsr0240v2t1g.scs\'';
use constant LOCAL_MODELS  => '';
#x use constant SPEC_MODELS   => '-modelfile \'/data/pdkoa/lbc8lv/current/models/spec/model.paths.scs\'';
use constant SPEC_MODELS   => '';

my $revcon_path      = REVCON_PATH;
my $tb_top_lib       = TB_TOP_LIB;
my $tb               = TB;
my $design_lib       = DESIGN_LIB;
my $dig_top          = DIG_TOP;
my $scan_top_name    = SCAN_TOP_NAME;
my $rev_ctrl_tool    = REV_CTRL_TOOL;
my $dssc_format      = DSSC_FORMAT;
my $netlister_ver    = NETLISTER_VER;
my $local_models     = LOCAL_MODELS;
my $spec_models      = SPEC_MODELS;


#--------------------------------------------------------------------------------
# $work assumes project structure of the format <project>/<user>/<workspace_name>
#--------------------------------------------------------------------------------

# Local variables (also available in subroutines)
my $cwd              = cwd();   # Get current directory

# Common variables
my $workspace        = $dvdir;
$workspace           =~ s/.*\/$user\/(.*)\/dv.*/$1/;
my $work             = $dvdir;
$work                =~ s/(.*)\/dv.*/$1/;
my $digdir           = $work . "/digital";

# sim variables
my $memdir           = $dvdir;
my $modelsdir        = $work . "/dv/abm";
my $sram_name        = "sshdbw3mll00256022040";
my $sram_modeldir    = $work . "/memory_ip/$sram_name/cad_models/verilog";
my $netdir           = $digdir . "/netlist";
my $rtldir           = $digdir . "/rtl";
my $cdsdir           = $work . "/cds";
my $cnfgDir;
my $dir;

# RunIK variables
#g my $testsdir       = $dvdir . "/tests";                                     # Tests directory
my $testsdir       = $tcdir;                                                # Tests directory
my $toolsdir       = $dvdir . "/tools";                                     # Simulation tools
my $vectdir        = ".";                                                   # vector directory is relative to dir sim is run from
my $logsdir        = ".";                                                   # log directory is relative dir sim is run from
my $scandir        = $digdir . "/atpg/verilog_output_files";             # scan code directory
my $mbist_rtldir   = $digdir . "/mbist";                                    # mbist RTL code directory
my $toplvlnetdir   = $digdir . "/netlist";                                  # top-level netlist directory
#g my $tbenchdir      = $dvdir . "/tb";                                        # testbench directory
my $tbenchdir      = $dvdir . "/includes";                                  # testbench directory
my $scriptsdir     = $dvdir . "/scripts";                                   # scripts directory
#g my $uvm_tc_dir     = $dvdir . "/uvm_tc";                                         # UVM testcases directory
my $tc_simdir;     # Testcase simulation directory.  Set dynamically based on testcase name

my $rundir;        # Note $rundir is set dynamically below based on testcase

my $cmd_log        = "sim_ams.cmd";
#g my $uvm_test_default = "test_default";
my $vc_uvm        = "";
my $vc1           = "";
my $vc2           = "";
my $v             = "";

#g # If a uvm testcase was specified, set the uvm flag
#g if ($uvm_testname eq "") {
#g   $uvm_testname = $uvm_test_default;
#g }
#g else {$uvm = 1;}


#################################################################################
## Setting environment variables needed for netlisting/simulation
#################################################################################
my $artisan_simdir;
my $tilib;
my $artisan_tiprocess;
my $artisan_pdkver;
my $artisan_pdkpath;
my $artisan_db_type;
my $artisan_digmodelpath;
    
open(ENVFILE, "< $work/artisan.cdsrc") or die "Could not open file: artisan.cdsrc in dir: $work \n";
  while(<ENVFILE>) {
    if(m/ARTISAN_SIMDIR +(.*$)/) {
      $artisan_simdir = $1;
    }
    if(m/TILIB +(.*$)/) {
      $tilib = $1;
    }
    if(m/ARTISAN_TIPROCESS +(.*$)/) {
      $artisan_tiprocess = $1;
    }
    if(m/ARTISAN_PDKVER +(.*$)/) {
      $artisan_pdkver = $1;
    }
    if(m/ARTISAN_DB_TYPE +(.*$)/) {
      $artisan_db_type = $1;
    }
    if(m/ARTISAN_PDKPATH +(.*$)/) {
      $artisan_pdkpath = $1;
    }
    if(m/ARTISAN_DIGMODELPATH +(.*$)/) {
      $artisan_digmodelpath = $1;
    }
  }
# print "aaa artisan_digmodelpath = $artisan_digmodelpath \n";

my $configdirexists  = 1;
my $resultsdirexists = 1;
my $digital_sim      = 1;


# This is a testcase name, but it may not have been provided since it could only be using a uvm tc
my $testCase               = $sim;
my $testCaseFullVerilog    = "$tcdir/$testCase.v";
my $testCaseFullSv         = "$tcdir/$testCase.sv";
my $testCaseFullVams       = "$tcdir/$testCase.vams";
my $testCaseVerilog        = "$testCase.v";
my $testCaseSv             = "$testCase.sv";
my $testCaseVams           = "$testCase.vams";

my $vams = 0;
my $verilog = 0;
my $sv = 0;

print "testCase=$testCase, verilog=$testCaseFullVerilog \n";

if ($testCase ne "") {
  if (-e $testCaseFullVerilog) {
    $verilog = 1;
  }
  elsif (-e $testCaseFullSv) {
    $sv = 1;
  }
  elsif (-e $testCaseFullVams) {
    $vams = 1;
  }
  else {die "No testcase named $testCaseVerilog or $testCaseSv or $testCaseVams in the directory $tcdir\n";}
}


#-------------------------------------------------------------------------
# Test configuration name if given
#-------------------------------------------------------------------------
my $config_test = $config . " ";

if($config_test =~ "config_dig ") {
  $config = "config_dig";
  #setup config dig stuff.
}

#-------------------------------------------------------------------------
# check if the sim is digital or full AMS
#-------------------------------------------------------------------------

if(($config =~ /^config_dig\Z/)) {
  $digital_sim = 1;
  $corner = "";
  $maxstep = "10m";
}
else { #AMS sim
  $digital_sim = 0;
  $corner .= $p . "_" . $temp . "C";
  $maxstep = "500u";
}

#-------------------------------------------------------------------------
# The following means STDOUT and STDERR is not buffered.  Things are
# displayed as soon as they are sent to STDOUT
#-------------------------------------------------------------------------

select STDOUT; $| = 1;
select STDERR; $| = 1;

#-------------------------------------------------------------------------
## Uniquify the sim directory name based on explicit parameter redefinitions, macro definitions and plusargs
## so that regressions of the same testcase will not clobber each other.
#-------------------------------------------------------------------------

my $extended_name;
if ($#defparam > -1) {
    $extended_name .= join " ", @defparam, "";
    $extended_name =~ s/(?:\S+\.)*(\S+)=/${1}__/g;  # trim hierarchical path off of parameter name
}
if ($#define > -1) {
    $extended_name .= join " ", @define, "";
    $extended_name =~ s/=/__/g;
}
if ($#plusarg > -1) {
    $extended_name .= join " ", @plusarg, "";
    $extended_name =~ s/=/__/g;
}
if ($id ne "") {  # add custom identifier
    $extended_name .= " $id";
}
if ($v1p8 > 0 && $digital_sim) {
    $extended_name .= "_v1p8$v1p8";
}
if ($vin > 0 && $digital_sim) {
    $extended_name .= "_vin$vin";
}

$extended_name =~ s/^\s+//;
$extended_name =~ s/\s+/./g;
$extended_name =~ s/\.$//;


# Verify something was specified to simulate, exit if not.
my $simRun;

if( ($testCase eq "") and ($uvm == 0) and ($scanset == 0) ) {
    $simRun = 0;
}
else {
    $simRun = 1;
}

if ( ($simRun == 0) and (!$netlist)) { print $usage; exit; }

#-------------------------------------------------------------------------
# Setting test name
#-------------------------------------------------------------------------
my $testname;

$testname = $testCase;

#-------------------------------------------------------------------------
# Setting sim directory name
#-------------------------------------------------------------------------
# Redirect sim directory if available
if($stash) {
    $artisan_simdir =~ s/_OA_DS/${stash}_OA_DS/;
}

my $baseDir = "$artisan_simdir/$user/$workspace" . "/" . "$tb";
print "artisan_simdir = $artisan_simdir \n";
print "user = $user\n";
print "workspace = $workspace\n";
print "baseDir = $baseDir \n";

my $simDir;
if($sim_num) {
    $simDir = $baseDir . "/$rsltsDir/SIM$sim_num/$testname";
}
else {
    $simDir = $baseDir . "/$rsltsDir/$testname";
}

#Create a symbolic link at the current work area to the results directory
if (!-d "results") {
    system("ln -s $baseDir/$rsltsDir/ results");
}


#g # Add uvm tc name if present
#g my $locuvm   = "";
#g if ($uvm_testname ne $uvm_test_default) {
#g   if ($sim ne "") {
#g     $locuvm =  ".uvm." . $uvm_testname;
#g   } else {
#g     $locuvm = "uvm." . $uvm_testname;
#g   }
#g   $simDir .= $locuvm;
#g }

# Add extensions to the name for other parameters
if ($extended_name ne "") {
  $simDir .= "." . $extended_name;
}

print "\n\nThis is a digital sim\n" if ($digital_sim);

# ---------------
# Add RunIK stuff
# ---------------
#my $locrunid = "";
#
#if($runid ne "") {
#  $locrunid = "__" . $runid;
#  $simDir .= "." . $locrunid;
#}

# end RunIK stuff


if($digital_sim && $scanset == 0) {
  $simDir .= "_" . "gates" . "_" . $sdf if ($gates == 1);
}
elsif($scanset == 1) {
  $simDir = $baseDir . "/$rsltsDir/scan_" . $scan . "_" . $sdf;
}


if($digital_sim ne 1) { #AMS sim
    $simDir .= "_" . $config . "_" . $corner;

    if ($v1p8 > 0) {
        $simDir .= "_v1p8$v1p8";
    }
    if ($vin > 0) {
        $simDir .= "_vin$vin";
    }

    $simDir .= "_" . $errpreset;

    if ($gates == 1) {
        $simDir .= "_" . "gates" . "_" . $sdf;
    }

}


#
# Include seed value in name of the simdir
#

my $seed_val;
if ($svseed) {
  if ($svseed =~ /rand/) {
    $seed_val = "random";
#    $seed_val = int(rand((1<<31)-1));
  }
  else {
  $seed_val = $svseed;
  }
#  $simDir = $simDir . ".svseed__${seed_val}";
}
else {
    $seed_val = 1;
}

my $seedArg = "-svseed $seed_val";

$rundir      = "$simDir";

print "\n\n**********************************************************************************************************************************\n"; 
print "* The sim results will be located in: $rundir *\n";
print "**********************************************************************************************************************************\n\n"; 

if (!-d $simDir and $simRun == 1) {
    #Only create sim directory if test case is specified
    CreateDir($simDir);
    $resultsdirexists = 0;
}

#-------------------------------------------------------------------------
# Creating the config directory if not a digital sim
#-------------------------------------------------------------------------
if(!$digital_sim) {

  $configsDir = $baseDir . "/$configsDir";
  $cnfgDir    =  $configsDir . "/$config";

  CreateDir($configsDir) if (!-d $configsDir);

  if (!-d $cnfgDir) {
    mkdir $cnfgDir;
    $configdirexists = 0;
  }
} # if not a digital sim


#Create a symbolic link at the current work area to the configs directory
if (!-d "configs" and !$digital_sim) {
    system("ln -s $configsDir/ configs");
}


#################################################################################
## If -clean option, save all tcl files in the dv/tcl/wavetmp dir then delete
## most items in the sim_results/<testcase> dir and then move tcl files back.
#################################################################################
if (($clean  || $netlist)) {
    if( $simRun == 1) {
        print "Temporarily saving any existing tcl or svcf files in the sim directory if they exist .....\n\n";
        CreateDir("$simDir/../tcl/wavetmp") unless (-e "$simDir/../tcl/wavetmp");
        system("mv $simDir/*tcl*  $simDir/../tcl/wavetmp/;") if (-e "$simDir/*tcl*");
        system("mv $simDir/*svcf* $simDir/../tcl/wavetmp/;")  if (-e "$simDir/*svcf*");
        print "\nCleaning the $simDir directory where the sim was built\n\n";
        print "\nMoving tcl and or svcf files back .....\n\n";
        system("rm -rf $simDir/*");
        system("mv $simDir/../tcl/wavetmp/*tcl*  $simDir;") if (-e "$simDir/../tcl/wavetmp/*tcl*");
        system("mv $simDir/../tcl/wavetmp/*svcf* $simDir;") if (-e "$simDir/../tcl/wavetmp/*svcf*");
    }
    if(!$digital_sim) {
        print "\nCleaning configuration:$config netlisting directories .....\n\n";
        print "\nRenetlisting configuration $config       ....\n\n";
        system("rm -rf $cnfgDir/*;");
        $configdirexists = 0;
    }
}

  $tc_simdir   = $simDir;

  if($scanset) {
    $tc_simdir  = $tc_simdir . "/" . "scan_" . $scan;
  }

#TODO...Will need to modify these after mbist structure is in
#g my $dig_top_path         = "tb_top.IDUT.IDIG";
#g? my $dig_top_path         = "simTopTestBench.LP5569.x_LOGIC.x_DIGITAL";
my $dig_top_path         = "$tb.$design_lib.x_LOGIC.x_DIGITAL";


#
# Setup ENV variables for verilog compile, used by *.vc files
#

#g Note: Some of these are repeated later...remove there or here?
$ENV{TBDIR}          = $tbenchdir;
$ENV{DVDIR}          = $dvdir;
$ENV{TCDIR}          = $tcdir;
$ENV{MEMDIR   }      = $memdir;
$ENV{MODELSDIR}      = $modelsdir;
$ENV{SRAM_MODELDIR}  = $sram_modeldir;
$ENV{RTLDIR}         = $rtldir;
$ENV{NETDIR}         = $netdir;
$ENV{MBIST_RTLDIR}   = $mbist_rtldir;
$ENV{CDSDIR}         = $cdsdir;
$ENV{TOPLVLNETDIR}   = $toplvlnetdir;

# Added for a2i2
#TODO: Use artisan.cdsrc variable here instead...might have to extract from a variable
my $CELL_LIB_NAME = "msl458"; # lbc8lv low-leakage 1.8V lib
my $CORE_NAME     = "CORE";
my $CORE_C_NAME   = "CORE_C";
my $CORE_W_NAME   = "CORE_W";
my $CTS_NAME      = "CTS";
my $CMOS_HOME     = "$artisan_pdkpath/diglib/$CELL_LIB_NAME/PAL";

if($digital_sim == 1) {
    $ENV{CMOS_HOME}         = $CMOS_HOME;
    $ENV{CORE_CELL_VERILOG} = "$CMOS_HOME/$CORE_NAME/verilog";
    $ENV{CORE_C_CELL_VERILOG} = "$CMOS_HOME/$CORE_C_NAME/verilog";
    $ENV{CORE_W_CELL_VERILOG} = "$CMOS_HOME/$CORE_W_NAME/verilog";
    $ENV{CTS_CELL_VERILOG}  = "$CMOS_HOME/$CTS_NAME/verilog";
}
else {  # Grab vams view for PG hookup
    $sram_modeldir    = $work . "/memory_ip/$sram_name/cad_models/verilogpw";    
    $ENV{SRAM_MODELDIR}  = $sram_modeldir;
    
    $CMOS_HOME = $CMOS_HOME . "/..";
    $ENV{CMOS_HOME}           = $CMOS_HOME;
    $ENV{CORE_CELL_VERILOG}   = "$CMOS_HOME/verilog/verilogsrc/msl458_lbc8lv";
    $ENV{CORE_C_CELL_VERILOG} = "$CMOS_HOME/verilog/verilogsrc/msl458_lbc8lv";
    $ENV{CORE_W_CELL_VERILOG} = "$CMOS_HOME/verilog/verilogsrc/msl458_lbc8lv";
    $ENV{CTS_CELL_VERILOG}    = "$CMOS_HOME/verilog/verilogsrc/msl458_lbc8lv";
}

# Put script command invocation into cmd log file so it can be easily recreated during later debug
if($simRun == 1) {
    open (my $cmdfh, ">", "$rundir/$cmd_log") or die "cannot create $rundir/$cmd_log";
    print $cmdfh "$cmdline\n";
    close($cmdfh);
}



#-------------------------------------------------------------------------
# Call in tcl file option, or defaults otherwise
#-------------------------------------------------------------------------
if($tcl) {
    $buildopts .= " -input "  . $dvdir . "/tcl/" . $tcl  . " ";
}
elsif($gui) {
    $buildopts .= " -input "  . $dvdir . "/tcl/default_gui.tcl"  . " ";
}
else{
    $buildopts .= " -input "  . $dvdir . "/tcl/default.tcl"  . " ";
}


#-------------------------------------------------------------------------
# Setting the irun command line options
#-------------------------------------------------------------------------
$breakonTyp = uc($breakonTyp);


#-------------------------------------------------------------------------
# options for all sims
#-------------------------------------------------------------------------
#x my $ncelabopts = "-ACCESS rwc";
#x $ncelabopts .= "  -SEQ_UDP_DELAY 1" if (($netlist == 1) and ($sdfset == 0) and ($simulator eq "nc"));
#x $ncelabopts .= "  -tfile ../mytfile.tfile" if (($netlist == 1) and ($sdfset == 1) and ($simulator eq "nc"));

# RunIK script options
$buildopts .= " +DV_DIR=" . ${dvdir} . " ";
$buildopts .= " +SIM_DIR=" . ${tc_simdir} . " ";

#g # The uvm testname is always tc now, so it does not change with the test case.
#g #    if ($uvm_testname ne "") {
#g #      $buildopts .= " +UVM_TESTNAME=$uvm_testname ";
#g if ($uvm_testname ne "") {
#g   $buildopts .= " +UVM_TESTNAME=tc_uvm ";
#g }

#oc If no verilog/sv test case, create a define so it can be ifdef'ed out
$buildopts .= " +define+V_SV_TC" if ($verilog or $sv);

#a2i2 Turn off ABV if desired
$buildopts .= " +define+ABV_ON " if ($noabv == 0);

#a2i2 Turn off ABV only for clocks if desired
$buildopts .= " +define+ABV_ON_CLK " if ($no_abvclk == 0 or $noabv == 0);

#a2i2 Turn off ABV only for use cases if desired
$buildopts .= " +define+USE_CASE_ON " if ($nousecase == 0);

#Pass svseed value to simulator
    $buildopts .= " $seedArg ";
    $buildopts .= " -sysv_ext .v,.sv ";
    $buildopts .= " +DV_DIR="  . ${dvdir}  . " ";
    $buildopts .= " +SIM_DIR=" . ${simDir} . " ";

    $buildopts .= " +define+DBG_BREAKON_TYP=".$breakonTyp{$breakonTyp} if (exists $breakonTyp{$breakonTyp});
    $buildopts .= " +define+DBG_BREAK_AFTER=".$breakafter;
#a2i2     $buildopts .= " +define+DBG_VERBOSITY=".$vrbLevel{$vrbLvl} if (exists $vrbLevel{$vrbLvl} and !$uvm);
    $buildopts .= " +define+DBG_VERBOSITY=".$vrbLevel{$vrbLvl} if (exists $vrbLevel{$vrbLvl});
#a2i2    $buildopts .= " +define+USE_TOP_LEVEL "     if (!$scanset);
    $buildopts .= " +define+USE_TOP_LEVEL ";#     if (!$scanset);
    $buildopts .= " +define+SIM ";
    $buildopts .= " -libext .v+.sv+.vams ";    # allows irun to find .v or .sv or .vams files in -y dirs
    $buildopts .= " +define+CONFIG_DIG "        if ($digital_sim);
#    $buildopts .= " -noupdate "        if (!$clean);
#    $buildopts .= " -R "        if (!$clean);

#-------------------------------------------------------------------------
# rtl sim command line options 
#-------------------------------------------------------------------------
#    $buildopts .= " +define+NO_PG "            if (!$gates);
    $buildopts .= " +define+NO_PG ";
#x     $buildopts .= " +define+TI_delay "         if (!$gates); #bcm Added for sram memory models, to include internal gate delays to avoid power supply errors since supply pins are tied-off internal to the model
    $buildopts .= " +define+NOT_SYNTH "        if (!$gates);
    $buildopts .= " +define+TI_functiononly "  if (!$gates and $sdfset == 0);

#-------------------------------------------------------------------------
# gate level sim command line options 
#-------------------------------------------------------------------------
#dec had to change because the define NORMAL is used in the design and this was conflicting.
#dec    $buildopts .= " +define+NORMAL "           if ($gates and !$scanset and !$mbist);
    $buildopts .= " +define+NORMAL_GATES "           if ($gates and !$scanset and !$mbist);

#-------------------------------------------------------------------------
# MBIST mode command line options 
#-------------------------------------------------------------------------
    $buildopts .= " +define+MBIST_GATES "            if($gates and $mbist);
#-------------------------------------------------------------------------
# SCAN mode command line options 
#-------------------------------------------------------------------------
    $buildopts .= " +define+ATPG_SIM "         if($scanset); 
    $buildopts .= " +define+ATPG "             if($scanset); 
    $buildopts .= " +define+FIRST5 "           if($scan eq "first5");
    $buildopts .= " +define+FULL "             if($scan eq "full");
    $buildopts .= " +define+PARALLEL "         if($scan eq "parallel");
    $buildopts .= " +define+SHIFT "            if($scan eq "shift");

#-------------------------------------------------------------------------
# Normal gate level or Scan mode sim command line options 
#-------------------------------------------------------------------------
    $buildopts .= " +define+TI_verilog "       if ($sdfset == 1);
    $buildopts .= " +define+GATES "            if ($gates or $scanset);
    $buildopts .= " +define+CHATTER "          if ($gates or $scanset);
    $buildopts .= " +define+NETLIST_SIM "      if ($gates or $scanset);

#-------------------------------------------------------------------------
# sdf related command line options 
#-------------------------------------------------------------------------
    $buildopts .= " +define+enable_sdf_${sdf_type} " if ($sdfset);
    $buildopts .= " +${sdf_delay}delays "       if ($sdfset);
    $buildopts .= " +${sdf_delay}_delay "       if ($sdfset);
    $buildopts .= " +define+GATE_MIN "          if ($sdfset and ($sdf_delay eq "min")); #For some FDC analog models
    $buildopts .= " +define+GATE_MAX "          if ($sdfset and ($sdf_delay eq "max")); #For some FDC analog models
    $buildopts .= " +define+GATE_TYP "          if ($sdfset and ($sdf_delay eq "typ")); #For some FDC analog models
    $buildopts .= " +define+vldo_${vldo} "      if ($sdfset);
    $buildopts .= " +neg_tchk "                 if ($sdfset);
    $buildopts .= " +sdf_verbose "              if ($sdfset);

    $buildopts .= " +no_notifier " if  ($sdfset == 1); #For Netlist - nc
    $buildopts .= " +nospecify " if (($gates == 1) and ($sdfset == 0));
    $buildopts .= " +delay_mode_zero " if (($gates == 1) and ($sdfset == 0) );

#-------------------------------------------------------------------------
# uvm related
#-------------------------------------------------------------------------
    $buildopts .= " +UVM_RESOURCE_DB_TRACE "                  if ($uvm_db);
    $buildopts .= " +UVM_CONFIG_DB_TRACE "                    if ($uvm_db);
    $buildopts .= " +UVM_VERBOSITY=" . $vrbLvl . " "          if (exists $vrbLevel{$vrbLvl});

    $buildopts .= join " -defparam ", ("",@defparam) if ($#defparam > -1) ;
    $buildopts .= join " +define+"  , ("",@define)   if ($#define   > -1) ;
    $buildopts .= join " +"         , ("",@plusarg)  if ($#plusarg  > -1) ;

#-------------------------------------------------------------------------
# sva related
#-------------------------------------------------------------------------
    $buildopts .= " -abvrecordcoverall ";

#-------------------------------------------------------------------------
#AMS related
#-------------------------------------------------------------------------
# Don't define AMS_SIM if this is really a digital config (i.e. config_dig, config_dig_mic, etc.)
#    $buildopts .= " +define+AMS_SIM "          if (!$digital_sim);
    $buildopts .= " +define+AMS_SIM "          if ($config !~ /^config_dig/);

#-------------------------------------------------------------------------
#gui or debug options
#-------------------------------------------------------------------------
#$buildopts .= " -iprof "                   if ($debug); # not supported in ams yet??
    $buildopts .= " -linedebug "               if ($debug || $ida);
#TEMP     $buildopts .= " -ida "                     if ($ida);
    $buildopts .= " +tcl+" . $dvdir . "/tcl/ida.tcl " if ($ida);
    $buildopts .= " -profile "                 if ($debug);
    $buildopts .= " -aps_args \"-ahdllint\" "  if ($debug);
    $buildopts .= " +define+SIM_TIMER "        if ($debug);
    $buildopts .= " +define+RAW_OTP "          if ($raw_otp);
    $buildopts .= " -access +r "               if ($fsdb || $vcd || $shm);          # enable debug if waves
    $buildopts .= " -access +rwc "             if ($gui);                           # enable debug if gui
    $buildopts .= " -gui "                     if ($gui);
    $buildopts .= " -debug "                   if ($gui);
    $buildopts .= " +fsdb "                    if ($fsdb);
# Contrast vs:
#   $buildopts .= " +define+FSDB";
    $buildopts .= " +vcd "                     if ($vcd);
    $buildopts .= " +shm "                     if ($shm);

#-------------------------------------------------------------------------
#code coverage
#-------------------------------------------------------------------------
#x     $buildopts .= " -covdut $dig_top "                   if ($coverage);
#TEMP     $buildopts .= " -covdut tb_top "                     if ($coverage);
#g     $buildopts .= " -inst_top tb_top "                   if ($coverage);
    $buildopts .= " -inst_top $tb "                   if ($coverage);
    $buildopts .= " -covfile ${dvdir}/scripts/$covfile " if ($coverage);
    $buildopts .= " -covoverwrite"                       if ($coverage);
    $buildopts .= " -covtest " . basename($simDir) . " " if ($coverage);
    # The following allows register prediction and coverage sampling
    $buildopts .= " +define+UVM_REG_EN "                 if ($coverage);

#x Shouldn't need this since use select_functional in covfile
#x     $buildopts .= " -coverage functional "              if ($coverage);
#oe  should we use the line below instead of -cov functional and remove select_functional from cov.ccf file ??
#oe     $buildopts .= " -coverage all "              if ($coverage);
#TODO: Uncomment above? Was uncommented in Ocarina

#-------------------------------------------------------------------------
# pass-thru args
#-------------------------------------------------------------------------
# Had to change how pass-thru args are passed in since it was confusing them with a C
# test case name when -boot is used w/o one
# $buildopts .= " @ARGV"        if ($#ARGV >= 0) ;                   # add pass-thru args
$buildopts .= " $passthru "      if ($passthru ne "") ;                 # add pass-thru args


#-------------------------------------------------------------------------
# below is for license timeout that can kill regressions
#-------------------------------------------------------------------------
#$buildopts .= " -spectre_args \"+lqt 0\" ";
#$buildopts .= " -spectre_args \"+lqs 300\" ";
#$buildopts .= " -aps_args \"+lqt 0\" ";
#$buildopts .= " -aps_args \"+lqs 300\" ";


#-------------------------------------------------------------------------
# Setup ENV variables for netlisting and simulations
#-------------------------------------------------------------------------
#dls my artisan_pdkpath      = $tilib . "/" . $artisan_tiprocess . "/" . $artisan_pdkver;
#dls $ENV{TC}               = $sim;
$ENV{DVDIR}             = $dvdir;
$ENV{WSPATH}            = $work;
$ENV{SIMDIR}            = $simDir;
$ENV{MODELSDIR}         = $modelsdir;
$ENV{RTLDIR}            = $rtldir;
$ENV{NETDIR}            = $netdir;
$ENV{CDSDIR}            = $cdsdir;
$ENV{CONFIGDIR}         = $cnfgDir;
$ENV{SCRIPTSDIR}        = $scriptsdir;
$ENV{AMS_RESULTS_DIR}   = $simDir;
$ENV{TILIB}             = $tilib;
$ENV{ARTISAN_TIPROCESS} = $artisan_tiprocess;
$ENV{ARTISAN_PDKVER}    = $artisan_pdkver;
$ENV{ARTISAN_PDKPATH}   = $artisan_pdkpath;
$ENV{ARTISAN_DB_TYPE}   = $artisan_db_type;
#dls $ENV{AMS_IUS_HIER}      = $ams_ius_hier;
$ENV{IC_INVOKE_DIR}     = $work;
$ENV{ARTISAN_NOSPLASH}  = "t";


#-------------------------------------------------------------------------
# Netlisting and Configurations
#-------------------------------------------------------------------------
if ($netlist) {

    if($digital_sim eq 1) {
        CreateDigNetlist();
    }
    else {
        CreateAmsNetlist();
    }
    # Netlist option has been selected, so do not run simulation
    die  "\n\n .......  switch option \"-netlist\" complete and testcase not given. My work is done.\n\n\n" if(!$sim);

}
elsif($configdirexists == 0 && !$digital_sim) {
    # Create AMS Configuration if it doesn't exist
    CreateAmsNetlist();
}


CreateAmsControlSpectre();
CreateSpectreProcessInclude();

#-------------------------------------------------------------------------
# Set simulation options (from RunIK)
#-------------------------------------------------------------------------
$simopts .= " -access r" if ($scanset == 1);  #anf-atpg
#x $simopts .= " -input $default_tcl"  if (($gui == 1) and (-e $default_tcl));
#x $simopts .= " -input $default_tcf"  if (($tcf == 1) and (-e $default_tcf));
#x $simopts .= " +${sdf_type}delays" if  (($simulator eq "nc") and ($sdfset == 1)); #For Netlist - nc
#if ($#plusarg > -1) {
#  $simopts .= join " +", ("",@plusarg);
#}
# Add any pass-thru arguments...actually these should have already been specified in
# -passthru so anything left is undesired
#bcm I don't think this is really needed anymore
#bcm But I did have to discard the cdef args if still left in the ARGV array since
#bcm they get passed to irun but really are only needed for the C compile makefile.
#bcm irun doesn't know what they are.
if ($#ARGV >= 0) {
  foreach my $arg (@ARGV) {
    if ($arg =~ /cdef/) {
      shift(@ARGV);
    } else {
      $simopts .= " $arg";
    }
  }
}

# This file should always be present since tb uses uvm
$vc_uvm =  $scriptsdir . "/uvm.vc";
die "Error! $vc_uvm not found" unless (-e $vc_uvm);

# set common vc file and simulation-specific vc file
$vc1 =  $scriptsdir."/tbench.vc" ;

if ($gates == 1 || $scanset == 1) {
  if ($sdfset==1) {
    $vc2 = $scriptsdir."/sdf.vc";
  } else {
    $vc2 = $scriptsdir."/netlist.vc";
  }
} else {
  $vc2 = $scriptsdir."/rtl.vc";
}
die "Error! $vc2 not found" unless (-e $vc2);

# set top-level file
if(!$digital_sim) {  #AMS Simulation Netlist File
    $v = $cnfgDir . "/netlist/netlist.vams";
}
elsif(!$scanset) { #Digital Simulation Netlist File
    $v = $modelsdir . "/netlist/netlist.vams";
}
elsif($scanset) {# setting different top-level tb for scan mode
  $v = $modelsdir . "/netlist/netlist.vams";
  }
if(!$scanset) {
  die "Error! $v not found" unless (-e $v);
}

#g # Add the uvm testname
#g if ($uvm_testname ne "") {
#g   $v = $v . " " . $uvm_tc_dir . "/" . $uvm_testname . ".sv";#  if(!$scanset);
#g }

# Add the verilog/sv/vams test case name if present
if    ($vams)    {
    #anf $v .= " " . $testCaseFullVams; #Comment out to support finland flow
    system("ln -sf $testCaseFullVams $simDir/_STIMULUS_.v");  # To work with Finland flow
}
elsif ($verilog) {
    #anf $v .= " " . $testCaseFullVerilog; #Comment out to support finland flow
    system("ln -sf $testCaseFullVerilog $simDir/_STIMULUS_.v");  # To work with Finland flow

}
elsif ($sv)      {
    #anf $v .= " " . $testCaseFullSv;  #Comment out to support finland flow
    system("ln -sf $testCaseFullSv $simDir/_STIMULUS_.v");  # To work with Finland flow

}


#-------------------------------------------------------------------------
# Set testcase options (from RunIK)
#-------------------------------------------------------------------------
$tcopts .= " +vcdfile=$testname\.vcd";

    # cd to Simulator directory

    print "the value of rundir is $rundir\n";
    chdir $rundir or die ("cd to $rundir failed");

    # Symbolic link to RTL
    system "rm -f verilog";
    symlink($rtldir,"verilog");

    # Create a link to the tc dir so data files can be loaded more easily
    if (-d tc){ system "rm -f tc";}
    symlink($testsdir, "tc");

#g     # Create a link to the uvm tc dir so data files can be loaded more easily
#g     if (-d uvm_tc){ system "rm -f uvm_tc";}
#g     symlink($uvm_tc_dir, "uvm_tc");

    # Need a link to .amerc so any non-default tool flows/packages will be used (if specified)
    if (-e ".amerc") { system "rm -f .amerc"; }
    symlink("$work/.amerc", ".amerc");

    # Remove any unnecessary old files from the rundir
    system "rm -f vsim.wlf";
    system "rm -f transcript";

print "tcopts = $tcopts \n";

#-------------------------------------------------------------------------
# Build & Run
#-------------------------------------------------------------------------

print "Building...\n";


#-------------------------------------------------------------------------
# Pulling in different source files for different kinds of simulations
#-------------------------------------------------------------------------

#RunIK Notes:
# $v = tb_top.vams with pathname, plus uvm.vc
# $vc1 = tbench.vc
# $vc2 = either netlist.vc or rtl.vc

my $sourcefiles = "";
if ($gates == 1 && $scanset == 0) {
  $sourcefiles .= " -f $vc_uvm -f $vc2 -f $vc1";
}
elsif ($scanset == 1){  # scan files
  $sourcefiles .= " -f $vc_uvm -f $vc2 -f $vc1";
}
else{  # else use rtl source files
  $sourcefiles .= " -f $vc_uvm -f $vc2 -f $vc1";
}
if ($sdfset==1) {
  $sourcefiles .= " $dvdir/includes/top_TB_sdf_annotate.sv -top top_TB_sdf_annotate";
}

#--------------------------------------------------------------------------------
# Add c file to allow DPI tcl integration
#--------------------------------------------------------------------------------
$sourcefiles .= " $dvdir/tb/cfcExecuteCommands.c ";


#--------------------------------------------------------------------------------
# Adding spice assert checking from command line
#--------------------------------------------------------------------------------

if ($asserts) {
  print "\n\n!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n";
  print "!!!                      SPICE ASSERT CHECKING IS TURNED ON             !!!\n";
  print "!!!  All warnings are in the log file - asserts.out in the results dir  !!!\n";
  print "!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!\n\n";
}


#-------------------------------------------------------------------------
# set top-level tb file
# setting different top-level tb for scan mode
#-------------------------------------------------------------------------
my $tbfile = "";
if($scanset) {
    if ($scan eq "first5"){
      $tbfile = $scandir . "/GUSTO_a0" . "_first_5_serial_verilog.mainsim.modified.v" . " +TESTFILE1=$scandir/GUSTO_a0" . "_first_5_serial_verilog.1.verilog $v -top tbdata_FULLSCAN_GUSTO_a0_full_scan_test -top $tb";
    }
    elsif ($scan eq "full") {
      $tbfile = $scandir . "/GUSTO_a0" . "_full_scan_verilog.mainsim.modified.v" . " +TESTFILE1=$scandir/GUSTO_a0" . "_full_scan_verilog.1.verilog $v -top tbdata_FULLSCAN_GUSTO_a0_full_scan_test -top $tb";
    }
    elsif ($scan eq "parallel") {
      $tbfile = $scandir . "/GUSTO_a0" . "_parallel_scan_verilog.mainsim.modified.v" . " +TESTFILE1=$scandir/GUSTO_a0" . "_parallel_scan_verilog.1.verilog $v -top tbdata_FULLSCAN_GUSTO_a0_full_scan_test -top $tb";
    }
    elsif ($scan eq "shift") {
      $tbfile = $scandir . "/GUSTO_a0" . "_scan_chain_shift_verilog.mainsim.modified.v" . " +TESTFILE1=$scandir/GUSTO_a0" . "_scan_chain_shift_verilog.1.verilog $v -top tbdata_FULLSCAN_GUSTO_a0_scan_chain_shift -top $tb";
    }
} #if $scanset
elsif ($scanset == 0) {
  $tbfile = " $v -top $tb";
}


#-------------------------------------------------------------------------
# Setting up defines and link for sdf annotation
#-------------------------------------------------------------------------
my $mode   = "normal";
  
if ($sdfset) {
  if($scanset) {
    $mode   = "scan";
  } #scan
  elsif($mbist) {
    $mode   = "mbist";
  } #mbist
  elsif($gates) {
    $mode   = "normal";
  } #gates
  else {
    die "The -sdf option must be used with the -scan or the -gates or the -mbist option\n";
  }
  #dec This creates a link in the simulation directory to the sdf file
  symlink("$netdir/$dig_top\_$mode\_$sdf.3.0.sdf.gz", "$simDir/$dig_top\_$mode\_$sdf.3.0.sdf.gz" );
}

#################################################################################
## if not a digital sim, copy over files to the results dir for local compiles
##.amsbind.scs
## userDisciplines.vams
## userMacros.h
#################################################################################
if(!$digital_sim) {
  system("cp $cnfgDir/netlist/.amsbind.scs $cnfgDir/netlist/userDisciplines.vams $cnfgDir/netlist/userMacros.h $simDir/"); 
  system("ln -s $cnfgDir/netlist/*tcl* $simDir/"); 
}
else {
    system("cp -L $work" . "/dv/abm/netlist/.amsbind.scs $simDir");
    system("chmod u+rw $simDir/.amsbind.scs");
}


#################################################################################
## AMS related irun args
#################################################################################
my $amscmdargs = "";

if( $setd ne "") {
    $amscmdargs .= " -f $dvdir/scripts/$setd "; #Sets default discipline resolutions
}
else {
    $amscmdargs .= " -f $dvdir/scripts/setd.f "; #Sets default discipline resolutions
}
$amscmdargs .= " -f $dvdir/scripts/spicecontrol.f "; #Analog solver args
$amscmdargs .= " -f $dvdir/scripts/connectrules.f "; # Connect module defines
$amscmdargs .= " -amsformat psfxl "        if ($psfxl);
#$amscmdargs .= " $dvdir/abm/netlist/userDisciplines.vams "; # Connect module defines


#-------------------------------------------------------------------------
# Create files for holding voltage values.  Allows us to pass voltages from command line to simulation
#-------------------------------------------------------------------------
open(VIN_FILE, "> $simDir/vin.voltage") or die "Could not open the vin.voltage file in the sim_results/testcase directory\n";
open(V1P8_FILE, "> $simDir/v1p8.voltage") or die "Could not open the v1p8.voltage file in the sim_results/testcase directory\n";
if ($vin > 0) {
    printf VIN_FILE $vin;
}
else {  # Set to a default value if not used
    printf VIN_FILE 3.6;
}

if ($v1p8 > 0) {
    printf V1P8_FILE $v1p8;
}
else {  # Set to a default value if not used
    printf V1P8_FILE 1.8;
}
    
close(VIN_FILE);
close(V1P8_FILE);

#-------------------------------------------------------------------------
# kicking off the simulation
#-------------------------------------------------------------------------
my $irun_cmd;
my $incisive_version = ""; #bcm
#my $incisive_version = "-14.20.003p1-incisiv"; #bcm
#oc my $incisive_version = "";
#oc my $incisive_version = " -14.20.012-incisiv ";
#bcm my $incisive_version = "-15.10.011-incisiv";

#kam added for float check.  need older version
if($float_check) {
$incisive_version = "-14.20.017p1-incisiv";
}

#bcm Commented above out since doesn't work for vmanager
if ($digital_sim) {
#oc   $irun_cmd = "irun $incisive_version $buildopts $pattern_define $simopts $tcopts $amscmdargs -f $dvdir/scripts/simcontrol.f $modelsdir/netlist/cds_globals.vams -f $modelsdir/netlist/textInputs $sourcefiles $tbfile $debug_driver";
  $irun_cmd = "irun $incisive_version -f $scriptsdir/options_file.txt $buildopts $simopts $tcopts               -f $dvdir/scripts/simcontrol.f $modelsdir/netlist/cds_globals.vams -f $modelsdir/netlist/textInputs $sourcefiles $tbfile   -amsbind";
} else { #AMS sim 
#oc   $irun_cmd = "irun $incisive_version $buildopts $pattern_define $simopts $tcopts $amscmdargs -f $dvdir/scripts/simcontrol.f $sourcefiles $tbfile $debug_driver -f $cnfgDir/netlist/textInputs $cnfgDir/netlist/cds_globals.vams";
    $irun_cmd = "irun $incisive_version -f $scriptsdir/options_file.txt $buildopts $simopts $tcopts $amscmdargs -f $dvdir/scripts/simcontrol.f $cnfgDir/netlist/cds_globals.vams   -f $cnfgDir/netlist/textInputs   $sourcefiles $tbfile $modelsdir/netlist/modules/otp_5v_core.sv";
#anf  $irun_cmd = "irun $incisive_version $buildopts $simopts $tcopts $amscmdargs -f $dvdir/scripts/simcontrol.f $sourcefiles $tbfile -f $cnfgDir/netlist/textInputs $cnfgDir/netlist/cds_globals.vams $modelsdir/netlist/modules/otp_5v_core.sv";
}

print "\n\nRunning irun as ....\n\n $irun_cmd\n\n\n";


chdir $simDir;
system "$irun_cmd" ;


if ($clean_after) {
  system("(cd $simDir; find . -mindepth 1 -maxdepth 1 -not -name 'irun.log' -not -name 'sim_ams.cmd' -not -name 'cov_work' -exec rm -rf '{}' \\;)");
}

#cd back to cwd
chdir $cwd;

exit;







#################################################################################
## Creating the amsControlSpectre file in the results directory
## Check that nothing should change at the beginning of each new project.
#################################################################################
sub CreateAmsControlSpectre() {
  open(AMSSCS, "> $simDir/amsControlSpectre.scs") or die "Could not open the amsControlSpectre.scs file in the sim_results/testcase directory\n";

  if($loose) {
      print AMSSCS "////////////////////////////////////////////////////////////////////////////////\n";
      print AMSSCS "// USING -loose: WHICH USES VERY LOOSE SETTINGS FOR RELTOL, VABSTOL, AND IABSTOL\n";
      print AMSSCS "// reltol  changed from 1e-3  to 5e-3\n";
      print AMSSCS "// vabstol changed from 1e-6  to 5e-6\n";
      print AMSSCS "// iabstol changed from 1e-12 to 5e-12\n";
      print AMSSCS "////////////////////////////////////////////////////////////////////////////////\n";
   } 
  printf AMSSCS "// This is the Cadence AMS Designer(R) analog simulation control file. \n";
  printf AMSSCS "// It specifies the options and analyses for the Spectre analog solver. \n\n";
  printf AMSSCS "simulator lang=spectre  \n\n";
  printf AMSSCS "simulatorOptions options temp=$temp\.0 tnom=27 \\\n", $temp;
  printf AMSSCS "scale=1.0e-6 scalem=1.0  \\\n";
  printf AMSSCS "preserve_inst=all \\\n";
  if($loose) {
    printf AMSSCS "reltol=5e-3 vabstol=5e-6 iabstol=5e-12  \\\n";
  } else {
    printf AMSSCS "reltol=1e-3 vabstol=1e-6 iabstol=1e-12  \\\n";
  }
  printf AMSSCS "gmin=1e-12 rforce=1 \\\n";
    printf AMSSCS "redefinedparams=warning maxnotes=5 maxwarns=100000 maxwarnstologfile=100000 maxnotestologfile=100000 digits=5 pivrel=1e-3 \\\n";


  
  if($asserts) {
    printf AMSSCS "dochecklimit=yes checklimitfile=\"asserts.out\" checklimitdest=psf \\\n";
  } elsif ($asserts_full) {
    printf AMSSCS "dochecklimit=yes checklimitfile=\"asserts.out\" checklimitdest=both \n IgnoreCheckName1 checklimit checkallasserts = yes check_windows=[0 1] \\\n";
  } else {
    printf AMSSCS "dochecklimit=no checklimitfile=\"asserts.out\" checklimitdest=both \\\n";
  }
  
  if($debug) {
    printf AMSSCS "convdbg=detailed nonconv_topnum=10 warnminstep=1e-12\n\n";
  } else {
    printf AMSSCS "\n";
  }

  # Set tran time for 100s on digital solver only sim.  100ms for AMS simulation.  Needed if dig sim doesn't envoke analog solver.
  if ($digital_sim) {
      printf AMSSCS "tran tran stop=100 errpreset=$errpreset save=none maxstep=$maxstep \\\n";
  } else {
      printf AMSSCS "tran tran stop=0.1 errpreset=$errpreset save=none maxstep=$maxstep \\\n";
  }      
  printf AMSSCS "skipcount=$skipcount \\\n" if($skipcount > 1);
  printf AMSSCS "write=\"spectre.ic\" writefinal=\"spectre.fc\" method=gear2only \\\n";
  if($tparam) {
  printf AMSSCS "relref=sigglobal annotate=status paramset=pset1 maxiters=5\n\n";
  } else {
  printf AMSSCS "relref=sigglobal annotate=status maxiters=5\n\n";
  }

  close(AMSSCS);
}

sub CreateSpectreProcessInclude() {
       open(PROCESSFILE, "> $simDir/process_corner.scs") or die "Could not open the process_corner.scs file in the sim_results/testcase directory\n";
       printf PROCESSFILE "simulator lang=spectre\n";
       printf PROCESSFILE "include \"\$TILIB\/\$ARTISAN_TIPROCESS\/\$ARTISAN_PDKVER\/models/spec/model.paths.%s.scs\" amsd_subckt_bind=yes\n", $p;

       if($float_check) {
           printf PROCESSFILE "include \"$dvdir/abm/spectre_floating_node.scs\" \n";
       }

       if ($tparam) {
           printf PROCESSFILE "include \"$dvdir/paramsets/$tparam\" \n";
       }
       close(PROCESSFILE);
}


sub CreateAmsNetlist() {
    system("cd $work; runams $netlister_ver -lib $tb_top_lib -cell $tb -state ams_state_netlist -view $config -netlist all -cdslib ./cds.lib -rundir $cnfgDir $local_models $spec_models");
}


#################################################################################
## Creating the Digital Netlist and placing the netlist and all necessary
## sim files in a revision controlled directory
#################################################################################
sub CreateDigNetlist() {
#############################################
###       Run the netlist Command         ###
#############################################

  my $netlist_dir;

  $netlist_dir = "$dvdir/abm/netlist";

  if( $rev_ctrl_tool eq "dssc") {
  system("dssc co -get -rec $netlist_dir ");
  system("chmod -R u+wr $netlist_dir ");
  }

  if (-d "$work/netlist_tmp") {
    print "\n\n ...... Clearing Out Previous Run Data in $work/netlist_tmp \n";
    system("rm -rf $work/netlist_tmp/*");
    }
  else {
    print "\n\n ...... Creating directory $work/netlist_tmp for netlisting \n\n";
    system "mkdir $work/netlist_tmp"
    }
  
  print "\n\n ...... Envoking Netlister \n\n";
  system("cd $work; env ARTISAN_NOSPLASH=t runams $netlister_ver -lib $tb_top_lib -cell $tb -state ams_state_netlist -view config_dig -netlist all -cdslib ./cds.lib -rundir $work/netlist_tmp/");


  print "\n ...... Moving Netlist File to revision controlled netlist directory\n";
  system("mv $work/netlist_tmp/netlist/netlist.vams $netlist_dir/");

  print "\n ...... Moving cds_globals.vams to netlist directory\n";
  system("mv $work/netlist_tmp/netlist/cds_globals.vams $netlist_dir/");

  print "\n ...... Moving .amsbind.scs to netlist directory\n";
  system("mv $work/netlist_tmp/netlist/.amsbind.scs $netlist_dir/");

  print "\n\n********************************************************************\n";
  print "*** You need to check these files in for others to use them      ***\n";
  print "********************************************************************\n\n";
  system("chmod -R +w $netlist_dir");

#############################################
###  Post Processing Netlister Output     ###
#############################################
  print "\n************************************\n";
  print "*** Post Processing Netlist Data ***\n";
  print "************************************\n\n";

  my $library;
  my $new_line;
  my $cell;
  my $view;
  my $ext;

  open(FILEIN, "< $work/netlist_tmp/netlist/textInputs") or die "Couldn't open textInputs file\n";
  open(FILEOUT, "> $netlist_dir/textInputs") or die "Couldn't create new file\n";

  print FILEOUT "\n\/\/********************************************************************************************************************************************\n";
  print FILEOUT "\/\/ The golden source of these models is in Virtuoso. Any changes made to the models will get overwritten each time a new netlist is generated.\n";
  print FILEOUT "\/\/********************************************************************************************************************************************\n\n\n";


  while(<FILEIN>) {

    if($_ =~ /.*\/(.*)\/(.*)\/(.*)\/verilog\.(.*) lib/) {
      $library = $1;
      $cell = $2;
      $view = $3;
      $ext = $4;

      $new_line = "-amscompilefile \"file:\$\{WSPATH\}/dv/abm/netlist/modules/$cell.$view.$ext lib:$library cell:$cell view:$view\"\n";
                
      if($library =~ $design_lib) {
        print " $work/cds/$library/$cell/$view/verilog.$ext";
        print "\n";
        if($dssc_format eq "modules") {
            system("cp -L $work/../MODULES/cdslibs/$library/$cell/$view/verilog.$ext $netlist_dir/modules/$cell.$view.$ext");
        }
        else {
            system("cp -L $work/cds/$library/$cell/$view/verilog.$ext $netlist_dir/modules/$cell.$view.$ext");
        }
        system("chmod u+rw $netlist_dir/modules/$cell.$view.$ext");
        print FILEOUT $new_line;
        }
      elsif($library =~ "msl") {
        print " $work/pdk/$library/$cell/$view/verilog.$ext";
        print "\n";
        # The following was needed because of a MSL directory change
        system("cp -L /data/GUSTO_OA_DS/sync/projLibs/pdk_Trunk.Latest/$library/$cell/$view/verilog.$ext $netlist_dir/modules/$cell.$view.$ext");
#        system("cp -L $work/pdk/$library/$cell/$view/verilog.$ext $netlist_dir/modules/$cell.$view.$ext");
        system("chmod u+rw $netlist_dir/modules/$cell.$view.$ext");
        print FILEOUT $new_line;        
        }
      else {
        print FILEOUT "$_";
        }

      }
    else {
      print FILEOUT "$_";
      }
    }

## Analog Cells instantiated in the rtl/gates needs to be listed here and pulled over separately.
  
## Seperately insert information for OTP module, since the config view doesn't control this.
  print "\n\n ........  Copying OTP models from Virtuoso\n\n";
  system("cp -L $work/cds/$design_lib/otp_5v_core/systemVerilog/verilog.sv $modelsdir/netlist/modules/otp_5v_core.sv");
  print " $work/cds/$design_lib/otp_5v_core/systemVerilog/verilog.sv\n";
  system("chmod u+rw $modelsdir/netlist/modules/otp_5v_core.sv");
  print FILEOUT "-amscompilefile \"file:\$\{WSPATH\}/dv/abm/netlist/modules/otp_5v_core.sv lib:GUSTO cell:otp_5v_core view:systemVerilog\"\n";

  
  
  close(FILEIN); 
  close(FILEOUT);

  print "\n\n*************************************************************************************************************************************\n";
  print "*** Netlist Generation Finished                                                                                                   ***\n";
  print "*** All new netlist items are in the $work/dv/abm/netlist diretory and NOT checked in. ***\n";
  print "*** You need to check these items in for others to use this netlist                                                               ***\n";
  print "*************************************************************************************************************************************\n\n\n";
  
}


#################################################################################
## Utility subroutines
#################################################################################
sub CatchCtrlC {
  print STDERR "\nCONTROL-C DETECTED...KILLING SIMV!!!!\n";
    setpgrp(0,$$);
    kill 9, -$$; # kill entire process group (including self)
}

sub CreateDir() {
  my $path = shift or die "Must provide a path to CreateDir()";

  my $temppath = "";

  foreach my $dir (split('\/', $path)) {
    if($dir ne "") {
      $temppath = $temppath . "/" . $dir;
      system "mkdir $temppath" if !(-d $temppath);
    }
  }
}



