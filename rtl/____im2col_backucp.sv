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
  parameter  WIDTH=4, SIZE_KER = 3,SIZE_WINDOW=6
)(
      input  logic              clk                      ,
      input  logic              nrst                     ,
      input  logic              valid_i                  ,
      output logic              ready_o                  ,
      input  logic              rvalid_o                 ,
      output logic              rready_i                 ,
      input  logic  [WIDTH-1:0] img [SIZE_WINDOW-1:0][SIZE_WINDOW-1:0] ,
      output logic  [WIDTH-1:0] col [(SIZE_WINDOW-SIZE_KER+1)*(SIZE_WINDOW-SIZE_KER+1)-1:0][SIZE_KER*SIZE_KER-1:0]

);
      
//logic [$clog2(SIZE_KER)-1:0] i_index_kernel, j_index_kernel;
logic [$clog2(SIZE_WINDOW)-1:0] i_index_img, j_index_img;
logic [$clog2(SIZE_WINDOW)-1:0] i_index_img_next, j_index_img_next;
logic [$clog2(SIZE_WINDOW*SIZE_WINDOW)-1:0] k_index_col, k_index_col_next;


logic [WIDTH-1:0] window [SIZE_KER*SIZE_KER-1:0];


logic [WIDTH-1:0] buffer_img;

generate
      genvar i_win, j_win;
      for(i_win =0; i_win< SIZE_KER; i_win++)
            for(j_win =0; j_win< SIZE_KER; j_win++)
                  assign window[i_win*SIZE_KER+j_win] = img[i_win+i_index_img][j_win+j_index_img];
endgenerate

always_ff@(posedge clk)begin
      if(!nrst)begin
            col <= '{default: '{default: '0}};
            i_index_img <= '{default:'0};
            j_index_img <= '{default:'0};
            k_index_col <= '{default:'0};
      end else begin
            i_index_img <= i_index_img_next;
            j_index_img <= j_index_img_next;
            k_index_col <= (SIZE_WINDOW-SIZE_KER+1)*i_index_img + j_index_img;
            {>>(WIDTH){col[k_index_col_next]}} <= window;
            ///outro indexador relativo à i e j;
            //considerando que as subimagens vem de outro bloco
      end
end


assign k_index_col_next = (SIZE_WINDOW-SIZE_KER+1)*i_index_img + j_index_img;
always_comb begin
casex({i_index_img > SIZE_WINDOW-SIZE_KER-1,j_index_img > SIZE_WINDOW-SIZE_KER-1})
      'b00:begin
            i_index_img_next = i_index_img;
            j_index_img_next = j_index_img+1;
      end
      'b01:begin
            i_index_img_next = i_index_img+1;
            j_index_img_next = 0;
      end
      'b10:begin
            i_index_img_next = i_index_img;
            j_index_img_next = j_index_img+1;
      end
      'b11:begin
            i_index_img_next = i_index_img;
            j_index_img_next = j_index_img;
      end 
      default:begin
            i_index_img_next = 0;
            j_index_img_next = 0;
      end           
endcase
end
endmodule



