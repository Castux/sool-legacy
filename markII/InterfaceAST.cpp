#include "InterfaceAST.hpp"
#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

Member::Member() : shared(false), internal(false)
{
}

Member::~Member()
{
}

Member *Member::Copy()
{
	Member *m = new Member(*this);
	
	return m;
}

Method::Method() : internal(false), selfless(false), foreign(false), setter(false), member(NULL)
{
}

Method::~Method()
{
}

Method *Method::Copy()
{
	Method *m = new Method(*this);
	
	return m;
}

Class::Class() :	value(false), validating_interface(false),
					valid_interface(false), valid_code(false)
{
}

Class *Class::Copy()
{
	Class *c = new Class(*this);
	
	return c;
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

std::string Class::Kind()
{
	std::string res;
	if(value)
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
}
