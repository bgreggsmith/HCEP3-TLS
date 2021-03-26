unit p3_CSECommunication;

{$Mode ObjFpc}

interface

uses
	p3_domain;

const
	//MPI message type IDs
	CSEMsg_None					=	0;
	CSEMsg_Cmd					=	1;
	CSEMsg_Flag					=	2;
	CSEMsg_Data					=	3;
	CSEMsg_WBack				=	4;
	
	CSEMsg_CfgData_T0			=	10;
	CSEMsg_CfgData_TStep		=	11;
	CSEMsg_CfgData_TEnd			=	12;
	CSEMsg_CfgData_nCells		=	13;
	CSEMsg_CfgData_nBCs			=	14;
	CSEMsg_CfgData_nTags		=	15;
	CSEMsg_CfgData_nConsts		=	16;
	CSEMsg_CfgData_LInterval	=	17;
	CSEMsg_CfgData_tagSize		=	18;
	CSEMsg_CfgData_masterID		=	19;
	
	CSEMsg_Data_Cell			=	21;
	CSEMsg_Data_Field			=	22;
	CSEMsg_Data_BC				=	23;
	CSEMsg_Data_Laplace			=	24;
	CSEMsg_Data_Const			=	25;
	CSEMsg_Data_Tag				=	26;
	CSEMsg_Data_Done			=	29;
	
	CSEMsg_WBack_TNow			=	80;
	CSEMsg_WBack_Iter			=	81;
	CSEMsg_WBack_FData			=	82;
	CSEMsg_WBack_Done			=	83;
	
	//MPI command message codes
	CSECmd_None					=	0;
	CSECmd_Cfg					=	110;
	CSECmd_Data					=	120;
	CSECmd_Ready				=	170;
	CSECmd_Terminate			=	199;
	
	CSE_BufferSize				=	62;

procedure CSE_TXConfig(tgt: Integer; Dom: pp3Domain);
procedure CSE_TXData(tgt: Integer; Dom: pp3Domain);
procedure CSE_BeginExec(tgt: Integer);
procedure CSE_RXFieldWBack(tgt: pp3Domain);

implementation

uses
	MPI,
	
	p3_globals,
	p3_buildConfig;

type
	pbyte = ^byte;
	C4T = array [1..4] of byte;
	C8T = array [1..8] of byte;

function rDouble(src: C8T): Double;
var
	d: Double absolute src;

begin
	rDouble := d;
end;

function rLW32(src: C4T): LongWord;
var
	l: LongWord absolute src;

begin
	rLW32 := l;
end;

procedure CSE_RXFieldWBack(tgt: pp3Domain);
var
	status: MPI_Status;
	fbuffer: array of byte;
	CmdCode: byte;
	n, i: LongWord;
	C4: C4T;
	C8: C8T;
	
begin
	SetLength(fBuffer, CSE_BufferSize);
	
	fBuffer[0] := 0;
	
	repeat
		MPI_Recv(@fBuffer[0], CSE_BufferSize, MPI_BYTE, MPI_ANY_SOURCE, CSEMsg_WBack, MPI_COMM_WORLD, @Status);
		
		case (fBuffer[0]) of
				CSEMsg_WBack_TNow: 
					begin
						for i := 0 to 7 do
							C8[i+1] := fBuffer[1+i];
						
						SimData.TNow := rDouble(C8);
					end;
				CSEMsg_WBack_Iter:
					begin
						for i := 0 to 3 do
							C4[i+1] := fBuffer[1+i];
						SimData.iter := rLW32(C4);
					end;
				CSEMsg_WBack_FData:
					begin
						for i := 0 to 3 do
							C4[i+1] := fBuffer[1+i];
						n := rLW32(C4);
						
						for i := 0 to 7 do
							C8[i+1] := fBuffer[5+i];
						SimData.cell[n].fieldValue[0] := rDouble(C8);
						
						for i := 0 to 7 do
							C8[i+1] := fBuffer[13+i];
						SimData.cell[n].fieldValue[1] := rDouble(C8);
						
						for i := 0 to 7 do
							C8[i+1] := fBuffer[21+i];
						SimData.cell[n].fieldValue[2] := rDouble(C8);
					end;
				CSEMsg_WBack_Done:
					break;
			end;
		
		until fBuffer[0] = CSEMsg_WBack_Done;
	
	writeln('TLS received field data for t=',SimData.TNow,' iter=',SimData.iter);
end;

procedure CSE_TXData(tgt: Integer; Dom: pp3Domain);
var
	fBuffer: array [0..CSE_BufferSize] of byte;
	n, z: LongWord;
	u16: Word;
	i16: SmallInt;
	i32: LongInt;
	d64: Double;
	u32: LongWord;
	CmdCode: Integer;

