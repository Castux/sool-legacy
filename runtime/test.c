#include <stdio.h>
#include <stdlib.h>
#include "array.h"
#include "vector.h"

int main(int argc, char **argv)
{
	sool_vec v = {1.0,argc};
	sool_vec x = sool_vec_normalize(v);
	
	printf("%f,%f\n", x.x, x.y);
	
	return 0;
}
