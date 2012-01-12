#include "Validator.hpp"
#include "Type.hpp"

using namespace sool;

Validator::Validator(Context *c) : tforge(this), context(c)
{
}

Validator::~Validator()
{
}

bool Validator::Validate()
{
	// Global stuff: check names, sort templates and extensions
	
	SortOutExtensions();
	
	if(!CheckClassNames())
		return false;
	
	SortOutTemplates();
	
	if(!CheckTemplateParameters())
		return false;
	
	// Deal with inheritence, in particular check circles
	
	for(uint i = 0 ; i < context->classes.size() ; i++)
	{
		if(!CheckParentClass(context->classes[i]))
			return false;
	}
	
	// Validate interfaces
	
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
	
	return true;
}

void Validator::SortOutExtensions()
{
	std::vector<Class*> extensions;
	std::vector<Class*> classes;
	
	std::vector<Class*>::iterator it;
	
	for(it = context->classes.begin(); it < context->classes.end(); it++)
	{
		if((*it)->extension)
			extensions.push_back(*it);
		else
			classes.push_back(*it);
	}
	
	context->extensions = extensions;
	context->classes = classes;
}

bool Validator::CheckClassNames()
{
	bool success = true;
	
	for(uint i = 0; i < context->classes.size(); i++)
	{
		Class *c = context->classes[i];
		
		ClassMap::iterator it = context->cmap.find(c->name);
		
		// Check unicity
		if(it != context->cmap.end())
		{
			AddError("previous definition of " + c->name, c->name_pos);
			AddInfo("here:", it->second->name_pos);
			
			success = false;
		}
		// Index by name
		else
		{
			context->cmap[c->name] = c;
		}
	}
	
	return success;
}

void Validator::SortOutTemplates()
{
	std::vector<Class*> templates;
	std::vector<Class*> classes;
	
	std::vector<Class*>::iterator it;
	
	for(it = context->classes.begin(); it < context->classes.end(); it++)
	{
		if((*it)->IsTemplate())
			templates.push_back(*it);
		else
			classes.push_back(*it);
	}
	
	context->templates = templates;
	context->classes = classes;
}

bool Validator::CheckTemplateParameters()
{
	bool success = true;
	
	for(uint i = 0 ; i < context->templates.size() ; i++)
	{
		Class *t = context->templates[i];
		
		for(uint j = 0 ; j < t->params.size() ; j++)
		{
			TypeDecl *param = t->params[j];
			
			Class *other = context->Get(param->name);
			if(other)
			{
				AddError("template parameter " + param->name + " shadows " + other->Kind() + " with the same name", param->pos);
				AddInfo("declared here:", other->name_pos);
				success = false;
				continue;
			}
		}
	}
	
	return success;
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
	
	// If we have a parent, it should be validated before us, for inheritance
	if(c->pclass)
		ValidateInterface(c->pclass);
	
	// The rest
	
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
	
	// Deal with structs
	if(c->structure)
	{
		AddError("structures cannot inherit", c->ptype->pos);
		AddInfo(c->name + " declared a structure here:", c->pos.To(c->name_pos));
		return false;
	}
	
	// Get an actual type from declaration
	Type *t = tforge.Get(c->ptype, &c->instmap);
	if(!t)
		return false;
	
	// Check it is indeed a class (not a struct)
	Class *pc = t->GetClass();
	if(pc->structure)
	{
		AddError("cannot inherit from a structure", c->ptype->pos);
		AddInfo(t->signature + " declared a structure here:", pc->pos.To(pc->name_pos));
		return false;
	}
	
	// And save for future reference
	c->pclass = pc;
	
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
