///////////////////////////////////////////////////////////////////////////////////////////////////
//
//        CLASS: i
//  DESCRIPTION: 
//         BUGS: ---
//       AUTHOR: Valmir F. Silva (), valmir.silva@ee.ufcg.edu.br
// ORGANIZATION: 
//      VERSION: 1.0
//      CREATED: 05/03/2026 11:23:41 AM
//     REVISION: ---
///////////////////////////////////////////////////////////////////////////////////////////////////

module img2col#
(
  parameter  WIDTH=4, SIZE_KER = 3,SIZE_WINDOW=6,
  localparam OUT_SIZE = SIZE_WINDOW - SIZE_KER + 1, NUM_PATCHES = OUT_SIZE * OUT_SIZE
)(
      input  logic              clk                      ,
      input  logic              rst_n_sync               ,
      input  logic              valid_i                  ,
      output logic              ready_o                  ,
      output  logic             rvalid_o                 ,
      input  logic              rready_i                 ,
      input  logic  [WIDTH-1:0] img [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0] ,
      output logic  [WIDTH-1:0] colout [OUT_SIZE*OUT_SIZE-1:0][SIZE_KER*SIZE_KER-1:0]

);

logic [$clog2(SIZE_WINDOW)-1:0] row, col;
logic [$clog2(SIZE_WINDOW)-1:0] i_index_img_next, j_index_img_next;
logic [$clog2(NUM_PATCHES)-1:0] patch_idx;
logic is_row_oob;
logic is_col_oob;

logic [WIDTH-1:0] window [SIZE_KER*SIZE_KER-1:0];
logic [WIDTH-1:0] window_reg [SIZE_KER*SIZE_KER-1:0];
enum {IDLE, TRANSFORM_IMAGE2COL,DONE} currentStateTransformUnit,nextStateTransformUnit;
generate
      genvar i_win, j_win;
      for(i_win =0; i_win< SIZE_KER; i_win++)
            for(j_win =0; j_win< SIZE_KER; j_win++)
                  assign window[i_win*SIZE_KER+j_win] = img[i_win+row][j_win+col];
endgenerate

always_ff@(posedge clk)begin
      if(!rst_n_sync)begin
            row <= '{default:'0};
            col <= '{default:'0};
            currentStateTransformUnit <= IDLE;
            window_reg <= '{default: '0};
      end else begin
            row <= i_index_img_next;
            col <= j_index_img_next;

            window_reg <= window;
            {>>(WIDTH){colout[patch_idx]}} <= window_reg;
            currentStateTransformUnit <= nextStateTransformUnit;
      end
end
assign patch_idx = (OUT_SIZE)*row + col;
assign is_row_oob = (row > OUT_SIZE);
assign is_col_oob = (col > OUT_SIZE);
            //{>>(WIDTH){colout[patch_idx_next]}} <= {(OUT_SIZE_NORM-SIZE_KER*SIZE_KER+10){1'b0},window};
            //$display("%x",window[patch_idx]);

always_comb case(currentStateTransformUnit) 
      IDLE:begin
            ready_o                      = 1                                                                    ;
            rvalid_o                     = 0                                                                    ;
            if(valid_i)begin
                  nextStateTransformUnit = TRANSFORM_IMAGE2COL;
            end else begin
                  nextStateTransformUnit = IDLE;
            end
            i_index_img_next = 0;
            j_index_img_next = 0;
      end
      TRANSFORM_IMAGE2COL:begin
            ready_o = 0;
            rvalid_o =0;
            case({is_row_oob,is_col_oob})
                  'b00:begin
                        i_index_img_next = row;
                        j_index_img_next = col+1;
                  end
                  'b01: begin         
                        i_index_img_next = row + 1;
                        j_index_img_next = 0;
                  end
                  'b10:begin
                        i_index_img_next = row+1;
                        j_index_img_next = 0;
                  end
                  'b11:begin
                        i_index_img_next = row;
                        j_index_img_next = col;
                  end 
                  default:begin
                        i_index_img_next = 0;
                        j_index_img_next = 0;
                  end           
            endcase
            nextStateTransformUnit = patch_idx >= NUM_PATCHES-1 ? DONE :TRANSFORM_IMAGE2COL;
      end
      DONE:begin
            ready_o  = 0;
            rvalid_o = 1;
            i_index_img_next = 0;
            j_index_img_next = 0;
            nextStateTransformUnit = rready_i ?  IDLE:DONE;
      end
      default:begin 
            ready_o = 1;
            rvalid_o= 0;
            if(valid_i)begin
                  nextStateTransformUnit = TRANSFORM_IMAGE2COL;
            end else begin
                  nextStateTransformUnit = IDLE;
            end
            i_index_img_next = 0;
            j_index_img_next = 0;
      end
endcase
endmodule



