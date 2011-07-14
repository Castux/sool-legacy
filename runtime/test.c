#include <stdio.h>
#include "array.h"

int main(void)
{
	uint32 i;
	
	sool_array *a = sool_array_new();
	
	for( i = 1 ; i <= 10 ; i++ )
		sool_array_append(a, i);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %d\n", i, sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);
	
	sool_array_insert(a,3,100);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %d\n", i, sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);

	sool_array_remove(a,5);
	sool_array_set(a,0,600);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %d\n", i, sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);
	
	return 0;
}
