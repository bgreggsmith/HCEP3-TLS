//HCE-P3 Top Level Synchroniser [TLS]

program TLS;

{$Mode ObjFpc}

uses
	MPI,
	crt,
	
	loader_adf,
	p3_globals,
	p3_fieldops,
	p3_simExec,
	p3_CSECommunication;

procedure DistributeData(nodes, ownID: Integer);
var
	n: LongWord;
	cse_ready: array of Boolean;

begin
	SetLength(cse_ready, nodes);
	
	for n := 0 to nodes -1 do
		cse_ready[n] := false;
	
	//Transmit case control variables to all CSEs
	for n := 0 to nodes - 1 do
		if ownID <> n then
			CSE_TXConfig(n, @SimData);

	//Transmit relevant domain data to CSEs
	//TODO: This needs to have domain decomposition for multi-node execution
	for n := 0 to nodes - 1 do
		if ownID <> n then
			CSE_TXData(n, @SimData);
	
	//Send ready flag to all nodes so they all start executing at the same time
	for n := 0 to nodes - 1 do
		if ownID <> n then
			CSE_BeginExec(n);
end;

begin
	MPI_Init();
	
	MPI_Comm_size(MPI_COMM_WORLD, @numprocs);
	MPI_Comm_rank(MPI_COMM_WORLD, @rank);
	
	writeln('TLS Rank=',rank,' of ',numprocs);
	
	LoadADF('lid.adf', @simData);
	
	writeln('Writing prestart field data...');
	SetBCCells(@SimData);
	DumpFieldsToFileVTK(@SimData, 'p', 'out/prestart.vtk');
	
	if numprocs > 1 then
		begin
			writeln('Distributing data to CSEs');
			DistributeData(numprocs, rank);
			
			writeln('Init complete, writing back incumbent field data.');
			ExecSimulation_CSE(@SimData);
		end;
	
	//If we arent running in an mpi environment then run the proofing code
	if numprocs <= 1 then
		ExecSimulation_Proof(@simData);
	
	//for n := 0 to SimData.cells-1 do
	//	writeln('Cell ',n,' has neighbours u(',SimData.cell[n].id_up,') r(',SimData.cell[n].id_right,') d(',SimData.cell[n].id_down,') l(',SimData.cell[n].id_left,') t=',SimData.cell[n].tags);
	
	MPI_Finalize();
end.

