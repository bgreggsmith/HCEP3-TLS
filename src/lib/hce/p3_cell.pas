unit p3_cell;

{$Mode ObjFpc}

interface

uses
	p3_vertex,
	p3_buildConfig;

type
	p3Cell = Record
			id_up, id_left, id_down, id_right: LongInt;
			fieldValue: array [0..p3_nFields - 1] of Double;
			area: Double;
			tags: LongInt;
			centre: vtx2;
		end;
	pp3Cell = ^p3Cell;

procedure CopyCell(Src, Dest: pp3Cell);

implementation

procedure CopyCell(Src, Dest: pp3Cell);
var
	n: LongWord;

begin
	Dest^.id_up := Src^.id_up;
	Dest^.id_down := Src^.id_down;
	Dest^.id_left := Src^.id_left;
	Dest^.id_right := Src^.id_right;
	
	for n := 0 to p3_nFields-1 do
		Dest^.fieldValue[n] := Src^.fieldValue[n];
	
	Dest^.area := Src^.area;
	Dest^.tags := Src^.tags;
	Dest^.centre := Src^.centre;
end;

begin
end.
