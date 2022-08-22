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

logic [DWIDTH-1:0] lifo_q [$];

logic [DWIDTH-1:0] q_ref;
logic              empty_ref;
logic              full_ref;
logic [AWIDTH:0]   usedw_ref;
logic              almost_full_ref;
logic              almost_empty_ref;

int                fd_w;
int                q_err, usedw_err;
int                almost_full_err, full_err;
int                almost_empty_err, empty_err;

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
  
  while( state < 6 )
    begin
      repeat( 2 ** ( AWIDTH + 1 ) )
        begin
          compare_signals(fd_w);
          case( state )
            // simultaneous recording and reading
            3'd0: wr_and_rd();
            
            // recording frequency is higher 
            3'd1: wr_freq_high();
            
            // reading from lifo to empty
            3'd2: rd_only();
            
            // random recording and reading
            3'd3: rand_wr_and_rd();
            
            // reading frequency is higher
            3'd4: rd_freq_high();
            
            // recording in lifo to full
            3'd5: wr_only();
          endcase
          model();

          // checking usedw output signal for the presence of twisting and reset all signals
          if( ( 0 <= usedw_o && usedw_o <= 2 ** AWIDTH ) === 1'b0 )
            begin
              srst_i    <= 1'b1;
              usedw_ref <= '0;
              q_ref     <= 'x;
              almost_full_ref  = 1'b0;
              full_ref         = 1'b0;
              almost_empty_ref = 1'b1;
              empty_ref        = 1'b1;
              lifo_q = {};
              ##1;
              srst_i    <= 1'b0;
              break;
            end
        end

      // inaction
      repeat( AWIDTH )
        begin
          compare_signals(fd_w);
          idle();
          model();
        end
      state = state + 1;
    end
endtask

task wr_only();
  wrreq_i <= 1'b1;
  rdreq_i <= 1'b0;
  data_i  <= $urandom();
  ##1;
endtask

task rd_only();
  wrreq_i <= 1'b0;
  rdreq_i <= 1'b1;
  data_i  <= $urandom();
  ##1;
endtask

task rand_wr_and_rd();
  wrreq_i <= $urandom_range(0, 1);
  rdreq_i <= $urandom_range(0, 1);
  data_i  <= $urandom();
  ##1;
endtask

task idle();
  wrreq_i <= 1'b0;
  rdreq_i <= 1'b0;
  data_i  <= 'x;
  ##1;
endtask

task wr_freq_high();
  int r;
  r = $urandom_range(0, 6);
  wrreq_i <= ( r >= 3'd2 );
  rdreq_i <= ( r < 3'd2 );
  data_i  <= $urandom();
  ##1;
endtask

task rd_freq_high();
  int r;
  r = $urandom_range(0, 6);
  wrreq_i <= ( r < 3'd2 );
  rdreq_i <= ( r >= 3'd2 );
  data_i  <= $urandom();
  ##1;
endtask

task wr_and_rd();
  wrreq_i <= 1'b1;
  rdreq_i <= 1'b1;
  data_i  <= $urandom();
  ##1;
endtask

function automatic void check ( int fd_w, string s, ref int error );
  if( error == 0 )
    begin
      $display( s, $time );
      $fdisplay( fd_w, s, $time );
    end
  error = error + 1;
endfunction

// ref model
task automatic model();
  if( rdreq_i === 1'b1 && empty_ref !== 1'b1 )
    q_ref = lifo_q.pop_back();
  if( wrreq_i === 1'b1 && full_ref !== 1'b1 )
    lifo_q.push_back(data_i);

  usedw_ref = lifo_q.size();

  almost_full_ref = ( usedw_ref >= ALMOST_FULL_VALUE );
  full_ref = ( usedw_ref === 2 ** AWIDTH );
  
  almost_empty_ref = ( usedw_ref <= ALMOST_EMPTY_VALUE );
  empty_ref = ( usedw_ref === 0 );
endtask

task compare_signals ( int fd_w );         
  if( q_o !== q_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: q ", q_err );
  
  if( usedw_o !== usedw_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: usedw ", usedw_err );
  
  if( almost_full_o !== almost_full_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_full ", almost_full_err );
  
  if( full_o !== full_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: full ", full_err );
  
  if( almost_empty_o !== almost_empty_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: almost_empty ", almost_empty_err );
  
  if( empty_o !== empty_ref )
    check( fd_w, " Error: reality & expectation mismatch \t Time:%d ps \t Signal: empty ", empty_err );
endtask


initial
  begin
    srst_i    <= 1'b0;
    ##1;
    srst_i    <= 1'b1;
    ##1;
    srst_i    <= 1'b0;
    usedw_ref <= '0;
    almost_full_ref  = 1'b0;
    full_ref         = 1'b0;
    almost_empty_ref = 1'b1;
    empty_ref        = 1'b1;
    ##1;
    
    fd_w = $fopen( "./tb/report.txt", "w" );
    
    q_err            = 0;
    usedw_err        = 0;
    almost_full_err  = 0;
    full_err         = 0;
    almost_empty_err = 0;
    empty_err        = 0;
    
    $display("Starting tests...");
    generate_data();
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
