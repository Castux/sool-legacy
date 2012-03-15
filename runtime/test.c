#include <stdio.h>
#include <stdlib.h>
#include <string.h>
#include <gc.h>

#include "text.h"

int main()
{
    stext *t;

    t = stext_from_utf8("Östergård");
    
    (*(schar *) &t->data[3]) = 0x1111111;
    
    printf("Tumdum %ld, %s\n", t->len, stext_to_utf8(t));
    
    return 0;
}
