#include "AST.hpp"
#include "Type.hpp"

using namespace sool;

Member::Member() : shared(false)
{
}

Member::~Member()
{
}

Method::Method() : proto(NULL)
{
}

Method::~Method()
{
	delete proto;
}

Class::~Class()
{
	for(uint i = 0 ; i < members.size() ; i++)
		delete members[i];
		
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}

std::string Class::KindToString()
{
	std::string res;
	if(kind == k_value)
		res = "value class";
	else
		res = "object class";
	
	return res;
}

std::string Class::FancyName()
{
	return KindToString() + " " + name;
}

Extension::Extension() : cname(NULL)
{
}

Extension::~Extension()
{
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}

std::string Interface::FancyName()
{
	return std::string("interface ") + name;
}

Interface::~Interface()
{
	for(uint i = 0 ; i < protos.size() ; i++)
		delete protos[i];
}

Context::~Context()
{
	for(uint i = 0 ; i < classes.size() ; i++)
		delete classes[i];
	
	for(uint i = 0 ; i < interfaces.size() ; i++)
		delete interfaces[i];
	
	for(uint i = 0 ; i < extensions.size() ; i++)
		delete extensions[i];
}
