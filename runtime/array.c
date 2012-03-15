#include <stdlib.h>
#include <string.h>

#include "array.h"
#include "error.h"

sarray *sarray_new(void)
{
	sarray *a = malloc(sizeof(sarray));
	if( a == NULL )
		serror("could not allocate array");
	
	a->allocated_count = 0;
	a->logical_count = 0;
	
	a->data = NULL;
	
	sarray_reserve(a,8);
	
	return a;
}

void sarray_reserve(sarray *a, uint32 count)
{
	uint32 i;
	
	/* Only use this function to grow the array */
	if( count <= a->allocated_count )
		return;
	
	/* Allocate count + 1 cells, since the 0 cell is not used */
	a->data = realloc(a->data, (count+1)*sizeof(a->data));
	if( a->data == NULL )
		serror("could not allocate memory for array");
		
	/* Fill the new cells with nil */
	for( i = a->allocated_count + 1 ; i <= count ; i++ )
		a->data[i] = nil;
	
	a->allocated_count = count;
}

type sarray_get(sarray *a, uint32 index)
{
	if( index == 0 || index > a->logical_count )
		return nil;
	
	return a->data[index];
}

uint32 sarray_size(sarray *a)
{
	return a->logical_count;
}

void sarray_set(sarray *a, uint32 index, type elem)
{
	/* Bound checking */
	if( index == 0 )
		serror("setting array at 0");
	
	if( index > a->logical_count )
	{
		/* When appending, double size */
		if( index == a->allocated_count + 1 )
			sarray_reserve(a, a->allocated_count * 2);
		/* When setting further away, adjust size */
		else if( index > a->allocated_count + 1 )
			sarray_reserve(a, index);
		
		a->logical_count = index;
	}
	
	/* Take place */
	a->data[index] = elem;
}

void sarray_append(sarray *a, type elem)
{
	/* Double reserved memory if needed */
	if( a->logical_count == a->allocated_count )
		sarray_reserve(a,a->allocated_count*2);
	
	a->logical_count++;
	a->data[a->logical_count] = elem;
}

void sarray_insert(sarray *a, uint32 index, type elem)
{
	uint32 i;
	
	if( index > a->logical_count )
	{
		sarray_set(a,index,elem);
		return;
	}
	
	if( a->logical_count == a->allocated_count )
		sarray_reserve(a,a->allocated_count*2);
	
	for( i = a->logical_count ; i >= index ; i-- )
		a->data[i+1] = a->data[i];
	
	a->data[index] = elem;
	a->logical_count++;
}

void sarray_remove(sarray *a, uint32 index)
{
	uint32 i;
	
	if( index > a->logical_count )
		return;
	
	for( i = index; i <= a->logical_count-1 ; i++ )
		a->data[i] = a->data[i+1];
	
	a->data[a->logical_count] = nil;
	a->logical_count--;
}

