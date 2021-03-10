unit p3_boundaryConditions;

{$Mode ObjFpc}

interface

type
	p3BoundaryCondition = Record
			BCType: LongInt;
			BCTag: LongInt;
			BCValue: Double;
			FieldID: LongInt;
		end;

function BCTypeFromStr(BCTypeName: ANSIString): LongInt;

implementation

uses
	p3_buildConfig;

function BCTypeFromStr(BCTypeName: ANSIString): LongInt;
begin
	BCTypeFromStr := -1;
	
	case BCTypeName of
			'constant': BCTypeFromStr := BCType_Constant;
		end;
end;

begin
end.
