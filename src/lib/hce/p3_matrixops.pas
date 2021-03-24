unit p3_matrixops;

{$Mode ObjFpc}

interface

type
	Matrix = array of array of Double;
	pMatrix = ^Matrix;
	IntVec = array of Integer;
	pIntVec = ^IntVec;

procedure InvertMatrix(Src, Dst: pMatrix; n: LongWord);

implementation

type
	DblArray = array of Double;
	pDblArray = ^DblArray;

procedure LUPDecompose(A, Output: pMatrix; N: longword; tolerance: Double; P: pIntVec);
var
	i, j, k, imax: Integer;
	maxA, absA: Double;
	ptr: pDblArray;
	LocalA: array of pDblArray;

begin
	for i := 0 to N do
		P^[i] := i;
	
	//Load local pointer mapping array for rows
	SetLength(LocalA, N);
	for i := 0 to N-1 do
		LocalA[i] := @A^[i];
	
	for i := 0 to N-1 do
		begin
			maxA := 0.0;
			iMax := i;
			
			for k := i to N-1 do
				begin
					absA := Abs(LocalA[k]^[i]);
					if absA > maxA then
						begin
							maxA := absA;
							imax := k;
						end;
				end;
			
			if (maxA < tolerance) then
				begin
					writeln('Error: Decomp of degenerate matrix');
					Halt;
				end;
			
			if (imax <> i) then
				begin
					j := P^[i];
					P^[i] := P^[imax];
					P^[imax] := j;
					
					ptr := LocalA[i];
					LocalA[i] := LocalA[imax];
					LocalA[imax] := ptr;
					
					P^[n] += 1;
				end;
			
			for j := i + 1 to N-1 do
				begin
					LocalA[j]^[i] /= LocalA[i]^[i];
					
					for k := i + 1 to N-1 do
						LocalA[j]^[k] -= LocalA[j]^[i] * LocalA[i]^[k];
				end;
		end;
	
	for i := 0 to N-1 do
		for j := 0 to N-1 do
			Output^[i][j] := LocalA[i]^[j];
end;

procedure InvertMatrix(Src, Dst: pMatrix; n: LongWord);
var
	P: array of Integer;
	i, j, k: Integer;
	D: Matrix;

begin
	SetLength(P, n + 1);
	SetLength(D, n, n);
	LUPDecompose(Src, @D, n, 1E-10, @P);
	
	for j := 0 to n-1 do
		begin
			for i := 0 to n-1 do
				begin
					if P[i] = j then
						Dst^[i][j] := 1
					else
						Dst^[i][j] := 0;
					
					for k := 0 to i-1 do
						Dst^[i][j] -= D[i][k] * Dst^[k][j];
				end;
			
			for i := n-1 downto 0 do
				begin
					for k := i+1 to n-1 do
						Dst^[i][j] -= D[i][k] * Dst^[k][j];
					
					if D[i][i] = 0 then
						begin
							writeln('Error: 0 divide on diagonal!')
							Halt;
						end
					else
						Dst^[i][j] /= D[i][i];
				end;
		end;
end;

begin
end.
