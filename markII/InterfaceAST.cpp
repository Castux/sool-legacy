#include "InterfaceAST.hpp"

using namespace sool;

TypeDecl::TypeDecl() : kind(t_unknown)
{
}

TypeDecl::~TypeDecl()
{
	for(uint i = 0 ; i < params.size() ; i++)
		delete params[i];
}

Member::Member() : shared(false), internal(false), type(NULL)
{
}

Member::~Member()
{
	delete(type);
}

Method::Method() : internal(false), selfless(false), foreign(false), rbyref(false), setter(false)
{
}

Method::~Method()
{
	for(uint i = 0 ; i < rtypes.size() ; i++)
		delete rtypes[i];
		
	for(uint i = 0 ; i < args.size() ; i++)
		delete args[i].type;
}

bool Class::IsTemplate()
{
	return(params.size() > 0);
}

Class::~Class()
{
	for(uint i = 0 ; i < params.size() ; i++)
		delete params[i];
	
	delete ptype;
	
	for(uint i = 0 ; i < members.size() ; i++)
		delete members[i];
		
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}

Context::~Context()
{
	for(uint i = 0 ; i < classes.size() ; i++)
		delete classes[i];
		
	for(uint i = 0 ; i < templates.size() ; i++)
		delete templates[i];
}
