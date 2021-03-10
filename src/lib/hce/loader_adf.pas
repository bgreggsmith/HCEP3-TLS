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
	
	Tgt^.BCs += 1;
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
				'logn' : Tgt^.LogInterval := StrToInt(Noun);
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
