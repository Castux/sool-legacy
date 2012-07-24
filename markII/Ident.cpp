#include "Ident.hpp"

using namespace sool;

Ident::Ident(string name) : name(name)
{
}

Ident::Ident(vector<string> &path, string name) : path(path), name(name)
{
}

Ident::Ident(vector<string> &path, string name, vector<Ident> &params) :
	path(path), name(name), params(params)
{
}

Ident::Ident(string name, vector<Ident> &params) : name(name), params(params)
{
}

Ident::operator string()
{
	string s;
	
	if( path.size() > 0 )
	{
		for( uint i = 0 ; i < path.size() ; i++ )
			s += path[i] + ':';
	}
	
	s += name;
	
	if( name == "#" && params.size() == 1 )
	{
		s += params.front();
		return s;
	}
	
	if( params.size() > 0 )
	{
		s += '|';
		
		if( params.size() == 1 )
		{
			s += params.front();
		}
		else
		{
			s += '(';
			for( uint i = 0 ; i < params.size() - 1 ; i++ )
			{
				s += params[i];
				s += ',';
			}
			
			s += params.back();
			s += ')';
		}
	}
	
	return s;
}
