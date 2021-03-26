Point(1) = {0, 0, 0};
Point(2) = {0, 1, 0};
Point(3) = {1, 1, 0};
Point(4) = {1, 0, 0};

Line(1) = {1, 2};
Line(2) = {2, 3};
Line(3) = {3, 4};
Line(4) = {4, 1};

Transfinite Line{1, 2, 3, 4} = 25 Using Progression 1;
Line Loop(11) = {4, 1, 2, 3};

Plane Surface(1) = {11};
Transfinite Surface{1} = {1, 2, 3, 4};
Recombine Surface(1);

Physical Line("lid") = {4};
Physical Line("wall") = {1, 2, 3};
