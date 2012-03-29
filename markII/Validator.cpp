#include "Validator.hpp"

using namespace sool;

IfaceInst::IfaceInst(Interface *i) : iface(i)
{
	// No params, name is trivial
	name = i->name;
}



















Validator::Validator(Context *c) : context(c)
{
}

Validator::~Validator()
{
	for(IfaceInstMap::iterator it = imap.begin() ; it != imap.end() ; it++)
		delete it->second;
}

void Validator::AddError(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Error, message, position);
}

void Validator::AddInfo(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Info, message, position);
}

bool Validator::Validate()
{
	bool success;
	
	success = CheckGlobalNames();
	if(!success)
		return false;
	
	success = CheckTemplateParams();
	if(!success)
		return false;
	
	InstantiateParameterlessInterfaces();
	
	AddInfo("context passed validation");
	return true;
}

// CheckGlobalNames: index classes and interfaces by name and check unicity

bool Validator::CheckGlobalNames()
{
	// First classes
	
	for(uint i = 0 ; i < context->classes.size() ; i++)
	{
		Class *c = context->classes[i];
		
		Class *prev = rawcmap[c->name];
		if(prev)
		{
			AddError(c->FancyName() + " was already defined", c->name_pos);
			AddInfo("here:", prev->name_pos);
			return false;
		}
		
		rawcmap[c->name] = c;
		globals.push_back(c);
	}
	
	// Then interfaces
	
	for(uint i = 0 ; i < context->interfaces.size() ; i++)
	{
		Interface *iface = context->interfaces[i];
		
		Global *g = LookupGlobal(iface->name);
		if(g)
		{
			AddError(g->FancyName() + " was already defined", iface->name_pos);
			AddInfo("here:", g->name_pos);
			return false;
		}
		
		rawimap[iface->name] = iface;
		globals.push_back(iface);
	}
	
	return true;
}

// Where we go through templates and verify that the parameter names do not conflict

bool Validator::CheckTemplateParams()
{
	for(uint i = 0 ; i < globals.size() ; i++)
	{
		Global *g = globals[i];
		
		for(uint j = 0 ; j < g->params.size() ; j++)
		{
			// Conflict with global name
			
			TemplateParam *p = &g->params[j];
			Global *other = LookupGlobal(p->name);
			if(other)
			{
				AddError("template parameter shadows " + other->FancyName(), p->pos);
				AddInfo("defined here:", other->name_pos);
				return false;
			}
			
			// Conflict with previous parameter
			
			for(uint k = 0 ; k < j ; k++)
			{
				TemplateParam *other = &g->params[k];
				if(p->name == other->name)
				{
					AddError("template parameter " + p->name + " was previously defined", p->pos);
					AddInfo("here:", other->pos);
					return false;
				}
			}
		}
	}
	
	return true;
}

Global* Validator::LookupGlobal(std::string name)
{
	Interface *prev = rawimap[name];
	if(prev)
		return prev;
	
	Class *cl = rawcmap[name];
	if(cl)
		return cl;
	
	return NULL;
}

void Validator::InstantiateParameterlessInterfaces()
{
	for(uint i = 0 ; i < context->interfaces.size() ; i++)
	{
		Interface *iface = context->interfaces[i];
		
		if(iface->params.size() != 0)
			continue;
		
		IfaceInst *inst = new IfaceInst(iface);
		
		// Sanity check
		if(imap[inst->name])
			error("Validator::InstantiateParameterlessInterfaces() - instance already present");
		
		// Insert new instance
		imap[inst->name] = inst;
	}
}
