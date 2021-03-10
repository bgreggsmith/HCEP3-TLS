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
			
			TStart, TStep, TEnd: Double;
			LogInterval: Int64;
		end;
	pp3Domain = ^p3Domain;

function MeshTagIDFromName(Tgt: pp3Domain; TagName: ANSIString): LongInt;

implementation

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
