unit loader_su2;

{$Mode ObjFpc}

interface

uses
	sysutils,
	strutils,
	math,
	
	p3_utils,
	p3_buildConfig,
	p3_cell,
	p3_domain;

procedure LoadSU2IntoDomain(Src: ANSIString; Dest: pp3Domain);
procedure GenerateConnectivity(Dom: pp3Domain);
procedure UpdateMetadata(Dom: pp3Domain);

implementation

uses
	p3_fieldops;

const
	ParserMode_Generic	=	0;
	ParserMode_Elem		=	1;
	ParserMode_Point	=	2;
	ParserMode_Tag		=	3;

procedure UpdateMetadata(Dom: pp3Domain);
var
	n, i, j, z: LongWord;
	SumA, SumB: Double;

begin
	for n := 0 to Dom^.cells - 1 do
		begin
			//Compute cell centre
			SumA := 0;
			SumB := 0;
			
			for i := 0 to Length(Dom^.elemVtx[n])-1 do
				begin
					SumA += Dom^.vertex[Dom^.elemVtx[n][i]].x;
					SumB += Dom^.vertex[Dom^.elemVtx[n][i]].y;
				end;
			
			SumA := SumA / (i + 1);
			SumB := SumB / (i + 1);
			
			Dom^.cell[n].centre.x := SumA;
			Dom^.cell[n].centre.y := SumB;
			
			//Compute cell area using shoelace formula
			SumA := 0;
			SumB := 0;
			for i := 0 to Length(Dom^.elemVtx[n])-2 do
				begin
					SumA += Dom^.vertex[Dom^.elemVtx[n][i]].x * Dom^.vertex[Dom^.elemVtx[n][i+1]].y;
					SumB -= Dom^.vertex[Dom^.elemVtx[n][i]].y * Dom^.vertex[Dom^.elemVtx[n][i+1]].x;
				end;
			
			Dom^.cell[n].area := abs(SumA + SumB) / 2;
			
			//Update tag count for the cell
			z := 0;
			for i := 0 to Dom^.tags - 1 do
				for j := 0 to Dom^.tagElems[i] do
					if Dom^.tagCells[i][j] = n then
						z += 1;
			
			Dom^.cell[n].tags := z;
			
			SetBCCells(Dom);
		end;
end;

procedure GenerateConnectivity(Dom: pp3Domain);
var
	c, n, i, j, k, l: LongWord;
	v1, v2: LongWord;
	i1, i2: LongWord;
	match: Integer;
	oX, oY: Double;
	aX, aY: Double;
	delta, direction: Double;
	totalMatches: LongWord;

begin
	totalMatches := 0;
	
	//This populates the neighbour information for each cell
	for n := 0 to Dom^.cells-1 do
		begin
			Dom^.cell[n].id_left := -1;
			Dom^.cell[n].id_right := -1;
			Dom^.cell[n].id_up := -1;
			Dom^.cell[n].id_down := -1;
			
			//Compute cell origin for later use in directionality test
			oX := 0;
			oY := 0;
			c := 0;
			for k := 0 to Length(Dom^.elemVtx[n])-1 do
				begin
					oX += Dom^.vertex[Dom^.elemVtx[n][k]].x;
					oY += Dom^.vertex[Dom^.elemVtx[n][k]].y;
					c += 1;
				end;
			oX := oX / c;
			oY := oY / c;
			
			for i := 0 to 3 do //Select each edge of the cell and check for neighbours that share the pair
				begin
					//Load each edge into v1 and v2 for neighbour search
					i1 := i;
					i2 := i + 1;
					
					if i2 > 3 then
						i2 := 0;
					
					v1 := Dom^.elemVtx[n][i1];
					v2 := Dom^.elemVtx[n][i2];
					
					//Search for a neighbour on this edge
					for j := 0 to Dom^.cells-1 do
						begin
							//Obviously the cell itself contains its own edges
							if j = n then
								continue;
							
							match := 0;
							
							for k := 0 to Length(Dom^.elemVtx[j])-1 do
								begin
									if Dom^.elemVtx[j][k] = v1 then
										match += 1;
									
									if Dom^.elemVtx[j][k] = v2 then
										match += 1;
								end;
							
							//These cells are adjacent, find out in which direction
							if match = 2 then
								begin
									aX := 0;
									aY := 0;
									c := 0;
									for l := 0 to Length(Dom^.elemVtx[j])-1 do
										begin
											aX += Dom^.vertex[Dom^.elemVtx[j][l]].x;
											aY += Dom^.vertex[Dom^.elemVtx[j][l]].y;
											c += 1;
										end;
									aX := aX / c;
									aY := aY / c;
									
									aX -= oX;
									aY -= oY;
									
									totalMatches += 1;
									
									direction := arctan2(aX, aY) * (180 / 3.1415926536);
									
									if (direction > -45) and (direction < 45) then
										Dom^.cell[n].id_up := j
									else if (direction > 45) and (direction < 135) then
										Dom^.cell[n].id_right := j
									else if (direction < -45) and (direction > -135) then
										Dom^.cell[n].id_left := j
									else
										Dom^.cell[n].id_down := j;
								end;
						end;
			end;
		end;
	
	writeln('   Found ',totalMatches,' edge matches');
end;

