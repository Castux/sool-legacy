#ifndef VECTOR_H
#define VECTOR_H

#include <math.h>

#include "types.h"

typedef struct { sool_num x,y; } sool_vec;

sool_vec sool_vec_add(sool_vec a, sool_vec b);
sool_vec sool_vec_sub(sool_vec a, sool_vec b);
sool_vec sool_vec_mul(sool_vec a, sool_num k);
sool_vec sool_vec_div(sool_vec a, sool_num k);
sool_vec sool_vec_neg(sool_vec a);
sool_num sool_vec_dot(sool_vec a, sool_vec b);
sool_num sool_vec_cross(sool_vec a, sool_vec b);
sool_num sool_vec_len(sool_vec a);
sool_num sool_vec_sqlen(sool_vec a);
sool_vec sool_vec_yx(sool_vec a);
sool_vec sool_vec_normalize(sool_vec a);

#endif /* VECTOR_H */
