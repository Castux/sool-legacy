#ifndef VECTOR_H
#define VECTOR_H

#include "types.h"

typedef struct { sool_num x,y; } sool_vec;

extern const sool_num sool_pi;
extern const sool_vec sool_i;

sool_vec sool_vec_add(sool_vec a, sool_vec b);
sool_vec sool_vec_sub(sool_vec a, sool_vec b);
sool_vec sool_vec_mul(sool_vec a, sool_num k);
sool_vec sool_vec_div(sool_vec a, sool_num k);
sool_vec sool_vec_neg(sool_vec a);

sool_num sool_vec_dot(sool_vec a, sool_vec b);
sool_num sool_vec_cross(sool_vec a, sool_vec b);	/* The z component of (ax,ay,0) x (bx,by,0) */
sool_vec sool_vec_cmul(sool_vec a, sool_vec b);		/* Complex multiplication */

sool_num sool_vec_norm(sool_vec a);
sool_num sool_vec_sqnorm(sool_vec a);
sool_vec sool_vec_normalize(sool_vec a);
sool_num sool_vec_dist(sool_vec a, sool_vec b);
sool_num sool_vec_sqdist(sool_vec a, sool_vec b);

sool_vec sool_vec_yx(sool_vec a);					/* Simple swap */
sool_vec sool_vec_ortho(sool_vec a);				/* Returns (-y,x), that is the pi/2 rotation of (x,y) */

sool_num sool_vec_dir(sool_vec a);
sool_num sool_vec_angle(sool_vec a, sool_vec b);
sool_vec sool_vec_polar(sool_vec a);				/* Return (norm,direction) in a vector, faster than calling norm() and dir() */
sool_vec sool_vec_rect(sool_vec a);					/* Takes (norm,direction) and put it back to rectangular coordinates */
sool_vec sool_vec_rotate(sool_vec a, sool_num angle, sool_vec center);

#endif /* VECTOR_H */
