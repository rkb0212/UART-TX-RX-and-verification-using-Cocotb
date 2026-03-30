`include "uvm_macros.svh"
import uvm_pkg::*;
////////////////////////////////////////////////////////////////////////////
class transaction extends uvm_sequence_item;
  rand bit [7:0] i_tx_byte;
  //bit [7:0] o_rx_byte;
  
  function new(input string path = "transaction");
    super.new(path);
  endfunction
  
  `uvm_object_utils_begin(transaction)
   `uvm_field_int(i_tx_byte, UVM_DEFAULT)
  `uvm_object_utils_end
endclass
//////////////////////////////////////////////////////////////
class generator extends uvm_sequence #(transaction);
`uvm_object_utils(generator)
 
transaction t;
 
  function new(input string path = "generator");
    super.new(path);
  endfunction
virtual task body();
  
  repeat(200) begin
    t = transaction::type_id::create("t");
    start_item(t);
      assert(t.randomize());
      `uvm_info("GEN",$sformatf("Data send to Driver i_tx_byte :%0d ",t.i_tx_byte), UVM_NONE);
    finish_item(t);
    end
endtask
endclass
 ////////////////////////////////////////////////////////////////////
class uart_sequencer extends uvm_sequencer #(transaction);
  `uvm_component_utils(uart_sequencer)

  function new(string path = "uart_sequencer", uvm_component parent = null);
    super.new(path, parent);
  endfunction
endclass 
////////////////////////////////////////////////////////////////////////////
////////////////////////////////////////////////////////////////////
class driver extends uvm_driver #(transaction);
`uvm_component_utils(driver)
 
  virtual uart_if aif;
  uvm_analysis_port #(transaction) drv_ap;
  event next;
    function new(input string path = "driver", uvm_component parent = null);
      super.new(path, parent);
      drv_ap = new("drv_ap", this);
     endfunction
  
 
 
    virtual function void build_phase(uvm_phase phase);
      super.build_phase(phase); 
      if(!uvm_config_db #(virtual uart_if)::get(this,"","aif",aif)) 
      `uvm_error("DRV","Unable to access uvm_config_db");
      
      if(!uvm_config_db#(event)::get(this,"","next_ev",next))
  `uvm_error("DRV","Cannot get next event");
    endfunction
 
    virtual task run_phase(uvm_phase phase);
      transaction tc, tx;
      aif.i_tx_dv <=0;
      aif.i_tx_byte <=8'h00;
    forever begin
    seq_item_port.get_next_item(tc);
      @(posedge aif.i_clock);
      while (aif.o_tx_active) 
      @(posedge aif.i_clock);
    aif.i_tx_byte <= tc.i_tx_byte;
      aif.i_tx_dv <= 1'b1;
      @(posedge aif.i_clock);
      aif.i_tx_dv <= 1'b0;
      `uvm_info("DRV", $sformatf("Trigger DUT tx_byte: %0d",tc.i_tx_byte), UVM_NONE); 
      tx = transaction::type_id::create("tx");
      tx.i_tx_byte = tc.i_tx_byte;
      drv_ap.write(tx);
      @(next);
    seq_item_port.item_done();
      @(posedge aif.i_clock);
      while(!aif.o_tx_done)
        @(posedge aif.i_clock);
    end
   endtask
endclass
 
////////////////////////////////////////////////////////////////////////
class monitor extends uvm_monitor;
`uvm_component_utils(monitor)
  
  virtual uart_if aif;
  uvm_analysis_port #(transaction) mon_ap;
  transaction t;
   
  covergroup cvg_tx;
    option.per_instance = 1;
    option.name = "UART_MONITOR_TX_RANGE_COVERED";
    TX_RANGE_CP: coverpoint t.i_tx_byte{
      bins low = {[0:85]};
      bins med = {[86:170]};
      bins high = {[171:255]};
    }
  endgroup
  
  
  function new(input string path = "monitor", uvm_component parent = null);
    super.new(path, parent);
    mon_ap = new("mon_ap", this);
    cvg_tx = new();
  endfunction
  
  virtual function void build_phase(uvm_phase phase);
   super.build_phase(phase);
    
   if(!uvm_config_db#(virtual uart_if)::get(this,"","aif",aif)) 
   `uvm_error("MON","Unable to access uvm_config_db");
  endfunction

  function void report_phase(uvm_phase phase);
    `uvm_info("MON_COV", $sformatf("Covergroup %s coverage = %0.2f%%", cvg_tx.option.name, cvg_tx.get_coverage()),
    UVM_NONE)
  endfunction
  
    virtual task run_phase(uvm_phase phase);
    forever begin
      @(posedge aif.i_clock);
      if (aif.o_rx_dv) begin
    t = transaction::type_id::create("t");
    t.i_tx_byte = aif.o_rx_byte;
        cvg_tx.sample();   ////////------------
	`uvm_info("MON", $sformatf("Data send to Scoreboard i_tx_byte : %0d", t.i_tx_byte), UVM_NONE);
        
  mon_ap.write(t);
    end
    end
 endtask
endclass
////////////////////////////////////////////////////////////////////////////
`uvm_analysis_imp_decl(_exp)
`uvm_analysis_imp_decl(_act)

class scoreboard extends uvm_scoreboard;
`uvm_component_utils(scoreboard)
 
  uvm_analysis_imp_exp #(transaction,scoreboard) exp_imp;
  uvm_analysis_imp_act #(transaction,scoreboard) act_imp;

  transaction exp_q[$];
  int pass_cnt = 0;
  int fail_cnt = 0;
  int exp_count = 200;
  event next;
  event done;
  transaction tr;
  bit [7:0] tx_byte;
  bit [7:0] rx_byte;
 
  covergroup cvg_tx_rx;
  option.per_instance = 1;
  option.name = "UART_SCOREBOARD_MATCH_COVERED";
  tx_cp: coverpoint tx_byte {
    bins low  = {[0:85]};
    bins med  = {[86:170]};
    bins high = {[171:255]};
  }
  match_cp: coverpoint (tx_byte == rx_byte) {
    bins matched    = {1};
    bins mismatched = {0};}
  TX_MATCH_CROSS: cross tx_cp, match_cp;
endgroup
  
  function new(input string path = "scoreboard", uvm_component parent = null);
    super.new(path, parent);
    exp_imp = new("exp_imp", this);
    act_imp = new("act_imp", this);
    cvg_tx_rx = new();
  endfunction
 
 virtual function void build_phase(uvm_phase phase);
  super.build_phase(phase);
    if(!uvm_config_db#(event)::get(this,"","next_ev",next))
  `uvm_error("SCO","Cannot get next event");
  endfunction

 virtual function void write_exp(input transaction t);
   tr = transaction::type_id::create("tr");
   tr.i_tx_byte = t.i_tx_byte;
   exp_q.push_back(tr);
  `uvm_info("SCO", $sformatf("Expected queued i_tx_byte: %0d", tr.i_tx_byte), UVM_NONE);  
 endfunction
  
virtual function void write_act(transaction t);
    
    transaction exp_tr;
    
    if (exp_q.size() == 0) begin
      `uvm_error("SCO", $sformatf("Unexpected actual byte received: %0d", t.i_tx_byte));
      fail_cnt++;
      -> done;
      return;
    end

    exp_tr = exp_q.pop_front();
  
  tx_byte = exp_tr.i_tx_byte;
  rx_byte = t.i_tx_byte;
  cvg_tx_rx.sample(); 
  
    `uvm_info("SCO", $sformatf("Compare Expected: %0d Actual: %0d", exp_tr.i_tx_byte, t.i_tx_byte), UVM_NONE);

    if (exp_tr.i_tx_byte == t.i_tx_byte) begin
      `uvm_info("SCO", "Test Passed", UVM_NONE);
      pass_cnt++;
    end
    else begin
      `uvm_error("SCO", $sformatf("Test Failed: Expected %0d Actual %0d", exp_tr.i_tx_byte, t.i_tx_byte));
      fail_cnt++;
    end
  ->next;
    if((pass_cnt + fail_cnt) == exp_count) begin
      -> done;
    end
  endfunction
  
  function void report_phase(uvm_phase phase);
    `uvm_info("SCO", $sformatf("PASS=%0d FAIL=%0d PENDING=%0d", pass_cnt, fail_cnt, exp_q.size()), UVM_NONE);
    `uvm_info("SCO_COV", $sformatf("Covergroup %s coverage = %0.2f%%", cvg_tx_rx.option.name, cvg_tx_rx.get_coverage()), UVM_NONE)
endfunction
endclass
////////////////////////////////////////////////
class agent extends uvm_agent;
`uvm_component_utils(agent)
 
 
function new(input string inst = "AGENT", uvm_component c);
super.new(inst, c);
endfunction
 
monitor m;
driver d;
//uvm_sequencer #(transaction) seqr;
uart_sequencer seqr;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  m = monitor::type_id::create("m",this);
  d = driver::type_id::create("d",this);
  //seqr = uvm_sequencer #(transaction)::type_id::create("seqr",this);
  seqr = uart_sequencer::type_id::create("seqr",this);
endfunction
 
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
  d.seq_item_port.connect(seqr.seq_item_export);
endfunction
endclass
 
/////////////////////////////////////////////////////
 
class env extends uvm_env;
`uvm_component_utils(env)
 
 
function new(input string inst = "ENV", uvm_component c);
super.new(inst, c);
endfunction
 
scoreboard s;
agent a;
 
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  s = scoreboard::type_id::create("s",this);
  a = agent::type_id::create("a",this);
endfunction
 
 
virtual function void connect_phase(uvm_phase phase);
super.connect_phase(phase);
  a.d.drv_ap.connect(s.exp_imp);
  a.m.mon_ap.connect(s.act_imp);
endfunction
 
endclass
 
////////////////////////////////////////////
 
class test extends uvm_test;
`uvm_component_utils(test)
 
 
function new(input string inst = "TEST", uvm_component c);
super.new(inst, c);
endfunction
 
generator gen;
env e;
 event next;
virtual function void build_phase(uvm_phase phase);
super.build_phase(phase);
  gen = generator::type_id::create("gen");
  e = env::type_id::create("e",this);
  uvm_config_db#(event)::set(this, "*", "next_ev", next);
endfunction
 
virtual task run_phase(uvm_phase phase);
   phase.raise_objection(this);
  e.s.exp_count = 200;
  fork
   gen.start(e.a.seqr);
   begin
     @e.s.done;
   end
  join
   phase.drop_objection(this);
endtask
endclass
//////////////////////////////////////////////////////////////////////////
module uart_tb();
  parameter c_clock_period_ns = 100;
  parameter c_CLKS_PER_BIT    = 87;
  uart_if aif();
  
  initial begin
    aif.i_clock = 0;
  end
  always #(c_clock_period_ns/2) aif.i_clock = ~aif.i_clock;
  
  uart_loopback_top #(.CLKS_PER_BIT(c_CLKS_PER_BIT) ) dut (
    .i_clock     (aif.i_clock),
    .i_tx_dv     (aif.i_tx_dv),
    .i_tx_byte   (aif.i_tx_byte),
    .o_tx_active (aif.o_tx_active),
    .o_tx_serial (aif.o_tx_serial),
    .o_tx_done   (aif.o_tx_done),
    .o_rx_dv     (aif.o_rx_dv),
    .o_rx_byte   (aif.o_rx_byte)
  );
  
  initial begin
    uvm_config_db#(virtual uart_if)::set(null, "*", "aif", aif);
    run_test("test");
  end
  
  initial begin
    $dumpfile("dump.vcd");
    $dumpvars(0);
  end
endmodule
