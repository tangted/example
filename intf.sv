`ifndef GCK_PERIOD
    `define GCK_PERIOD 50ns
`endif

`ifdef DCK_PERIOD
    `define DCK_PERIOD_WCS `DCK_PERIOD
    `define DCK_PERIOD_BCS `DCK_PERIOD
    `define DCK_PERIOD_TYP `DCK_PERIOD
`else
    `define DCK_PERIOD_WCS 60ns
    `define DCK_PERIOD_BCS 30ns
    `define DCK_PERIOD_TYP 30ns
`endif

interface twall_drv_if;

    parameter CHANNEL_NUM = 48;

`ifdef WCS_SIM
    realtime DCK_HPULSE_WIDTH = `DCK_PERIOD_WCS * 0.5;
    realtime DCK_LPULSE_WIDTH = `DCK_PERIOD_WCS * 0.5;
    realtime LAT_HPULSE_WIDTH = 20ns;
    
    realtime LAT_SETUP_TO_DCK = 3ns; //Signal setup time (LAT^ to SCLK^)  
    realtime LATL_HOLD_TO_DCK = 2ns; //Signal hold time (SCLK^ to LAT^), low voltage hold 
    realtime LATH_HOLD_TO_DCK = 13ns;//Signal hold time (SCLK^ to LATv), high voltage hold
    
    realtime SIN_SETUP_TO_DCK = 2ns;
    realtime SIN_HOLD_TO_DCK  = 2ns;

    realtime LAT_IDLE_TO_DCK_WRITE = 30ns;
    realtime LAT_IDLE_TO_DCK_READ  = 80ns;
    realtime LAT_IDLE_TO_BLANK     = 60ns;
    realtime LAT_IDLE_TO_LAT       = 60ns;

`elsif TYP_SIM
    realtime DCK_HPULSE_WIDTH = `DCK_PERIOD_TYP * 0.5;
    realtime DCK_LPULSE_WIDTH = `DCK_PERIOD_TYP * 0.5;
    realtime LAT_HPULSE_WIDTH = 10ns;
    
    realtime LAT_SETUP_TO_DCK = 3ns; //Signal setup time (LAT^ to SCLK^)  
    realtime LATL_HOLD_TO_DCK = 2ns; //Signal hold time (SCLK^ to LAT^), low voltage hold 
    realtime LATH_HOLD_TO_DCK = 13ns;//Signal hold time (SCLK^ to LATv), high voltage hold
    
    realtime SIN_SETUP_TO_DCK = 2ns;
    realtime SIN_HOLD_TO_DCK  = 2ns;

    realtime LAT_IDLE_TO_DCK_WRITE = 30ns;
    realtime LAT_IDLE_TO_DCK_READ  = 80ns;
    realtime LAT_IDLE_TO_BLANK     = 60ns;
    realtime LAT_IDLE_TO_LAT       = 60ns;

`elsif BCS_SIM
    realtime DCK_HPULSE_WIDTH = `DCK_PERIOD_BCS * 0.5;
    realtime DCK_LPULSE_WIDTH = `DCK_PERIOD_BCS * 0.5;
    realtime LAT_HPULSE_WIDTH = 10ns;
    
    realtime LAT_SETUP_TO_DCK = 3ns; //Signal setup time (LAT^ to SCLK^)  
    realtime LATL_HOLD_TO_DCK = 2ns; //Signal hold time (SCLK^ to LAT^), low voltage hold 
    realtime LATH_HOLD_TO_DCK = 13ns;//Signal hold time (SCLK^ to LATv), high voltage hold
    
    realtime SIN_SETUP_TO_DCK = 2ns;
    realtime SIN_HOLD_TO_DCK  = 2ns;

    realtime LAT_IDLE_TO_DCK_WRITE = 30ns;
    realtime LAT_IDLE_TO_DCK_READ  = 80ns;
    realtime LAT_IDLE_TO_BLANK     = 60ns;
    realtime LAT_IDLE_TO_LAT       = 60ns;

`else
    realtime DCK_HPULSE_WIDTH = `DCK_PERIOD_TYP * 0.5;
    realtime DCK_LPULSE_WIDTH = `DCK_PERIOD_TYP * 0.5;
    realtime LAT_HPULSE_WIDTH = `DCK_PERIOD_TYP * 0.5;
    
    realtime LAT_SETUP_TO_DCK = 3ns; //Signal setup time (LAT^ to SCLK^)  
    realtime LATL_HOLD_TO_DCK = 2ns; //Signal hold time (SCLK^ to LAT^), low voltage hold 
    realtime LATH_HOLD_TO_DCK = 13ns;//Signal hold time (SCLK^ to LATv), high voltage hold
    
    realtime SIN_SETUP_TO_DCK = `DCK_PERIOD_TYP * 0.25;
    realtime SIN_HOLD_TO_DCK  = `DCK_PERIOD_TYP * 0.25;

    realtime LAT_IDLE_TO_DCK_WRITE = `DCK_PERIOD_TYP;
    realtime LAT_IDLE_TO_DCK_READ  = `DCK_PERIOD_TYP * 2;
    realtime LAT_IDLE_TO_BLANK     = `DCK_PERIOD_TYP * 2;
    realtime LAT_IDLE_TO_LAT       = `DCK_PERIOD_TYP * 2;

