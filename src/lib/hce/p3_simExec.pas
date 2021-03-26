unit p3_simExec;

{$Mode ObjFpc}

interface

uses
	p3_domain;

procedure ExecSimulation_Proof(Dom: pp3Domain);
procedure ExecSimulation_CSE(Dom: pp3Domain);

implementation

uses
	crt,
	sysutils,
	
	p3_matrixops,
	p3_fieldops,
	p3_buildConfig,
	p3_CSECommunication;

procedure ExecSimulation_CSE(Dom: pp3Domain);
begin
	Dom^.TNow := Dom^.TStart;
	
	repeat
		CSE_RXFieldWBack(Dom);
		DumpFieldsToFileVTK(Dom, 'p', 'out/result.vtk.' + IntToStr(Dom^.Iter));
		until Dom^.TNow > Dom^.TEnd;
end;

procedure ApplyCellBCs(Dom: pp3Domain; cellId: Int64);
var
	i, j, n: LongWord;

begin
	n := 0;
	for i := 0 to Dom^.BCs-1 do //Iterate through all current BCs
		for j := 0 to Dom^.tagElems[Dom^.BCData[i].BCTag]-1 do
			if cellId = Dom^.tagCells[Dom^.BCData[i].BCTag][j] then
				begin
					case Dom^.BCData[i].BCType of
							BCType_Constant: Dom^.cell[cellid].fieldValue[Dom^.BCData[i].FieldID] := Dom^.BCData[i].BCValue;
						end;
					
					if n >= Dom^.cell[cellid].tags then
						Exit;
				end;
end;

procedure ApplySmoothing(Data: pp3Domain);
var
	i, j, k: LongWord;
	n: Int64;
	Sum: Double;
	id: array [0..3] of Int64;

begin
	for i := 0 to Data^.cells-1 do
		begin
			id[0] := Data^.cell[i].id_up;
			id[1] := Data^.cell[i].id_down;
			id[2] := Data^.cell[i].id_left;
			id[3] := Data^.cell[i].id_right;
			
			for k := 0 to p3_nFields-1 do
				begin
					Sum := 0;
					n := 0;
					
					for j := 0 to 3 do
						if id[j] >= 0 then
							begin
								Sum += Data^.cell[i].fieldValue[k];
								n += 1;
							end;
					
					if n > 0 then
						Data^.cell[i].fieldValue[k] := Sum / n;
				end;
		end;
end;

procedure ApplyLimiters(Data: pp3Domain);
var
	rho, pLimit, vLimit: Double;
	n: LongWord;
	pField, uField, vField: Integer;

	function Sign(v: Double): Double;
	begin
		if v < 0 then
			Sign := -1
		else
			Sign := +1;
	end;

begin
	rho := GetConst(Data, 'rho');
	
	pField := GetFieldNFromName('p');
	uField := GetFieldNFromName('ux');
	vField := GetFieldNFromName('uy');
	
	//Limit to sonic speeds, stagnation pressure
	vLimit := 20;
	pLimit := 50E5;
	
	for n := 0 to Data^.cells - 1 do
		begin
			if Data^.cell[n].fieldValue[pField] > pLimit then
				Data^.cell[n].fieldValue[pField] := pLimit;
			
			if Data^.cell[n].fieldValue[pField] < 0 then
				Data^.cell[n].fieldValue[pField] := 0;
			
			if abs(Data^.cell[n].fieldValue[uField]) > vLimit then
				Data^.cell[n].fieldValue[uField] := sign(Data^.cell[n].fieldValue[uField]) * vLimit;
			
			if abs(Data^.cell[n].fieldValue[vField]) > vLimit then
				Data^.cell[n].fieldValue[vField] := sign(Data^.cell[n].fieldValue[vField]) * vLimit;
		end;
end;

