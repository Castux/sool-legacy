#include "AST.hpp"
#include "Type.hpp"

using namespace sool;

Member::Member() : shared(false)
{
}

Member::~Member()
{
}

Method::Method() : setter(false), member(NULL)
{
}

Method::~Method()
{
}

Class::Class() :	validating_interface(false),
					valid_interface(false), valid_code(false)
{
}

Member *Class::GetMember(std::string name)
{
	MemberMap::iterator it = mem_map.find(name);
	if(it != mem_map.end())
		return it->second;
	
	return NULL;
}

Class::~Class()
{
	for(uint i = 0 ; i < members.size() ; i++)
		delete members[i];
		
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}

bool Class::IsTemplate()
{
	return(params.size() > 0);
}

std::string Class::KindToString()
{
	std::string res;
	if(kind == k_value)
		res = "value class";
	else
		res = "object class";
	
	if(IsTemplate())
		res += " template";
	
	return res;
}

Extension::Extension()
{
}

Extension::~Extension()
{
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}
