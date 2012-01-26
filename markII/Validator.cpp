#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

Class *Context::Instantiate(Class *templ, std::vector<Type*> params)
{
	// Start by building the signature
	
	std::string sig;
	
	if(templ->name == "#")
	{
		// Special array case, we know there should be only one parameter
		// thanks to the parser
		
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
	
	// If not we simply make a copy of the template, replace the template
	// parameters by they values
	
	inst = templ->Copy();
	
	if(params.size() != templ->params.size())
		error("Class::Instantiate - mismatched number of parameters");
	
	// Do the big replacement of types!
	
	inst->params.clear();
	inst->name = sig;
	
	// Then add it to the context
	
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
	for(ClassMap::iterator it = cmap.begin(); it != cmap.end(); it++)
		delete(it->second);
}

Validator::Validator() : tforge(this)
{
}

Validator::~Validator()
{
}

bool Validator::Validate(ParseResult res)
{
	// Start by filling the context
	
	context = new Context;
	
	if(!FillContextWithClasses(res))
		return false;
	
	delete(res.classes);
	delete(res.extensions);
	
	// Validate interfaces
	/*
	for(uint i = 0 ; i < context->classes.size() ; i++)
	{
		if(!ValidateInterface(context->classes[i]))
			break;
	}
	
	
	// DEBUG
	
	for(uint i = 0 ; i < context->classes.size() ; i++)
	{
		Class *c = context->classes[i];
		AddInfo(c->name + (c->pclass ? " : " + c->pclass->name : ""));
	}
	
	for(TypeMap::iterator it = tforge.tmap.begin(); it != tforge.tmap.end(); it++)
		AddInfo(it->second->signature);
	*/
	return true;
}

bool Validator::FillContextWithClasses(ParseResult res)
{
	std::vector<Class*> *classes = res.classes;
	
	bool success = true;
	
	// Index classes by name, check unicity
	
	for(uint i = 0; i < classes->size(); i++)
	{
		Class *c = (*classes)[i];
		
		ClassMap::iterator it = context->cmap.find(c->name);
		
		// Check unicity
		if(it != context->cmap.end())
		{
			AddError("previous definition of " + c->name, c->name_pos);
			AddInfo("here:", it->second->name_pos);
			
			success = false;
			delete(c);
		}
		// Index by name
		else
		{
			context->cmap[c->name] = c;
		}
	}
	
	if(!success)
		return false;
	
	// Then check parameters in templates
	
	for(ClassMap::iterator it = context->cmap.begin(); it != context->cmap.end(); it++)
	{
		Class *t = it->second;
		if(!t->IsTemplate())
			continue;
		
		for(uint j = 0 ; j < t->params.size() ; j++)
		{
			std::string param = t->params[j];
			
			// Param - class conflict
			
			Class *other = context->Get(param);
			if(other)
			{
				AddError("template parameter " + param + " shadows " + other->Kind() + " with the same name", t->params_pos[j]);
				AddInfo("declared here:", other->name_pos);
				success = false;
				continue;
			}
			
			// Param - param conflict
			
			for(uint k = 0 ; k < j ; k++)
			{
				if(param == t->params[k])
				{
					AddError("template parameter " + param + " shadows previous parameter with the same name", t->params_pos[j]);
					AddInfo("here:", t->params_pos[k]);
					success = false;
					continue;
				}
				
				if(!success)
					continue;
			}
		}
	}
	
	if(!success)
		return false;
	
	// Then the big magic "make it all happen"
	if(!MakeAllTypesAndInstances())
		return false;
	
	// Finally, now that all possible classes do exist, append the extensions
	//
	
	return success;
}

bool Validator::MakeAllTypesAndInstances()
{
	for(ClassMap::iterator it = context->cmap.begin(); it != context->cmap.end(); it++)
	{
		Class *c = it->second;
		
		if(c->IsTemplate())
			continue;
		
		for(uint j = 0 ; j < c->type_decls.size() ; j++)
		{
			TypeDecl *decl = c->type_decls[j];
			
			Type *t = tforge.ConvertDecl(decl);
			if(!t)
				return false;
		}
	}
	
	// The same with instances, and again, until all is treated
	
	return true;
}

bool Validator::ValidateInterface(Class *c)
{
	// Don't do the work twice!
	if(c->valid_interface)
		return true;
	
	// Check for circular inheritance
	if(c->validating_interface)
	{
		AddError("circular inheritance detected for class " + c->name, c->ptype->pos);
		
		std::string tmp = c->name + " child of ";
		Class *ptr = c->pclass;
		
		while(ptr != c)
		{
			tmp += ptr->name + " child of ";
			ptr = ptr->pclass;
		}
		
		tmp += c->name;
		
		AddInfo(tmp);
		
		return false;
	}
	
	c->validating_interface = true;
	
	// The validation
	
	if(!CheckParentClass(c))
		return false;
	
	// If we have a parent, it should be validated before us, for inheritance
	if(c->pclass)
		ValidateInterface(c->pclass);
	
	// Then members
	
	if(!TreatMembers(c))
		return false;
	
	// Update the guards
	
	c->valid_interface = true;
	c->validating_interface = false;
	return true;
}

bool Validator::CheckParentClass(Class *c)
{
	// This may create new classes by template instantiation
	// but they're added at the end of the vector, and I use the
	// dynamic "index + check size" kind of loop, so it's ok.
	
	// No parent!
	if(!c->ptype)
		return true;
	
	// Deal with value classes
	if(c->value)
	{
		AddError("value classes cannot inherit", c->ptype->pos);
		AddInfo(c->name + " declared a value class here:", c->pos.To(c->name_pos));
		return false;
	}
	
	// Get an actual type from declaration
	Type *t = tforge.Get(c->ptype);
	if(!t)
		return false;
	
	// Check it is indeed an object class
	Class *pc = t->GetClass();
	if(pc->value)
	{
		AddError("cannot inherit from a value class", c->ptype->pos);
		AddInfo(t->signature + " declared a value class here:", pc->pos.To(pc->name_pos));
		return false;
	}
	
	// And save for future reference
	c->pclass = pc;
	
	return true;
}

bool Validator::TreatMembers(Class *c)
{
	for(uint i = 0 ; i < c->members.size() ; i++)
	{
		Member *m = c->members[i];
		
		// Resolve type
		m->type = tforge.Get(m->tdecl);
		if(!m->type)
			return false;
		
		// Check name collision
		Member *other = c->GetMember(m->name);
		if(other)
		{
			AddError(std::string("member ") + m->name + " was already defined", m->name_pos);
			AddInfo("here:", other->name_pos);
			return false;
		}
		
		// Fine, index it by name
		c->mem_map[m->name] = m;
		
		// Add the accessor methods. FIXME! Must invent void type
		
		Method *setter = new Method;
		
		setter->internal = m->internal;
		setter->selfless = m->shared;
		setter->rtype = m->type;
		setter->name = m->name;
		setter->setter = true;
		setter->member = m;
		setter->signature = setter->name + ":";
		
		c->meth_map[setter->signature] = setter;
		
		Method *getter = new Method;
		
		getter->internal = m->internal;
		getter->selfless = m->shared;
		getter->rtype = m->type;
		getter->name = m->name;
		getter->setter = true;
		getter->member = m;
		getter->signature = setter->name + ":";
		
		c->meth_map[setter->signature] = setter;
	}
	
	return true;
}

void Validator::AddError(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Error, message, position);
}

void Validator::AddInfo(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Info, message, position);
}
