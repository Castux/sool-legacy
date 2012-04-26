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

IfaceInst::~IfaceInst()
{
	for(uint i = 0 ; i < pvec.size() ; i++)
	{
		if(porigin[pvec[i]] == this)
			delete pvec[i];
	}
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
		{
			delete p;
			return false;
		}
		
		for(uint j = 0 ; j < p->args.size() ; j++)
		{
			success = v->ValidateType(p->args[j].type, p->args[j].pos);
			if(!success)
				return false;
		}
		
		// Check selector conflicts
		Prototype *other = pmap[p->selector];
		if(other)
		{
			if(p->rtype != other->rtype)
			{
				v->AddError("method " + p->selector + " was already declared with a different return type (" + other->rtype.signature + ")", this, p->pos);
				v->AddInfo("here:", porigin[other], other->pos);
				delete p;
				return false;
			}
			delete p;
		}
		else
		{
			AddProto(p);
		}
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

bool IfaceInst::Contains(Prototype *p)
{
	if(!validated)
		error("IfaceInst::Contains() - iface not validated");
	
	Prototype *own = pmap[p->selector];
	if(!own)
		return false;
	
	if(own->rtype == p->rtype)
		return true;
	
	return false;
}

/***************/
/** ClassInst **/
/***************/

std::string ClassInst::AnswerInfo::ToString()
{
	std::string tmp = rtype.signature + " (";
	
	switch(mode)
	{
		case a_not:
			tmp += "no answer";
			break;
		case a_self:
			tmp += "self implemented";
			break;
		case a_selfless:
			tmp += "selfless method in the class";
			break;
		case a_member:
			tmp += "accessor for member";
			break;
		case a_shared_member:
			tmp += "accessor for shared member";
			break;
		case a_embed:
			tmp += "embeded class answers";
			break;
		case a_generic:
			tmp += "generic class implements";
			break;
		case a_shortcut:
			tmp += "shortcut to method with optionals";
			break;
	}
	
	tmp += ")";
	return tmp;
}

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

ClassInst::~ClassInst()
{
	for(uint i = 0 ; i < members.size() ; i++)
		delete members[i];
		
	for(uint i = 0 ; i < pvec.size() ; i++)
		delete pvec[i];
}

std::vector<ClassInst*> ClassInst::validation_stack;

bool ClassInst::Validate()
{
	if(validated)
		return true;
	
	if(validating)
	{
		v->AddError("self embedding of class " + name->signature + " detected");
		
		std::string tmp;
		for(uint i = 0 ; i < validation_stack.size() ; i++)
			tmp += validation_stack[i]->name->signature + " embeds ";
		
		tmp += name->signature;
		
		v->AddInfo(tmp);
		
		return false;
	}
	
	validating = true;
	validation_stack.push_back(this);
	
	// Validating classes is also pretty easy, because lots of shadowing
	// is allowed: embeds are really just members, and if there are name
	// conflicts, the top level ones win. We don't even have to check here,
	// that's done by the Answers() lookup. Badass.
	
	// And always convert types, we have to assume that we're dealing with
	// a template
	
	bool success;
	
	// Check that we don't embed a same class multiple times
	
	for(uint i = 0 ; i < cl->embeds.size() ; i++)
	{
		// Apply template parameters
		ClassName *cn = cl->embeds[i]->ReplaceTemplateParams(tmap);
		
		// Make sure instance exists
		success = v->ValidateClassName(cn, cl->embed_pos[i]);
		if(!success)
			return false;
		
		// Get instance
		GlobalInst *inst = v->GetGlobal(cn);
		if(!inst)
			error("ClassInst::Validate() - no instance found");
		
		// Make sure it's valid
		success = inst->Validate();
		if(!success)
			return false;
		
		Type type = Type(cn,false);		// false for non optional
		
		// Prevent multiple embedding of same class
		// As of now there are only embeddings, so a type check is enough
		for(uint j = 0 ; j < members.size() ; j++)
		{
			if(members[j]->type == type)
			{
				v->AddError("attempting to embed class " + cn->signature + " several times", this, cl->embed_pos[i]);
				v->AddInfo("previous embedding was here:", this, cl->embed_pos[j]);		// Embeds are added in the same order as they appears, so 'j' should be fine
				return false;
			}
		}
		
		// Fine, embed.
		Member *m = new Member;
		m->shared = false;
		m->type = type;
		m->name = cn->signature;
		m->pos = cl->embed_pos[i];
		m->type_pos = cl->embed_pos[i];
		m->name_pos = cl->embed_pos[i];
		
		AddMember(m);
	}
	
	// Now deal with the regular members
	
	for(uint i = 0 ; i < cl->members.size() ; i++)
	{
		// Apply template parameters
		Member *m = cl->members[i]->ReplaceTemplateParams(tmap);
		
		// Make sure instance exists
		success = v->ValidateClassName(m->type.cname, m->type_pos);
		if(!success)
		{
			delete m;
			return false;
		}
		
		// Now check name collisions
		for(uint j = 0 ; j < members.size() ; j++)
		{
			if(members[j]->name == m->name)
			{
				v->AddError("member " + m->name + " was already defined", this, m->name_pos);
				v->AddInfo("here:", this, members[j]->name_pos);
				delete m;
				return false;
			}
		}
		
		// Fine, add
		AddMember(m);
	}
	
	// Finally, methods
	
	for(uint i = 0 ; i < cl->methods.size() ; i++)
	{
		// Apply template parameters
		Prototype *p = cl->methods[i]->proto->ReplaceTemplateParams(tmap);
		
		// Check types' validity
		success = v->ValidateType(p->rtype, p->rtype_pos);
		if(!success)
		{
			delete p;
			return false;
		}
		
		for(uint j = 0 ; j < p->args.size() ; j++)
		{
			success = v->ValidateType(p->args[j].type, p->args[j].pos);
			if(!success)
			{
				delete p;
				return false;
			}
		}
		
		// Check selector conflict
		AnswerInfo other = answers[p->selector];
		switch(other.mode)
		{
			case a_member:
			case a_shared_member:
				v->AddError("method " + p->selector + " shadows accessor of member", this, p->pos);
				v->AddInfo("defined here:", this, other.member->pos);
				delete p;
				return false;
			case a_self:
			case a_selfless:
				v->AddError("method " + p->selector + " was already declared", this, p->pos);
				v->AddInfo("here:", this, other.proto->pos);
				delete p;
				return false;
			case a_not:
				// fine
				break;
			default:
				error("Other kinds of answer information should not be there yet");
		}
		
		AddProto(p);
		
		AnswerInfo info;
		info.mode = cl->methods[i]->kind == Method::k_normal ? a_self : a_selfless;
		info.proto = p;
		info.rtype = p->rtype;
		answers[p->selector] = info;
	}
	
	success = CheckShortcutConflicts();
	if(!success)
		return false;
	
	validated = true;
	validating = false;
	validation_stack.pop_back();
	
	return true;
}

bool ClassInst::CheckShortcutConflicts()
{
	for(uint i = 0 ; i < pvec.size() ; i++)
	{
		Prototype *p = pvec[i];
		
		Prototype *curr = p;
		
		while(true)
		{
			Prototype *prev = curr;		// for memory cleanup
			
			// Check if last argument is optional
			if(curr->args.size() > 0 && curr->args.back().type.optional)
			{
				// Yes! Make shortcut
				Prototype *shortcut = new Prototype(*curr);
				shortcut->args.pop_back();
				shortcut->ComputeSignature();
				
				// Check conflict
				AnswerInfo other = answers[shortcut->selector];
				switch(other.mode)
				{
					case a_member:
					case a_shared_member:
						v->AddError("optional argument makes shorcut " + shortcut->selector + " shadow accessor of member", this, p->pos);
						v->AddInfo("defined here:", this, other.member->pos);
						delete shortcut;
						return false;
					case a_self:
					case a_selfless:
						v->AddError("optional argument makes shorcut " + shortcut->selector + " shadow method", this, p->pos);
						v->AddInfo("defined here:", this, other.proto->pos);
						delete shortcut;
						return false;
					case a_shortcut:
						v->AddError("optional argument makes shorcut " + shortcut->selector + " conflict", this, p->pos);
						v->AddInfo("with shortcut for:", this, other.proto->pos);
						delete shortcut;
						return false;
					case a_not:
						// fine
						break;
					default:
						error("Other kinds of answer information should not be there yet");
				}
				
				// No conflict, add
				
				AnswerInfo info;
				info.mode = a_shortcut;
				info.proto = p;
				info.rtype = p->rtype;
				answers[shortcut->selector] = info;
				
				curr = shortcut;
				
				if(prev != p)
					delete prev;
			}
			else
			{
				if(prev != p)
					delete prev;
				break;
			}
		}
	}
	
	return true;
}

void ClassInst::AddMember(Member *m)
{
	members.push_back(m);
	
	// Getter
	Prototype *p = new Prototype;
	
	p->rtype = m->type;
	p->name = m->name;
	p->setter = false;
	
	p->pos = m->pos;
	p->rtype_pos = m->type_pos;

	p->ComputeSignature();
	
	AddProto(p);
	
	AnswerInfo info;
	info.mode = m->shared ? a_shared_member : a_member;
	info.member = m;
	info.rtype = p->rtype;
	answers[p->selector] = info;
	
	// Setter
	p = new Prototype;
	
	p->rtype = MultiType();		// void
	p->name = m->name;
	p->setter = true;
	
	Prototype::Argument arg;
	arg.type = m->type;
	arg.pos = m->pos;
	p->args.push_back(arg);

	p->pos = m->pos;

	p->ComputeSignature();
	
	AddProto(p);
	
	info.rtype = p->rtype;
	answers[p->selector] = info;
}

void ClassInst::AddProto(Prototype *p)
{
	// Sanity check
	if(pmap[p->selector])
		error("ClassInst::AddProto() - prototype already present: " + p->selector);
	
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
		
	for(uint i = 0 ; i < cvec.size() ; i++)
		delete cvec[i];
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
	
	success = ValidateParameterlessInterfaces();
	if(!success)
		return false;
		
	success = ValidateParameterlessClasses();
	if(!success)
		return false;
	
	for(uint i = 0 ; i < cvec.size() ; i++)
	{
		AddInfo("------Class: " + cvec[i]->name->signature);
		//for(uint j = 0 ; j < cvec[i]->pvec.size() ; j++)
		//	AddInfo("\t" + cvec[i]->pvec[j]->signature);
		for(std::map<std::string,ClassInst::AnswerInfo>::iterator j = cvec[i]->answers.begin() ; j != cvec[i]->answers.end() ; j++)
			AddInfo("\tanswers to " + j->first + " -> " + j->second.ToString());
	}
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

bool Validator::ValidateParameterlessInterfaces()
{
	// First instantiate them
	
	for(uint i = 0 ; i < context->interfaces.size() ; i++)
	{
		Interface *iface = context->interfaces[i];
		
		if(iface->params.size() != 0)
			continue;
		
		IfaceInst *inst = new IfaceInst(this, iface);
		
		// Insert new instance
		AddIface(inst);
	}
	
	// From there initiate validation of single interfaces. If required,
	// other instances will be added at the vector's end, and validations
	// will be launched recursively
	
	bool success;
	
	for(uint i = 0 ; i < ivec.size() ; i++)
	{
		success = ivec[i]->Validate();
		if(!success)
			return false;
	}
	
	return true;
}

bool Validator::ValidateParameterlessClasses()
{
	// First instantiate the ones that haven't been yet
	// (the previous validation of interfaces may have created some already)
	
	for(uint i = 0 ; i < context->classes.size() ; i++)
	{
		Class *c = context->classes[i];
		
		if(c->params.size() != 0)
			continue;
		
		ClassInst *prev = cmap[ClassName::Build(c->name)];
		if(prev)
			continue;
		
		ClassInst *inst = new ClassInst(this, c);
		
		// Insert new instance
		AddClass(inst);
	}
	
	// From there initiate validation of single classes. If required,
	// other classes will be added at the vector's end, and validations
	// will be launched recursively
	
	bool success;
	
	for(uint i = 0 ; i < cvec.size() ; i++)
	{
		success = cvec[i]->Validate();
		if(!success)
			return false;
	}
	
	return true;
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

GlobalInst* Validator::GetGlobal(ClassName *name)
{
	IfaceInst *i = imap[name];
	if(i)
		return i;
	
	ClassInst *c = cmap[name];
	if(c)
		return c;
	
	return NULL;
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
