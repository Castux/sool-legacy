#ifndef VECTOR_H
#define VECTOR_H

#include "types.h"

typedef struct { snum x,y; } svec;

svec svec_add(svec a, svec b);
svec svec_sub(svec a, svec b);
svec svec_mul(svec a, snum k);
svec svec_div(svec a, snum k);
svec svec_neg(svec a);

snum svec_dot(svec a, svec b);
snum svec_cross(svec a, svec b);	/* The z component of (ax,ay,0) x (bx,by,0) */
svec svec_cmul(svec a, svec b);		/* Complex multiplication */

snum svec_norm(svec a);
snum svec_sqnorm(svec a);
svec svec_normalize(svec a);
snum svec_dist(svec a, svec b);
snum svec_sqdist(svec a, svec b);

svec svec_yx(svec a);					/* Simple swap */
svec svec_ortho(svec a);				/* Returns (-y,x), that is the pi/2 rotation of (x,y) */

snum svec_dir(svec a);
snum svec_angle(svec a, svec b);
svec svec_polar(svec a);				/* Return (norm,direction) in a vector, faster than calling norm() and dir() */
svec svec_rect(svec a);					/* Takes (norm,direction) and put it back to rectangular coordinates */
svec svec_rotate(svec a, snum angle, svec center);

#endif /* VECTOR_H */
