//The bare minimum of imports from PMAPI
unit p3_utils;

{$Mode ObjFpc}

interface

function GetCharSVParameterFromString(Id: Int64; CSV, Sep: ANSIString): ANSIString;
function StripLeft(Match: Char; Dat: ANSIString): ANSIString;

implementation

function StripLeft(Match: Char; Dat: ANSIString): ANSIString;
var
	Buffer: ANSIString;

begin
	StripLeft := '';
	
	if Length(Dat) <= 0 then
		Exit;
	
	Buffer := Dat;
	StripLeft := Dat;
	
	if Buffer[1] <> Match then
		Exit;
	
	while Buffer[1] = Match do
		Delete(Buffer, 1, 1);
	
	StripLeft := Buffer;
end;

function GetStringPart(Data: ANSIString; StartPosition, EndPosition: Int64): ANSIString;
var
	c: Int64;

begin
	GetStringPart := '';
	
	if (StartPosition < 0) or (Length(Data) <= 0) then
		Exit;
	if (EndPosition < 0) or (EndPosition > Length(Data)) then
		EndPosition := Length(Data);
	if EndPosition < StartPosition then
		begin
			c := StartPosition;
			StartPosition := EndPosition;
			EndPosition := c;
		end;
	if EndPosition = StartPosition then
		begin
			GetStringPart := Data[StartPosition];
			Exit;
		end;
	
	c := StartPosition;
	repeat
		GetStringPart += Data[c];
		c += 1;
		until c > EndPosition;
end;

function FindOccurencesInString(Raw: ANSIString; Data: ANSIString): Int64;
var
	Occurences: Int64;
	SearchPosition, fP: Int64;

begin
	Occurences := 0;
	SearchPosition := 1;
	if (Length(Raw) <= 0) or ((Length(Data) <= 0) and (Pos(Raw, Data) > 0)) then
		Exit;
		
	repeat
		fP := Pos(Data, Raw[SearchPosition..Length(Raw)]);
		
		if fP > 0 then
			Occurences += 1
		else
			break;
		
		SearchPosition += fP;
		
		until SearchPosition >= Length(Raw);
	FindOccurencesInString := Occurences;
end;

function FindOccurenceInString(Raw, Data: ANSIString; n: Int64): Int64;
var
	c: Int64;
	LastPos: Int64;
	NextPos: Int64;
	
begin
	FindOccurenceInString := 0;
	if FindOccurencesInString(Raw, Data) < n then
		Exit;
	if n <= 0 then
		Exit;
		
	LastPos := 0;
	NextPos := 0;
	c := 0;
	repeat
		c += 1;
		NextPos := Pos(Data, GetStringPart(Raw, LastPos, -1));
		LastPos += NextPos;
		if c >= n then
			begin
				FindOccurenceInString := LastPos - 1;
				Exit;
			end;
		until c >= Length(Raw);
end;

function GetCharSVParameterFromString(Id: Int64; CSV, Sep: ANSIString): ANSIString;
var
	StartPosition, EndPosition: Int64;

begin
	GetCharSVParameterFromString := '';
	if Id < 0 then
		Exit;
	
	if FindOccurencesInString(CSV, Sep) < Id - 1 then
		Exit;
	
	StartPosition := FindOccurenceInString(CSV, Sep, Id - 1) + 1;
	EndPosition := FindOccurenceInString(CSV, Sep, Id) - 1;
	
	if (EndPosition = 0) and (StartPosition > EndPosition) then
		EndPosition := Length(CSV);
	
	GetCharSVParameterFromString := CSV[StartPosition..EndPosition];
end;

begin
end.
