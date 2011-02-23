#include <stdlib.h>

struct sool_list_node
{
    struct sool_list_node *next;
    struct sool_list_node *prev;
    char data[];
};

struct sool_list
{
    int data_size;
    
    struct sool_list_node *first;
    struct sool_list_node *last;
    
    int length;
};

struct sool_list *sool_list_new(int data_size)
{
    struct sool_list *l = malloc(sizeof(l));
    
    l->data_size = data_size;
    
    l->first = NULL;
    l->last = NULL;
    l->length = 0;
    
    return l;
}

void sool_list_append(struct sool_list *l, void *e)
{
    
}
