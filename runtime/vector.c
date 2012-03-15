#include <math.h>
#include "vector.h"

static const snum spi = 3.14159265358979323846;
static const svec si = {0.0, 1.0};

svec svec_add(svec a, svec b)
{
	svec c;
	c.x = a.x + b.x;
	c.y = a.y + b.y;
	return c;
}

svec svec_sub(svec a, svec b)
{
	svec c;
	c.x = a.x - b.x;
	c.y = a.y - b.y;
	return c;
}

svec svec_mul(svec a, snum k)
{
	svec c;
	c.x = a.x * k;
	c.y = a.y * k;
	return c;
}

svec svec_div(svec a, snum k)
{
	svec c;
	c.x = a.x / k;
	c.y = a.y / k;
	return c;
}

svec svec_neg(svec a)
{
	return svec_mul(a,-1.0);
}

snum svec_dot(svec a, svec b)
{
	return a.x*b.x + a.y*b.y;
}

snum svec_cross(svec a, svec b)
{
	return a.x*b.y - a.y*b.x;
}

svec svec_cmul(svec a, svec b)
{
	svec c;
	c.x = a.x*b.x - a.y*b.y;
	c.y = a.x*b.y + a.y*b.x;
	return c;
}

snum svec_norm(svec a)
{
	return sqrt(a.x*a.x + a.y*a.y);
}

snum svec_sqnorm(svec a)
{
	return a.x*a.x + a.y*a.y;
}

snum svec_dist(svec a, svec b)
{
	return svec_norm(svec_sub(a,b));
}

snum svec_sqdist(svec a, svec b)
{
	return svec_sqnorm(svec_sub(a,b));
}

svec svec_yx(svec a)
{
	svec b;
	b.x = a.y;
	b.y = a.x;
	return b;
}

svec svec_ortho(svec a)
{
	svec b;
	b.x = -a.y;
	b.y = a.x;
	return b;
}
svec svec_normalize(svec a)
{
    return svec_div(a,svec_norm(a));
}

snum svec_angle(svec a, svec b)
{
	snum angle_a = atan2(a.y,a.x);
	snum angle_b = atan2(b.y,b.x);
	snum diff = angle_b - angle_a;
	
	if(diff <= -spi)
		diff += 2*spi;
	else if(diff > spi)
		diff -= 2*spi;
	
	return diff;
}

snum svec_dir(svec a)
{
	return atan2(a.y,a.x);
}

svec svec_polar(svec a)
{
	snum dir = atan2(a.y,a.x);
	snum len;
	svec res;
	
	if(a.x == 0.0)
		len = fabs(a.y);
	else
		len = a.x/cos(dir);
	
	res.x = len;
	res.y = dir;
	return res;
}

svec svec_rect(svec a)
{
	snum len = a.x;
	snum dir = a.y;
	svec res;
	res.x = len*cos(dir);
	res.y = len*sin(dir);
	return res;
}

svec svec_rotate(svec a, snum angle, svec center)
{
	svec rot;
	rot.x = cos(angle);
	rot.y = sin(angle);
	
	a = svec_sub(a,center);
	a = svec_cmul(a,rot);
	a = svec_add(a,center);
	return a;
}
