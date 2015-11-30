//	version	1.0	--	setup
//	Description:

`include "../../global_define.v"
module conv_layer_controller(
	
	//--input
	clk,
	rst_n,
	enable,
	input_interface_ack,
	
	//--output
	input_interface_cmd,
	current_state
//	kernel_array_cmd,
//	output_inteface_cmd,
);

parameter	KERNEL_SIZE			=	3;	//3x3
parameter	IMAGE_SIZE			=	8;
parameter	ARRAY_SIZE			=	6;

parameter	ADDR_WIDTH			=	6;
parameter	ROM_DEPTH			=	64;

parameter	ACK_IDLE			=	2'd0;
parameter	ACK_PRELOAD_FIN		=	2'd1;
parameter	ACK_SHIFT_FIN		=	2'd2;
parameter	ACK_LOAD_FIN		=	2'd3;

parameter	CMD_IDLE			=	2'd0;
parameter	CMD_PRELOAD			=	2'd1;
parameter	CMD_SHIFT			=	2'd2;
parameter	CMD_LOAD			=	2'd3;

parameter	TOTAL_WEIGHT		=	4;
parameter	TOTAL_SHIFT			=	ARRAY_SIZE;

input					clk;
input					rst_n;
input					enable;
input	[1:0]			input_interface_ack;


output 	[1:0]			input_interface_cmd;
reg		[1:0]			input_interface_cmd;

reg		[1:0]			weight_cycle;
reg		[2:0]			shift_cycle;

output	[2:0]			current_state;
reg		[2:0]			current_state;
reg		[2:0]			next_state;

parameter	STATE_INIT			=	3'd0;
parameter	STATE_PRELOAD		=	3'd1;	
parameter	STATE_SHIFT			=	3'd2;
parameter	STATE_LOAD			=	3'd3;
//parameter	STATE_IDLE			=	3'd7;

always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 
		current_state	<=	STATE_INIT;
	else begin
		if (enable)
			current_state	<=	next_state;
		else
			current_state	<= 	current_state;
	end
end

always @(current_state, input_interface_ack, weight_cycle) begin
	case (current_state)
		STATE_INIT: 
			next_state	=	STATE_PRELOAD;
		
		STATE_PRELOAD: 
			if ( input_interface_ack == ACK_PRELOAD_FIN )
				next_state	=	STATE_SHIFT;
			else
				next_state	=	STATE_PRELOAD;
		
		STATE_SHIFT: begin
			if ( input_interface_ack == ACK_SHIFT_FIN ) begin
				if ( weight_cycle == TOTAL_WEIGHT - 1  ) begin
					if ( shift_cycle  == TOTAL_SHIFT - 1 )
						next_state	<=	STATE_PRELOAD;
					else
						next_state	=	STATE_LOAD;
				end
				else
					next_state	=	STATE_SHIFT;
			end
			else
				next_state	= STATE_SHIFT;
		end
		
		STATE_LOAD: 
			if (input_interface_ack	==	ACK_LOAD_FIN)
				next_state	=	STATE_SHIFT;
			else
				next_state	=	STATE_LOAD;
		
		default:
			next_state	= current_state;
	endcase		
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n)
		input_interface_cmd	<=	CMD_IDLE;
	else begin
		case (current_state)
			STATE_INIT:
				input_interface_cmd <=	CMD_PRELOAD;
				
			STATE_PRELOAD:
				if ( input_interface_ack == ACK_PRELOAD_FIN )
					input_interface_cmd	<=	CMD_SHIFT;
				else
					input_interface_cmd	<=	CMD_IDLE;
					
			STATE_SHIFT:
				if ( input_interface_ack == ACK_SHIFT_FIN) begin
					if ( weight_cycle == TOTAL_WEIGHT - 1 ) begin
						if ( shift_cycle  == TOTAL_SHIFT - 1 )
							input_interface_cmd	<=	CMD_PRELOAD;
						else
							input_interface_cmd	<=	CMD_LOAD;
					end	
					else
						input_interface_cmd	<=	CMD_SHIFT;
				end
				else
					input_interface_cmd	<= CMD_IDLE;
			
			STATE_LOAD:
				if ( input_interface_ack == ACK_LOAD_FIN)
					input_interface_cmd	<=	CMD_SHIFT;
				else
					input_interface_cmd	<=	CMD_IDLE;
					
			default:
				input_interface_cmd	<=	CMD_IDLE;
				
		endcase
	end
end

//	--	
always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 	
		weight_cycle	<=	2'd0;
	else if ( input_interface_ack == ACK_SHIFT_FIN) begin
		if ( weight_cycle == TOTAL_WEIGHT - 1 )
			weight_cycle	<=	2'd0;
		else
			weight_cycle	<=	weight_cycle	+ 1'd1;
	end 
	else
		weight_cycle	<=	weight_cycle;	
end

always @(posedge clk, negedge rst_n) begin
	if(!rst_n) 	
		shift_cycle		<=	3'd0;
	else if (input_interface_ack == ACK_SHIFT_FIN && weight_cycle == TOTAL_WEIGHT - 1) 
		shift_cycle		<=	shift_cycle	+ 1'b1;	
	else if ( shift_cycle == TOTAL_SHIFT)
		shift_cycle		<=	3'd0;
	else
		shift_cycle	<=	shift_cycle;
end

endmodule
		