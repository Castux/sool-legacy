#include <stdio.h>
#include <stdlib.h>
#include "array.h"
#include "vector.h"

int main(int argc, char **argv)
{
	sool_vec a = {0,2};
	sool_vec b = {0,2};
	sool_vec w = sool_vec_cmul(a,b);
	
	printf("%f,%f\n", w.x, w.y);
	
	return 0;
}
