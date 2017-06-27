#-----------------       INCISIVE VER     ---------------------------------
ifndef IUS_VER
IUS_VER = \
	-14.10.003-incisiv
endif

#-----------------       AFFIRMA PATH     ---------------------------------
ifndef AFFIRMA_AMS_PATH
AFFIRMA_AMS_PATH = \
	/ams_path/tools/affirma_ams/etc/connect_lib
endif

#-----------------      FDV HOME     ---------------------------------
ifndef FDV_HOME
#FDV_HOME = \
#	/db/mvc/FDV/tools/bin
endif

#---------------------- FDV USER     ---------------------------------
ifndef FDV_USER
#FDV_USER=$(USER)
endif


#-----------------   COMPILE DESIGN      ---------------------------------
DESIGNLIB = \
	DESIGNLIB

#-----------------   COMPILE CELIB      ---------------------------------
CONNECTLIB = \
	CELIB

#-----------------   COMPILE HDL         ---------------------------------
HDLLIB = \
	HDLLIB

#-----------------   COMPILE STD CELLS   ---------------------------------
STDLIB = \
	STDLIB

#-----------------  FDV WORKSPACE        ---------------------------------
#export FDV_WORKSPACE=/proj_path/users/${USER}/Latest



#-----------------       EXTRACTION DIR     ---------------------------------
ifndef DV_EXT_DIR
DV_EXT_DIR =  \
    /proj_path/users/${USER}/Latest/dv/source/tb
endif

#-----------------       TOP Cell         ---------------------------------
TOPCELL = \
	dv_top_main

#-----------------      CONNECT ELEMENTS    ---------------------------------
#CONNECT_FILES =  \
	${FDV_HOME}/packages/connect_modules/R2L.vams  \
	${FDV_HOME}/packages/connect_modules/RL_bidir.vams \
	${FDV_HOME}/packages/connect_modules/R2LV.vams \
	${FDV_HOME}/packages/connect_modules/L2R.vams  \
	${FDV_HOME}/packages/connect_modules/L2RV.vams \
	${FDV_HOME}/packages/connect_modules/CML2L.vams \
	${FDV_HOME}/packages/connect_modules/L2CML.vams

AMS_CONNECT_FILES =  \
	${AFFIRMA_AMS_PATH}/ER_bidir.vams \
	${AFFIRMA_AMS_PATH}/E2R.vams \
	${AFFIRMA_AMS_PATH}/R2E_2.vams \
	${AFFIRMA_AMS_PATH}/L2E.vams \
	${AFFIRMA_AMS_PATH}/E2L.vams 
#	${DV_EXT_DIR}/connect_modules/connRules.vams

#----------------------    TEMPERATURE    ---------------------------------
TEMP = 27

#----------------- SPECTRE PROCESS CORNER ---------------------------------
include ${DV_EXT_DIR}/Makefile.process_corner

#---------------------- LSF ARGUMENTS     ---------------------------------
ifndef LSF_ARGS
LSF_ARGS=bsub -q regress -J fdv_${TOPCELL} -R "select[sles11&&ncpus>1] span[hosts=1]" -n 2
endif

#----------------  VERILOG-AMS MODEL Files         -----------------------------------$
VERILOGAMS_MODEL_FILES =  \
	${DV_EXT_DIR}/MODELED_CELL_VIEWS/verilogAMS/cur_sink_bias.vams        \
	${DV_EXT_DIR}/MODELED_CELL_VIEWS/verilogAMS/isink.vams                

#-----------------     NCVLOG OPTIONS    ---------------------------------
NCVLOGOPTS =  \
	-NOWARN DLNCML \
	-NOWARN XSCPNU \
	-NOCOPYRIGHT \
	-MESSAGES \
	-NOWARN AMSIUSLD \
	-DEFINE LEVEL2_cur_sink_bias \
	-DEFINE LEVEL2_isink \
	-DEFINE LEVEL2_osc 

#-----------------       PSL  OPTIONS    ---------------------------------
PSLWREALMACROS =  \
	${DV_EXT_DIR}/pslWrealMacros.v

PSLVAMSMACROS =  \
	${DV_EXT_DIR}/pslVamsMacros.v

PSLSPECTREMACROS =  \
	$(PWD)/pslSpectreMacros.v


#-----------------           AMS OPTS     ---------------------------------

ifndef AMSOPTIONS
AMSOPTIONS = \
	-amsconnrules e2r_only \
	-amspartinfo  partition.info \
	-simcompatible_ams spectre
endif


#-----------------         AMS Config         -----------------------------------$
ifndef AMSCBSCS
AMSCBSCS = \
	amscb.scs
endif


#-----------------       COMPILE OPTS     ---------------------------------

ifndef IRUN_ARGS
IRUN_ARGS = \
	-timescale 1ns/1ns \
	-vtimescale 1ns/1ns \
	-discipline logic \
	-access +rwc \
	-libverbose
endif


ifndef VLOGC
VLOGC          =   /apps/ame/bin/irun ${IUS_VER} ${IRUN_ARGS}
endif

ifndef VLOGC_BSUB
VLOGC_BSUB          =  ${LSF_ARGS}  /apps/ame/bin/irun ${IUS_VER} ${IRUN_ARGS}
endif

#-----------------
stdcomp:
	${VLOGC} -work ${STDLIB} -ALLOWREDEFINITION -f ${DV_EXT_DIR}/diglib.f  -view gate -compile

designcomp:
	${VLOGC} -work ${DESIGNLIB} ${CONNECT_FILES} ${WREAL_MODEL_FILES} ${STRUCTURE_FILES} ${NCVLOGOPTS} ${PROPFILE_OPTS} -compile

