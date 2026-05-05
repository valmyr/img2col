module tb;
  parameter  WIDTH=8, SIZE_KER = 5,SIZE_WINDOW=6;
  localparam OUT_SIZE = SIZE_WINDOW - SIZE_KER + 1;
  localparam OUT_SIZE_NORM = $clog2(2**((OUT_SIZE)*(OUT_SIZE)));
logic nrst,clk;

logic [WIDTH-1:0] imagem[SIZE_WINDOW-1:0][SIZE_WINDOW-1:0];
logic [WIDTH-1:0] col[OUT_SIZE_NORM-1:0][OUT_SIZE_NORM-1:0];
integer k=1;
logic rvalid_o;
logic valid_i;

logic [31:0] cnt;

initial begin
    nrst =1;
    clk=0;
    #2 nrst=0;
    #500ps nrst=1;


    
    
    for(integer  i =0; i < SIZE_WINDOW; i++)begin
        for(integer  j =0; j < SIZE_WINDOW; j++)begin
            imagem[i][j] = k;
            $write("%d  ",k);
            k++;
        end 
         $display("\n");
    end

end

always #2 clk =~clk;

always_ff@(posedge clk)begin
        if(!nrst)cnt <=0;
        else begin
            
            cnt <= cnt+1;
        end

        if(cnt == 10)begin
            valid_i <=1;
        end else begin
            valid_i <=0;
        end
        if(rvalid_o) begin 
        for(integer  i =0; i < OUT_SIZE_NORM; i++)begin
            for(integer  j =0; j < OUT_SIZE_NORM; j++)begin
            $write("%d  ",col[i][j]);
            end 
        $display("\n");
        end
            $finish;

        end
    end
img2row #(.WIDTH(WIDTH),.SIZE_KER(SIZE_KER),.SIZE_WINDOW(SIZE_WINDOW))inst0(
      .clk      (clk)                ,
      .rst_n_sync     (nrst)                ,
      .valid_i  (valid_i)                ,
      .ready_o  ()                ,
      .rvalid_o (rvalid_o)                ,
      .rready_i (0)                ,
      .img      (imagem) ,
      .colout      (col)              
);


endmodule
