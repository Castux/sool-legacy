#ifndef IDENT_HPP
#define IDENT_HPP

#include "common.hpp"

namespace sool
{
	// Ident is used to represent all identifiers, with an optional
	// namespace path: locals, member names, methods names, class and
	// interface names, etc.
	
	class Ident
	{
		public:
		
		vector<string>	path;		// optional module path
		string			name;
		vector<Ident>	params;		// optional template parameters
		
		Ident(string name);
		Ident(vector<string> &path, string name);
		Ident(vector<string> &path, string name, vector<Ident> &params);
		Ident(string name, vector<Ident> &params);
		
		operator string();
	};
	
}

#endif // IDENT_HPP