procedure LoadSU2IntoDomain(Src: ANSIString; Dest: pp3Domain);
var
	Disk: Text;
	LineIn: ANSIString;
	PMode: Integer;
	curTag, curTagElem: Integer;
	
	procedure ParseCommand(Dat: ANSIString);
	var
		Verb, Noun: ANSIString;
		NounI: LongInt;
	
	begin
		//Strip any spaces that may be present (mostly around the =)
		Dat := ReplaceStr(Dat, ' ', '');
		
		Verb := Upcase(GetCharSVParameterFromString(1, Dat, '='));
		Noun := GetCharSVParameterFromString(2, Dat, '=');
		
		if TryStrToInt(Noun, NounI) = False then
			NounI := 0;
		
		case Verb of
				'NDIME':
					begin
						if StrToInt(Noun) <> 2 then
							begin
								writeln('Error - input mesh is not 2D!');
								Halt;
							end;
						
						PMode := ParserMode_Generic;
					end;
				
				'NELEM':
					begin
						Dest^.cells := NounI;
						SetLength(Dest^.cell, Dest^.cells);
						SetLength(Dest^.elemVtx, Dest^.cells);
						
						PMode := ParserMode_Elem;
					end;
				
				'NPOIN':
					begin
						Dest^.vertices := NounI;
						SetLength(Dest^.vertex, Dest^.vertices);
						
						PMode := ParserMode_Point;
					end;
				
				'NMARK':
					begin
						PMode := ParserMode_Tag;
						
						Dest^.tags := NounI;
						SetLength(Dest^.tagElems, Dest^.tags);
						SetLength(Dest^.tagCells, Dest^.tags);
						SetLength(Dest^.tagName, Dest^.tags);
					end;
				
				'MARKER_TAG':
					begin
						curTag += 1;
						
						Dest^.tagName[curTag] := Noun;
						
						PMode := ParserMode_Tag;
					end;
				
				'MARKER_ELEMS':
					begin
						Dest^.tagElems[curTag] := NounI;
						SetLength(Dest^.tagCells[curTag], NounI);
						
						PMode := ParserMode_Tag;
						curTagElem := 0;
					end;
			end;
	end;
	
	procedure ParseElementFromLine(Dat: ANSIString);
	const
		nVtx	= 4;
	
	var
		lineType, ID, n: LongWord;
		v: array of LongWord;
	
	begin
		lineType := StrToInt(GetCharSVParameterFromString(1, Dat, ' '));
		
		//Reject anything that isnt a quad
		if lineType <> 9 then
			begin
				writeln('ERROR: Non-quad element in mesh!');
				
				Exit;
			end;
		
		//Load quads
		SetLength(v, nVtx);
		
		for n := 0 to nVtx-1 do
			v[n] := StrToInt(GetCharSVParameterFromString(n + 2, Dat, ' '));
		
		ID := StrToInt(GetCharSVParameterFromString(n + 3, Dat, ' '));
		
		SetLength(Dest^.elemVtx[ID], nVtx);
		
		for n := 0 to nVtx-1 do
			Dest^.elemVtx[ID][n] := v[n];
	end;
	
	procedure ParsePointFromLine(Dat: ANSIString);
	var
		x, y: Double;
		id: LongWord;
	
	begin
		x := StrToFloat(GetCharSVParameterFromString(1, Dat, ' '));
		y := StrToFloat(GetCharSVParameterFromString(2, Dat, ' '));
		id := StrToInt(GetCharSVParameterFromString(3, Dat, ' '));
		
		Dest^.vertex[id].x := x;
		Dest^.vertex[id].y := y;
	end;
	
	//For tags it is assumed these edges are boundaries and are *NOT* shared by multiple cells otherwise this will break
	procedure ParseTagFromLine(Dat: ANSIString);
	var
		typeID, e1, e2: Int64;
		n, i, z, nMatch: Int64;
	
	begin
		typeID := StrToInt(GetCharSVParameterFromString(1, Dat, ' '));
		e1 := StrToInt(GetCharSVParameterFromString(2, Dat, ' '));
		e2 := StrToInt(GetCharSVParameterFromString(3, Dat, ' '));
		
		//Find the cell which contains this edge
		for n := 0 to Dest^.cells-1 do
			begin
				nMatch := 0;
				
				for i := 0 to Length(Dest^.elemVtx[n])-1 do
					begin
						if Dest^.elemVtx[n][i] = e1 then
							nMatch += 1;
						
						if Dest^.elemVtx[n][i] = e2 then
							nMatch += 1;
					end;
				
				if nMatch = 2 then
					begin
						z := n;
						break;
					end;
			end;
		
		Dest^.tagCells[curTag][curTagElem] := z;
		Dest^.cell[z].tags += 1;
		curTagElem += 1;
	end;

begin
	curTag := -1;
	
	PMode := ParserMode_Generic;
	
	Assign(Disk, Src);
	Reset(Disk);
	
	repeat
		readln(Disk, LineIn);
		
		//Check for a command
		if pos('=', LineIn) > 0 then
			ParseCommand(LineIn)
		else
			case PMode of
					ParserMode_Elem: ParseElementFromLine(LineIn);
					ParserMode_Point: ParsePointFromLine(LineIn);
					ParserMode_Tag: ParseTagFromLine(LineIn);
				end;
		
		until eof(Disk);
	
	Close(Disk);
	
	writeln('Mesh file load summary:');
	writeln('   ',Dest^.cells,' elements loaded.');
	writeln('   ',Dest^.vertices,' spatial vertices loaded.');
	
	
	writeln('Generating mesh connectivity data:');
	GenerateConnectivity(Dest);
end;

begin
end.
