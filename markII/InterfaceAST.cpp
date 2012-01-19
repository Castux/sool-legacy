#include "InterfaceAST.hpp"
#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

TypeDecl::TypeDecl() : kind(t_unknown)
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

Method::Method() : internal(false), selfless(false), foreign(false), rbyref(false), setter(false), member(NULL)
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

Class::Class() :	structure(false), ptype(NULL), pclass(NULL), validating_interface(false),
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
	// Instances don't own anything, they just point at their model
	if(IsInstance())
		return;
	
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

bool Class::IsInstance()
{
	return(!instmap.empty());
}

std::string Class::Kind()
{
	if(structure)
		return "structure";
	else
		return "class";
}

Extension::Extension() : type(NULL)
{
}

Extension::~Extension()
{
	delete type;
}


Class *Context::Instantiate(Class *templ, std::vector<Type*> params)
{
	// Start by building the signature
	
	std::string sig;
	
	if(templ->name == "#")
	{
		// Special array case, we know there should be only one parameter
		// thanks to the built-in declaration
		
		if(params.size() != 1)
			error("array type didn't get exactly one parameter");
		
		sig = std::string("#") + params[0]->signature;
	}
	else
	{
		// Normal case, just cat the params
		
		sig = templ->name + "|";
		
		if(params.size() > 1)
			sig += "(";
		
		for(uint i = 0; i < params.size()-1; i++)
			sig += params[i]->signature + ",";
		
		sig += params.back()->signature;
		
		if(params.size() > 1)
			sig += ")";
	}
	
	// Check if the class already exists
	
	Class *inst = Get(sig);
	
	if(inst)
		return inst;
	
	// If not we simply make a copy of the template, remove the declared template params,
	// and add a string->Type map
	
	inst = new Class;
	
	*inst = *templ;
	
	if(params.size() != templ->params.size())
		error("Class::Instantiate - mismatched number of parameters");
	
	for(uint i = 0; i < params.size(); i++)
	{
		inst->instmap[templ->params[i]] = params[i];
	}
	
	inst->params.clear();
	inst->name = sig;
	
	// Then add it to the context
	
	instances.push_back(inst);
	cmap[sig] = inst;
	
	return inst;
}

Class* Context::Get(std::string name)
{
	ClassMap::iterator it = cmap.find(name);
	
	if(it != cmap.end())
		return it->second;
	
	return NULL;
}

Context::~Context()
{
	for(uint i = 0 ; i < classes.size() ; i++)
		delete classes[i];
		
	for(uint i = 0 ; i < templates.size() ; i++)
		delete templates[i];
		
	for(uint i = 0 ; i < instances.size() ; i++)
		delete instances[i];
		
	for(uint i = 0 ; i < extensions.size() ; i++)
		delete extensions[i];
}
