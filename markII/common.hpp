#include <cstdlib>
#include <iostream>
#include <vector>
#include <map>
#include <string>

#include <tr1/memory>

#include "error.hpp"

namespace sool
{
	using std::tr1::shared_ptr;
	using std::tr1::weak_ptr;
	using std::tr1::dynamic_pointer_cast;
	
	using std::vector;
	using std::map;
	using std::string;
	
	typedef unsigned int uint;
	typedef double num;
}

#define DEBUG(x) std::cout << x << std::endl;
