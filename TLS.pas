//HCE-P3 Top Level Synchroniser [TLS]

program TLS;

{$Mode ObjFpc}

uses
	loader_adf,
	p3_globals;

var
	n: Longword;

begin
	LoadADF('test.adf', @simData);
	
	//for n := 0 to SimData.cells-1 do
	//	writeln('Cell ',n,' has neighbours u(',SimData.cell[n].id_up,') r(',SimData.cell[n].id_right,') d(',SimData.cell[n].id_down,') l(',SimData.cell[n].id_left,') t=',SimData.cell[n].tags);
end.

