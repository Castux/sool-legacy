#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

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

Validator::Validator()
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
	*/
	for(ClassNameMap::iterator it = ClassName::map.begin(); it != ClassName::map.end(); it++)
		AddInfo(it->second->signature);
	
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
	
	return success;
}
/*
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
*/
void Validator::AddError(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Error, message, position);
}

void Validator::AddInfo(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Info, message, position);
}
