#include <sstream>

#include "Type.hpp"
#include "InterfaceAST.hpp"
#include "Validator.hpp"

using namespace sool;

Type::Type(Class* cl) : c(cl)
{
	signature = c->name;
}

Class *Type::GetClass()
{
	return c;
}

TypeForge::TypeForge(Validator *validator) : v(validator)
{
}

TypeForge::~TypeForge()
{
	TypeMap::iterator it;
	
	for(it = tmap.begin(); it != tmap.end(); it++)
		delete it->second;
}

Type* TypeForge::Get(std::string sig)
{
	TypeMap::iterator it = tmap.find(sig);
	
	if(it != tmap.end())
		return it->second;
	
	return NULL;
}

Type* TypeForge::Get(TypeDecl* decl)
{
	DeclToTypeMap::iterator it = decl_map.find(decl);
	
	if(it != decl_map.end())
		return it->second;
	
	return NULL;
}

Type *TypeForge::ConvertDecl(TypeDecl* decl)
{
	// Simple case: not a template, just get the class
	
	if(decl->params.size() == 0)
	{
		Class *c = v->context->Get(decl->name);
		if(!c)
		{
			// Not found, maybe it is a template parameter in the class where it was defined
			TypeMap *instmap = &decl->def_class->instmap;
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
		Type *t = new Type(c);
		Type *intern = Internize(t);
		
		return intern;
	}
	
	// Less simple case, template instantiation
	
	// Check there is a template by that name
	
	Class *c = v->context->Get(decl->name);
	if(!c)
	{
		v->AddError("unknown template " + decl->name, decl->name_pos);
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
		Type *t = Get(decl->params[i]);
		if(!t)
			return NULL;
		
		params.push_back(t);
	}
	
	// Now it gets ugly: request the corresponding class
	
	Class *inst = v->context->Instantiate(c,params);
	
	// Finally build the type
	
	Type *t = new Type(inst);
	Type *intern = Internize(t);
	
	// Save in shortcut map
	
	decl_map[decl] = intern;
	
	return intern;
}

Type *TypeForge::Internize(Type *t)
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
