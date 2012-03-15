#include <gc/gc.h>
#include "memory.h"
#include "error.h"

void *smalloc(sblob size)
{
	return GC_malloc(size);
}

void *smalloc_no_pointers(sblob size)
{
	return GC_malloc_atomic(size);
}

void sset_weak_pointer(void **ptr)
{
	int res = GC_register_disappearing_link(ptr);
	if(res != 0)
		serror("could not set weak pointer");
}
