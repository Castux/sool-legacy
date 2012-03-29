#include <sstream>
#include "Validator.hpp"

using namespace sool;

/***************/
/** IfaceInst **/
/***************/

IfaceInst::IfaceInst(Validator *vali, Interface *i) : v(vali), iface(i), validated(false)
{
	// No params, name is trivial
	name = ClassName::Build(i->name);
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
/** ClassInst **/
/***************/

ClassInst::ClassInst(Validator *vali, Class *c) : v(vali), cl(c), validated(false)
{
	// No params, name is trivial
	name = ClassName::Build(c->name);
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
	
	for(uint i = 0 ; i < cvec.size() ; i++)
		AddInfo("Class: " + cvec[i]->name->signature);
	
	AddInfo("context passed validation");
	return true;
}

// CheckGlobalNames: index classes and interfaces by name and check unicity

bool Validator::CheckGlobalNames()
{
	for(uint i = 0 ; i < context->globals.size() ; i++)
	{
		Global *g = context->globals[i];
		
		Global *prev = global_map[g->name];
		if(prev)
		{
			AddError(prev->FancyName() + " was already defined", g->name_pos);
			AddInfo("here:", prev->name_pos);
			return false;
		}
		
		global_map[g->name] = g;
	}
	
	
	return true;
}

// Where we go through templates and verify that the parameter names do not conflict

bool Validator::CheckTemplateParams()
{
	for(uint i = 0 ; i < context->globals.size() ; i++)
	{
		Global *g = context->globals[i];
		
		for(uint j = 0 ; j < g->params.size() ; j++)
		{
			// Conflict with global name
			
			TemplateParam *p = &g->params[j];
			Global *other = global_map[p->name];
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

void Validator::AddClass(ClassInst* cl)
{
	// Sanity check
	if(cmap[cl->name])
		error("Validator::AddClass() - instance already present: " + cl->name->signature);
	
	cvec.push_back(cl);
	cmap[cl->name] = cl;
}

bool Validator::ValidateType(Type &t, SourcePos pos)
{
	// It's really more about the ClassName inside
	return ValidateClassName(t.cname, pos);
}

bool Validator::ValidateClassName(ClassName *cname, SourcePos pos)
{
	// First check if it already exists, as a class or interface
	
	ClassInst *c = cmap[cname];
	if(c)
		return true;
	
	IfaceInst *iface = imap[cname];
	if(iface)
		return true;
	
	// It doesn't. Now check that the base name exists
	
	Global *g = global_map[cname->name];
	if(!g)
	{
		AddError("unknown class " + cname->name, pos);
		return false;
	}
	
	// Check that the number of params matches
	
	uint needed_num_params = g->params.size();
	uint provided_num_params = cname->params.size();
	
	std::stringstream needed_s, provided_s;
	needed_s << needed_num_params;
	provided_s << provided_num_params;
	
	if(needed_num_params != provided_num_params)
	{
		SourcePos p;
		if(needed_num_params == 0)
			p = g->name_pos;
		else
			p = g->params.front().pos.To(g->params.back().pos);
		
		AddError(g->FancyName() + " used with " + provided_s.str() + " template parameter" + (provided_num_params != 1 ? "s" : ""), pos);
		AddInfo("but declared with " + needed_s.str(), p);
		return false;
	}
	
	// Check that the given classes comply with the interfaces
	// TODO
	
	// Recursively validate classnames
	
	for(uint i = 0 ; i < cname->params.size() ; i++)
	{
		if(!ValidateClassName(cname->params[i], pos))
			return false;
	}
	
	// Instantiate
	// FIXME: put the subtypes...
	if(g->IsClass())
	{
		ClassInst *inst = new ClassInst(this, (Class*) g);
		AddClass(inst);
	}
	else
	{
		IfaceInst *inst = new IfaceInst(this, (Interface*) g);
		AddIface(inst);
	}
	
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
