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
sool_num sool_vec_cross(sool_vec a, sool_vec b);
sool_vec sool_vec_cmul(sool_vec a, sool_vec b);

sool_num sool_vec_norm(sool_vec a);
sool_num sool_vec_sqnorm(sool_vec a);
sool_vec sool_vec_normalize(sool_vec a);

sool_vec sool_vec_yx(sool_vec a);
sool_vec sool_vec_ortho(sool_vec a);

sool_num sool_vec_dir(sool_vec a);
sool_num sool_vec_angle(sool_vec a, sool_vec b);
sool_vec sool_vec_polar(sool_vec a);
sool_vec sool_vec_rect(sool_vec a);
sool_vec sool_vec_rotate(sool_vec a, sool_num angle, sool_vec center);

#endif /* VECTOR_H */
