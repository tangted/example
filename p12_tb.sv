class example_tb extends uvm_env;
  // UVM Factory Registration Macro
  //
  `uvm_component_utils(example_tb)
  //------------------------------------------
  // Data Members
  //------------------------------------------

  //csv writter items for parametric database 
  csv_writer#(parametric_db_item) csv_writer_h;
  csv_writer#(functional_db_item) csv_writer_func_h;  
  example_csv_if_item csv_if_logger_h;
  //Parametric Spec Database pointer
  parametric_db_pkg::parametric_db specs;  
  //Analog Interface pointer
  virtual interface example_e2r_if analog_if;
  //Switch interface pointer
  virtual interface example_tb_if tb_if;  
  //Model interface pointer
  virtual interface example_model_if model_if;    
  // interfaces pointers
  virtual interface spi_mpl_if spi_if;
  eeprom_pkg::eeprom_if_base eeprom_ip_if_main;
  eeprom_pkg::eeprom_if_base eeprom_ip_if_fmon;
  //TODO FMON EEPROM
  virtual interface cas_digital_if cas_dig_if;
  virtual interface sleep_digital_if sleep_dig_if;
  virtual interface psm_digital_if psm_dig_if;
  virtual interface smps_digital_if smps_dig_if;
  virtual interface fmon_ee_digital_if fmon_ee_dig_if;
  virtual interface wssim_if wssim1_if;
  virtual interface wssim_if wssim2_if;
  virtual interface wssim_if wssim3_if;
  virtual interface wssim_if wssim4_if;

  //CAN Interface pointers
  virtual interface can_phy_node_if can1_node_if;
  virtual interface can_phy_node_if can2_node_if;
  virtual interface can_phy_bus_if  can_bus_if;  

  //Environment Configuration
  example_tb_config tb_cfg;

  //ADC UVC
  example_adc_env adc;

  //Open drain UVC's
  od_agent mpo1, mpo2, mpo3, mpo4, mpo5, mpo6, isok;

  //WSSIM UVC's
  wssim_agent wssim1, wssim2, wssim3, wssim4;
  wssim_agent_config wssim_config;

  //SCAN UVC
  scan_driver_ti_agent scan_driver_ti;
  scan_driver_cas_agent scan_driver_cas;

  //FMON UVC
  fmon_env  fmon;

  //CAN UVC's
  can_tester_env can1_tester, can2_tester;
  can_phy_env can_protocol_env;

  //PSI5 UVC's
  psi5_tester_agent psi5_1_tester, psi5_2_tester;
  
  //Instrument UVC's
  dms_inst_agent vsource_KL30BA;
  dms_inst_agent vsource_KL30BB;
  dms_inst_agent vsource_VPRE_SUP;
  dms_inst_agent vsource_SLP_GND;  
  dms_inst_agent vsource_VCCA_SUP;
  dms_inst_agent vsource_MOTM;
  dms_inst_agent vsource_MOTP;
  dms_inst_agent vsource_CPVI;
  dms_inst_agent vsource_CPPX;
  dms_inst_agent vsource_PSISUP;

  dms_inst_agent vsource_ISOK;
  dms_inst_agent vsource_MPO1;
  dms_inst_agent vsource_MPO2;
  dms_inst_agent vsource_MPO3;
  dms_inst_agent vsource_MPO4;
  dms_inst_agent vsource_MPO5;
  dms_inst_agent vsource_MPO6;
  dms_inst_agent vsource_IGN;
  dms_inst_agent vsource_MDOFF3;
  dms_inst_agent vsource_MDOFF2;
  dms_inst_agent vsource_MDOFF1;
  dms_inst_agent vsource_HS1;
  dms_inst_agent vsource_HS2;
  dms_inst_agent vsource_HS3;
  dms_inst_agent vsource_HS4;
  dms_inst_agent vsource_INH1;
  dms_inst_agent vsource_FVCCA;
  dms_inst_agent vsource_FVCC3;
  dms_inst_agent vsource_VRCFG;
  dms_inst_agent vsource_ADVCC;
  dms_inst_agent vsource_MONKL30;
  dms_inst_agent vsource_OUT1;
  dms_inst_agent vsource_REF1;
  dms_inst_agent vsource_DRN1;
  dms_inst_agent vsource_DRN2;
  dms_inst_agent vsource_REF2;
  dms_inst_agent vsource_OUT2;
  dms_inst_agent vsource_DRN3;
  dms_inst_agent vsource_SRC3;
  dms_inst_agent vsource_OUT3;
  dms_inst_agent vsource_OUTFRW;
  dms_inst_agent vsource_HS8;
  dms_inst_agent vsource_HS7;
  dms_inst_agent vsource_HS6;
  dms_inst_agent vsource_HS5;
  dms_inst_agent vsource_RP_KL30VI;
  dms_inst_agent vsource_RP_CTRL;
  dms_inst_agent vsource_MON_KL30RP;
  dms_inst_agent vsource_TPM2;
  dms_inst_agent vsource_TPM_HS;
  dms_inst_agent vsource_TPM1;
  dms_inst_agent vsource_SUP_FMON;
  dms_inst_agent vsource_SUP_IO;
  dms_inst_agent vsource_SUP_MPO;
  dms_inst_agent vsource_SUP_SPI;
  dms_inst_agent vsource_VO1;
  dms_inst_agent vsource_VO2;
  dms_inst_agent vsource_VO3;
  dms_inst_agent vsource_VO4;
  dms_inst_agent vsource_VO5;
  dms_inst_agent vsource_VO6;
  dms_inst_agent vsource_VO7;
  dms_inst_agent vsource_VO8;
  dms_inst_agent vsource_VO9;
  dms_inst_agent vsource_VO10;
  dms_inst_agent vsource_VO11;
  dms_inst_agent vsource_VO12;
  dms_inst_agent vsource_VO13;
  dms_inst_agent vsource_VO14;
  
  dms_inst_agent isource_VO11;
  dms_inst_agent isource_VO1;
  dms_inst_agent isource_HS1;
  dms_inst_agent isource_VO2;
  dms_inst_agent isource_HS2;
  dms_inst_agent isource_VO7;
  dms_inst_agent isource_VO8;
  dms_inst_agent isource_HS3;
  dms_inst_agent isource_HS4;
  dms_inst_agent isource_VO5;
  dms_inst_agent isource_VO12;
  dms_inst_agent isource_VRCFG;
  dms_inst_agent isource_VO14;
  dms_inst_agent isource_VO6;
  dms_inst_agent isource_HS8;
  dms_inst_agent isource_HS7;
  dms_inst_agent isource_VO10;
  dms_inst_agent isource_VO9;
  dms_inst_agent isource_HS6;
  dms_inst_agent isource_VO4;
  dms_inst_agent isource_HS5;
  dms_inst_agent isource_VO3;
  dms_inst_agent isource_VO13;

  //Regulator UVC's  
  regulator_agent vreg_VCAN1;
  regulator_agent vreg_VCAN2;
  regulator_agent vreg_PVCC5;
  regulator_agent vreg_PSVCC5;
  regulator_agent vreg_VCC5;
  regulator_agent vreg_EXTVCC5;
  regulator_agent vreg_VPRE;
  regulator_agent vreg_VCCA;
  regulator_agent vreg_VCC3;
  regulator_agent vreg_VDIG;
  regulator_agent vreg_CP;
  regulator_agent vreg_RC1;
  regulator_agent vreg_RC2;
  regulator_agent vreg_V1P5INT_SLP;
  regulator_agent vreg_V3P6INT_SLP;
  regulator_agent vreg_V1P5INT_STB;
  regulator_agent vreg_V3P6INT_STB;
  regulator_agent vreg_V5_VALVES_T;
  regulator_agent vreg_V5_VALVES_B;
  regulator_agent vreg_V5INT_LINEARS;
  
  //eeprom UVC
  eeprom_pkg::eeprom_env eeprom_bank_main;
  eeprom_pkg::eeprom_env eeprom_bank_fmon;
  //TODO-eeprom_env #(.ee_n_logical_word_bits(16), .ee_n_addr_bits(5)) eeprom_bank;
  //SPI UVC
  spi_mpl_phy_master_agent spi_mpl_master;  
  spi_mpl_data_master_agent spi_mpl_data_master;   
  // Digital pinModel uvc
  PCU12_pins  pinDB;
  // Watchdog Component
  example_wd watchdog;
  //Register Layer
  TOP_MAP reg_model;
  example_reg2spi_adapter reg2spi;
  example_register_sequencer reg_sequencer;
  uvm_reg_predictor#(spi_mpl_data_item) reg_predictor;

  //LVM
  ind_addr_data_master_agent ind_addr_agent;
  uvm_sequencer #(ind_addr_data_item, ind_addr_data_item) ind_addr_sequencer;
  TOP_MAP_LVM reg_model_lvm;
  example_reg2spi_adapter_lvm reg2spi_lvm;
  uvm_reg_predictor#(ind_addr_data_item) reg_predictor_lvm;
  
  //CAN_PN1
  ind_addr_data_master_agent ind_addr_agent_can_pn1;
  uvm_sequencer #(ind_addr_data_item, ind_addr_data_item) ind_addr_sequencer_can_pn1;
  TOP_MAP_CAN_PN reg_model_can_pn1;
  example_reg2spi_adapter_can_pn1 reg2spi_can_pn1;
  uvm_reg_predictor#(ind_addr_data_item) reg_predictor_can_pn1;
  
  //CAN_PN2
  ind_addr_data_master_agent ind_addr_agent_can_pn2;
  uvm_sequencer #(ind_addr_data_item, ind_addr_data_item) ind_addr_sequencer_can_pn2;
  TOP_MAP_CAN_PN reg_model_can_pn2;
  example_reg2spi_adapter_can_pn2 reg2spi_can_pn2;
  uvm_reg_predictor#(ind_addr_data_item) reg_predictor_can_pn2;

  //EEPROM_MAIN
  TOP_MAP_EEPROM reg_model_eeprom;
  example_reg2eeprom_adapter reg2eeprom;
  example_register_sequencer_eeprom reg_sequencer_eeprom;
  uvm_reg_predictor#(eeprom_pkg::ee_bus_transaction) reg_predictor_eeprom;
  uvm_reg_predictor#(ind_addr_data_item) reg_predictor_ind_eeprom;
  ind_addr_data_master_agent ind_addr_agent_eeprom;

  // virtual sequencer
  example_virtual_sequencer example_vsqr;
  // monitor
  example_monitor example_mon;
  // utilities
  example_utilities example_utils;

  
  //------------------------------------------
  // Constraints
  //------------------------------------------
   
  //------------------------------------------
  // Methods
  //------------------------------------------
   
  // Standard UVM Methods:
  extern function new(string name = "example_tb", uvm_component parent = null);
  extern function void build_phase(uvm_phase phase);
  extern function void connect_phase(uvm_phase phase);
  extern function void report_phase(uvm_phase phase);
endclass:example_tb

//////////////////////////////////////////////////////////
//new
//////////////////////////////////////////////////////////

function example_tb::new(string name = "example_tb", uvm_component parent = null);
   super.new(name, parent);
endfunction

//////////////////////////////////////////////////////////
//build
//////////////////////////////////////////////////////////
function void example_tb::build_phase(uvm_phase phase);
  string inst_name;
  uvm_cmdline_processor clp;
  int num_arg_match;
  string sim_temp;
  string sim_model;
  string sim_config;

  super.build_phase(phase);

  clp = uvm_cmdline_processor::get_inst();

  if(!uvm_config_db #(example_tb_config)::get(this, "", "tb_cfg", tb_cfg)) begin
      `uvm_error("build_phase", "Failed to find example_tb_config")
  end

  //grab csv logger items
  if (!uvm_config_db#(example_csv_if_item)::get(this,"","csv_if_logger_h",csv_if_logger_h))
      `uvm_fatal("NOCSV",{"csv_if_logger_h must be set for: ",get_full_name(),".csv_if_logger_h"})
  if (!uvm_config_db#(csv_writer#(parametric_db_item))::get(this,"","csv_writer_h",csv_writer_h))
      `uvm_fatal("NOCSV",{"csv_writer_h must be set for: ",get_full_name(),".csv_writer_h"})
  if (!uvm_config_db#(csv_writer#(functional_db_item))::get(this,"","csv_writer_func_h",csv_writer_func_h))
      `uvm_fatal("NOCSV",{"csv_writer_func_h must be set for: ",get_full_name(),".csv_writer_func_h"})

  //VIRTUAL SEQUENCER:
  example_vsqr = example_virtual_sequencer::type_id::create("example_vsqr", this);
  

  //REG LAYER
  // create register model
  reg_model = TOP_MAP::type_id::create("reg_model");
  reg_model.build();
  reg_model.lock_model();

  //pinModel 
  pinDB = PCU12_pins::type_id::create("pinDB", this);
  uvm_config_db #(TOP_MAP)::set(null, "*", "regfile", reg_model);

  // create register adapter (SPI)
  reg2spi = example_reg2spi_adapter::type_id::create("reg2spi");
  // create register sequencer (SPI)
  reg_sequencer = example_register_sequencer::type_id::create("reg_sequencer", this);
  // create register predictor (SPI)
  reg_predictor = uvm_reg_predictor#(spi_mpl_data_item)::type_id::create("reg_predictor", this);

  //LVM REG LAYER
  reg_model_lvm = TOP_MAP_LVM::type_id::create("reg_model_lvm");
  reg_model_lvm.build();
  reg_model_lvm.lock_model();

  ind_addr_sequencer = uvm_sequencer#(ind_addr_data_item, ind_addr_data_item)::type_id::create("ind_addr_sequencer", this);
  // create register adapter (SPI)
  reg2spi_lvm = example_reg2spi_adapter_lvm::type_id::create("reg2spi_lvm");
  // create register predictor (SPI)
  reg_predictor_lvm = uvm_reg_predictor#(ind_addr_data_item)::type_id::create("reg_predictor_lvm", this);
  ind_addr_agent = ind_addr_data_master_agent::type_id::create("ind_addr_agent", this);

  //CAN_PN1 Reg Layer
  reg_model_can_pn1 = TOP_MAP_CAN_PN::type_id::create("reg_model_can_pn1");
  reg_model_can_pn1.build();
  reg_model_can_pn1.lock_model();

  ind_addr_sequencer_can_pn1 = uvm_sequencer#(ind_addr_data_item, ind_addr_data_item)::type_id::create("ind_addr_sequencer_can_pn1", this);
  // create register adapter (SPI)
  reg2spi_can_pn1 = example_reg2spi_adapter_can_pn1::type_id::create("reg2spi_can_pn1");
  // create register predictor (SPI)
  reg_predictor_can_pn1 = uvm_reg_predictor#(ind_addr_data_item)::type_id::create("reg_predictor_can_pn1", this);
  ind_addr_agent_can_pn1 = ind_addr_data_master_agent::type_id::create("ind_addr_agent_can_pn1", this);
  
  //CAN_PN2 Reg Layer
  reg_model_can_pn2 = TOP_MAP_CAN_PN::type_id::create("reg_model_can_pn2");
  reg_model_can_pn2.build();
  reg_model_can_pn2.lock_model();

  ind_addr_sequencer_can_pn2 = uvm_sequencer#(ind_addr_data_item, ind_addr_data_item)::type_id::create("ind_addr_sequencer_can_pn2", this);
  // create register adapter (SPI)
  reg2spi_can_pn2 = example_reg2spi_adapter_can_pn2::type_id::create("reg2spi_can_pn2");
  // create register predictor (SPI)
  reg_predictor_can_pn2 = uvm_reg_predictor#(ind_addr_data_item)::type_id::create("reg_predictor_can_pn2", this);
  ind_addr_agent_can_pn2 = ind_addr_data_master_agent::type_id::create("ind_addr_agent_can_pn2", this);
  

  reg_model_eeprom = TOP_MAP_EEPROM::type_id::create("reg_model_eeprom");
  reg_model_eeprom.build();
  reg_model_eeprom.lock_model();
  // create register adapter (EEPROM)
  reg2eeprom = example_reg2eeprom_adapter::type_id::create("reg2eeprom");
  // create register sequencer (EEPROM)
  reg_sequencer_eeprom = example_register_sequencer_eeprom::type_id::create("reg_sequencer_eeprom", this);
  // create register predictor (EEPROM)
  reg_predictor_eeprom = uvm_reg_predictor#(eeprom_pkg::ee_bus_transaction)::type_id::create("reg_predictor_eeprom", this);
  reg_predictor_ind_eeprom = uvm_reg_predictor#(ind_addr_data_item)::type_id::create("reg_predictor_ind_eeprom", this);
  ind_addr_agent_eeprom = ind_addr_data_master_agent::type_id::create("ind_addr_agent_eeprom", this);
    
  //Watchdog
  watchdog = example_wd::type_id::create("watchdog", this);

  //MONITOR
  example_mon = example_monitor::type_id::create("example_mon", this);
  
  //UTILITIES
  example_utils = example_utilities::type_id::create("example_utils", this);
  

  //SPI UVC
  if (tb_cfg.has_spi_agent) begin
    //create SPI agent
    spi_mpl_master= spi_mpl_phy_master_agent::type_id::create("spi_mpl_master", this);
    spi_mpl_data_master= spi_mpl_data_master_agent::type_id::create("spi_mpl_data_master", this);
    if(!uvm_config_db #(virtual spi_mpl_if)::get(this, "", "spi_if", spi_mpl_master.SPI)) begin
	    `uvm_error("NOVIF", "SPI virtual interface not found")
      end
    if (!uvm_config_db#(virtual spi_mpl_if)::get(this,"","spi_if", spi_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".spi_if"})

  end


  
  //TODO  - 
 // // create Digital CTRL env
 // if (tb_cfg.has_digital_ctrl) begin
 //   dc_env = digital_ctrl_env::type_id::create("dc_env", this);
 //   uvm_config_db#(digital_ctrl_config)::set(this, "dc_env", "cfg", tb_cfg.dc_cfg);
 //   // connect monitor to Digital Control uVC's configuration port
 //   example_mon.digital_ctrl_cfg_port.connect(dc_env.dut_cfg_port_in);
 // end
 // //EEPROM UVC:
 // //over-ride transactions to be of type 16row 16column 
  set_inst_override_by_type("eeprom_bank_main*",eeprom_pkg::ee_bus_transaction::get_type(),eeprom_pkg::ee_bus_transaction_00128008040::get_type());
  set_inst_override_by_type("eeprom_bank_main*",eeprom_pkg::ee_memory_transaction::get_type(),eeprom_pkg::ee_memory_transaction_00128008040::get_type());
  set_inst_override_by_type("eeprom_bank_fmon*",eeprom_pkg::ee_bus_transaction::get_type(),eeprom_pkg::ee_bus_transaction_00008004040::get_type());
  set_inst_override_by_type("eeprom_bank_fmon*",eeprom_pkg::ee_memory_transaction::get_type(),eeprom_pkg::ee_memory_transaction_00008004040::get_type());
  set_config_int("eeprom_bank_main","num_agents",1);          
  uvm_config_db#(uvm_active_passive_enum)::set(this, "eeprom_bank_main.*", "is_active", UVM_PASSIVE);     
  uvm_config_db#(bit)::set(this, "eeprom_bank_main.*", "checks_enable", 1);    
  eeprom_bank_main = eeprom_pkg::eeprom_env::type_id::create("eeprom_bank_main", this);    

  set_config_int("eeprom_bank_fmon","num_agents",1);          
  uvm_config_db#(uvm_active_passive_enum)::set(this, "eeprom_bank_fmon.*", "is_active", UVM_PASSIVE);     
  uvm_config_db#(bit)::set(this, "eeprom_bank_fmon.*", "checks_enable", 1);    
  eeprom_bank_fmon = eeprom_pkg::eeprom_env::type_id::create("eeprom_bank_fmon", this);    

  //WSSIM UVC's

  wssim_config = wssim_agent_config::type_id::create("wssim_config", this);

  uvm_config_db#(wssim_pkg::wssim_agent_config)::set(this,"wssim1","config", wssim_config);
  uvm_config_db#(wssim_pkg::wssim_agent_config)::set(this,"wssim2","config", wssim_config);
  uvm_config_db#(wssim_pkg::wssim_agent_config)::set(this,"wssim3","config", wssim_config);
  uvm_config_db#(wssim_pkg::wssim_agent_config)::set(this,"wssim4","config", wssim_config);

  wssim1 = wssim_agent::type_id::create("wssim1", this);    
  wssim2 = wssim_agent::type_id::create("wssim2", this);    
  wssim3 = wssim_agent::type_id::create("wssim3", this);    
  wssim4 = wssim_agent::type_id::create("wssim4", this);    

  //ADC
  adc = example_adc_env::type_id::create("adc", this);

  //Open Drain UVC
  uvm_config_db#(od_config)::set(this, "mpo1*", "od_cfg", tb_cfg.mpo1_config);
  uvm_config_db#(od_config)::set(this, "mpo2*", "od_cfg", tb_cfg.mpo2_config);
  uvm_config_db#(od_config)::set(this, "mpo3*", "od_cfg", tb_cfg.mpo3_config);
  uvm_config_db#(od_config)::set(this, "mpo4*", "od_cfg", tb_cfg.mpo4_config);
  uvm_config_db#(od_config)::set(this, "mpo5*", "od_cfg", tb_cfg.mpo5_config);
  uvm_config_db#(od_config)::set(this, "mpo6*", "od_cfg", tb_cfg.mpo6_config);
  uvm_config_db#(od_config)::set(this, "isok", "od_cfg", tb_cfg.isok_config);
  mpo1 = od_agent::type_id::create("mpo1",this);
  mpo2 = od_agent::type_id::create("mpo2",this);
  mpo3 = od_agent::type_id::create("mpo3",this);
  mpo4 = od_agent::type_id::create("mpo4",this);
  mpo5 = od_agent::type_id::create("mpo5",this);
  mpo6 = od_agent::type_id::create("mpo6",this);
  isok = od_agent::type_id::create("isok",this);




  //FMON UVC
  fmon = fmon_env::type_id::create("fmon", this);    

  //SCAN UVC
  scan_driver_ti = scan_driver_ti_agent::type_id::create("scan_driver_ti", this);    
  scan_driver_cas = scan_driver_cas_agent::type_id::create("scan_driver_cas", this);    
  


  //PSI5 TESTER UVC's
  if(tb_cfg.has_psi5_tester) begin
    uvm_config_db#(psi5_tester_agent_config)::set(this, "psi5_1_tester", "cfg", tb_cfg.psi5_1_tester_config);
    uvm_config_db#(psi5_tester_agent_config)::set(this, "psi5_2_tester", "cfg", tb_cfg.psi5_2_tester_config);
    psi5_1_tester = psi5_tester_agent::type_id::create("psi5_1_tester", this);    
    psi5_2_tester = psi5_tester_agent::type_id::create("psi5_2_tester", this);    
  end

  //CAN TESTER UVC's
  if(tb_cfg.has_can_tester) begin
    can1_tester = can_tester_env::type_id::create("can1_tester", this);    
    can2_tester = can_tester_env::type_id::create("can2_tester", this);    
    uvm_config_db#(uvm_active_passive_enum)::set(this, "can?_tester.*", 
                  "tester_bus_termination_is_active", tb_cfg.can_tester_bus_termination_is_active);
  end
    
  //CAN PROTOCOL UVC's 
  if(tb_cfg.has_can_protocol_env) begin    
    can_protocol_env = can_phy_env::type_id::create("can_protocol_env", this);    
    set_config_int("can_protocol_env","num_node_agents",tb_cfg.num_can_phy_node_agents);        
    set_config_int("can_protocol_env","num_bus_agents",tb_cfg.num_can_phy_bus_agents);
    set_config_int("can_protocol_env","has_phy_checks",tb_cfg.has_can_phy_checks);
    set_config_int("can_protocol_env","has_protocol_checks",tb_cfg.has_can_protocol_checks);

    if (!uvm_config_db#(virtual interface can_phy_node_if)::get(this,"","can1_node_if", can1_node_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".can1_node_if"})
    if (!uvm_config_db#(virtual interface can_phy_node_if)::get(this,"","can2_node_if", can2_node_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".can2_node_if"})
    if (!uvm_config_db#(virtual interface can_phy_bus_if)::get(this,"","can_bus_if", can_bus_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".can_bus_if"})

    for(int i =0; i<tb_cfg.num_can_phy_node_agents; i++) begin
      $sformat(inst_name, "node_agents[%0d]",i);
      set_config_int({"can_protocol_env.",inst_name},"node_number",i+1);
    end
    for(int i =0; i<tb_cfg.num_can_phy_bus_agents; i++) begin
      $sformat(inst_name, "bus_agents[%0d]",i);
      set_config_int({"can_protocol_env.",inst_name},"node_number",i+tb_cfg.num_can_phy_node_agents+1);
    end
    set_config_int("can_protocol_env*","monitor_protocol",tb_cfg.can_phy_monitor_protocol);
    uvm_config_db#(uvm_active_passive_enum)::set(this, "can_protocol_env.*", "is_active", UVM_ACTIVE);     
    //uvm_config_db#(bit)::set(this, "can_protocol_env.*.*", "checks_enable", tb_cfg.can_phy_checks_enable);   
  end

 // //Voltage Source Instrument UVC's
  if(tb_cfg.has_vsource_inst) begin    
    uvm_config_db#(uvm_active_passive_enum)::set(this, "vsource_*", "is_active", UVM_ACTIVE); //set all drivers to active config      
    vsource_KL30BA = dms_inst_agent::type_id::create("vsource_KL30BA", this);
    vsource_KL30BB = dms_inst_agent::type_id::create("vsource_KL30BB", this);
    vsource_VPRE_SUP = dms_inst_agent::type_id::create("vsource_VPRE_SUP", this);
    vsource_SLP_GND = dms_inst_agent::type_id::create("vsource_SLP_GND", this);
    vsource_VCCA_SUP = dms_inst_agent::type_id::create("vsource_VCCA_SUP", this);
    vsource_MOTM = dms_inst_agent::type_id::create("vsource_MOTM", this);
    vsource_MOTP = dms_inst_agent::type_id::create("vsource_MOTP", this);
    vsource_CPVI = dms_inst_agent::type_id::create("vsource_CPVI", this);
    vsource_CPPX = dms_inst_agent::type_id::create("vsource_CPPX", this);
    vsource_ISOK = dms_inst_agent::type_id::create("vsource_ISOK", this);
    vsource_MPO1 = dms_inst_agent::type_id::create("vsource_MPO1", this);
    vsource_MPO2 = dms_inst_agent::type_id::create("vsource_MPO2", this);
    vsource_MPO3 = dms_inst_agent::type_id::create("vsource_MPO3", this);
    vsource_MPO4 = dms_inst_agent::type_id::create("vsource_MPO4", this);
    vsource_MPO5 = dms_inst_agent::type_id::create("vsource_MPO5", this);
    vsource_MPO6 = dms_inst_agent::type_id::create("vsource_MPO6", this);
    vsource_FVCCA = dms_inst_agent::type_id::create("vsource_FVCCA", this);
    vsource_FVCC3 = dms_inst_agent::type_id::create("vsource_FVCC3", this);
    vsource_MDOFF3 = dms_inst_agent::type_id::create("vsource_MDOFF3", this);
    vsource_MDOFF2 = dms_inst_agent::type_id::create("vsource_MDOFF2", this);
    vsource_MDOFF1 = dms_inst_agent::type_id::create("vsource_MDOFF1", this);
    vsource_HS1 = dms_inst_agent::type_id::create("vsource_HS1", this);
    vsource_HS2 = dms_inst_agent::type_id::create("vsource_HS2", this);
    vsource_HS3 = dms_inst_agent::type_id::create("vsource_HS3", this);
    vsource_HS4 = dms_inst_agent::type_id::create("vsource_HS4", this);
    vsource_INH1 = dms_inst_agent::type_id::create("vsource_INH1", this);
    vsource_TPM2 = dms_inst_agent::type_id::create("vsource_TPM2", this);
    vsource_TPM_HS = dms_inst_agent::type_id::create("vsource_TPM_HS", this);
    vsource_TPM1 = dms_inst_agent::type_id::create("vsource_TPM1", this);
    vsource_VRCFG = dms_inst_agent::type_id::create("vsource_VRCFG", this);
    vsource_ADVCC = dms_inst_agent::type_id::create("vsource_ADVCC", this);
    vsource_IGN = dms_inst_agent::type_id::create("vsource_IGN", this);
    vsource_MON_KL30RP = dms_inst_agent::type_id::create("vsource_MON_KL30RP", this);
    vsource_MONKL30 = dms_inst_agent::type_id::create("vsource_MONKL30", this);
    vsource_OUT1 = dms_inst_agent::type_id::create("vsource_OUT1", this);
    vsource_REF1 = dms_inst_agent::type_id::create("vsource_REF1", this);
    vsource_DRN1 = dms_inst_agent::type_id::create("vsource_DRN1", this);
    vsource_DRN2 = dms_inst_agent::type_id::create("vsource_DRN2", this);
    vsource_REF2 = dms_inst_agent::type_id::create("vsource_REF2", this);
    vsource_OUT2 = dms_inst_agent::type_id::create("vsource_OUT2", this);
    vsource_DRN3 = dms_inst_agent::type_id::create("vsource_DRN3", this);
    vsource_SRC3 = dms_inst_agent::type_id::create("vsource_SRC3", this);
    vsource_OUT3 = dms_inst_agent::type_id::create("vsource_OUT3", this);
    vsource_OUTFRW = dms_inst_agent::type_id::create("vsource_OUTFRW", this);
    vsource_HS8 = dms_inst_agent::type_id::create("vsource_HS8", this);
    vsource_HS7 = dms_inst_agent::type_id::create("vsource_HS7", this);
    vsource_HS6 = dms_inst_agent::type_id::create("vsource_HS6", this);
    vsource_HS5 = dms_inst_agent::type_id::create("vsource_HS5", this);
    vsource_RP_KL30VI = dms_inst_agent::type_id::create("vsource_RP_KL30VI", this);
    vsource_RP_CTRL = dms_inst_agent::type_id::create("vsource_RP_CTRL", this);    
    vsource_SUP_IO = dms_inst_agent::type_id::create("vsource_SUP_IO", this);
    vsource_SUP_SPI = dms_inst_agent::type_id::create("vsource_SUP_SPI", this);
    vsource_SUP_FMON = dms_inst_agent::type_id::create("vsource_SUP_FMON", this);
    vsource_SUP_MPO = dms_inst_agent::type_id::create("vsource_SUP_MPO", this);
    vsource_VO1 = dms_inst_agent::type_id::create("vsource_VO1", this);
    vsource_VO2 = dms_inst_agent::type_id::create("vsource_VO2", this);
    vsource_VO3 = dms_inst_agent::type_id::create("vsource_VO3", this);
    vsource_VO4 = dms_inst_agent::type_id::create("vsource_VO4", this);
    vsource_VO5 = dms_inst_agent::type_id::create("vsource_VO5", this);
    vsource_VO6 = dms_inst_agent::type_id::create("vsource_VO6", this);
    vsource_VO7 = dms_inst_agent::type_id::create("vsource_VO7", this);
    vsource_VO8 = dms_inst_agent::type_id::create("vsource_VO8", this);
    vsource_VO9 = dms_inst_agent::type_id::create("vsource_VO9", this);
    vsource_VO10 = dms_inst_agent::type_id::create("vsource_VO10", this);
    vsource_VO11 = dms_inst_agent::type_id::create("vsource_VO11", this);
    vsource_VO12 = dms_inst_agent::type_id::create("vsource_VO12", this);
    vsource_VO13 = dms_inst_agent::type_id::create("vsource_VO13", this);
    vsource_VO14 = dms_inst_agent::type_id::create("vsource_VO14", this);
    vsource_PSISUP = dms_inst_agent::type_id::create("vsource_PSISUP", this);
    
    isource_VO11 = dms_inst_agent::type_id::create("isource_VO11", this);
    isource_VO1 = dms_inst_agent::type_id::create("isource_VO1", this);
    isource_HS1 = dms_inst_agent::type_id::create("isource_HS1", this);
    isource_VO2 = dms_inst_agent::type_id::create("isource_VO2", this);
    isource_HS2 = dms_inst_agent::type_id::create("isource_HS2", this);
    isource_VO7 = dms_inst_agent::type_id::create("isource_VO7", this);
    isource_VO8 = dms_inst_agent::type_id::create("isource_VO8", this);
    isource_HS3 = dms_inst_agent::type_id::create("isource_HS3", this);
    isource_HS4 = dms_inst_agent::type_id::create("isource_HS4", this);
    isource_VO5 = dms_inst_agent::type_id::create("isource_VO5", this);
    isource_VO12 = dms_inst_agent::type_id::create("isource_VO12", this);
    isource_VRCFG = dms_inst_agent::type_id::create("isource_VRCFG", this);
    isource_VO14 = dms_inst_agent::type_id::create("isource_VO14", this);
    isource_VO6 = dms_inst_agent::type_id::create("isource_VO6", this);
    isource_HS8 = dms_inst_agent::type_id::create("isource_HS8", this);
    isource_HS7 = dms_inst_agent::type_id::create("isource_HS7", this);
    isource_VO10 = dms_inst_agent::type_id::create("isource_VO10", this);
    isource_VO9 = dms_inst_agent::type_id::create("isource_VO9", this);
    isource_HS6 = dms_inst_agent::type_id::create("isource_HS6", this);
    isource_VO4 = dms_inst_agent::type_id::create("isource_VO4", this);
    isource_HS5 = dms_inst_agent::type_id::create("isource_HS5", this);
    isource_VO3 = dms_inst_agent::type_id::create("isource_VO3", this);
    isource_VO13 = dms_inst_agent::type_id::create("isource_VO13", this);              
  end

  //REGULATOR UVC:
  if(tb_cfg.has_regulator) begin
    vreg_VCAN1 = regulator_agent::type_id::create("vreg_VCAN1", this);
    vreg_VCAN2 = regulator_agent::type_id::create("vreg_VCAN2", this);
    vreg_PVCC5 = regulator_agent::type_id::create("vreg_PVCC5", this);
    vreg_PSVCC5 = regulator_agent::type_id::create("vreg_PSVCC5", this);
    vreg_VCC5 = regulator_agent::type_id::create("vreg_VCC5", this);
    vreg_EXTVCC5 = regulator_agent::type_id::create("vreg_EXTVCC5", this);
    vreg_VPRE = regulator_agent::type_id::create("vreg_VPRE", this);
    vreg_VCCA = regulator_agent::type_id::create("vreg_VCCA", this);
    vreg_VCC3 = regulator_agent::type_id::create("vreg_VCC3", this);
    vreg_VDIG = regulator_agent::type_id::create("vreg_VDIG", this);
    vreg_CP = regulator_agent::type_id::create("vreg_CP", this);
    vreg_RC1 = regulator_agent::type_id::create("vreg_RC1", this);
    vreg_RC2 = regulator_agent::type_id::create("vreg_RC2", this);
    vreg_V1P5INT_SLP = regulator_agent::type_id::create("vreg_V1P5INT_SLP", this);
    vreg_V3P6INT_SLP = regulator_agent::type_id::create("vreg_V3P6INT_SLP", this);
    vreg_V1P5INT_STB = regulator_agent::type_id::create("vreg_V1P5INT_STB", this);
    vreg_V3P6INT_STB = regulator_agent::type_id::create("vreg_V3P6INT_STB", this);
    vreg_V5_VALVES_T = regulator_agent::type_id::create("vreg_V5_VALVES_T", this);
    vreg_V5_VALVES_B = regulator_agent::type_id::create("vreg_V5_VALVES_B", this);
    vreg_V5INT_LINEARS = regulator_agent::type_id::create("vreg_V5INT_LINEARS", this);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VCAN1", "config", tb_cfg.vreg_VCAN1_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VCAN2", "config", tb_cfg.vreg_VCAN2_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_PVCC5", "config", tb_cfg.vreg_PVCC5_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_PSVCC5", "config", tb_cfg.vreg_PSVCC5_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VCC5", "config", tb_cfg.vreg_VCC5_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_EXTVCC5", "config", tb_cfg.vreg_EXTVCC5_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VPRE", "config", tb_cfg.vreg_VPRE_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VCCA", "config", tb_cfg.vreg_VCCA_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VCC3", "config", tb_cfg.vreg_VCC3_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_VDIG", "config", tb_cfg.vreg_VDIG_config);
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_CP", "config", tb_cfg.vreg_CP_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_RC1", "config", tb_cfg.vreg_RC1_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_RC2", "config", tb_cfg.vreg_RC2_config);   
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V1P5INT_SLP", "config", tb_cfg.vreg_V1P5INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V1P5INT_STB", "config", tb_cfg.vreg_V1P5INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V3P6INT_SLP", "config", tb_cfg.vreg_V3P6INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V3P6INT_STB", "config", tb_cfg.vreg_V3P6INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V5_VALVES_T", "config", tb_cfg.vreg_V5INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V5_VALVES_B", "config", tb_cfg.vreg_V5INT_config);    
    uvm_config_db#(regulator_agent_config)::set(this, "vreg_V5INT_LINEARS", "config", tb_cfg.vreg_V5INT_config);    
  end

  if(tb_cfg.has_analog_e2r) begin
    if (!uvm_config_db#(virtual interface example_e2r_if)::get(this,"","analog_if", analog_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".analog_if"})
    csv_if_logger_h.vif = analog_if;
  end

  if(tb_cfg.has_switches) begin
    if (!uvm_config_db#(virtual interface example_tb_if)::get(this,"","tb_if", tb_if))
      `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".tb_if"})
  end

  if (!uvm_config_db#(virtual interface example_model_if)::get(this,"","model_if", model_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".model_if"})

  if (!uvm_config_db#(eeprom_pkg::eeprom_if_base)::get(this,"","eeprom_ip_if_main", eeprom_ip_if_main))
     `uvm_fatal("NOVIF",{"interface must be set for: ",get_full_name(),".eeprom_ip_if_main"})
   if (!uvm_config_db#(eeprom_pkg::eeprom_if_base)::get(this,"","eeprom_ip_if_fmon", eeprom_ip_if_fmon))
      `uvm_fatal("NOVIF",{"interface must be set for: ",get_full_name(),".eeprom_ip_if_fmon"})
  if (!uvm_config_db#(virtual interface cas_digital_if)::get(this,"","cas_dig_if", cas_dig_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".cas_dig_if"})
  if (!uvm_config_db#(virtual interface sleep_digital_if)::get(this,"","sleep_dig_if", sleep_dig_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".sleep_dig_if"})
  if (!uvm_config_db#(virtual interface psm_digital_if)::get(this,"","psm_dig_if", psm_dig_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".psm_dig_if"})
  if (!uvm_config_db#(virtual interface smps_digital_if)::get(this,"","smps_dig_if", smps_dig_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".smps_dig_if"})
  if (!uvm_config_db#(virtual interface fmon_ee_digital_if)::get(this,"","fmon_ee_dig_if", fmon_ee_dig_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".fmon_ee_dig_if"})

  example_mon.cas_dig_if = cas_dig_if;
  example_vsqr.cas_dig_if = cas_dig_if; 
  example_mon.sleep_dig_if = sleep_dig_if;
  example_vsqr.sleep_dig_if = sleep_dig_if; 
  example_mon.psm_dig_if = psm_dig_if;
  example_vsqr.psm_dig_if = psm_dig_if;
  example_mon.smps_dig_if = smps_dig_if;
  example_vsqr.smps_dig_if = smps_dig_if; 
  example_mon.fmon_ee_dig_if = fmon_ee_dig_if;
  example_vsqr.fmon_ee_dig_if = fmon_ee_dig_if; 


  example_mon.spi_if = spi_if;
  example_mon.eeprom_ip_if_main = eeprom_ip_if_main;
  example_mon.eeprom_ip_if_fmon = eeprom_ip_if_fmon;
  
  if (!uvm_config_db#(virtual interface wssim_if)::get(this,"","wssim1_if", wssim1_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".wssim1_if"})
  example_mon.wssim1_if = wssim1_if;
  if (!uvm_config_db#(virtual interface wssim_if)::get(this,"","wssim2_if", wssim2_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".wssim2_if"})
  example_mon.wssim2_if = wssim2_if;
  if (!uvm_config_db#(virtual interface wssim_if)::get(this,"","wssim3_if", wssim3_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".wssim3_if"})
  example_mon.wssim3_if = wssim3_if;
  if (!uvm_config_db#(virtual interface wssim_if)::get(this,"","wssim4_if", wssim4_if))
    `uvm_fatal("NOVIF",{"virtual interface must be set for: ",get_full_name(),".wssim4_if"})
  example_mon.wssim4_if = wssim4_if;

  if (!uvm_config_db#(parametric_db)::get(this,"","specs", specs))
      `uvm_fatal("NOSPEC",{"Spec must be set for: ",get_full_name(),".specs"})
  example_vsqr.specs = specs;
  example_mon.specs = specs;

  //TODO - add tb_cfg to disable csv logger
  csv_writer_h.assign_if_logger(csv_if_logger_h);

  //Read in temperature and model settings from irun command line +args
  num_arg_match = clp.get_arg_value("+TEMP=", sim_temp);
  if(num_arg_match == 0) begin
    sim_temp = "27";
    `uvm_info("SIMINFO","No +TEMP Argument found, Assuming TEMP=27",UVM_LOW)
    end
  else if(num_arg_match == 1) begin
    `uvm_info("SIMINFO",$sformatf("+TEMP=%s Detected for analog temperature", sim_temp),UVM_LOW)
    end
  else begin
    `uvm_warning("SIMINFO",$sformatf("Multiple +TEMP found. Taking 1st one: +TEMP=%s", sim_temp))    
    end

  num_arg_match = clp.get_arg_value("+PROCESS_CORNER=", sim_model);
  if(num_arg_match == 0) begin
    sim_model = "NOMINAL";
    `uvm_info("SIMINFO","No +PROCESS_CORNER Argument found, Assuming PROCESS_CORNER=NOMINAL",UVM_LOW)
    end
  else if(num_arg_match == 1) begin
    `uvm_info("SIMINFO",$sformatf("+PROCESS_CORNER=%s Detected for analog model", sim_model),UVM_LOW)
    end
  else begin
    `uvm_warning("SIMINFO",$sformatf("Multiple +PROCESS_CORNER found. Taking 1st one: +PROCESS_CORNER=%s", sim_model))    
    end

  num_arg_match = clp.get_arg_value("+SIM_CONFIG=", sim_config);
  if(num_arg_match == 0) begin
    sim_config = "UNKOWN";
    `uvm_info("SIMINFO","No +SIM_CONFIG Argument found, Assuming SIM_CONFIG=UNKOWN",UVM_LOW)
    end
  else if(num_arg_match == 1) begin
    `uvm_info("SIMINFO",$sformatf("+SIM_CONFIG=%s Detected", sim_config),UVM_LOW)
    end
  else begin
    `uvm_warning("SIMINFO",$sformatf("Multiple +SIM_CONFIG found. Taking 1st one: +SIM_CONFIG=%s", sim_config))    
    end
  
  example_mon.temperature = sim_temp.atoi();
  csv_writer_h.set_constant("temp",sim_temp);
  csv_writer_h.set_constant("model",sim_model);
  csv_writer_h.set_constant("scope","tb_example_top");
  csv_writer_h.set_constant("config",sim_config);
  csv_writer_h.open_file("example_parametric_results.csv");
  csv_writer_h.write_header();

  csv_writer_func_h.set_constant("temp",sim_temp);
  csv_writer_func_h.set_constant("model",sim_model);
  csv_writer_func_h.set_constant("scope","tb_example_top");
  csv_writer_func_h.set_constant("config",sim_config);
  csv_writer_func_h.open_file("example_functional_results.csv");
  csv_writer_func_h.write_header();
endfunction:build_phase

//////////////////////////////////////////////////////////
//connection
//////////////////////////////////////////////////////////
function void example_tb::connect_phase(uvm_phase phase);

  super.connect_phase(phase);
  
  // register model
  // SPI
  reg_model.default_map.set_sequencer(spi_mpl_data_master.sqr, reg2spi);
  reg_predictor.map = reg_model.default_map;
  reg_predictor.adapter = reg2spi;
  spi_mpl_data_master.ap.connect(reg_predictor.bus_in);
  reg2spi.monitor = example_mon;
  reg2spi.ind_addr_agent = ind_addr_agent;

  //LVM
  ind_addr_sequencer = ind_addr_agent.sqr;
  reg_model_lvm.default_map.set_sequencer(ind_addr_sequencer, reg2spi_lvm);
  reg_predictor_lvm.map = reg_model_lvm.default_map;
  reg_predictor_lvm.adapter = reg2spi_lvm;
  ind_addr_agent.drv.ap.connect(reg_predictor_lvm.bus_in);
  
  reg2spi.lvm_data_mail = ind_addr_agent.ind_addr_data_mail;
  
  //ind_addr_agent.drv.get_txn.connect(lvm_fifo.get_peek_export);
  reg2spi_lvm.monitor = example_mon;

  //CAN_PN1
  ind_addr_sequencer_can_pn1 = ind_addr_agent_can_pn1.sqr;
  reg_model_can_pn1.default_map.set_sequencer(ind_addr_sequencer_can_pn1, reg2spi_can_pn1);
  reg_predictor_can_pn1.map = reg_model_can_pn1.default_map;
  reg_predictor_can_pn1.adapter = reg2spi_can_pn1;
  ind_addr_agent_can_pn1.drv.ap.connect(reg_predictor_can_pn1.bus_in);
  
  reg2spi.can_pn1_data_mail = ind_addr_agent_can_pn1.ind_addr_data_mail;
  
  //ind_addr_agent.drv.get_txn.connect(lvm_fifo.get_peek_export);
  reg2spi_can_pn1.monitor = example_mon;

  //CAN_PN2
  ind_addr_sequencer_can_pn2 = ind_addr_agent_can_pn2.sqr;
  reg_model_can_pn2.default_map.set_sequencer(ind_addr_sequencer_can_pn2, reg2spi_can_pn2);
  reg_predictor_can_pn2.map = reg_model_can_pn2.default_map;
  reg_predictor_can_pn2.adapter = reg2spi_can_pn2;
  ind_addr_agent_can_pn2.drv.ap.connect(reg_predictor_can_pn2.bus_in);
  
  reg2spi.can_pn2_data_mail = ind_addr_agent_can_pn2.ind_addr_data_mail;
  
  //ind_addr_agent.drv.get_txn.connect(lvm_fifo.get_peek_export);
  reg2spi_can_pn2.monitor = example_mon;


  reg_model_eeprom.default_map.set_sequencer(spi_mpl_data_master.sqr, reg2eeprom);
  reg_predictor_eeprom.map = reg_model_eeprom.default_map;
  reg_predictor_eeprom.adapter = reg2eeprom;
  reg_predictor_ind_eeprom.map = reg_model_eeprom.default_map;
  reg_predictor_ind_eeprom.adapter = reg2eeprom;
  eeprom_bank_main.agent[0].bus_monitor.item_collected_port.connect(reg_predictor_eeprom.bus_in);
  ind_addr_agent_eeprom.drv.ap.connect(reg_predictor_ind_eeprom.bus_in);
  reg2eeprom.monitor = example_mon;
  example_vsqr.ee_memory_sqr_main = eeprom_bank_main.agent[0].memory_sequencer; 
  reg2spi.ti_data_mail = ind_addr_agent_eeprom.ind_addr_data_mail;

  //
    
  // EEPROM_FMON
  // reg_predictor_eeprom.map = reg_model.default_map;
  // reg_predictor_eeprom.adapter = reg2eeprom;
  // eeprom_bank_fmon.agent[0].bus_monitor.item_collected_port.connect(reg_predictor_eeprom.bus_in);
  // reg2eeprom.monitor = example_mon;
  example_vsqr.ee_memory_sqr_fmon = eeprom_bank_fmon.agent[0].memory_sequencer; 
  
  // SPI
  if (tb_cfg.has_spi_agent) begin
    // define phy_agent pointer in SPI data agent
    spi_mpl_data_master.phy_agent = spi_mpl_master;   

    example_vsqr.spi_phy_sequencer = spi_mpl_master.sqr;
    example_vsqr.spi_data_sequencer = spi_mpl_data_master.sqr;
    example_vsqr.spi_mpl_master = spi_mpl_master;

    spi_mpl_master.drv.cfg_mpl = 0; //Set default to SPI mode...can be changed in monitor/testcase
    
    // connect global monitor with SPI monitor
    spi_mpl_data_master.ap.connect(example_mon.spi_transaction);
    spi_mpl_master.ap.connect(example_mon.spi_phy_transaction);    
    watchdog.spi_mpl_master = spi_mpl_master;
    watchdog.ap.connect(example_mon.wd_transaction);
  end
  example_vsqr.watchdog = watchdog;
  example_mon.watchdog = watchdog;  
  example_vsqr.reg_model = reg_model;
  example_vsqr.reg_model_eeprom = reg_model_eeprom;
  example_vsqr.reg_model_lvm = reg_model_lvm;
  example_vsqr.reg_model_can_pn1 = reg_model_can_pn1;
  example_vsqr.reg_model_can_pn2 = reg_model_can_pn2;
  example_vsqr.reg_sequencer = reg_sequencer;
  example_vsqr.reg_sequencer_eeprom = reg_sequencer_eeprom;
  
  //connect WSSIM analysis ports to monitor
  wssim1.protocol_ap.connect(example_mon.wssim1_transaction);
  wssim2.protocol_ap.connect(example_mon.wssim2_transaction);
  wssim3.protocol_ap.connect(example_mon.wssim3_transaction);
  wssim4.protocol_ap.connect(example_mon.wssim4_transaction);

  example_vsqr.example_mon = example_mon;
  example_vsqr.example_utils = example_utils;
  
  example_mon.reg_model = reg_model;
  example_mon.reg_model_lvm = reg_model_lvm;
  example_mon.reg_model_can_pn1 = reg_model_can_pn1;
  example_mon.reg_model_can_pn2 = reg_model_can_pn2;
  example_mon.reg_model_eeprom = reg_model_eeprom;  
  example_mon.utilities = example_utils;
  example_mon.tb_cfg = tb_cfg;
  example_utils.reg_model = reg_model;
  
  example_vsqr.wssim1 = wssim1;
  example_vsqr.wssim2 = wssim2;
  example_vsqr.wssim3 = wssim3;
  example_vsqr.wssim4 = wssim4;

  example_vsqr.fmon_sqr = fmon.dig_agent.sequencer;

  //SCAN UVC
  example_vsqr.scan_driver_ti = scan_driver_ti;
  example_vsqr.scan_driver_cas = scan_driver_cas;


  example_vsqr.adc = adc;

  // Virtual sequencer mpo connection
  example_vsqr.mpo1 = mpo1;
  example_vsqr.mpo2 = mpo2;
  example_vsqr.mpo3 = mpo3;
  example_vsqr.mpo4 = mpo4;
  example_vsqr.mpo5 = mpo5;
  example_vsqr.mpo6 = mpo6;
  example_vsqr.isok = isok;
  // example_monitor mpo connection
  example_mon.mpo1 = mpo1;
  example_mon.mpo2 = mpo2;
  example_mon.mpo3 = mpo3;
  example_mon.mpo4 = mpo4;
  example_mon.mpo5 = mpo5;
  example_mon.mpo6 = mpo6;
  example_mon.isok = isok;

  if(tb_cfg.has_psi5_tester) begin
    example_vsqr.psi5_1_tester_sqr = psi5_1_tester.sequencer; 
    example_vsqr.psi5_2_tester_sqr = psi5_2_tester.sequencer;  
    example_vsqr.psi5_1_tester = psi5_1_tester; 
    example_vsqr.psi5_2_tester = psi5_2_tester;
    example_mon.psi5_1_tester = psi5_1_tester;
    example_mon.psi5_2_tester = psi5_2_tester;
  end

  if(tb_cfg.has_can_tester) begin
    example_vsqr.can1_tester_sqr = can1_tester.tester_agent.sequencer; 
    example_vsqr.can2_tester_sqr = can2_tester.tester_agent.sequencer;  
  end

  if(tb_cfg.has_can_protocol_env) begin    
    example_vsqr.can_phy_sqr = can_protocol_env.vseqr;    
    example_vsqr.can1_node_if = can1_node_if;    
    example_vsqr.can2_node_if = can2_node_if;    
    example_vsqr.can_bus_if = can_bus_if;    
  end

  if(tb_cfg.has_vsource_inst) begin    
    example_vsqr.KL30BA_vsource_sqr = vsource_KL30BA.sequencer;
    example_vsqr.KL30BB_vsource_sqr = vsource_KL30BB.sequencer;
    example_vsqr.VPRE_SUP_vsource_sqr = vsource_VPRE_SUP.sequencer;
    example_vsqr.SLP_GND_vsource_sqr = vsource_SLP_GND.sequencer;
    example_vsqr.VCCA_SUP_vsource_sqr = vsource_VCCA_SUP.sequencer;
    example_vsqr.MOTM_vsource_sqr = vsource_MOTM.sequencer;
    example_vsqr.MOTP_vsource_sqr = vsource_MOTP.sequencer;
    example_vsqr.CPVI_vsource_sqr = vsource_CPVI.sequencer;
    example_vsqr.CPPX_vsource_sqr = vsource_CPPX.sequencer;
    example_vsqr.ISOK_vsource_sqr = vsource_ISOK.sequencer;
    example_vsqr.MPO1_vsource_sqr = vsource_MPO1.sequencer;
    example_vsqr.MPO2_vsource_sqr = vsource_MPO2.sequencer;
    example_vsqr.MPO3_vsource_sqr = vsource_MPO3.sequencer;
    example_vsqr.MPO4_vsource_sqr = vsource_MPO4.sequencer;
    example_vsqr.MPO5_vsource_sqr = vsource_MPO5.sequencer;
    example_vsqr.MPO6_vsource_sqr = vsource_MPO6.sequencer;
    example_vsqr.FVCCA_vsource_sqr = vsource_FVCCA.sequencer;
    example_vsqr.FVCC3_vsource_sqr = vsource_FVCC3.sequencer;
    example_vsqr.MDOFF3_vsource_sqr = vsource_MDOFF3.sequencer;
    example_vsqr.MDOFF2_vsource_sqr = vsource_MDOFF2.sequencer;
    example_vsqr.MDOFF1_vsource_sqr = vsource_MDOFF1.sequencer;
    example_vsqr.HS1_vsource_sqr = vsource_HS1.sequencer;
    example_vsqr.HS2_vsource_sqr = vsource_HS2.sequencer;
    example_vsqr.HS3_vsource_sqr = vsource_HS3.sequencer;
    example_vsqr.HS4_vsource_sqr = vsource_HS4.sequencer;
    example_vsqr.INH1_vsource_sqr = vsource_INH1.sequencer;
    example_vsqr.TPM2_vsource_sqr = vsource_TPM2.sequencer;
    example_vsqr.TPM_HS_vsource_sqr = vsource_TPM_HS.sequencer;
    example_vsqr.TPM1_vsource_sqr = vsource_TPM1.sequencer;
    example_vsqr.VRCFG_vsource_sqr = vsource_VRCFG.sequencer;
    example_vsqr.ADVCC_vsource_sqr = vsource_ADVCC.sequencer;
    example_vsqr.IGN_vsource_sqr = vsource_IGN.sequencer;
    example_vsqr.MON_KL30RP_vsource_sqr = vsource_MON_KL30RP.sequencer;
    example_vsqr.MONKL30_vsource_sqr = vsource_MONKL30.sequencer;
    example_vsqr.OUT1_vsource_sqr = vsource_OUT1.sequencer;
    example_vsqr.REF1_vsource_sqr = vsource_REF1.sequencer;
    example_vsqr.DRN1_vsource_sqr = vsource_DRN1.sequencer;
    example_vsqr.DRN2_vsource_sqr = vsource_DRN2.sequencer;
    example_vsqr.REF2_vsource_sqr = vsource_REF2.sequencer;
    example_vsqr.OUT2_vsource_sqr = vsource_OUT2.sequencer;
    example_vsqr.DRN3_vsource_sqr = vsource_DRN3.sequencer;
    example_vsqr.SRC3_vsource_sqr = vsource_SRC3.sequencer;
    example_vsqr.OUT3_vsource_sqr = vsource_OUT3.sequencer;
    example_vsqr.OUTFRW_vsource_sqr = vsource_OUTFRW.sequencer;
    example_vsqr.HS8_vsource_sqr = vsource_HS8.sequencer;
    example_vsqr.HS7_vsource_sqr = vsource_HS7.sequencer;
    example_vsqr.HS6_vsource_sqr = vsource_HS6.sequencer;
    example_vsqr.HS5_vsource_sqr = vsource_HS5.sequencer;
    example_vsqr.RP_KL30VI_vsource_sqr = vsource_RP_KL30VI.sequencer;
    example_vsqr.RP_CTRL_vsource_sqr = vsource_RP_CTRL.sequencer;
    example_vsqr.SUP_IO_vsource_sqr = vsource_SUP_IO.sequencer;
    example_vsqr.SUP_SPI_vsource_sqr = vsource_SUP_SPI.sequencer;
    example_vsqr.SUP_FMON_vsource_sqr = vsource_SUP_FMON.sequencer;
    example_vsqr.SUP_MPO_vsource_sqr = vsource_SUP_MPO.sequencer;
    example_vsqr.VO1_vsource_sqr = vsource_VO1.sequencer;
    example_vsqr.VO2_vsource_sqr = vsource_VO2.sequencer;
    example_vsqr.VO3_vsource_sqr = vsource_VO3.sequencer;
    example_vsqr.VO4_vsource_sqr = vsource_VO4.sequencer;
    example_vsqr.VO5_vsource_sqr = vsource_VO5.sequencer;
    example_vsqr.VO6_vsource_sqr = vsource_VO6.sequencer;
    example_vsqr.VO7_vsource_sqr = vsource_VO7.sequencer;
    example_vsqr.VO8_vsource_sqr = vsource_VO8.sequencer;
    example_vsqr.VO9_vsource_sqr = vsource_VO9.sequencer;
    example_vsqr.VO10_vsource_sqr = vsource_VO10.sequencer;
    example_vsqr.VO11_vsource_sqr = vsource_VO11.sequencer;
    example_vsqr.VO12_vsource_sqr = vsource_VO12.sequencer;
    example_vsqr.VO13_vsource_sqr = vsource_VO13.sequencer;
    example_vsqr.VO14_vsource_sqr = vsource_VO14.sequencer;
    example_vsqr.PSISUP_vsource_sqr = vsource_PSISUP.sequencer;
    
    example_vsqr.VO11_isource_sqr = isource_VO11.sequencer;
    example_vsqr.VO1_isource_sqr = isource_VO1.sequencer;
    example_vsqr.HS1_isource_sqr = isource_HS1.sequencer;
    example_vsqr.VO2_isource_sqr = isource_VO2.sequencer;
    example_vsqr.HS2_isource_sqr = isource_HS2.sequencer;
    example_vsqr.VO7_isource_sqr = isource_VO7.sequencer;
    example_vsqr.VO8_isource_sqr = isource_VO8.sequencer;
    example_vsqr.HS3_isource_sqr = isource_HS3.sequencer;
    example_vsqr.HS4_isource_sqr = isource_HS4.sequencer;
    example_vsqr.VO5_isource_sqr = isource_VO5.sequencer;
    example_vsqr.VO12_isource_sqr = isource_VO12.sequencer;
    example_vsqr.VRCFG_isource_sqr = isource_VRCFG.sequencer;
    example_vsqr.VO14_isource_sqr = isource_VO14.sequencer;
    example_vsqr.VO6_isource_sqr = isource_VO6.sequencer;
    example_vsqr.HS8_isource_sqr = isource_HS8.sequencer;
    example_vsqr.HS7_isource_sqr = isource_HS7.sequencer;
    example_vsqr.VO10_isource_sqr = isource_VO10.sequencer;
    example_vsqr.VO9_isource_sqr = isource_VO9.sequencer;
    example_vsqr.HS6_isource_sqr = isource_HS6.sequencer;
    example_vsqr.VO4_isource_sqr = isource_VO4.sequencer;
    example_vsqr.HS5_isource_sqr = isource_HS5.sequencer;
    example_vsqr.VO3_isource_sqr = isource_VO3.sequencer;
    example_vsqr.VO13_isource_sqr = isource_VO13.sequencer;                 
  end

  if(tb_cfg.has_regulator) begin
    example_vsqr.VCAN1_reg_sqr = vreg_VCAN1.sequencer;
    example_vsqr.VCAN2_reg_sqr = vreg_VCAN2.sequencer;
    example_vsqr.PVCC5_reg_sqr = vreg_PVCC5.sequencer;
    example_vsqr.PSVCC5_reg_sqr = vreg_PSVCC5.sequencer;
    example_vsqr.VCC5_reg_sqr = vreg_VCC5.sequencer;
    example_vsqr.EXTVCC5_reg_sqr = vreg_EXTVCC5.sequencer;
    example_vsqr.VPRE_reg_sqr = vreg_VPRE.sequencer;
    example_vsqr.VCCA_reg_sqr = vreg_VCCA.sequencer;
    example_vsqr.VCC3_reg_sqr = vreg_VCC3.sequencer;
    example_vsqr.VDIG_reg_sqr = vreg_VDIG.sequencer;
    example_vsqr.CP_reg_sqr = vreg_CP.sequencer;     
    example_vsqr.RC1_reg_sqr = vreg_RC1.sequencer;     
    example_vsqr.RC2_reg_sqr = vreg_RC2.sequencer;  
    example_vsqr.V1P5INT_SLP_reg_sqr = vreg_V1P5INT_SLP.sequencer;  
    example_vsqr.V3P6INT_SLP_reg_sqr = vreg_V3P6INT_SLP.sequencer;  
    example_vsqr.V1P5INT_STB_reg_sqr = vreg_V1P5INT_STB.sequencer;  
    example_vsqr.V3P6INT_STB_reg_sqr = vreg_V3P6INT_STB.sequencer;  
    example_vsqr.V5_VALVES_T_reg_sqr = vreg_V5_VALVES_T.sequencer;  
    example_vsqr.V5_VALVES_B_reg_sqr = vreg_V5_VALVES_B.sequencer;  
    example_vsqr.V5INT_LINEARS_reg_sqr = vreg_V5INT_LINEARS.sequencer;  
    example_mon.vreg_VCAN1 =vreg_VCAN1;
    example_mon.vreg_VCAN2 =vreg_VCAN2;
    example_mon.vreg_PVCC5 =vreg_PVCC5;
    example_mon.vreg_PSVCC5 =vreg_PSVCC5;
    example_mon.vreg_VCC5 =vreg_VCC5;
    example_mon.vreg_EXTVCC5 =vreg_EXTVCC5;
    example_mon.vreg_VPRE =vreg_VPRE;
    example_mon.vreg_VCCA =vreg_VCCA;
    example_mon.vreg_VCC3 =vreg_VCC3;
    example_mon.vreg_VDIG =vreg_VDIG;
    example_mon.vreg_CP =vreg_CP;
    example_mon.vreg_RC1 =vreg_RC1;
    example_mon.vreg_RC2 =vreg_RC2;
    example_mon.vreg_V1P5INT_SLP =vreg_V1P5INT_SLP;
    example_mon.vreg_V3P6INT_SLP =vreg_V3P6INT_SLP;
    example_mon.vreg_V1P5INT_STB =vreg_V1P5INT_STB;
    example_mon.vreg_V3P6INT_STB =vreg_V3P6INT_STB;
    example_mon.vreg_V5_VALVES_T =vreg_V5_VALVES_T;
    example_mon.vreg_V5_VALVES_B =vreg_V5_VALVES_B;
    example_mon.vreg_V5INT_LINEARS =vreg_V5INT_LINEARS;

  end

  if(tb_cfg.has_analog_e2r) begin
    example_vsqr.analog_if = analog_if;
    example_mon.analog_if = analog_if;
  end

  if(tb_cfg.has_switches) begin
    example_vsqr.tb_if = tb_if;
    example_mon.tb_if = tb_if;
  end

    example_vsqr.model_if = model_if;

endfunction: connect_phase

function void example_tb::report_phase(uvm_phase phase);
  bit test_case_pass = 0;
  int num_uvm_error;
  int num_uvm_fatal;
  uvm_report_server reportServer;

  super.report_phase(phase);

  reportServer = uvm_report_server::get_server();
  num_uvm_error = reportServer.get_severity_count(UVM_ERROR);
  num_uvm_fatal = reportServer.get_severity_count(UVM_FATAL);
  //`uvm_info("SUMMARY",$sformatf("\nTotal Errors = %0d \nTotal Fatal = %0d",num_uvm_error,num_uvm_fatal),UVM_LOW)

  if(num_uvm_error + num_uvm_fatal == 0)
    test_case_pass = 1;
  else
    test_case_pass = 0;

  //Count pass fail for any functional tests in spec list
  specs.func_test_covered_list(test_case_pass);

  //close csv files
  csv_writer_h.close_file();
  csv_writer_func_h.close_file();

endfunction: report_phase
