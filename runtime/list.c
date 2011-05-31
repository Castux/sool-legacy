#include <stdlib.h>

struct sool_list_node
{
	struct sool_list_node *next;
	struct sool_list_node *prev;
	char *data;
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

struct sool_list_node *sool_list_node_new(struct sool_list *l)
{
	return malloc(sizeof(struct sool_list_node) + l->data_size);
}

void *sool_list_push_right(struct sool_list *l)
{
	struct sool_list_node *n = sool_list_node_new(l);
	
	/* empty list */
	if(l->last == NULL)
	{
		n->next = NULL;
		n->prev = NULL;
		
		l->first = n;
		l->last = n;
	}
	
	/* not empty */
	else
	{
		n->next = NULL;
		n->prev = l->last;
		
		l->last->next = n;
		l->last = n;
	}
	
	l->length++;
	return n->data;
}

void *sool_list_push_left(struct sool_list *l)
{
	struct sool_list_node *n = sool_list_node_new(l);
	
	/* empty list */
	if(l->first == NULL)
	{
		n->next = NULL;
		n->prev = NULL;
		
		l->first = n;
		l->last = n;
	}
	
	/* not empty */
	else
	{
		n->prev = NULL;
		n->next = l->first;
		
		l->first->prev = n;
		l->first = n;
	}
	
	l->length++;
	return n->data;
}

void *sool_list_first(struct sool_list *l)
{
	return l->first->data;
}

void *sool_list_last(struct sool_list *l)
{
	return l->last->data;
}
