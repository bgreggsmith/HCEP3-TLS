unit p3_domain;

{$Mode ObjFpc}

interface

uses
	p3_cell,
	p3_boundaryConditions,
	p3_vertex,
	p3_matrixops;

type
	p3Domain = Record
			elemVtx: array of array of LongWord; //Stores which vertices each element is bounded by
			
			cell: array of p3Cell; //Stores the computation information pertaining to a given cell
			cells: Int64; //Number of cells in the domain
			
			vertex: array of vtx2; //Spatial vertex information
			vertices: Int64; //Number of spatial vertices
			
			tags: Int64;
			tagElems: array of LongWord;
			tagName: array of ANSIString;
			tagCells: array of array of LongWord;
			
			BCs: Int64;
			BCdata: array of p3BoundaryCondition;
			
			TNow, TStart, TStep, TEnd: Double;
			logInterval: Int64;
			
			consts: Int64;
			ConstID: array of ANSIString;
			ConstValue: array of Double;
			
			InvertedConnectivityMatrix: Matrix;
		end;
	pp3Domain = ^p3Domain;

function MeshTagIDFromName(Tgt: pp3Domain; TagName: ANSIString): LongInt;
procedure CopyDomain(Src, Dest: pp3Domain);
function GetConst(Dom: pp3Domain; ID: ANSIString): Double;
procedure SetConst(Dom: pp3Domain; ID: ANSIString; Value: Double);

implementation

function GetConst(Dom: pp3Domain; ID: ANSIString): Double;
var
	n: LongWord;

begin
	GetConst := 0;
	
	if Dom^.consts > 0 then
		for n := 0 to Dom^.consts - 1 do
			if ID = Dom^.ConstID[n] then
				begin
					GetConst := Dom^.ConstValue[n];
					Exit;
				end;
	
	writeln('ERROR: p3_Domain:GetConst() invalid undefined constant [',ID,']');
end;

procedure SetConst(Dom: pp3Domain; ID: ANSIString; Value: Double);
var
	n: LongWord;

begin
	if Dom^.consts >= Length(Dom^.ConstID) then
		begin
			SetLength(Dom^.ConstID, Dom^.consts + 8);
			SetLength(Dom^.ConstValue, Dom^.consts + 8);
		end;
	
	//Check if this is an update and not a new creation
	if Dom^.consts > 0 then
		for n := 0 to Dom^.consts - 1 do
			if Dom^.ConstID[n] = ID then
				begin
					Dom^.ConstID[n] := ID;
					Dom^.ConstValue[n] := Value;
					Exit;
				end;
	
	Dom^.ConstID[Dom^.consts] := ID;
	Dom^.ConstValue[Dom^.consts] := Value;
	Dom^.consts += 1;
end;

procedure CopyDomain(Src, Dest: pp3Domain);
var
	n, i: LongWord;

begin
	SetLength(Dest^.elemVtx, Length(Src^.elemVtx));
	for n := 0 to Length(Src^.elemVtx) - 1 do
		begin
			SetLength(Dest^.elemVtx[n], Length(Src^.elemVtx[n]));
			
			for i := 0 to Length(Src^.elemVtx[n]) - 1 do
				Dest^.elemVtx[n][i] := Src^.elemVtx[n][i];
		end;
	
	Dest^.cells := Src^.cells;
	SetLength(Dest^.cell, Length(Src^.cell));
	for n := 0 to Length(Src^.cell) - 1 do
		CopyCell(@Src^.cell[n], @Dest^.cell[n]);
	
	Dest^.vertices := Src^.vertices;
	SetLength(Dest^.vertex, Length(Src^.vertex));
	for n := 0 to Length(Src^.vertex) - 1 do
		Dest^.vertex[n] := Src^.vertex[n];
	
	Dest^.tags := Src^.tags;
	SetLength(Dest^.tagElems, Src^.tags);
	SetLength(Dest^.tagName, Src^.tags);
	SetLength(Dest^.tagCells, Src^.tags);
	for n := 0 to Src^.tags - 1 do
		begin
			Dest^.tagElems[n] := Src^.tagElems[n];
			Dest^.tagName[n] := Src^.tagName[n];
			
			SetLength(Dest^.tagCells[n], Length(Src^.tagCells[n]));
			for i := 0 to Length(Src^.tagCells[n]) - 1 do
				Dest^.tagCells[n][i] := Src^.tagCells[n][i];
		end;
	
	Dest^.BCs := Src^.BCs;
	SetLength(Dest^.BCdata, Length(Src^.BCdata));
	for n := 0 to Length(Src^.BCdata) do
		Dest^.BCdata[n] := Src^.BCdata[n];
	
	Dest^.TNow := Src^.TNow;
	Dest^.TStart := Src^.TStart;
	Dest^.TStep := Src^.TStep;
	Dest^.TEnd := Src^.TEnd;
	
	Dest^.LogInterval := Src^.LogInterval;
	
	Dest^.consts := Src^.consts;
	SetLength(Dest^.constID, Length(Src^.constID));
	SetLength(Dest^.constValue, Length(Src^.constValue));
	for n := 0 to Length(Src^.constID) do
		begin
			Dest^.constID[n] := Src^.constID[n];
			Dest^.constValue[n] := Src^.constValue[n];
		end;
	
	SetLength(Dest^.InvertedConnectivityMatrix, Src^.cells, Src^.cells);
	for n := 0 to Src^.cells - 1 do
		for i := 0 to Src^.cells - 1 do
			Dest^.InvertedConnectivityMatrix[n][i] := Src^.InvertedConnectivityMatrix[n][i];
end;

function MeshTagIDFromName(Tgt: pp3Domain; TagName: ANSIString): LongInt;
var
	n: LongWord;

begin
	MeshTagIDFromName := -1;
	
	for n := 0 to Tgt^.tags - 1 do
		if Tgt^.tagName[n] = TagName then
			begin
				MeshTagIDFromName := n;
				Exit;
			end;
end;

begin
end.
