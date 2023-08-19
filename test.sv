class transaction;
  rand bit [7:0] tx_data;
  rand bit [3:0] length;
  rand bit tx_start;
  rand bit parity_type,parity_en, stop2;
  bit tx, tx_done, tx_err;
  
  constraint length_c{length  inside {5,6,7,8};};
  constraint tx_start_c{tx_start inside {1};}
    function void display(string name);
    $display("---------------------------------");
    $display (" %s ",name);
    $display("---------------------------------");
      $display("tx_data=%b, length=%0d, parity_type=%0d, stop2=%b, tx=%0d, tx_done=%0d, tx_err= %b",tx_data, length, parity_type ,stop2,tx, tx_done, tx_err);
    $display("---------------------------------");
          $display("---------------------------------");


  endfunction
endclass



class generator;
  mailbox gen2driv;
event scb_done;
 transaction trans;
  int stimu=5;
  
  function new (mailbox gen2driv,event scb_done);
    this.gen2driv=gen2driv;
        this.scb_done=scb_done;

  endfunction
  
  task main();
    repeat(stimu)
    begin
    trans= new();
  if( !trans.randomize() ) $fatal("Gen:: trans randomization failed");  
      gen2driv.put(trans);
      trans.display("Generator");
      @scb_done;

      end
  endtask
endclass


class driver;
  mailbox gen2driv; 
  transaction trans;
  virtual  inter_f int_v;
  event driv_done;
  function new (virtual  inter_f int_v,mailbox gen2driv,event driv_done);
    this.gen2driv=gen2driv;
    this.int_v=int_v;
    this.driv_done=driv_done;
  endfunction
  
  task reset;
    @(posedge int_v.tx_clk && int_v.rst )
        $display(" ----------------------------");

    $display("reseting !!!!!!!!!!!!!!!!!!!");
    int_v.tx_start <=0;
    int_v.tx_data <=0;
    int_v.length <=0;
    int_v.parity_en <=0;
    int_v.stop2<=0;
    $display(" ----------------------------");

  endtask:reset
  
  task main();
    forever
      begin
        gen2driv.get(trans);
        @(posedge int_v.tx_clk );
        int_v.tx_start<=trans.tx_start;
        int_v.tx_data <=trans.tx_data;
        int_v.length <=trans.length;
        int_v.parity_type <=trans.parity_type;
        int_v.parity_en <=trans.parity_en;
        int_v.stop2 <=trans.stop2;
        @(posedge int_v.tx_clk);

        int_v.tx <=trans.tx;
        int_v.tx_done <=trans.tx_done;
        int_v.tx_err <=trans.tx_err;
        @(posedge int_v.tx_clk);

            ->driv_done;

      end
  endtask
endclass


class monitor;
  
  mailbox mon2scr;
  transaction trans;
    event driv_done;
  
  virtual  inter_f int_v;
  function new (virtual  inter_f int_v,mailbox mon2scr,event driv_done);
    this.mon2scr=mon2scr;
    this.int_v=int_v;
    this.driv_done=driv_done;

  endfunction

  task main();
        @driv_done;

    forever
      begin 
     trans=new();

        while(!trans.tx_done)begin
                  @(posedge int_v.tx_clk);

        trans.tx_data= int_v.tx_data;
        trans.length=int_v.length;
        trans.parity_type= int_v.parity_type;
        trans.parity_en= int_v.parity_en;
        trans.stop2=int_v.stop2;

        trans.tx=int_v.tx;
        trans.tx_done= int_v.tx_done;
        trans.tx_err=int_v.tx_err;
                  mon2scr.put(trans);

        end
        
      end
  endtask
endclass


interface inter_f(input bit tx_clk, input bit rst);
  logic tx_start, parity_type, parity_en, stop2;
  logic [7:0] tx_data;
  logic  [3:0] length;
  logic tx, tx_done, tx_err;


endinterface




class enviroment;
  generator gen;
  driver driv;
  monitor mon;
  scoreboard scb;
  mailbox gen2driv;
  mailbox mon2scb;
  event driv_done;
  event scb_done;

virtual inter_f int_v;
  
  function new(virtual inter_f int_v);
    this.int_v=int_v;
    gen2driv=new();
    mon2scb=new ();
    gen=new (gen2driv,scb_done);
    driv=new (int_v,gen2driv,driv_done);
    mon=new (int_v,mon2scb,driv_done);
    scb=new(mon2scb,scb_done);
  endfunction
  
  task test();
    fork
      gen.main();
      driv.main();
      mon.main();
      scb.main();
      driv.reset();

    join
  endtask
  
  
  task run;

    test();

 $finish;
  endtask
  
endclass



class scoreboard;
  mailbox mon2scr;
    transaction trans;
    driver gen;
event scb_done;
  int i, j;
  int s;
  int count=1;
  int parity;
  function new (mailbox mon2scr, event scb_done);
    this.mon2scr=mon2scr;
    this.scb_done=scb_done;
  endfunction
  
  
  task main();

forever
  begin
                trans=new();


     mon2scr.get(trans);
          s = trans.stop2 ? 2 : 1;
      parity= trans.parity_en? 1:0;

    if( i < (trans.length +s+parity))
      begin
        if(i<1)i++;
        else 
          begin
            if(trans.tx===trans.tx_data[j])
            $display("test passed ,i=%0d, tx_data[j]=%b , tx=%b",i,trans.tx_data[j],trans.tx);
        else
          $display("Test Faild,i=%0d, tx_data[j]=%b , tx=%b",i,trans.tx_data[j],trans.tx);
         
            trans.display("scoreboard ");

        i++;
        j++;
        end
    end
    else 
      begin
        ->scb_done;
        $display("-----------------------------");
        $display("Testing #", count);
        $display("-----------------------------");

        count++;
        i=0;
        j=0;
    end

    


      end
  endtask
endclass



program test(inter_f intf_1);
  enviroment env;
  initial 
    begin 
      env =new (intf_1);
      env.run();
      
    end
endprogram



module tb;
      bit clk, rst;

  inter_f int_f(clk, rst);
  test t(int_f);

  uart_tx tx(
    .tx_clk(int_f.tx_clk),
    .tx_start(int_f.tx_start),
    .rst(int_f.rst),
    .tx_data(int_f.tx_data),
    .length(int_f.length),
    .parity_type(int_f.parity_type),
    .parity_en(int_f.parity_en),
    .stop2(int_f.stop2),
    .tx(int_f.tx),
    .tx_done(int_f.tx_done),
    .tx_err(int_f.tx_err)
  );
  
   always #10 clk=~ clk;
   initial begin 
    $dumpfile("dump.vcd"); 
     $dumpvars;
     clk=1;
     rst=1;
     #10;
     rst=0;
        #1000;$finish;
  end
endmodule
