procedure KernelExec(RData, WData: pp3Domain);
var
	n, i, j: LongWord;
	pField, uField, vField, nx, ny: Integer;
	id: array [0..3] of LongInt;
	Sum, u_here, v_here: Double;
	us, vs, rh: array of Double;
	delu, d2fdx2, d2fdy2, fdfdx, fdfdy, dx1, dx2, dy1, dy2, dx, dy, deltaT, nu, rho, dfdx, dfdy: Double;
	id_xm, id_xp, id_ym, id_yp: LongInt;

	function Max(a, b: Double): Double;
	begin
		if a > b then
			Max := a
		else
			Max := b;
	end;

	procedure PopulateNeighDeltas();
	var
		_i, _n: LongWord;
		_su, _sv: Double;
	
	begin
		//This neighbour data and dx/dy values for each cell could really be cached for maximum speed
		id[0] := RData^.cell[n].id_up;
		id[1] := RData^.cell[n].id_down;
		id[2] := RData^.cell[n].id_left;
		id[3] := RData^.cell[n].id_right;
		
		if id[0] >= 0 then id_yp := id[0] else id_yp := n;
		if id[1] >= 0 then id_ym := id[1] else id_ym := n;
		if id[3] >= 0 then id_xp := id[3] else id_xp := n;
		if id[2] >= 0 then id_xm := id[2] else id_xm := n;
		
		_su := 0;
		_sv := 0;
		_n := 0;
		for _i := 0 to 3 do
			if id[_i] >= 0 then
				begin
					_su += RData^.cell[id[_i]].fieldValue[uField];
					_sv += RData^.cell[id[_i]].fieldValue[vField];
					_n += 1;
				end;
		
		u_here := _su / _n;
		v_here := _sv / _n;
		
		//If there are tags do not try to perform the normal inner-cell kernel
		//if RData^.cell[n].tags > 0 then
		//	goto EntryPoint_FinaliseCell;
		
//Common values for all discretisations
		
		//writeln('Cell ',n,' u=',u_here,' v=',v_here);
		
		//Distances to centre of neighbour cell (left/right/up/down)
		dx := 0;
		dy := 0;
		nx := 0;
		ny := 0;
		
		if id[2] >= 0 then
			begin
				dx1 := abs(RData^.cell[n].centre.x - RData^.cell[id[2]].centre.x);
				nx += 1;
			end;
		
		if id[3] >= 0 then
			begin
				dx2 := abs(RData^.cell[id[3]].centre.x - RData^.cell[n].centre.x);
				nx += 1;
			end;
		
		if nx = 2 then
			dx := 0.5 * (dx1 + dx2)
		else
			dx := max(dx1, dx2);
		
		if id[0] >= 0 then
			begin
				dy1 := abs(RData^.cell[n].centre.y - RData^.cell[id[0]].centre.y);
				ny += 1;
			end;
		
		if id[1] >= 0 then
			begin
				dy2 := abs(RData^.cell[id[1]].centre.y - RData^.cell[n].centre.y);
				ny += 1;
			end;
		
		if ny = 2 then
			dy := 0.5 * (dy1 + dy2)
		else
			dy := max(dy1, dy2);
	end;

label EntryPoint_FinaliseCell, EntryPoint_Laplace, EntryPoint_Corrector;

const	relax = 0.7;

begin
	deltaT := RData^.TStep;
	
	writeln('solver deltaT=',deltaT);
	
	nu := GetConst(RData, 'nu');
	rho := GetConst(RData, 'rho');
	
	pField := GetFieldNFromName('p');
	uField := GetFieldNFromName('ux');
	vField := GetFieldNFromName('uy');
	
	SetLength(us, RData^.cells);
	SetLength(vs, RData^.cells);
	SetLength(rh, RData^.cells);
	
	for n := 0 to RData^.cells - 1 do
		begin
			//Populate id[] cell neighbour fields and dx/dy data based on the position in the grid
			PopulateNeighDeltas();
			
//Ux discretisation
			//Compute components (d2u/dx2, d2u/dy2, udu/dx, vdu/dy)
			d2fdx2 := RData^.cell[id_xm].fieldValue[uField] - (2 * RData^.cell[n].fieldValue[uField]) + RData^.cell[id_xp].fieldValue[uField];
			d2fdx2 /= (dx * dx);
			
			d2fdy2 := RData^.cell[id_ym].fieldValue[uField] - (2 * RData^.cell[n].fieldValue[uField]) + RData^.cell[id_yp].fieldValue[uField];
			d2fdy2 /= (dy * dy);
			
			fdfdx := RData^.cell[id_xp].fieldValue[uField] - RData^.cell[id_xm].fieldValue[uField];
			fdfdx := (fdfdx / (2 * dx)) * RData^.cell[n].fieldValue[uField];
			
			fdfdy := RData^.cell[id_yp].fieldValue[uField] - RData^.cell[id_ym].fieldValue[uField];
			fdfdy := (fdfdy / (2 * dy)) * v_here;
			
			Sum := (nu * ( d2fdx2 + d2fdy2 )) - (fdfdx + fdfdy);
			
			us[n] := RData^.cell[n].fieldValue[uField] + (deltaT * Sum);

