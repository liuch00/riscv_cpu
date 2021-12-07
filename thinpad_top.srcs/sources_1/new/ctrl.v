module ctrl(

	input wire rst,
    input wire stallreq_from_mem,
	input wire stallreq_from_id,  // lw 后读寄存器
	input wire stallreq_from_if,  // 如果同时做 IF 和 MEM 段访存，则让 IF 等着，生成一些气泡
	input wire branch_req,  // 跳转
	input wire pred_error,  // 预测失败
	output reg [5:0] stall       	
);
	always @(*) begin
		if(rst == 1'b1) 
			stall <= 6'b000000;
        else if(stallreq_from_mem == 1)
        	//访存的时候把流水线全暂停
            stall <= 6'b111111;
		else if(stallreq_from_id == 1'b1) 
			//遇到lw相关的数据冲突的时候，要等读出来数据才能解决冲突，所以ID段和之前的指令等一个周期
			stall <= 6'b000111;
		else if(stallreq_from_if == 1'b1)
			//如果本周期MEM段访存，那就先不服务IF段的取指令需求
			stall <= 6'b000011;
		// else if (branch_req == 1'b1)
		// 	//把读错的一条指令刷掉
		// 	//老的版本相当于每次都预测不跳
		// 	//所以只要ID发现跳了就说明预测错了，否则预测是对的
		// 	//既然预测错了，那就有一条指令本来不该读的，这条指令需要刷掉
		// // 	stall <= 6'b000010;
		else if (pred_error == 1'b1)
			//既然预测错了，那就有一条指令本来不该读的，这条指令需要刷掉
			stall <= 6'b000010;
		else 
			stall <= 6'b000000;
	end     
			

endmodule