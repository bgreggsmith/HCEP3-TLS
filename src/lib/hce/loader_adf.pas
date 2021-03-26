unit loader_adf;

{$Mode ObjFpc}

interface

uses
	p3_domain;

procedure LoadADF(Src: ANSIString; Tgt: pp3Domain);

implementation

uses
	sysutils,
	
	p3_utils,
	p3_boundaryConditions,
	p3_fieldops,
	p3_matrixops,
	
	loader_su2;

procedure NewBC(Tgt: pp3Domain; TagName, BCTypeName, FieldName: ANSIString; BCValue: Double);
var
	BCTYP, BCTID, FLDID: Int64;
	
begin
	if Tgt^.BCs + 1 >= Length(Tgt^.BCdata) then
		SetLength(Tgt^.BCdata, Tgt^.BCs + 8);
	
	BCTYP := BCTypeFromStr(BCTypeName);
	BCTID := MeshTagIDFromName(Tgt, TagName);
	FLDID := GetFieldNFromName(FieldName);
	
	if FLDID < 0 then
		begin
			writeln('Error: NewBC() Unknown boundary type [',FieldName,']');
			Halt;
		end;
	
	if BCTYP < 0 then
		begin
			writeln('Error: NewBC() Unknown boundary type [',BCTypeName,']');
			Halt;
		end;
	
	if BCTID < 0 then
		begin
			writeln('Error: NewBC() Unknown mesh tag [',TagName,']');
			Halt;
		end;
	
	Tgt^.BCdata[Tgt^.BCs].BCType := BCTYP;
	Tgt^.BCdata[Tgt^.BCs].BCTag := BCTID;
	Tgt^.BCdata[Tgt^.BCs].BCValue := BCValue;
	Tgt^.BCdata[Tgt^.BCs].FieldID := FLDID;
	
	writeln('BC Created id=',Tgt^.BCs);
	
	Tgt^.BCs += 1;
end;

procedure GenerateConnectivityMatrix(Dom: pp3Domain; Dst: pMatrix);
var
	n, i: LongWord;
	id: array [0..3] of Int64;
	dx, dy, dx1, dx2, dy1, dy2: Double;
	nx, ny: Int64;

	function Max(a, b: Double): Double;
	begin
		if a > b then
			Max := a
		else
			Max := b;
	end;

begin
	for n := 0 to Dom^.cells-1 do
		for i := 0 to Dom^.cells-1 do
			Dst^[n][i] := 0;
	
	for n := 0 to Dom^.cells-1 do
		begin
			//Neighbour cell IDs
			id[0] := Dom^.cell[n].id_up;
			id[1] := Dom^.cell[n].id_down;
			id[2] := Dom^.cell[n].id_left;
			id[3] := Dom^.cell[n].id_right;
		
			//Distances to centre of neighbour cell (left/right/up/down)
			dx := 0;
			dy := 0;
			nx := 0;
			ny := 0;
			
			//Compute dx
			if id[2] >= 0 then
				begin
					dx1 := abs(Dom^.cell[n].centre.x - Dom^.cell[id[2]].centre.x);
					nx += 1;
				end;
			
			if id[3] >= 0 then
				begin
					dx2 := abs(Dom^.cell[id[3]].centre.x - Dom^.cell[n].centre.x);
					nx += 1;
				end;
			
			if nx = 2 then
				dx := 0.5 * (dx1 + dx2)
			else
				dx := max(dx1, dx2);
			
			//Compute dy
			if id[0] >= 0 then
				begin
					dy1 := abs(Dom^.cell[n].centre.y - Dom^.cell[id[0]].centre.y);
					ny += 1;
				end;
			
			if id[1] >= 0 then
				begin
					dy2 := abs(Dom^.cell[id[1]].centre.y - Dom^.cell[n].centre.y);
					ny += 1;
				end;
			
			if ny = 2 then
				dy := 0.5 * (dy1 + dy2)
			else
				dy := max(dy1, dy2);
			
			//Local cell connectivity along diagonal
			Dst^[n][n] := -(nx / (dx * dx)) - (ny / (dy * dy));
			
			//Store inter-cell connectivity components
			if id[2] >= 0 then
				Dst^[n][id[2]] := 1/(dx*dx);
			
			if id[3] >= 0 then
				Dst^[n][id[3]] := 1/(dx*dx);
			
			if id[0] >= 0 then
				Dst^[n][id[0]] := 1/(dy*dy);
			
			if id[1] >= 0 then
				Dst^[n][id[1]] := 1/(dy*dy);
		end;
	
	//for n := 0 to Dom^.cells-1 do
	//	Dst^[0][n] := 0;
	
	//Set reference pressure cell
	Dst^[0][0] := 1;
