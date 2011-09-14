#include <stdio.h>
#include <stdlib.h>
#include "array.h"
#include "vector.h"

int main(int argc, char **argv)
{
	sool_vec a = {argc,rand()};
	sool_vec w = sool_vec_ortho(a);
	
	printf("%f,%f, %f\n", w.x, w.y, sool_vec_dot(a,w));
	
	return 0;
}
