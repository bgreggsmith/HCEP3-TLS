unit p3_fieldops;

{$Mode ObjFpc}

interface

uses
	p3_domain;

function GetFieldNFromName(FName: ANSIString): LongInt;
procedure SetFieldUniform(tgt: pp3Domain; fieldName: ANSIString; value: Double);

implementation

uses
	p3_buildConfig;

function GetFieldNFromName(FName: ANSIString): LongInt;
var
	n: LongWord;

begin
	GetFieldNFromName := -1;
	
	for n := 0 to p3_nFields - 1 do
		if p3_FieldName[n] = FName then
			begin
				GetFieldNFromName := n;
				Exit;
			end;
end;

procedure SetFieldUniform(tgt: pp3Domain; fieldName: ANSIString; value: Double);
var
	n: LongWord;
	fNum: LongInt;

begin
	fNum := GetFieldNFromName(fieldName);
	
	if fNum < 0 then
		begin
			writeln('Error: Invalid field [',fieldName,']');
			Exit;
		end;
	
	for n := 0 to tgt^.cells - 1 do
		tgt^.cell[n].fieldValue[fNum] := value;
end;

begin
end.
