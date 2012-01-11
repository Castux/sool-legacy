#include "InterfaceAST.hpp"
#include "Validator.hpp"

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

Class::Class() : structure(false), extension(false), ptype(NULL)
{
}

Class::~Class()
{
	// Instances don't own anything, they just point at their model
	if(IsInstance())
		return;
	
	for(uint i = 0 ; i < params.size() ; i++)
		delete params[i];
	
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
		inst->instmap[templ->params[i]->name] = params[i];
	}
	
	inst->params.clear();
	inst->name = sig;
	
	// Then add it to classes
	
	classes.push_back(inst);
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
}