crulescomp:
	${VLOGC} -MESSAGES -work ${CONNECTLIB} ${CONNECT_FILES} ${AMS_CONNECT_FILES} -compile -log crules.log

svcomp:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${NCVLOGOPTS} ${SV_MODEL_FILES} -view sv -compile -log sv_models.log

wrealcomp:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${NCVLOGOPTS} ${PSLSPECTREMACROS} ${STRUCTURE_FILES} -view str -compile -log wreal_hier.log
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${PSLWREALMACROS} ${NCVLOGOPTS} ${PROPFILE_OPTS} ${WREAL_MODEL_FILES} -view wreal -compile -log wreal_models.log

verilogamscomp:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${PSLVAMSMACROS} ${NCVLOGOPTS} ${PROPFILE_OPTS} ${VERILOGAMS_MODEL_FILES} -view vams -compile -log vams_models.log

verilogacomp:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${NCVLOGOPTS} ${VERILOGA_MODEL_FILES} -view va -compile -log va_models.log

atpgcomp:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${NCVLOGOPTS} ${ATPG_STRUCTURE_FILES} ${NCVLOGOPTS} -view atpgstr -compile -log atpg_hier.log
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${NCVLOGOPTS} ${ATPG_MODEL_FILES} -view atpg -compile -log atpg_models.log

#custom_makefile
DIG_SCOPE          = GATE_MIN
ENV_TYPE           = DIGITAL
TEST_NAME          =
SVSEED             = 1
NCLIBDIRPATH       = .
VERBOSITY          = LOW
RUN_MODE           = 
  
SV_MODEL_FILES := \
      -uvm \
      -f ${DB_PROJECT_ROOT}/dv/digital/sims/f/fdv_uvm_tb.f \
      ${SV_MODEL_FILES}
      
ifeq ($(DIG_SCOPE),RTL)
      HDL_FILES =  \
      -f ${DB_PROJECT_ROOT}/dv/digital/sims/f/rtl_source.f
endif

ifeq ($(DIG_SCOPE),GATE_MAX)
      HDL_FILES =  \
      -f ${DB_PROJECT_ROOT}/dv/digital/sims/f/gates_source.f
      
      NCVLOGOPTS      += -define SDF_MAX -define GATE_LEVEL_SIM
endif

ifeq ($(DIG_SCOPE),GATE_MIN)
      HDL_FILES =  \
      -f ${DB_PROJECT_ROOT}/dv/digital/sims/f/gates_source.f
      
      NCVLOGOPTS      += -define SDF_MIN -define GATE_LEVEL_SIM -define TI_verilog
      
endif  
   

ifndef DIGOPTIONS
DIGOPTIONS = +UVM_TESTNAME=$(TEST_NAME) \
             +SVSEED=$(SVSEED) \
             +UVM_VERBOSITY=$(VERBOSITY) \
             -nclibdirpath $(NCLIBDIRPATH) \
             -access +rwc \
             -input probe.tcl
endif

#--Add run-mode options
ifeq ($(RUN_MODE),GUI)
  DIGOPTIONS      += -gui
endif
ifeq ($(RUN_MODE),BATCH)
  DIGOPTIONS      += -run
endif

ifeq ($(ENV_TYPE), DIGITAL)
  NCVLOGOPTS      += -define FDV_DIGITAL_STANDALONE
endif

#--Add coverage options
COVER_OPTIONS = \
  -f ${DB_PROJECT_ROOT}/dv/coverage/cov_ncelab_opts.f \
  -f ${DB_PROJECT_ROOT}/dv/coverage/cov_ncsim_opts.f \
  -coverage ALL \
  -covoverwrite \
  -covfile covfile.cf \
  -covtest $(TEST_NAME)

Vman :
	emanager -desktop -p "setup" &

OPTIONS           += +UVM_TESTNAME=
      
hdlcomp:
	${VLOGC} -work ${DESIGNLIB} ${HDL_FILES} -view rtl -compile -log rtl.log
gatecomp:
	${VLOGC} -work ${DESIGNLIB} ${HDL_FILES} -view gate -compile -log gate.log

runcompiletb:
	make -i hdlcomp
	make -i stdcomp
	make -i crulescomp
	make -i svcomp
	make -i atpgcomp
	make -i wrealcomp
	make -i verilogamscomp
	
runcompiledig:
	make -i hdlcomp 
	make -i stdcomp
	make -i crulescomp
	make -i svcomp 
	make -i atpgcomp
	make -i wrealcomp
	make -i verilogamscomp

runcompilegate:
	make -i gatecomp 
	make -i stdcomp
	make -i crulescomp
	make -i svcomp 
	make -i atpgcomp
	make -i wrealcomp
	make -i verilogamscomp

rundig:
	${VLOGC} +UVM_TESTNAME=dig_read_reg -gui -MESSAGES -work ${DESIGNLIB} ${AMS_CONNECT_FILES} ${PROPFILE_OPTS} ${AMSCBSCS} ${AMSOPTIONS} ${DIGOPTIONS} ${COVER_OPTIONS} -access +rwc -f model.binds -ncinitialize 0 -top ${TOPCELL}:atpgstr -input probe.tcl -clean

runtop:
	${VLOGC} -MESSAGES -work ${DESIGNLIB} ${AMS_CONNECT_FILES} ${PROPFILE_OPTS} ${AMSCBSCS} ${AMSOPTIONS} -access +rwc -f model.binds -ncinitialize 0 -analogcontrol amsControlSpectre.scs -top ${TOPCELL}:str -input probe.tcl -clean 
