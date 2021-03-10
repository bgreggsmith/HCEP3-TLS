unit p3_cell;

{$Mode ObjFpc}

interface

uses
	p3_buildConfig;

type
	p3Cell = Record
			id_up, id_left, id_down, id_right: LongInt;
			fieldValue: array [0..p3_nFields - 1] of Double;
			vertexIDs: array of LongWord;
			area: Double;
			tags: Integer;
		end;

implementation

begin
end.
