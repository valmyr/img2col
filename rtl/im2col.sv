///////////////////////////////////////////////////////////////////////////////////////////////////
//
//        CLASS: i
//  DESCRIPTION: 
//         BUGS: ---
//       AUTHOR: Valmir F. Silva (), valmir.silva@ee.ufcg.edu.br
// ORGANIZATION: 
//      VERSION: 2.0 Paraleismo espacial de janelas
//      CREATED: 05/03/2026 11:23:41 AM
//     REVISION: ---
///////////////////////////////////////////////////////////////////////////////////////////////////
module img2row#
(
  parameter  WIDTH=4, SIZE_KER = 3,SIZE_WINDOW=6,
  localparam OUT_SIZE = SIZE_WINDOW - SIZE_KER + 1,
  localparam OUT_SIZE_NORM = $clog2(2**((OUT_SIZE)*(OUT_SIZE)))
)(
      input  logic              clk                                           ,
      input  logic              rst_n_sync                                    ,
      input  logic              valid_i                                       ,
      output logic              ready_o                                       ,
      output logic              rvalid_o                                      ,
      input  logic              rready_i                                      ,
      input  logic              ena_mc                                        ,
      input  logic  [WIDTH-1:0] img [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0]        ,
      output logic  [WIDTH-1:0] colout [OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0]

);
logic [$clog2(SIZE_WINDOW)-1:0] row, col;
logic [$clog2(SIZE_WINDOW)-1:0] row_next, col_next;
logic [$clog2(SIZE_WINDOW*SIZE_WINDOW)-1:0] patch_idx, patch_idx_next;
logic is_row_oob;
logic is_col_oob;

logic [WIDTH-1:0]                   window0      [OUT_SIZE-1:0][SIZE_KER*SIZE_KER-1:0];
logic [WIDTH*SIZE_KER*SIZE_KER-1:0] window_f0    [OUT_SIZE-1:0];

enum {IDLE, TRANSFORM_IMAGE2COL,DONE} currentStateTransformUnit,nextStateTransformUnit;

logic [((OUT_SIZE_NORM - SIZE_KER*SIZE_KER) * WIDTH) - 1 : 0] zero_pad;

generate
      genvar i_win, j_win, k_mult_win;
      for(i_win =0; i_win< SIZE_KER; i_win++)
            for(j_win =0; j_win< SIZE_KER; j_win++)begin
                  for(k_mult_win =0; k_mult_win < OUT_SIZE; k_mult_win++)begin
                        assign window0[k_mult_win][i_win*SIZE_KER+j_win] = img[i_win+k_mult_win][j_win+col];
                  end
            end
endgenerate
generate
      genvar i_flatten;
      for(i_flatten = 0;i_flatten < OUT_SIZE; i_flatten++)begin
            assign window_f0[i_flatten] = {>>{window0[i_flatten]}};             
      end
endgenerate
always_ff@(posedge clk)begin
      if(!rst_n_sync)begin
            row <= '{default:'0};
            col <= '{default:'0};
            patch_idx <= '{default:'0};
            currentStateTransformUnit <= IDLE;
            colout <='{default: '{default: '0}};
      end else begin
            row <= row_next;
            col <= col_next;
            patch_idx <= (OUT_SIZE)*row + col;

            for(int i =0; i < OUT_SIZE; i++)begin
                  {>>(WIDTH){colout[patch_idx_next+i*OUT_SIZE]}}  <={zero_pad, window_f0[i]} ;
            end
            currentStateTransformUnit <= nextStateTransformUnit;
      end
end

assign zero_pad = '0;
assign patch_idx_next = col;
assign is_row_oob = '1;
assign is_col_oob = (col >OUT_SIZE - 2);

always_comb case(currentStateTransformUnit) 
      IDLE:begin
            ready_o                      = 1;
            rvalid_o                     = 0;
            if(valid_i)begin
                  nextStateTransformUnit = TRANSFORM_IMAGE2COL;
            end else begin
                  nextStateTransformUnit = IDLE;
            end
            row_next = 0;
            col_next = 0;
      end
      TRANSFORM_IMAGE2COL:begin
            ready_o = 0;
            rvalid_o =0;
            casex({is_row_oob,is_col_oob})
                  'b00:begin
                        row_next = row;
                        col_next = col+1;
                  end
                  'b01:begin
                        row_next = row+1;
                        col_next = 0;
                  end
                  'b10:begin
                        row_next = row;
                        col_next = col+1;
                  end
                  'b11:begin
                        row_next = row;
                        col_next = col;
                  end 
                  default:begin
                        row_next = 0;
                        col_next = 0;
                  end           
            endcase
            nextStateTransformUnit = (is_row_oob && is_col_oob) ? DONE :TRANSFORM_IMAGE2COL;
      end
      DONE:begin
            ready_o  = 0;
            rvalid_o = 1;
            row_next = 0;
            col_next = 0;
            nextStateTransformUnit = rready_i ?  IDLE:DONE;
      end
      default:begin 
            ready_o                      = 1;
            rvalid_o                     = 0;
            if(valid_i)begin
                  nextStateTransformUnit = TRANSFORM_IMAGE2COL;
            end else begin
                  nextStateTransformUnit = IDLE;
            end
            row_next = 0;
            col_next = 0;
      end
endcase
endmodule


