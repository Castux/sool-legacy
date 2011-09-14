#include <math.h>
#include "vector.h"

const sool_num sool_pi = 3.14159265358979323846;
const sool_vec sool_i = {0.0, 1.0};

sool_vec sool_vec_add(sool_vec a, sool_vec b)
{
	sool_vec c;
	c.x = a.x + b.x;
	c.y = a.y + b.y;
	return c;
}

sool_vec sool_vec_sub(sool_vec a, sool_vec b)
{
	sool_vec c;
	c.x = a.x - b.x;
	c.y = a.y - b.y;
	return c;
}

sool_vec sool_vec_mul(sool_vec a, sool_num k)
{
	sool_vec c;
	c.x = a.x * k;
	c.y = a.y * k;
	return c;
}

sool_vec sool_vec_div(sool_vec a, sool_num k)
{
	sool_vec c;
	c.x = a.x / k;
	c.y = a.y / k;
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

sool_vec sool_vec_cmul(sool_vec a, sool_vec b)
{
	sool_vec c;
	c.x = a.x*b.x - a.y*b.y;
	c.y = a.x*b.y + a.y*b.x;
	return c;
}

sool_num sool_vec_norm(sool_vec a)
{
	return sqrt(a.x*a.x + a.y*a.y);
}

sool_num sool_vec_sqnorm(sool_vec a)
{
	return a.x*a.x + a.y*a.y;
}

sool_vec sool_vec_yx(sool_vec a)
{
	sool_vec b;
	b.x = a.y;
	b.y = a.x;
	return b;
}

sool_vec sool_vec_ortho(sool_vec a)
{
	sool_vec b;
	b.x = -a.y;
	b.y = a.x;
	return b;
}
sool_vec sool_vec_normalize(sool_vec a)
{
    return sool_vec_div(a,sool_vec_norm(a));
}

sool_num sool_vec_angle(sool_vec a, sool_vec b)
{
	sool_num angle_a = atan2(a.y,a.x);
	sool_num angle_b = atan2(b.y,b.x);
	sool_num diff = angle_b - angle_a;
	
	if(diff <= -sool_pi)
		diff += 2*sool_pi;
	else if(diff > sool_pi)
		diff -= 2*sool_pi;
	
	return diff;
}

sool_num sool_vec_dir(sool_vec a)
{
	return atan2(a.y,a.x);
}

sool_vec sool_vec_polar(sool_vec a)
{
	sool_num dir = atan2(a.y,a.x);
	sool_num len;
	sool_vec res;
	
	if(a.x == 0.0)
		len = fabs(a.y);
	else
		len = a.x/cos(dir);
	
	res.x = len;
	res.y = dir;
	return res;
}

sool_vec sool_vec_rect(sool_vec a)
{
	sool_num len = a.x;
	sool_num dir = a.y;
	sool_vec res;
	res.x = len*cos(dir);
	res.y = len*sin(dir);
	return res;
}

sool_vec sool_vec_rotate(sool_vec a, sool_num angle, sool_vec center)
{
	sool_vec rot;
	rot.x = cos(angle);
	rot.y = sin(angle);
	
	a = sool_vec_sub(a,center);
	a = sool_vec_cmul(a,rot);
	a = sool_vec_add(a,center);
	return a;
}