begin
	CmdCode := CSECmd_Data;
	writeln('TLS Sending CMDCode=',CmdCode,' in MSGType=',CSEMsg_Cmd,' to rank=',tgt);
	MPI_Send(@CmdCode, 1, MPI_INTEGER, tgt, CSEMsg_Cmd, MPI_COMM_WORLD);

	//Send boundary condition data
	u16 := CSEMsg_Data_BC;
	Move(u16, fBuffer[0], 2);
	
	{	BC Data format:
		int32_t		BCNumber = i32(&fBuffer[2]);
		int32_t		BCType = i32(&fBuffer[6]);
		int32_t		BCTag = i32(&fBuffer[10]);
		double		BCValue = d64(&fBuffer[14]);
		int16_t		FieldID = i16(&fBuffer[22]);
	}
	for n := 0 to Dom^.BCs - 1 do
		begin
			i32 := n;
			Move(i32, fBuffer[2], 4);
			
			i32 := Dom^.BCData[n].BCType;
			Move(i32, fBuffer[6], 4);
			
			i32 := Dom^.BCData[n].BCTag;
			Move(i32, fBuffer[10], 4);
			
			d64 := Dom^.BCData[n].BCValue;
			Move(d64, fBuffer[14], 8);
			
			i16 := Dom^.BCData[n].fieldID;
			Move(i16, fBuffer[22], 2);
			
			MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
		end;
	
	//Send cell data
	u16 := CSEMsg_Data_Cell;
	Move(u16, fBuffer[0], 2);
	{	Cell data transfer format
		uint32_t	cellNumber
		int32_t		id_up
		int32_t		id_left
		int32_t		id_down
		int32_t		id_right
		double		area
		uint16_t	tags
		double		centre_x
		double		centre_y
	}
	for n := 0 to Dom^.cells - 1 do
		begin
			i32 := n;
			Move(i32, fBuffer[2], 4);
			
			i32 := Dom^.cell[n].id_up;
			Move(i32, fBuffer[6], 4);
			
			i32 := Dom^.cell[n].id_left;
			Move(i32, fBuffer[10], 4);
			
			i32 := Dom^.cell[n].id_down;
			Move(i32, fBuffer[14], 4);
			
			i32 := Dom^.cell[n].id_right;
			Move(i32, fBuffer[18], 4);
			
			d64 := Dom^.cell[n].area;
			Move(d64, fBuffer[22], 8);
			
			u16 := Dom^.cell[n].tags;
			Move(u16, fBuffer[30], 2);
			
			d64 := Dom^.cell[n].centre.x;
			Move(d64, fBuffer[32], 8);
			
			d64 := Dom^.cell[n].centre.y;
			Move(d64, fBuffer[40], 8);
			
			MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
		end;
	
	//Send field data
	u16 := CSEMsg_Data_Field;
	Move(u16, fBuffer[0], 2);
	
	{ Field data transfer format
		uint16_t	FieldID
		uint32_t	CellNumber
		double		fieldValue
	}
	for n := 0 to Dom^.cells - 1 do
		for z := 0 to p3_nFields - 1 do
			begin
				i16 := z;
				Move(i16, fBuffer[2], 2);;
				
				i32 := n;
				Move(i32, fBuffer[4], 4);
				
				d64 := Dom^.cell[n].fieldValue[z];
				Move(d64, fBuffer[8], 8);
				
				//This is hugely inefficient, we are using 16 bytes of a ~62 byte message! We really ought to send all fields at once...
				MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
			end;
	
	//Send laplacian data
	u16 := CSEMsg_Data_Laplace;
	Move(u16, fBuffer[0], 2);
	
	{ Laplacian data transfer format
		uint32_t	pos_i
		uint32_t	pos_j
		double		value
	}
	for n := 0 to Dom^.cells - 1 do
		for z := 0 to Dom^.cells - 1 do
			if Dom^.InvertedConnectivityMatrix[n][z] <> 0 then
				begin
					i32 := n;
					Move(i32, fBuffer[2], 4);
					
					i32 := z;
					Move(i32, fBuffer[6], 4);
					
					d64 := Dom^.InvertedConnectivityMatrix[n][z];
					Move(d64, fBuffer[10], 8);
					
					//More hugely inefficient rubbish...
					MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
				end;
	
	//Send constants data
	u16 := CSEMsg_Data_Const;
	Move(u16, fBuffer[0], 2);
	
	{ Constant data transfer format
		uint16_t	Const ID
		double		Const Value
	}
	for n := 0 to Dom^.consts - 1 do
		begin
			case Dom^.constID[n] of
					'nu': u16 := 0;
					'rho': u16 := 1;
				end;
			Move(u16, fBuffer[2], 2);
			
			d64 := Dom^.constValue[n];
			Move(d64, fBuffer[4], 8);
			
			MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
		end;
	
	//Send tag data
	u16 := CSEMsg_Data_Tag;
	Move(u16, fBuffer[0], 2);
	
	{ Constant tag cell transfer format
		uint16_t	Tag ID
		uint32_t	Cell tag position n
		uint32_t	Cell ID
	}
	for n := 0 to Dom^.tags - 1 do
		begin
			u16 := n;
			Move(u16, fBuffer[2], 2);
			
			for z := 0 to Dom^.tagElems[n] - 1 do
				begin
					u32 := z;
					Move(u32, fBuffer[4], 4);
					
					u32 := Dom^.tagCells[n][z];
					Move(u32, fBuffer[8], 4);
			
					MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
				end;
		end;
	
	//Send done message to finalise the transfer
	u16 := CSEMsg_Data_Done;
	Move(u16, fBuffer[0], 2);
	MPI_Send(@fBuffer[0], CSE_BufferSize, MPI_BYTE, tgt, CSEMsg_Data, MPI_COMM_WORLD);
