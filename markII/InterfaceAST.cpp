#include "InterfaceAST.hpp"
#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

TypeDecl::TypeDecl()
{
}

TypeDecl *TypeDecl::Copy()
{
	TypeDecl *t = new TypeDecl(*this);
	
	for(uint i = 0 ; i < t->params.size() ; i++)
		t->params[i] = params[i]->Copy();
	
	return t;
}

TypeDecl::~TypeDecl()
{
	for(uint i = 0 ; i < params.size() ; i++)
		delete params[i];
}

Member::Member() : shared(false), internal(false), tdecl(NULL), type(NULL)
{
}

Member::~Member()
{
	delete(tdecl);
}

Member *Member::Copy()
{
	Member *m = new Member(*this);
	
	m->tdecl = tdecl->Copy();
	
	return m;
}

Method::Method() : internal(false), selfless(false), foreign(false), setter(false), member(NULL)
{
}

Method::~Method()
{
	for(uint i = 0 ; i < ret_decls.size() ; i++)
		delete ret_decls[i];
		
	for(uint i = 0 ; i < args.size() ; i++)
		delete args[i].type;
}

Method *Method::Copy()
{
	Method *m = new Method(*this);
	
	for(uint i = 0 ; i < ret_decls.size() ; i++)
		m->ret_decls[i] = ret_decls[i]->Copy();
	
	for(uint i = 0 ; i < args.size() ; i++)
		m->args[i].type = args[i].type->Copy();
	
	return m;
}

Class::Class() :	value(false), ptype(NULL), pclass(NULL), validating_interface(false),
					valid_interface(false), valid_code(false)
{
}

Class *Class::Copy()
{
	Class *c = new Class(*this);
	
	c->ptype = ptype->Copy();
	
	for(uint i = 0 ; i < members.size() ; i++)
		c->members[i] = members[i]->Copy();
	
	for(uint i = 0 ; i < methods.size() ; i++)
		c->methods[i] = methods[i]->Copy();
	
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
	delete ptype;
	
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

Extension::Extension() : type(NULL)
{
}

Extension::~Extension()
{
	delete type;
}
