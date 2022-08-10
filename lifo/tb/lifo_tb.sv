`timescale 1 ps / 1 ps

module lifo_tb;

parameter DWIDTH             = 16;
parameter AWIDTH             = 8;
parameter ALMOST_FULL_VALUE  = 2;
parameter ALMOST_EMPTY_VALUE = 2;

bit                clk_i;
logic              srst_i;

logic [DWIDTH-1:0] data_i;
logic              wrreq_i;
logic              rdreq_i;

logic [DWIDTH-1:0] memory [2**AWIDTH-1:0];
logic [AWIDTH:0]   addr;

logic [DWIDTH-1:0] q_o;
logic              empty_o, full_o;
logic [AWIDTH:0]   usedw_o;
logic              almost_full_o, almost_empty_o;

logic [DWIDTH-1:0] q_dut, q_exp;
logic              empty_dut, empty_exp;
logic              full_dut, full_exp;
logic [AWIDTH:0]   usedw_dut, usedw_exp;
logic              almost_full_dut, almost_full_exp;
logic              almost_empty_dut, almost_empty_exp;

lifo #(
) lifo (
  .clk_i              ( clk_i              ),
  .srst_i             ( srst_i             ),
  
  .data_i             ( data_i             ),
  .wrreq_i            ( wrreq_i            ),
  .rdreq_i            ( rdreq_i            ),
   
  .q_o                ( q_o                ),
  .empty_o            ( empty_o            ),
  .full_o             ( full_o             ),
  .usedw_o            ( usedw_o            ),
  .almost_full_o      ( almost_full_o      ),
  .almost_empty_o     ( almost_empty_o     )
);

mailbox #() mb_data = new();
mailbox #() mb_dut  = new();
mailbox #() mb_exp  = new();

int fd_w;
int q_err, usedw_err;
int almost_full_err, full_err;
int almost_empty_err, empty_err;


initial
  begin
    clk_i = 0;
    forever
      #5 clk_i = !clk_i;
  end

default clocking cb
  @ (posedge clk_i);
endclocking


task generate_data (  );
  int r, state;
  int d;
  d = 0;
  state = 0;

  while( state < 3 )
    begin
      case( state )
        3'd0:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = d;
                d++;
                wrreq_i = 1'b1;
                rdreq_i = 1'b0;
                mb_data.put( { data_i, wrreq_i, rdreq_i } );
                reading_outputs();
                ##1;
              end
            wrreq_i = 1'b1;
            rdreq_i = 1'b0;
            mb_data.put( { data_i, wrreq_i, rdreq_i } );
            reading_outputs();
            ##1;
            wrreq_i = 1'b1;
            rdreq_i = 1'b0;
            mb_data.put( { data_i, wrreq_i, rdreq_i } );
            reading_outputs();
            ##1;
          end

        3'd1:
          begin
            repeat( 2 ** AWIDTH )
              begin
                wrreq_i = 1'b0;
                rdreq_i = 1'b1;
                mb_data.put( { data_i, wrreq_i, rdreq_i } );
                reading_outputs();
                ##1;
            end
            wrreq_i = 1'b0;
            rdreq_i = 1'b1;
            mb_data.put( { data_i, wrreq_i, rdreq_i } );
            reading_outputs();
            ##1;
            wrreq_i = 1'b0;
            rdreq_i = 1'b1;
            mb_data.put( { data_i, wrreq_i, rdreq_i } );
            reading_outputs();
            ##1;
          end
    
        3'd2:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = $urandom_range(0, 256);
                r = $urandom_range(0, 6);
                wrreq_i = ( r >= 3'd3 );
                rdreq_i = ( r <= 3'd3 );
                mb_data.put( { data_i, wrreq_i, rdreq_i } );
                reading_outputs();
                ##1;
              end
          end
      endcase
      state = state + 1;
    end
endtask


task reading_outputs (  );
  mb_dut.put( { q_o, usedw_o, 
                almost_full_o, full_o, 
                almost_empty_o, empty_o } );
endtask


task gen_exp_outputs ( mailbox #() mb_inputs );
  logic [DWIDTH+1:0] inputs;
  logic [DWIDTH-1:0] data;
  logic              wrreq;
  logic              rdreq;
  
  forever
    begin
      mb_inputs.get( inputs );
      { data, wrreq, rdreq } = inputs;
      
      almost_full_exp = ( usedw_exp >= ALMOST_FULL_VALUE);
      full_exp = ( usedw_exp === 2 ** AWIDTH );
      
      almost_empty_exp = ( usedw_exp <= ALMOST_EMPTY_VALUE);
      empty_exp = ( usedw_exp === 0 );
      
      if( wrreq !== rdreq )
        begin
          if( wrreq === 1'b1 && full_exp === 1'b0 )
            usedw_exp <= usedw_exp + 1'(1);
          if( rdreq === 1'b1 && empty_exp === 1'b0 )
            usedw_exp <= usedw_exp - 1'(1);
        end
      else
        begin
          if( wrreq === 1'b1 )
            if( empty_exp === 1'b1 )
              usedw_exp <= usedw_exp + 1'(1);
        end
      
      if( wrreq !== rdreq )
        begin
          if( wrreq === 1'b1 && full_exp === 1'b0 )
            if( addr <  ( 2 ** AWIDTH ) )
              addr <= addr + 1'(1);
          if( rdreq === 1'b1 && empty_exp === 1'b0 )
            if( addr > 0 )
              addr <= addr - 1'(1);
        end
      else
        begin
          if( wrreq === 1'b1 )
            if( empty_exp === 1'b1 )
              addr <= addr + 1'(1);
        end
      
      if( wrreq !== rdreq )
        begin
          if( rdreq === 1'b1 && empty_exp === 1'b0 )
            q_exp <= memory[addr-1];
          if( wrreq === 1'b1 && full_exp === 1'b0 )
            memory[addr] <= data;
        end
      else
        begin
          if( wrreq === 1'b1 )
            begin
              if( empty_exp === 1'b0 )
                begin
                  q_exp <= memory[addr-1];
                  memory[addr-1] <= data;
                end
              if( empty_exp === 1'b1 )
                memory[addr] <= data;
            end
        end

      mb_exp.put( { q_exp, usedw_exp, 
                    almost_full_exp, full_exp, 
                    almost_empty_exp, empty_exp } );
      ##1;
    end
endtask


task compare_signals ( mailbox #() mb_dut, 
                       mailbox #() mb_exp, 
                       int fd_w );
  logic [DWIDTH+AWIDTH+3:0] temp1, temp2;
  
  forever
    begin
      if( mb_dut.num() != mb_exp.num() )
        $display( "Error: num tests(dut=(%d) exp=(%d))", mb_dut.num(), mb_exp.num() );
      else
        begin
          mb_dut.get( temp1 );
          { q_dut, usedw_dut, almost_full_dut, 
          full_dut, almost_empty_dut, empty_dut } = temp1;
          
          mb_exp.get( temp2 );
          { q_exp, usedw_exp, almost_full_exp, 
          full_exp, almost_empty_exp, empty_exp } = temp2;
          
          if( q_dut !== q_exp )
            begin
              if( q_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: q ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: q", $time);
                end
              q_err = q_err + 1;
            end
          
          if( usedw_dut !== usedw_exp )
            begin
              if( usedw_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: usedw ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: usedw", $time);
                end
              usedw_err = usedw_err + 1;
            end
          
          if( almost_full_dut !== almost_full_exp )
            begin
              if( almost_full_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_full ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_full", $time);
                end
              almost_full_err = almost_full_err + 1;
            end
          
          if( full_dut !== full_exp )
            begin
              if( full_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: full ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: full", $time);
                end
              full_err = full_err + 1;
            end
          
          if( almost_empty_dut !== almost_empty_exp )
            begin
              if( almost_empty_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_empty ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_empty", $time); 
                end 
              almost_empty_err = almost_empty_err + 1;
            end
          
          if( empty_dut !== empty_exp )
            begin
              if( empty_err == 0 )
                begin
                  $display( " Error: reality & expectation mismatch \t Time:%d ps \t Signal: empty ", $time );
                  $fdisplay( fd_w, "Error: reality & expectation mismatch \t Time:%d ps \t Signal: empty", $time);
                end
              empty_err = empty_err + 1;
            end
          ##1;
        end
    end
endtask


initial
  begin
    srst_i    <= 1'b0;
    ##1;
    srst_i    <= 1'b1;
    ##1;
    srst_i    <= 1'b0;
    usedw_exp <= 0;
    addr      <= 0;
    almost_full_exp  = 1'b0;
    full_exp         = 1'b0;
    almost_empty_exp = 1'b1;
    empty_exp        = 1'b1;
    ##1;
    
    fd_w = $fopen( "./report.txt", "w" );
    
    q_err            = 0;
    usedw_err        = 0;
    almost_full_err  = 0;
    full_err         = 0;
    almost_empty_err = 0;
    empty_err        = 0;
    $display("Starting tests...");
    
    fork
      generate_data(  );
      gen_exp_outputs( mb_data );
      compare_signals( mb_dut, mb_exp, fd_w );
    join_any

    $display( "Tests completed with ( %d ) errors.", ( q_err + 
                                                       usedw_err + 
                                                       almost_full_err +
                                                       full_err +
                                                       almost_empty_err +
                                                       empty_err ) );

    $fclose( fd_w );
    $stop;
  end

endmodule