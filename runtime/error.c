#include <stdlib.h>
#include <stdio.h>

#include "error.h"

void sool_error(const char *message)
{
	printf("sool runtime error: %s\n", message);
	exit(EXIT_FAILURE);
}
