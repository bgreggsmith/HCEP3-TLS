//HCE-P3 Top Level Synchroniser [TLS]

program TLS;

{$Mode ObjFpc}

uses
	MPI,
	crt,
	
	loader_adf,
	p3_globals,
	p3_fieldops,
	p3_simExec;

var
	//n: Longword;
	numprocs, rank: Integer;

begin
	MPI_Init();
	
	MPI_Comm_size(MPI_COMM_WORLD, @numprocs);
	MPI_Comm_rank(MPI_COMM_WORLD, @rank);
	
	writeln('TLS Rank=',rank,' of ',numprocs);
	
	LoadADF('lid.adf', @simData);
	
	writeln('Writing prestart field data...');
	SetBCCells(@SimData);
	DumpFieldsToFileVTK(@SimData, 'p', 'out/prestart.vtk');
	
	writeln('ADF Loaded, any key to start the mayhem.');
	ReadKey();
	
	ExecSimulation_Proof(@simData);
	
	//for n := 0 to SimData.cells-1 do
	//	writeln('Cell ',n,' has neighbours u(',SimData.cell[n].id_up,') r(',SimData.cell[n].id_right,') d(',SimData.cell[n].id_down,') l(',SimData.cell[n].id_left,') t=',SimData.cell[n].tags);
	
	MPI_Finalize();
end.

