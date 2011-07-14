#include <stdlib.h>
#include <string.h>

#include "array.h"
#include "error.h"

sool_array *sool_array_new(void)
{
	sool_array *a = malloc(sizeof(sool_array));
	if( a == NULL )
		sool_error("could not allocate array");
	
	a->allocated_count = 0;
	a->logical_count = 0;
	
	a->data = NULL;
	
	sool_array_reserve(a,8);
	
	return a;
}

void sool_array_reserve(sool_array *a, uint32 count)
{
	uint32 i;
	
	/* Only use this function to grow the array */
	if( count <= a->allocated_count )
		return;
	
	/* Allocate count + 1 cells, since the 0 cell is not used */
	a->data = realloc(a->data, (count+1)*sizeof(*a->data));
	if( a->data == NULL )
		sool_error("could not allocate memory for array");
		
	/* Fill the new cells with nil */
	for( i = a->allocated_count + 1 ; i <= count ; i++ )
		a->data[i] = nil;
	
	a->allocated_count = count;
}

type sool_array_get(sool_array *a, uint32 index)
{
	if( index == 0 || index > a->logical_count )
		return nil;
	
	return a->data[index];
}

uint32 sool_array_size(sool_array *a)
{
	return a->logical_count;
}

void sool_array_set(sool_array *a, uint32 index, type elem)
{
	/* Bound checking */
	if( index == 0 )
		sool_error("setting array at 0");
	
	if( index > a->logical_count )
	{
		/* When appending, double size */
		if( index == a->allocated_count + 1 )
			sool_array_reserve(a, a->allocated_count * 2);
		/* When setting further away, adjust size */
		else if( index > a->allocated_count + 1 )
			sool_array_reserve(a, index);
		
		a->logical_count = index;
	}
	
	/* Take place */
	a->data[index] = elem;
}

void sool_array_append(sool_array *a, type elem)
{
	/* Double reserved memory if needed */
	if( a->logical_count == a->allocated_count )
		sool_array_reserve(a,a->allocated_count*2);
	
	a->logical_count++;
	a->data[a->logical_count] = elem;
}

void sool_array_insert(sool_array *a, uint32 index, type elem)
{
	uint32 i;
	
	if( index > a->logical_count )
	{
		sool_array_set(a,index,elem);
		return;
	}
	
	if( a->logical_count == a->allocated_count )
		sool_array_reserve(a,a->allocated_count*2);
	
	for( i = a->logical_count ; i >= index ; i-- )
		a->data[i+1] = a->data[i];
	
	a->data[index] = elem;
	a->logical_count++;
}

void sool_array_remove(sool_array *a, uint32 index)
{
	uint32 i;
	
	if( index > a->logical_count )
		return;
	
	for( i = index; i <= a->logical_count-1 ; i++ )
		a->data[i] = a->data[i+1];
	
	a->data[a->logical_count] = nil;
	a->logical_count--;
}

