#ifndef ARRAY_H
#define ARRAY_H

#include "types.h"

typedef void* type;
#define nil (0)

typedef struct
{
	sblob allocated_count;
	sblob logical_count;
	
	type *data;
} sarray;

extern sarray *sarray_new(void);
extern void sarray_reserve(sarray *a, uint32 count);

extern type sarray_get(sarray *a, uint32 index);
extern uint32 sarray_size(sarray *a);

extern void sarray_set(sarray *a, uint32 index, type elem);
extern void sarray_append(sarray *a, type elem);
extern void sarray_insert(sarray *a, uint32 index, type elem);
extern void sarray_remove(sarray *a, uint32 index);

#endif /* ARRAY_H */
