#include "vector.h"

sool_vec sool_vec_add(sool_vec a, sool_vec b)
{
	sool_vec c = {a.x + b.x, a.y + b.y};
	return c;
}

sool_vec sool_vec_sub(sool_vec a, sool_vec b)
{
	sool_vec c = {a.x - b.x, a.y - b.y};
	return c;
}

sool_vec sool_vec_mul(sool_vec a, sool_num k)
{
	sool_vec c = {a.x * k, a.y * k};
	return c;
}

sool_vec sool_vec_div(sool_vec a, sool_num k)
{
	sool_vec c = {a.x / k, a.y / k};
	return c;
}

sool_vec sool_vec_neg(sool_vec a)
{
	return sool_vec_mul(a,-1.0);
}

sool_num sool_vec_dot(sool_vec a, sool_vec b)
{
	return a.x*b.x + a.y*b.y;
}

sool_num sool_vec_cross(sool_vec a, sool_vec b)
{
	return a.x*b.y - a.y*b.x;
}

sool_num sool_vec_len(sool_vec a)
{
	return sqrt(a.x*a.x + a.y*a.y);
}

sool_num sool_vec_sqlen(sool_vec a)
{
	return a.x*a.x + a.y*a.y;
}

sool_vec sool_vec_yx(sool_vec a)
{
	sool_vec b = {a.y, a.x};
	return b;
}

sool_vec sool_vec_normalize(sool_vec a)
{
    return sool_vec_div(a,sool_vec_len(a));
}
