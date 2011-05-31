#ifndef ARRAY_H
#define ARRAY_H

#include "types.h"

typedef struct
{
	uint32 allocated_count;
	uint32 logical_count;
	
	sool_destructor destructor;
	
	void **data;
} sool_array;

extern sool_array *sool_array_new(sool_destructor destructor);
extern void sool_array_reserve(sool_array *a, uint32 count);

extern void *sool_array_get(sool_array *a, uint32 index);
extern uint32 sool_array_size(sool_array *a);

extern void sool_array_set(sool_array *a, uint32 index, void *elem);
extern void sool_array_append(sool_array *a, void *elem);
extern void sool_array_insert(sool_array *a, uint32 index, void *elem);
extern void sool_array_remove(sool_array *a, uint32 index);

#endif /* ARRAY_H */
