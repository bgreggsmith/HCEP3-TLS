unit p3_simExec;

{$Mode ObjFpc}

interface

uses
	p3_domain;

procedure ExecSimulation_Proof(Dom: pp3Domain);

implementation

uses
	sysutils,
	
	p3_fieldops;

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
	vLimit := 500;
	pLimit := 0.5 * rho * vLimit;
	
	for n := 0 to Data^.cells - 1 do
		begin
			if Data^.cell[n].fieldValue[pField] > pLimit then
				Data^.cell[n].fieldValue[pField] := pLimit;
			
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
	us, vs, delp, delu, rh: array of Double;
	d2fdx2, d2fdy2, fdfdx, fdfdy, dx1, dx2, dy1, dy2, dx, dy, deltaT, nu, rho, dfdx, dfdy: Double;
	flag_Edge: Boolean;

	function Max(a, b: Double): Double;
	begin
		if a > b then
			Max := a
		else
			Max := b;
	end;

label EntryPoint_FinaliseCell, EntryPoint_Laplace, EntryPoint_Corrector;

begin
	deltaT := RData^.TStep;
	
	writeln('solver deltaT=',deltaT);
	
	nu := GetConst(RData, 'nu');
	rho := GetConst(RData, 'rho');
	
	pField := GetFieldNFromName('p');
	uField := GetFieldNFromName('ux');
	vField := GetFieldNFromName('uy');
	
	SetLength(delp, RData^.cells);
	SetLength(delu, RData^.cells);
	SetLength(us, RData^.cells);
	SetLength(vs, RData^.cells);
	SetLength(rh, RData^.cells);
	
	for n := 0 to RData^.cells - 1 do
		begin
			id[0] := RData^.cell[n].id_up;
			id[1] := RData^.cell[n].id_down;
			id[2] := RData^.cell[n].id_left;
			id[3] := RData^.cell[n].id_right;
			
			flag_Edge := False;
			for i := 0 to 3 do
				if id[i] < 0 then
					flag_Edge := True;
			
			//If there are tags do not try to perform the normal inner-cell kernel
			//if RData^.cell[n].tags > 0 then
			//	goto EntryPoint_FinaliseCell;
			
//Common values for all discretisations
			v_here := RData^.cell[n].fieldValue[vField];
			u_here := RData^.cell[n].fieldValue[uField];
			
			writeln('Cell ',n,' u=',u_here,' v=',v_here);
			
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
					nx += 1;
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
			
//Ux discretisation
			//Compute components (d2u/dx2, d2u/dy2, udu/dx, vdu/dy)
			d2fdx2 := 0;
			d2fdy2 := 0;
			fdfdx := 0;
			fdfdy := 0;
			
			if (id[2] >= 0) and (id[3] >= 0) then
				begin
					d2fdx2 := RData^.cell[id[2]].fieldValue[uField] - (2 * RData^.cell[n].fieldValue[uField]) + RData^.cell[id[3]].fieldValue[uField];
					d2fdx2 := d2fdx2 / (dx * dx);
					
					fdfdx := u_here * ( RData^.cell[id[3]].fieldValue[uField] - RData^.cell[id[2]].fieldValue[uField] );
					fdfdx := fdfdx / (2  * dx);
				end;
			
			if (id[0] >= 0) and (id[1] >= 0) then
				begin
					d2fdy2 := RData^.cell[id[1]].fieldValue[uField] - (2 * RData^.cell[n].fieldValue[uField]) + RData^.cell[id[0]].fieldValue[uField];
					d2fdy2 := d2fdy2 / (dy * dy);
					
					fdfdy := v_here * ( RData^.cell[id[0]].fieldValue[uField] - RData^.cell[id[1]].fieldValue[uField] );
					fdfdy := fdfdy / (2  * dy);
				end;
			
			Sum := v_here * ( d2fdx2 + d2fdy2 );
			Sum -= (fdfdx + fdfdy);
			
			us[n] := u_here + (deltaT * Sum);

