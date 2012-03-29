#include <sstream>

#include "Type.hpp"

using namespace sool;

ClassName::ClassName()
{
}

ClassNameMap ClassName::map;

ClassName *ClassName::Build(std::string name, std::vector<ClassName*> params)
{
	// Build signature
	
	std::string sig;
	
	if(name == "#")
	{
		// Special array case, we know there should be only one parameter
		// thanks to the parser
		
		if(params.size() != 1)
			error("array class name didn't get exactly one parameter");
		
		sig = std::string("#") + params[0]->signature;
	}
	else if(params.size() > 0)
	{
		// Normal case, just cat the params
		
		sig = name + "|";
		
		if(params.size() > 1)
			sig += "(";
		
		for(uint i = 0; i < params.size()-1; i++)
		{
			sig += params[i]->signature;
			sig += ",";
		}
		
		sig += params.back()->signature;
		
		if(params.size() > 1)
			sig += ")";
	}
	else
	{
		sig = name;
	}
	
	// Check if it already exists
	
	ClassName *cname = Get(sig);
	if(cname)
		return cname;
	
	// Make new one otherwise
	
	cname = new ClassName;
	
	cname->name = name;
	cname->params = params;
	cname->signature = sig;
	
	// Add to map
	
	map[sig] = cname;
	
	// And return
	
	return cname;
}

ClassName *ClassName::Get(std::string sig)
{
	ClassNameMap::iterator it = map.find(sig);
	
	if(it != map.end())
		return it->second;
	
	return NULL;
}

void ClassName::Clear()
{
	ClassNameMap::iterator it;
	
	for(it = map.begin(); it != map.end(); it++)
		delete it->second;
}

ClassName *ClassName::ReplaceTemplateParams(ClassNameMap &tmap)
{
	// Look for base name in replacement map
	ClassNameMap::iterator it = tmap.find(name);
	
	// Found!
	if(it != tmap.end())
	{
		ClassName *cl = it->second;
		
		// Sanity check, our main name is itself a param, there should not be any subnames:
		// T|(A,B,C) cannot exist if T is a template parameter in the current class
		
		if(params.size() > 0)
			error("a template parameter is used as template");		// This should be caught upstream
		
		// Normal case: that's the proper replacement for a simple param that appears alone
		return cl;
	}
	
	// Not found! If we have no subnames, we're a plain and simple class name. Nothing to do.
	if(params.size() == 0)
		return this;
	
	// If we do have subnames, there might be some replacements to do there. Recurse.
	std::vector<ClassName*> subnames;
	
	for(uint i = 0; i < params.size(); i++)
		subnames.push_back(params[i]->ReplaceTemplateParams(tmap));
	
	// And build new ClassName (it might be the same, but who cares, it's internized)
	return Build(name, subnames);
}


Type::Type() : cname(NULL), optional(false)
{
}

Type::Type(ClassName *c, bool opt) : cname(c), optional(opt)
{
	signature = c->signature;
	if(opt)
		signature += "?";
}

Type Type::ReplaceTemplateParams(ClassNameMap &tmap)
{
	ClassName *cl = cname->ReplaceTemplateParams(tmap);
	return Type(cl, optional);
}

bool Type::operator==(const Type& other)
{
	return cname == other.cname && optional == other.optional;
}

bool Type::operator!=(const Type& other)
{
	return !(*this == other);
}

MultiType::MultiType()
{
}

MultiType::MultiType(Type t)
{
	types.push_back(t);
	signature = t.signature;
}

MultiType::MultiType(std::vector<Type> sub)
{
	if(sub.size() == 0)
	{
		signature = "void";
	}
	else
	{
		for(uint i = 0 ; i < sub.size() ; i++)
		{
			types.push_back(sub[i]);
			signature += sub[i].signature;
			if(i < sub.size()-1)
				signature += ",";
		}
	}
}

MultiType MultiType::ReplaceTemplateParams(ClassNameMap &tmap)
{
	std::vector<Type> subtypes;
	
	for(uint i = 0 ; i < types.size() ; i++)
		subtypes.push_back(types[i].ReplaceTemplateParams(tmap));
	
	return MultiType(subtypes);
}

bool MultiType::operator==(const MultiType& other)
{
	if(types.size() != other.types.size())
		return false;
	
	for(uint i = 0 ; i < types.size() ; i++)
	{
		if(types[i] != other.types[i])
			return false;
	}
	
	return true;
}

bool MultiType::operator!=(const MultiType& other)
{
	return !(*this == other);
}
