#include <stdio.h>
#include "array.h"

int main(void)
{
	uint32 i;
	
	sool_array *a = sool_array_new(NULL);

	for( i = 1 ; i <= 10 ; i++ )
		sool_array_append(a,(void*)(long int)i);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %ld\n", i, (long int) sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);
	
	sool_array_insert(a,3,(void*) 100);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %ld\n", i, (long int) sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);

	sool_array_remove(a,5);

	for( i = 1 ; i <= sool_array_size(a) ; i++ )
		printf("%d: %ld\n", i, (long int) sool_array_get(a,i));

	printf("reserved: %d, size: %d\n", a->allocated_count, a->logical_count);
	
	return 0;
}
