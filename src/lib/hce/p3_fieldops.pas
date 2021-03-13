unit p3_fieldops;

{$Mode ObjFpc}

interface

uses
	p3_domain;

function GetFieldNFromName(FName: ANSIString): LongInt;
procedure SetFieldUniform(tgt: pp3Domain; fieldName: ANSIString; value: Double);
procedure DumpFieldToFileCSV(Dom: pp3Domain; FieldName: ANSIString; DestFile: ANSIString);
procedure DumpFieldsToFileVTK(Dom: pp3Domain; FieldName: ANSIString; DestFile: ANSIString);
function FieldMax(Dom: pp3Domain; FieldName: ANSIString): Double;

implementation

uses
	sysutils,
	
	p3_buildConfig;

function FieldMax(Dom: pp3Domain; FieldName: ANSIString): Double;
var
	n: LongWord;
	max: Double;
	fieldID: LongInt;

begin
	fieldID := GetFieldNFromName(FieldName);
	if fieldID < 0 then
		begin
			writeln('ERROR! FieldMax() invalid field [' + FieldName + ']');
			Halt;
		end;
	
	max := Dom^.cell[0].fieldValue[fieldID];
	for n := 1 to Dom^.cells - 1 do
		if Dom^.cell[n].fieldValue[fieldID] > max then
			max := Dom^.cell[n].fieldValue[fieldID];
	
	FieldMax := max;
end;

procedure DumpFieldsToFileVTK(Dom: pp3Domain; FieldName: ANSIString; DestFile: ANSIString);
var
	n, i: LongWord;
	Disk: Text;
	LineBuffer: ANSIString;
	fieldID: Integer;

begin
	Assign(Disk, DestFile);
	Rewrite(Disk);
	
	//write VTK header
	writeln(Disk, '# vtk DataFile Version 2.0');
	writeln(Disk, 'Unstructured Grid Example');
	writeln(Disk, 'ASCII');
	writeln(Disk, 'DATASET POLYDATA');
	
	//export mesh points
	writeln(Disk, 'POINTS ',Dom^.vertices,' float');
	for n := 0 to Dom^.vertices - 1 do
		writeln(Disk, Dom^.vertex[n].x,' ',Dom^.vertex[n].y,' 0');
	
	//export mesh cells
	writeln(Disk, 'POLYGONS ',Dom^.Cells,' ',Dom^.Cells * 5);
	for n := 0 to Dom^.Cells - 1 do
		writeln(Disk, '4 ', Dom^.elemVtx[n][0], ' ', Dom^.elemVtx[n][1], ' ',Dom^.elemVtx[n][2], ' ', Dom^.elemVtx[n][3]);
	
	writeln(Disk, 'CELL_DATA ', Dom^.Cells);
	
	for i := 0 to p3_nFields - 1 do
		begin
			writeln(Disk, 'SCALARS ', p3_FieldName[i], ' float 1');
			writeln(Disk, 'LOOKUP_TABLE default');
			for n := 0 to Dom^.Cells - 1 do
				begin
					LineBuffer := FloatToStr(Dom^.cell[n].fieldValue[i]);
					
					writeln(Disk, LineBuffer);
				end;
		end;
	
	Close(Disk);
end;

procedure DumpFieldToFileCSV(Dom: pp3Domain; FieldName: ANSIString; DestFile: ANSIString);
var
	n: LongWord;
	Disk: Text;
	LineBuffer: ANSIString;
	fieldID: Integer;

begin
	fieldID := GetFieldNFromName(FieldName);
	
	if fieldID < 0 then
		begin
			writeln('Error: DumpFieldToFileCSV() Invalid field [',FieldName,']');
			Halt;
		end;
	
	Assign(Disk, DestFile);
	Rewrite(Disk);
	
	writeln(Disk, '"x","y","' + FieldName + '"');
	
	for n := 0 to Dom^.Cells - 1 do
		begin
			LineBuffer := FloatToStr(Dom^.cell[n].centre.x) + ',' + FloatToStr(Dom^.cell[n].centre.y) + ',' + FloatToStr(Dom^.cell[n].fieldValue[fieldID]);
			
			writeln(Disk, LineBuffer);
		end;
	
	Close(Disk);
end;

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
