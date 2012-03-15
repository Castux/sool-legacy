#ifndef MEMORY_H
#define MEMORY_H

#include "types.h"

void *smalloc(sblob size);
void *smalloc_no_pointers(sblob size);
void sset_weak_pointer(void **);


#endif /* MEMORY_H */
