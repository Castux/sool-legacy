#ifndef TEXT_H
#define TEXT_H

#include "types.h"

typedef struct
{
	sblob len;
	const schar *data;
} stext;

struct stext_entry
{
	sblob hash;
	stext text;
	struct stext_entry *next;
};

typedef struct
{
	
	
	
} stext_table;

stext *stext_from_latin1(const char *str);
char *stext_to_latin1(stext *text);
stext *stext_from_utf8(const char *str);
sblob schar_to_utf8(schar c, char *bytes);
char *stext_to_utf8(stext *t);
sblob stext_hash(stext *text);


#endif /* TEXT_H */