//Uy discretisation
			//Compute components (d2u/dx2, d2u/dy2, udu/dx, vdu/dy)
			d2fdx2 := RData^.cell[id_xm].fieldValue[vField] - (2 * RData^.cell[n].fieldValue[vField]) + RData^.cell[id_xp].fieldValue[vField];
			d2fdx2 /= (dx * dx);
			
			d2fdy2 := RData^.cell[id_ym].fieldValue[vField] - (2 * RData^.cell[n].fieldValue[vField]) + RData^.cell[id_yp].fieldValue[vField];
			d2fdy2 /= (dy * dy);
			
			fdfdx := RData^.cell[id_xp].fieldValue[vField] - RData^.cell[id_xm].fieldValue[vField];
			fdfdx := (fdfdx / (2 * dx)) * RData^.cell[n].fieldValue[vField];
			
			fdfdy := RData^.cell[id_yp].fieldValue[vField] - RData^.cell[id_ym].fieldValue[vField];
			fdfdy := (fdfdy / (2 * dy)) * u_here;
			
			Sum := (nu * ( d2fdx2 + d2fdy2 )) - (fdfdx + fdfdy);
			
			vs[n] := RData^.cell[n].fieldValue[vField] + (deltaT * Sum);
			
//Solving the poisson equation
EntryPoint_Laplace:
			//Check for any edges and use copy results
			//delu := ((us[id_xp] - us[n]) / dx) + ((vs[id_yp] - vs[n]) / dy);
			delu := -(((RData^.cell[id_xp].fieldValue[uField] - RData^.cell[n].fieldValue[uField]) / dx) + 
						((RData^.cell[id_yp].fieldValue[vField] - RData^.cell[n].fieldValue[vField]) / dy));
			
			rh[n] := (rho / deltaT) * delu;
		end;
	
	//The RH vector for computing the new P field is now populated, compute the matrix-vector kernel for p_n+1
	for n := 0 to RData^.cells - 1 do
		begin
			PopulateNeighDeltas();
			
			WData^.cell[n].fieldValue[pField] := 0;
			for i := 0 to RData^.cells - 1 do
				WData^.cell[n].fieldValue[pField] += (RData^.InvertedConnectivityMatrix[n][i] * rh[i]);
			
			WData^.cell[n].fieldValue[pField] := WData^.cell[n].fieldValue[pField];
		end;
	
	for n := 0 to RData^.cells - 1 do
		begin
EntryPoint_Corrector:
			PopulateNeighDeltas();
//Corrector
			dfdx := 0.1 * (WData^.cell[id_ym].fieldValue[pField] - WData^.cell[n].fieldValue[pField]) / dx;
			dfdy := 0.1 * (WData^.cell[id_xm].fieldValue[pField] - WData^.cell[n].fieldValue[pField]) / dy;
			
			WData^.cell[n].fieldValue[uField] := us[n] + (deltaT / rho) * dfdx;
			WData^.cell[n].fieldValue[vField] := vs[n] + (deltaT / rho) * dfdy;
			
			//WData^.cell[n].fieldValue[pField] += RData^.cell[n].fieldValue[pField];
			
EntryPoint_FinaliseCell:
		end;
end;

procedure ExecSimulation_Proof(Dom: pp3Domain);
var
	SwapBuffer: p3Domain;
	ReadPtr, WritePtr: pp3Domain;
	iter: LongInt;

	procedure SwapPTR();
	var
		tempPTR: pp3Domain;
	
	begin
		tempPTR := ReadPtr;
		ReadPtr := WritePtr;
		WritePtr := tempPTR;
	end;

begin
	Dom^.TNow := Dom^.TStart;
	
	//Initialise Swapbuffer
	CopyDomain(Dom, @SwapBuffer);
	
	ReadPtr := Dom;
	WritePtr := @Swapbuffer;
	
	DumpFieldsToFileVTK(WritePTR, 'p', 'out/result.vtk.' + IntToStr(0));
	
	iter := 1;
	repeat
		writeln('Kernel exec for t=',ReadPtr^.TNow);
		
		KernelExec(ReadPtr, WritePtr);
		SetBCCells(WritePTR);
		ApplyLimiters(WritePTR);
		ApplySmoothing(WritePTR);
		
		if iter mod Dom^.logInterval = 0 then
			DumpFieldsToFileVTK(WritePTR, 'p', 'out/result.vtk.' + IntToStr(iter));
		
		SwapPTR();
		ReadPtr^.TNow += Dom^.TStep;
		
		iter += 1;
		until Dom^.TNow > Dom^.TEnd;
	
	//Write back data into domain if last iteration wrote to local buffer
	if WritePtr <> Dom then
		CopyDomain(WritePtr, Dom);
end;

begin
end.
