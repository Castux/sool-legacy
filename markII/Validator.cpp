#include <sstream>

#include "Validator.hpp"

using namespace sool;

/****************/
/***** Type *****/
/****************/

TypeMap Type::tmap;
Validator *Type::v;

Type::Type()
{
}

Type* Type::Get(std::string sig, TypeMap *instmap)
{
	TypeMap::iterator it = tmap.find(sig);
	
	if(it != tmap.end())
		return it->second;
	
	// Not found, check if it's a template parameter
	it = instmap->find(sig);
	
	if(it != instmap->end())
		return it->second;
	
	return NULL;
}

Type* Type::Get(TypeDecl* decl, TypeMap *instmap)
{
	// Simple case: not a template, just get the class
	
	if(decl->params.size() == 0)
	{
		Class *c = v->context->Get(decl->name);
		if(!c)
		{
			// Not found, maybe it is a template parameter
			
			TypeMap::iterator it = instmap->find(decl->name);
			if(it != instmap->end())
			{
				// Yes, found
				return it->second;
			}
			else
			{
				v->AddError("unknown class " + decl->name, decl->name_pos);
				return NULL;
			}
		}
		
		// Found something. If it's a template, no good, we don't have parameters
		
		if(c->IsTemplate())
		{
			v->AddError("template " + c->Kind() + " " + c->name + " used without parameters", decl->pos);
			return NULL;
		}
		
		// Otherwise, ok. Build type.
		Type *t = new ClassType(c);
		Type *intern = Internize(t);
		
		return intern;
	}
	
	// Less simple case, template instantiation
	
	// Check there is a template by that name
	
	Class *c = v->context->Get(decl->name);
	if(!c)
	{
		v->AddError("unknown template class " + decl->name, decl->name_pos);
		return NULL;
	}
	
	// Check that it is indeed a template
	
	if(!c->IsTemplate())
	{
		v->AddError(c->Kind() + " " + c->name + " used as a template", decl->pos);
		v->AddInfo("but not declared as one:", c->name_pos);
		return NULL;
	}
	
	// Check that the number of parameters match
	
	uint usenum = decl->params.size();
	uint declnum = c->params.size();
	if(usenum != declnum)
	{
		std::stringstream tmp;
		tmp << "template " << c->Kind() << " " << c->name << " used with " << usenum << " parameter";
		if(usenum > 1)
			tmp << "s";
		
		v->AddError(tmp.str(), decl->pos);
		
		std::stringstream tmp2;
		tmp2 << "but declared with " << declnum;
		
		v->AddInfo(tmp2.str(), c->fullname_pos);
		
		return NULL;
	}
	
	// Recursively get subtypes
	
	std::vector<Type*> params;
	
	for(uint i = 0; i < usenum; i++)
	{
		Type *t = Get(decl->params[i], instmap);
		if(!t)
		{
			return NULL;
		}
		
		params.push_back(t);
	}
	
	// Now it gets ugly: request the corresponding class
	
	Class *inst = v->context->Instantiate(c,params);
	
	// Finally build the type
	
	Type *t = new ClassType(inst);
	Type *intern = Internize(t);
	
	return intern;
}

Type *Type::Internize(Type *t)
{
	TypeMap::iterator it = tmap.find(t->signature);
	
	if(it == tmap.end())
	{
		tmap[t->signature] = t;
		return t;
	}
	else
	{
		delete t;
		return it->second;
	}
}

ClassType::ClassType(Class* c) : cl(c)
{
	signature = c->name;
}

Class *ClassType::GetClass()
{
	return cl;
}

/*********************/
/***** Validator *****/
/*********************/

Validator::Validator(Context *c) : context(c)
{
	// Give handle to type system
	Type::v = this;
}

Validator::~Validator()
{
}

bool Validator::Validate()
{
	return ValidateInterfaces();
}

bool Validator::ValidateInterfaces()
{
	SortOutExtensions();
	
	if(!CheckClassNames())
		return false;
	
	SortOutTemplates();
	
	if(!CheckParentClasses())
		return false;
	
	AddInfo("classes");
	
	for(uint i = 0; i < context->classes.size() ; i++)
		AddInfo(context->classes[i]->name);
	
	AddInfo("templates");
	
	for(uint i = 0; i < context->templates.size() ; i++)
		AddInfo(context->templates[i]->name);
	
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

bool Validator::CheckParentClasses()
{
	bool success = true;
	
	for(uint i = 0; i < context->classes.size(); i++)
	{
		Class *c = context->classes[i];
		
		if(!c->ptype)
			continue;
		
		// Deal with structs
		if(c->structure)
		{
			AddError("structures do not support inheritance", c->ptype->pos);
			success = false;
			continue;
		}
		
		// Get an actual type from declaration
		Type *t = Type::Get(c->ptype, &c->instmap);
		
		/*
		// Check it is indeed a class (not a struct)
		if(t->GetClass()->structure)
		{
			//
		}*/
	}
	
	return success;
}

void Validator::AddError(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Error, message, position);
}

void Validator::AddInfo(std::string message, SourcePos position)
{
	report.Add("validator", Diagnostic::Info, message, position);
}