//Uy discretisation
			//Compute components (d2u/dx2, d2u/dy2, udu/dx, vdu/dy)
			d2fdx2 := 0;
			d2fdy2 := 0;
			fdfdx := 0;
			fdfdy := 0;
			
			if (id[2] >= 0) and (id[3] >= 0) then
				begin
					d2fdx2 := RData^.cell[id[2]].fieldValue[vField] - (2 * RData^.cell[n].fieldValue[vField]) + RData^.cell[id[3]].fieldValue[vField];
					d2fdx2 := d2fdx2 / (dx * dx);
					
					fdfdx := u_here * ( RData^.cell[id[3]].fieldValue[vField] - RData^.cell[id[2]].fieldValue[vField] );
					fdfdx := fdfdx / (2  * dx);
				end;
			
			if (id[1] >= 0) and (id[0] >= 0) then
				begin
					d2fdy2 := RData^.cell[id[1]].fieldValue[vField] - (2 * RData^.cell[n].fieldValue[vField]) + RData^.cell[id[0]].fieldValue[vField];
					d2fdy2 := d2fdy2 / (dy * dy);
					
					fdfdy := v_here * ( RData^.cell[id[0]].fieldValue[vField] - RData^.cell[id[1]].fieldValue[vField] );
					fdfdy := fdfdy / (2  * dy);
				end;
			
			Sum := v_here * ( d2fdx2 + d2fdy2 );
			Sum -= (fdfdx + fdfdy);
			
			vs[n] := v_here + (deltaT * Sum);

//Solving the poisson equation
EntryPoint_Laplace:
			//Check for any edges and use copy results
			delp[n] := 0;
			delu[n] := 0;
			
			if (id[2] >= 0) and (id[3] >= 0) then
				delu[n] := (us[id[3]] - us[id[2]]) / dx;
			
			Sum := 0;
			
			if (id[0] >= 0) and (id[1] >= 0) then
				delu[n] := ((vs[id[0]] - vs[id[1]]) / dy) + delu[n];
			
			nx := 0;
			ny := 0;
			
			if id[0] >= 0 then
				begin
					delp[n] += RData^.cell[id[0]].fieldValue[pField] / dy;
					ny += 1;
				end;
			
			if id[1] >= 0 then
				begin
					delp[n] += RData^.cell[id[1]].fieldValue[pField] / dy;
					ny += 1;
				end;
			
			if id[2] >= 0 then
				begin
					delp[n] -= RData^.cell[id[2]].fieldValue[pField] / dx;
					nx += 1;
				end;
			
			if id[3] >= 0 then
				begin
					delp[n] -= RData^.cell[id[3]].fieldValue[pField] / dx;
					nx += 1;
				end;
			
			delp[n] += ((nx / dx) + (ny / dy)) * RData^.cell[n].fieldValue[pField];
			
			rh[n] := (-rho / deltaT) * delu[n];
			
			if rh[n] <> 0 then
				WData^.cell[n].fieldValue[pField] := delp[n] / rh[n]
			else
				WData^.cell[n].fieldValue[pField] := 1E99;

EntryPoint_Corrector:
//Corrector
			dfdx := 0;
			dfdy := 0;
			if (id[2] >= 0) and (id[3] >= 0) then
				dfdx := (RData^.cell[id[3]].fieldValue[pField] - RData^.cell[id[2]].fieldValue[pField]) / (2 * dx);
			
			if (id[0] >= 0) and (id[1] >= 0) then
				dfdy := (RData^.cell[id[1]].fieldValue[pField] - RData^.cell[id[0]].fieldValue[pField]) / (2 * dy);
			
			WData^.cell[n].fieldValue[uField] := us[n] - deltaT / rho * dfdx;
			WData^.cell[n].fieldValue[vField] := vs[n] - deltaT / rho * dfdy;

EntryPoint_FinaliseCell:
			//For now we do a copy forward for tagged cells, in future this needs to resolve the correct BC and do the appropriate things
			//if RData^.cell[n].tags > 0 then
			//	WData^.cell[n].fieldValue[pField] := RData^.cell[n].fieldValue[pField];
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
	
	DumpFieldsToFileVTK(WritePTR, 'p', 'out/result.vtk.' + IntToStr(1));
	
	iter := 0;
	repeat
		writeln('Kernel exec for t=',ReadPtr^.TNow);
		
		KernelExec(ReadPtr, WritePtr);
		SetBCCells(WritePTR);
		ApplyLimiters(WritePTR);
		
		if iter mod Dom^.logInterval = 0 then
			DumpFieldsToFileVTK(WritePTR, 'p', 'out/result.vtk.' + IntToStr(iter+1));
		
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
