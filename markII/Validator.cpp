#include <sstream>
#include "Validator.hpp"

using namespace sool;

/***************/
/** IfaceInst **/
/***************/

IfaceInst::IfaceInst(Validator *vali, Interface *i) : v(vali), iface(i), validated(false), validating(false)
{
	// No params, just set the name
	name = ClassName::Build(i->name);
}

IfaceInst::IfaceInst(Validator *vali, Interface *i, std::vector<ClassName*> params) : v(vali), iface(i), validated(false), validating(false)
{
	// Sanity check
	if(i->params.size() != params.size())
		error("IfaceInst::IfaceInst() - param number mismatch");
	
	// Build tmap
	for(uint j = 0 ; j < params.size() ; j++)
		tmap[i->params[j].name] = params[j];
	
	// Build class name
	name = ClassName::Build(i->name, params);
}

std::vector<IfaceInst*> IfaceInst::validation_stack;

bool IfaceInst::Validate()
{
	if(validated)
		return true;
	
	if(validating)
	{
		v->AddError("self embedding of interface " + name->signature + " detected");
		
		std::string tmp;
		for(uint i = 0 ; i < validation_stack.size() ; i++)
			tmp += validation_stack[i]->name->signature + " embeds ";
		
		tmp += name->signature;
		
		v->AddInfo(tmp);
		
		return false;
	}
	
	validating = true;
	validation_stack.push_back(this);
	
	// Interfaces are pretty straightforward. The only thing that can go
	// wrong is to have two methods with the same selector but a different
	// return type. On the way, we index prototypes by selector
	
	// Remember, we have to take the instmap in account, this could be a template!
	
	bool success;
	
	// Deal with embedding. We simply add the method set and check for selector conflicts.
	// This requires the other interfaces to have been validated first
	// Hence recursive call, and self-embedding guard.
	
	for(uint i = 0 ; i < iface->embeds.size() ; i++)
	{
		// Apply template parameters
		ClassName *cn = iface->embeds[i]->ReplaceTemplateParams(tmap);
		
		// Make sure instance exists
		success = v->ValidateClassName(cn, iface->embed_pos[i]);
		if(!success)
			return false;
		
		// Get instance
		IfaceInst *inst = v->imap[cn];
		if(!inst)
		{
			// It's probably not an interface, then
			ClassInst *cinst = v->cmap[cn];
			if(cinst)
			{
				v->AddError("cannot embed class in interface", this, iface->embed_pos[i]);
				v->AddInfo(cinst->name->signature + " declared a class here:", cinst->cl->pos.To(cinst->cl->name_pos));
				return false;
			}
			else
				error("IfaceInst::Validate() - no instance found");
		}
		
		// Validate it first
		success = inst->Validate();
		if(!success)
			return false;
		
		// Retrieve method set!
		std::vector<Prototype*> *protos = &inst->pvec;
		
		// Add them with conflict check
		for(uint j = 0 ; j < protos->size() ; j++)
		{
			Prototype *proto = (*protos)[j];
			
			Prototype *other = pmap[proto->selector];
			if(other && proto->rtype != other->rtype)
			{
				v->AddError("cannot embed interface " + inst->name->signature + " in " + name->signature, this, iface->embed_pos[i]);
				v->AddInfo("method " + proto->signature + " was already declared with a different return type (" + other->rtype.signature + ")", inst, proto->pos);
				v->AddInfo("here:", porigin[other], other->pos);
				return false;
			}
			
			if(!other)
				AddProto(proto, inst);
		}
	}
	
	// Then own methods
	
	for(uint i = 0 ; i < iface->protos.size() ; i++)
	{
		// Instantiate prototype template
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
		
		// Check selector conflicts
		Prototype *other = pmap[p->selector];
		if(other && p->rtype != other->rtype)
		{
			v->AddError("method " + p->signature + " was already declared with a different return type (" + other->rtype.signature + ")", this, p->pos);
			v->AddInfo("here:", porigin[other], other->pos);
			return false;
		}
		
		if(!other)
			AddProto(p);
	}
	
	validated = true;
	validating = false;
	validation_stack.pop_back();
	
	return true;
}

void IfaceInst::AddProto(Prototype* p, IfaceInst* origin)
{
	// Sanity check
	if(pmap[p->selector])
		error("IfaceInst::AddProto() - prototype already present");
	
	pvec.push_back(p);
	pmap[p->selector] = p;
	porigin[p] = origin ? origin : this;
}

/***************/
/** ClassInst **/
/***************/

ClassInst::ClassInst(Validator *vali, Class *c) : v(vali), cl(c), validated(false), validating(false)
{
	// No params, name is trivial
	name = ClassName::Build(c->name);
}

ClassInst::ClassInst(Validator *vali, Class *c, std::vector<ClassName*> params) : v(vali), cl(c), validated(false), validating(false)
{
	// Sanity check
	if(c->params.size() != params.size())
		error("ClassInst::ClassInst() - param number mismatch");
	
	// Build tmap
	for(uint j = 0 ; j < params.size() ; j++)
		tmap[c->params[j].name] = params[j];
	
	// Build class name
	name = ClassName::Build(c->name, params);
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

void Validator::AddInfo(std::string message, IfaceInst *inst, SourcePos position)
{
	// If inst happens to be a template instantiation, it can be usefull to remind it
	if(!inst->tmap.empty())
	{
		std::string tmp = " [" + inst->name->signature + " instance of interface template " + inst->iface->name + "]";
		message += Diagnostic::C(tmp,0);
	}
	
	AddInfo(message, position);
}

void Validator::AddInfo(std::string message, ClassInst *inst, SourcePos position)
{
	// If inst happens to be a template instantiation, it can be usefull to remind it
	if(!inst->tmap.empty())
	{
		std::string tmp = " [" + inst->name->signature + " instance of class template " + inst->cl->name + "]";
		message += Diagnostic::C(tmp,0);
	}
	
	AddInfo(message, position);
}

void Validator::AddError(std::string message, IfaceInst *inst, SourcePos position)
{
	// If inst happens to be a template instantiation, it can be usefull to remind it
	if(!inst->tmap.empty())
	{
		std::string tmp = " [" + inst->name->signature + " instance of interface template " + inst->iface->name + "]";
		message += Diagnostic::C(tmp,0);
	}
	
	AddError(message, position);
}

void Validator::AddError(std::string message, ClassInst *inst, SourcePos position)
{
	// If inst happens to be a template instantiation, it can be usefull to remind it
	if(!inst->tmap.empty())
	{
		std::string tmp = " [" + inst->name->signature + " instance of class template " + inst->cl->name + "]";
		message += Diagnostic::C(tmp,0);
	}
	
	AddError(message, position);
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
	for(uint i = 0 ; i < ivec.size() ; i++)
	{
		AddInfo("------Iface: " + ivec[i]->name->signature);
		for(uint j = 0 ; j < ivec[i]->pvec.size() ; j++)
			AddInfo("\t" + ivec[i]->pvec[j]->signature);
	}
	
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
	// FIXME: we might need to do it at a later phase, when interfaces are full (just don't forget)
    // For instance when checking the class itself?
	
	// Recursively validate classnames
	
	for(uint i = 0 ; i < cname->params.size() ; i++)
	{
		if(!ValidateClassName(cname->params[i], pos))
			return false;
	}
	
	// Instantiate
	
	if(g->IsClass())
	{
		ClassInst *inst = new ClassInst(this, (Class*) g, cname->params);
		AddClass(inst);
	}
	else
	{
		IfaceInst *inst = new IfaceInst(this, (Interface*) g, cname->params);
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
