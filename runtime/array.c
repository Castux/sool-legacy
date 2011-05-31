#include <stdlib.h>
#include <string.h>

#include "array.h"
#include "error.h"

#define rawindex(a,i) a->data[i-1]

sool_array *sool_array_new(sool_destructor destructor)
{
	sool_array *a = malloc(sizeof(sool_array));
	if( a == NULL )
		sool_error("could not allocate array");
	
	a->allocated_count = 0;
	a->logical_count = 0;
	
	a->destructor = destructor;

	a->data = NULL;
	
	sool_array_reserve(a,8);
	
	return a;
}

void sool_array_reserve(sool_array *a, uint32 count)
{
	if( a->allocated_count >= count )
		return;
	
	a->data = realloc(a->data, count*sizeof(*a->data));
	if( a->data == NULL )
		sool_error("could not allocate memory for array");
	
	memset(a->data + a->allocated_count, 0, count - a->allocated_count);
	
	a->allocated_count = count;
}

void *sool_array_get(sool_array *a, uint32 index)
{
	if( index > a->logical_count )
		return NULL;
	
	return rawindex(a,index);
}

uint32 sool_array_size(sool_array *a)
{
	return a->logical_count;
}


void sool_array_set(sool_array *a, uint32 index, void *elem)
{
	void **cell;
	
	/* Bound checking/resizing */
	if( index > a->logical_count )
	{
		if( index > a->allocated_count )
			sool_array_reserve(a,index);
	
		a->logical_count = index;
	}

	/* Index is in 1..logical_count */
	
	cell = &rawindex(a,index);
	
	/* Release previous element if we own it */
	if( a->destructor != NULL )
		a->destructor(*cell);
	
	/* Take place */
	*cell = elem;
}

void sool_array_append(sool_array *a, void *elem)
{
	/* Double reserved memory if needed */
	if( a->logical_count == a->allocated_count )
		sool_array_reserve(a,a->allocated_count*2);
	
	a->data[a->logical_count] = elem;
	a->logical_count++;
}

void sool_array_insert(sool_array *a, uint32 index, void *elem)
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
		rawindex(a,i+1) = rawindex(a,i);
	
	a->data[index-1] = elem;
	a->logical_count++;
}

void sool_array_remove(sool_array *a, uint32 index)
{
	uint32 i;
	
	if( index > a->logical_count )
		return;
	
	if( a->destructor != NULL )
		a->destructor( a->data[index-1] );
	
	for( i = index; i <= a->logical_count-1 ; i++ )
		rawindex(a,i) = rawindex(a,i+1);
	
	rawindex(a,a->logical_count) = NULL;
	a->logical_count--;
}

