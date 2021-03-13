unit p3_domain;

{$Mode ObjFpc}

interface

uses
	p3_cell,
	p3_boundaryConditions,
	p3_vertex;

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
		end;
	pp3Domain = ^p3Domain;

function MeshTagIDFromName(Tgt: pp3Domain; TagName: ANSIString): LongInt;
procedure CopyDomain(Src, Dest: pp3Domain);

implementation

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
		Dest^.cell[n] := Src^.cell[n];
	
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
