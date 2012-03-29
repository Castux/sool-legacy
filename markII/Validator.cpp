#include "Validator.hpp"

using namespace sool;

/***************/
/** IfaceInst **/
/***************/

IfaceInst::IfaceInst(Validator *vali, Interface *i) : v(vali), iface(i), validated(false)
{
	// No params, name is trivial
	name = i->name;
}

bool IfaceInst::Validate()
{
	if(validated)
		return true;
	
	// Interfaces are pretty straightforward. The only thing that can go
	// wrong is to have two methods with the same selector but a different
	// return type. On the way, we index prototypes by selector
	
	// Remember, we have to take the instmap in account, this could be a template!
	
	bool success;
	
	for(uint i = 0 ; i < iface->protos.size() ; i++)
	{
		// Instantiate template
		Prototype *p = iface->protos[i]->ReplaceTemplateParams(tmap);
		
		// Check types' validity
		success = v->ValidateType(p->rtype, p->rtype_pos);
		if(!success)
			return false;
		
		for(uint j = 0 ; j < p->args.size() ; j++)
		{
			success = v->ValidateType(p->args[j].type, p->args[j].pos);
			if(!success)
				return false;
		}
	}
	
	
	validated = true;
	return true;
}

void IfaceInst::AddProto(Prototype* p)
{
	// Sanity check
	if(pmap[p->selector])
		error("IfaceInst::AddProto() - prototype already present");
	
	pvec.push_back(p);
	pmap[p->selector] = p;
}

/***************/
/** Validator **/
/***************/

Validator::Validator(Context *c) : context(c)
{
}

Validator::~Validator()
{
	for(uint i = 0 ; i < ivec.size() ; i++)
		delete ivec[i];
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
	
	// From there initiate validation of single interfaces. If required,
	// other instances will be added at the vector's end, and validations
	// will be launched recursively
	
	for(uint i = 0 ; i < ivec.size() ; i++)
	{
		success = ivec[i]->Validate();
		if(!success)
			return false;
	}
	
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
		
		IfaceInst *inst = new IfaceInst(this, iface);
		
		// Insert new instance
		AddIface(inst);
	}
}

void Validator::AddIface(IfaceInst* iface)
{
	// Sanity check
	if(imap[iface->name])
		error("Validator::AddIface() - instance already present");
	
	ivec.push_back(iface);
	imap[iface->name] = iface;
}

bool Validator::ValidateType(Type &t, SourcePos pos)
{
	AddInfo("lol me plenty " + t.signature);
	
	return true;
}

bool Validator::ValidateType(MultiType &t, SourcePos pos)
{
	for(uint i = 0 ; i < t.types.size() ; i++)
	{
		if(!ValidateType(t.types[i], pos))
			return false;
	}
	
	return true;
}
