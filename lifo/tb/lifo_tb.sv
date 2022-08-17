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

logic [DWIDTH-1:0] queue [$];

lifo #(
  .DWIDTH             ( DWIDTH             ),
  .AWIDTH             ( AWIDTH             ),
  .ALMOST_FULL        ( ALMOST_FULL_VALUE  ),
  .ALMOST_EMPTY       ( ALMOST_EMPTY_VALUE )
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
        // recording in lifo to full
        3'd0:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = d;
                d++;
                wrreq_i = 1'b1;
                rdreq_i = 1'b0;
                reading_outputs();
                gen_exp_outputs();
                ##1;
              end
            wrreq_i = 1'b1;
            rdreq_i = 1'b0;
            reading_outputs();
            gen_exp_outputs();
            ##1;
            wrreq_i = 1'b1;
            rdreq_i = 1'b0;
            reading_outputs();
            gen_exp_outputs();
            ##1;
          end
        
        // reading from lifo to empty
        3'd1:
          begin
            repeat( 2 ** AWIDTH )
              begin
                wrreq_i = 1'b0;
                rdreq_i = 1'b1;
                reading_outputs();
                gen_exp_outputs();
                ##1;
            end
            wrreq_i = 1'b0;
            rdreq_i = 1'b1;
            reading_outputs();
            gen_exp_outputs();
            ##1;
            wrreq_i = 1'b0;
            rdreq_i = 1'b1;
            reading_outputs();
            gen_exp_outputs();
            ##1;
          end
        
        // random recording and reading
        3'd2:
          begin
            repeat( 2 ** AWIDTH )
              begin
                data_i  = $urandom_range(0, 256);
                r = $urandom_range(0, 6);
                wrreq_i = ( r >= 3'd3 );
                rdreq_i = ( r <= 3'd3 );
                reading_outputs();
                gen_exp_outputs();
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


task gen_exp_outputs (  );
  almost_full_exp = ( usedw_exp >= ALMOST_FULL_VALUE);
  full_exp = ( usedw_exp === 2 ** AWIDTH );
      
  almost_empty_exp = ( usedw_exp <= ALMOST_EMPTY_VALUE);
  empty_exp = ( usedw_exp === 0 );
      
  if( wrreq_i !== rdreq_i )
    begin
      if( wrreq_i === 1'b1 && full_exp === 1'b0 )
        usedw_exp <= usedw_exp + 1'(1);
      if( rdreq_i === 1'b1 && empty_exp === 1'b0 )
        usedw_exp <= usedw_exp - 1'(1);
    end
  else
    begin
      if( wrreq_i === 1'b1 )
        if( empty_exp === 1'b1 )
          usedw_exp <= usedw_exp + 1'(1);
    end
    
  if( wrreq_i !== rdreq_i )
    begin
      if( rdreq_i === 1'b1 && empty_exp === 1'b0 )
        q_exp <= queue.pop_back();
      if( wrreq_i === 1'b1 && full_exp === 1'b0 )
        queue.push_back(data_i);
    end
  else
    begin
      if( wrreq_i === 1'b1 )
        begin
          if( empty_exp === 1'b0 )
            begin
              q_exp <= queue.pop_back();
              queue.push_back(data_i);
            end
          if( empty_exp === 1'b1 )
            queue.push_back(data_i);
        end
    end
      
  mb_exp.put( { q_exp, usedw_exp, 
                almost_full_exp, full_exp, 
                almost_empty_exp, empty_exp } );
endtask


function automatic void check ( int fd_w, string s, ref int error );
  if( error == 0 )
    begin
      $display( s, $time );
      $fdisplay( fd_w, s, $time );
    end
  error = error + 1;
endfunction


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
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: q ", q_err );
          
          if( usedw_dut !== usedw_exp )
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: usedw ", usedw_err );
          
          if( almost_full_dut !== almost_full_exp )
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_full ", almost_full_err );
          
          if( full_dut !== full_exp )
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: full ", full_err );
          
          if( almost_empty_dut !== almost_empty_exp )
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_empty ", almost_empty_err );
          
          if( empty_dut !== empty_exp )
            check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: empty ", empty_err );

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
    almost_full_exp  = 1'b0;
    full_exp         = 1'b0;
    almost_empty_exp = 1'b1;
    empty_exp        = 1'b1;
    ##1;
    
    fd_w = $fopen( "./tb/report.txt", "w" );
    
    q_err            = 0;
    usedw_err        = 0;
    almost_full_err  = 0;
    full_err         = 0;
    almost_empty_err = 0;
    empty_err        = 0;
    $display("Starting tests...");
    
    fork
      generate_data(  );
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
