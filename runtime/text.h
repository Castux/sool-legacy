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

/* Build new stext from NULL terminated string encoded in latin1 */
stext *stext_from_latin1(const char *str);

/* Convert stext to new NULL terminated string encoded in latin1 */
char *stext_to_latin1(stext *text);

/* Build new stext from NULL terminated string encoded in UTF-8 */
stext *stext_from_utf8(const char *str);

/* Convert stext to new NULL terminated string encoded in UTF-8 */
char *stext_to_utf8(stext *t);

/* Hash stext */
sblob stext_hash(stext *text);


#endif /* TEXT_H */
