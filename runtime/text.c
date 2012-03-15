#include <string.h>
#include <stdio.h>

#include "text.h"
#include "memory.h"

stext *stext_from_latin1(const char *str)
{
	stext *t = smalloc(sizeof(stext));
	
	sblob len = strlen(str);
	schar *data = smalloc_no_pointers(len * sizeof(schar));
	
	// Latin1 coincides with codepoints, just copy
	for(sblob i = 0 ; i < len ; i++)
		data[i] = str[i];
	
	t->data = data;
	t->len = len;
	
	return t;
}

char *stext_to_latin1(stext *text)
{
	char *str = smalloc(text->len + 1);
	
	for(sblob i = 0 ; i < text->len ; i++)
	{
		if(text->data[i] <= 255)
			str[i] = text->data[i];
		else
			str[i] = '?';
	}
	
	str[text->len] = 0;
	
	return str;
}

sblob schar_from_utf8(schar *c, const char *bytes)
{
	if((bytes[0] & 0x80) == 0)
	{
		*c = bytes[0];
		return 1;
	}
	else if((bytes[0] & 0xe0) == 0xc0)
	{
		if((bytes[1] & 0xc0) != 0x80)
			return 0;
		
		schar res = ((bytes[0] & 0x1f) << 6) | (bytes[1] & 0x3f);
		
		if(res >= 0x80)
		{
			*c = res;
			return 2;
		}
		
		return 0;
	}
	else if((bytes[0] & 0xf0) == 0xe0)
	{
		if((bytes[1] & 0xc0) != 0x80)
			return 0;
		if((bytes[2] & 0xc0) != 0x80)
			return 0;
		
		schar res = ((bytes[0] & 0x0f) << 12) | ((bytes[1] & 0x3f) << 6) | (bytes[0] & 0x3f);
		
		if(res >= 0x800 && (res < 0xd800 || res > 0xdfff))
		{
			*c = res;
			return 3;
		}
		
		return 0;
	}
	else if((bytes[0] & 0xf8) == 0xf0)
	{
		if((bytes[1] & 0xc0) != 0x80)
			return 0;
		if((bytes[2] & 0xc0) != 0x80)
			return 0;
		if((bytes[3] & 0xc0) != 0x80)
			return 0;
		
		schar res = ((bytes[0] & 0x07) << 18) | ((bytes[1] & 0x3f) << 12) | ((bytes[2] & 0x3f) << 6) | (bytes[3] & 0x3f);
		
		if(res >= 0x10000 && res <= 0x10ffff)
		{
			*c = res;
			return 4;
		}
		
		return 0;
	}
	
	return 0;
}

stext *stext_from_utf8(const char *str)
{
	sblob len = strlen(str);
	schar *buff = smalloc_no_pointers(len * sizeof(schar));
	
	const char *currbyte = str;
	sblob index = 0;
	
	while(currbyte < str + len)
	{
		schar c;
		sblob size = schar_from_utf8(&c, currbyte);
		if(size == 0)
		{
			currbyte++;		// Try to recover
		}
		else
		{
			currbyte += size;
			buff[index] = c;
			index++;
		}
	}
	
	schar *final = smalloc_no_pointers(index * sizeof(schar));
	memcpy(final, buff, index * sizeof(schar));
	
	stext *t = smalloc(sizeof(stext));
	t->data = final;
	t->len = index;
	
	return t;
}

sblob schar_to_utf8(schar c, char *bytes)
{
	// Surrogates
	if(0xd800 <= c && c <= 0xdfff)
		return 0;

	// Non-characters:
	if(0xfdd0 <= c && c <= 0xfdef)
		return 0;
	
	if((c & 0xffff) == 0xfffe || (c & 0xffff) == 0xffff)
		return 0;
	
	// Valid codepoints
	if(c <= 0x7f)
	{
		bytes[0] = c;
		return 1;
	}
	else if(c <= 0x7ff)
	{
		bytes[0] = 0xc0 | (c >> 6);
		bytes[1] = 0x80 | (c & 0x3f);
		return 2;
	}
	else if(c <= 0xffff)
	{
		
		bytes[0] = 0xe0 | (c >> 12);
		bytes[1] = 0x80 | ((c >> 6) & 0x3f);
		bytes[2] = 0x80 | (c & 0x3f);
		return 3;
	}
	else if(c <= 0x10ffff)
	{
		bytes[0] = 0xf0 | (c >> 18);
		bytes[1] = 0x80 | ((c >> 12) & 0x3f);
		bytes[2] = 0x80 | ((c >> 6) & 0x3f);
		bytes[3] = 0x80 | (c & 0x3f);
		return 4;
	}
	
	return 0;
}

char *stext_to_utf8(stext *t)
{
	char *buff = smalloc(t->len * 4);
	char *curr = buff;
	
	for(sblob i = 0 ; i < t->len ; i++)
	{
		int len;
		len = schar_to_utf8(t->data[i], curr);
		if(len == 0)
			len = schar_to_utf8(0xfffd, curr);		// Insert replacement character '�' in case of error
		
		curr += len;
	}
	
	sblob len = curr - buff + 1;
	char *final = smalloc(len);
	memcpy(final, buff, len);
	final[len] = 0;
	
	return final;
}

sblob stext_hash(stext *text)
{
	// Hash function taken from Lua
	sblob h = text->len;
	sblob step = (text->len >> 5) + 1;
	
	for(sblob i = text->len ; i >= step ; i -= step)
		h = h ^ ((h<<5) + (h>>2) + (sblob) text->data[i-1]);
	
	return h;
}