end;

procedure InitialiseMatrixConnectivity(Dom: pp3Domain);
var
	CMat: Matrix;

begin
	writeln('Initialising connectivity matrix data...');
	SetLength(CMat, Dom^.cells, Dom^.cells);
	writeln('Generating forward connectivity matrix...');
	GenerateConnectivityMatrix(Dom, @CMat);
	writeln('Inverting connectivity matrix...');
	SetLength(Dom^.InvertedConnectivityMatrix, Dom^.cells, Dom^.cells);
	InvertMatrix(@Cmat, @Dom^.InvertedConnectivityMatrix, Dom^.cells);
end;

procedure LoadADF(Src: ANSIString; Tgt: pp3Domain);
var
	Disk: Text;
	LineIn: ANSIString;

	procedure ProcessLineIn();
	var
		Verb, Noun, Noun2, Noun3, Noun4: ANSIString;
	
	begin
		Verb := GetCharSVParameterFromString(1, LineIn, ' ');
		Noun := GetCharSVParameterFromString(2, LineIn, ' ');
		
		writeln('ADFLoad>',Verb,':');
		
		case Verb of
				'time_start': Tgt^.TStart := StrToFloat(Noun);
				'time_end': Tgt^.TEnd := StrToFloat(Noun);
				'time_step': Tgt^.TStep := StrToFloat(Noun);
				'meshfile': 
					begin
						writeln('Loading mesh from [',Noun,']...');
						LoadSU2IntoDomain(Noun, Tgt);
						
						writeln('Generating mesh connectivity...');
						GenerateConnectivity(Tgt);
					end;
				'meshinit':
					begin
						writeln('Updating mesh metadata...');
						UpdateMetadata(Tgt);
						
						//Generate connectivity matrix and compute the inverse for solving the poission equation with L*P*L_inv=R*L_inv
						InitialiseMatrixConnectivity(Tgt);
					end;
				'logn' : Tgt^.LogInterval := StrToInt(Noun);
				'const':
					begin
						Noun2 := GetCharSVParameterFromString(3, LineIn, ' '); //Const value
						SetConst(Tgt, Noun, StrToFloat(Noun2));
					end;
				'bctag': 
					begin
						//Noun contains Mesh patch tag name
						Noun2 := GetCharSVParameterFromString(3, LineIn, ' '); //BC Type
						Noun3 := GetCharSVParameterFromString(4, LineIn, ' '); //field name
						Noun4 := GetCharSVParameterFromString(5, LineIn, ' '); //BC value
						
						NewBC(Tgt, Noun, Noun2, Noun3, StrToFloat(Noun4));
					end;
				'bgfield':
					begin
						Noun2 := GetCharSVParameterFromString(3, LineIn, ' ');
						
						SetFieldUniform(Tgt, Noun, StrToFloat(Noun2));
					end;
			end;
	end;

begin
	Assign(Disk, Src);
	Reset(Disk);
	
	repeat
		readln(Disk, LineIn);
		
		//Remove any leading spaces and tabs
		LineIn := StripLeft(' ', LineIn);
		LineIn := StripLeft('	', LineIn);
		
		//Ignore empty input and comment lines
		if (Length(LineIn) <= 0) or (LineIn[1] = '#') then
			continue;
		
		ProcessLineIn();
		
		until eof(Disk);
	
	Close(Disk);
	
	writeln('ADFLoad> Complete.');
end;

begin
end.