`endif

    realtime dck_period = DCK_HPULSE_WIDTH + DCK_LPULSE_WIDTH;

    logic dck, sin, sout, gck, gck_en;
    logic lat;
    logic resb;
    logic [33:0] otp_trim = 34'd0;
    logic [15:0] lod_r = 16'd0;
    logic [15:0] lod_g = 16'd0;
    logic [15:0] lod_b = 16'd0;
    logic tsd = 1'b0;
    int sin_volt, lat_volt;
    logic [`CHIP_NUM*CHANNEL_NUM-1:0] out_r, out_g, out_b;

    always begin
        gck = 1'b0;
        wait(gck_en);
        #(`GCK_PERIOD/2);
        gck = 1'b1;
        #(`GCK_PERIOD/2);
    end
    

    modport DUT (
        input dck, sin, lat, gck,
        input resb,
        input otp_trim, lod_r, lod_g, lod_b, tsd,
        input sin_volt, lat_volt,
        output sout,
        output out_r, out_g, out_b
    );

    function void intf_turn_gck (bit on);
        gck_en = on;
    endfunction

    task intf_send_gck (int ck_num);
        gck_en = 1'b1;
        repeat(ck_num) @(posedge gck);
        gck_en = 1'b0;
    endtask

    task intf_lat_time (realtime lat_time=0);
        if (lat_time==0) lat_time = LAT_HPULSE_WIDTH;
        #(LAT_IDLE_TO_LAT); 
        lat = 1'b1;
        #(lat_time);
        lat = 1'b0;
    endtask

    task intf_lat_dck (int dck_num);
        realtime lat_setup_to_dck;
        lat_setup_to_dck = $urandom_range(LAT_SETUP_TO_DCK, (dck_period-LATL_HOLD_TO_DCK));
        sin = 1'b0;
        #(LAT_IDLE_TO_LAT);
        lat = 1'b1;
        #(lat_setup_to_dck);
        if (dck_num == 0) begin
            #(DCK_HPULSE_WIDTH - lat_setup_to_dck + LATH_HOLD_TO_DCK);
            lat = 1'b0;
        end
        else begin
            fork
                for(int i=dck_num-1; i>=0; i--) begin
                    dck = 1'b1;
                    #(DCK_HPULSE_WIDTH);
                    dck = 1'b0;
                    if (i>0) #(DCK_LPULSE_WIDTH);
                end
                begin
                    #((dck_num-1) * dck_period + LATH_HOLD_TO_DCK);
                    lat = 1'b0;
                end
            join
        end
    endtask

    task intf_write_unit (logic [`CHIP_NUM-1:0][CHANNEL_NUM-1:0] data_w, int dck_in_lat, logic read);
        logic [CHANNEL_NUM-1:0] data_in;
        realtime wait_time;
        realtime lat_setup_to_dck;
        lat_setup_to_dck = $urandom_range(LAT_SETUP_TO_DCK, (dck_period-LATL_HOLD_TO_DCK));
        wait_time = read ? LAT_IDLE_TO_DCK_READ : LAT_IDLE_TO_DCK_WRITE;
        foreach (data_w[i])
            $display("data_w[%0d] = %48b", i, data_w[i]); 
        fork
            if (dck_in_lat > 0) begin //LAT
                #(wait_time);
                for(int i=`CHIP_NUM*CHANNEL_NUM-1; i>=0; i--) begin
                    if (i == dck_in_lat) begin
                        #(dck_period-lat_setup_to_dck);
                        lat = 1'b1;
                    end
                    if (i>1) #(dck_period);
                    else begin
                        #(lat_setup_to_dck + LATH_HOLD_TO_DCK);
                        lat = 1'b0;
                    end
                end
            end
            begin //SIN
                #(wait_time - SIN_SETUP_TO_DCK);
                for(int i=`CHIP_NUM-1; i>=0; i--) begin
                    data_in = data_w[i];
                    for (int j=CHANNEL_NUM-1; j>=0; j--) begin
                        sin = data_in[j]; 
                        #(SIN_SETUP_TO_DCK + SIN_HOLD_TO_DCK);
                        sin = 1'bz;
                        if (i+j>0) #(dck_period - SIN_SETUP_TO_DCK - SIN_HOLD_TO_DCK);
                    end    
                end
            end
            begin //DCK
                #(wait_time);
                for(int i=`CHIP_NUM*CHANNEL_NUM-1; i>=0; i--) begin
                    dck = 1'b1;
                    #(DCK_HPULSE_WIDTH);
                    dck = 1'b0;
                    if (i>0) #(DCK_LPULSE_WIDTH);
                end
            end
        join
    endtask

    
    task intf_enter_test ( int set_lat_volt=7, set_sin_volt=7);
        lat_volt = set_lat_volt;
        sin_volt = set_sin_volt;
        #(SIN_HOLD_TO_DCK);
        sin = 1'b1;
        #5ns;
        lat = 1'b1;
        #(LAT_HPULSE_WIDTH);
        lat = 1'b0;
        #5ns;
        sin = 1'b0;
    endtask


    task intf_reset ();
        dck = 1'b0;
        sin = 1'b0;
        lat = 1'b0;
        sin_volt = 5;
        lat_volt = 5;
    endtask

    initial begin
        intf_reset();
        gck_en = 1'b0;
        resb = 1'b0;
        #1us;
        resb = 1'b1;
    end 
    
endinterface