end;

procedure CSE_BeginExec(tgt: Integer);
var
	dummy: byte;
	CmdCode: Integer = CSECmd_Ready;
	
begin
	MPI_Send(@CmdCode, 1, MPI_Byte, tgt, CSEMsg_Flag, MPI_COMM_WORLD);
end;

procedure CSE_TXConfig(tgt: Integer; Dom: pp3Domain);
var
	CmdCode: Integer = CSECmd_Cfg;
	fBuffer: array [0..9] of byte;
	u32: LongWord;
	n: LongWord;
	
begin
	CmdCode := CSECmd_Cfg;
	
	//Notify CSE it is about to receive config information
	writeln('TLS Sending CMDCode=',CmdCode,' in MSGType=',CSEMsg_Cmd,' to rank=',tgt,' nCells=',Dom^.cells);
	MPI_Send(@CmdCode, 1, MPI_INTEGER, tgt, CSEMsg_Cmd, MPI_COMM_WORLD);
	
	//Send Master node ID for field data writeback
	MPI_Send(@rank, 1, MPI_INTEGER, tgt, CSEMsg_CfgData_masterID, MPI_COMM_WORLD);
	
	//Send time control information
	MPI_Send(@Dom^.TStart, 1, MPI_DOUBLE, tgt, CSEMsg_CfgData_T0, MPI_COMM_WORLD);
	MPI_Send(@Dom^.TStep, 1, MPI_DOUBLE, tgt, CSEMsg_CfgData_TStep, MPI_COMM_WORLD);
	MPI_Send(@Dom^.TEnd, 1, MPI_DOUBLE, tgt, CSEMsg_CfgData_TEnd, MPI_COMM_WORLD);
	MPI_Send(@Dom^.logInterval, 1, MPI_LONG_LONG_INT, tgt, CSEMsg_CfgData_LInterval, MPI_COMM_WORLD);
	
	//Send memory allocation parameters for the CSEs
	MPI_Send(@Dom^.cells, 1, MPI_LONG_LONG_INT, tgt, CSEMsg_CfgData_nCells, MPI_COMM_WORLD);
	MPI_Send(@Dom^.tags, 1, MPI_LONG_LONG_INT, tgt, CSEMsg_CfgData_nTags, MPI_COMM_WORLD);
	MPI_Send(@Dom^.BCs, 1, MPI_LONG_LONG_INT, tgt, CSEMsg_CfgData_nBCs, MPI_COMM_WORLD);
	MPI_Send(@Dom^.consts, 1, MPI_LONG_LONG_INT, tgt, CSEMsg_CfgData_nConsts, MPI_COMM_WORLD);
	
	fBuffer[0] := 0;
	for n := 0 to Dom^.tags - 1 do
		begin
			u32 := n;
			Move(u32, fBuffer[1], 4);
			
			writeln('TLS tagElems[',n,']=',Dom^.tagElems[n]);
			
			u32 := Dom^.tagElems[n];
			Move(u32, fBuffer[5], 4);
			MPI_Send(@fBuffer, 10, MPI_BYTE, tgt, CSEMsg_CfgData_tagSize, MPI_COMM_WORLD);
		end;
	
	fBuffer[0] := 1;
	MPI_Send(@fBuffer, 10, MPI_BYTE, tgt, CSEMsg_CfgData_tagSize, MPI_COMM_WORLD);
end;

begin
end.
