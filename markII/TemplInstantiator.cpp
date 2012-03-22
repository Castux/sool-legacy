#include "TemplInstantiator.hpp"

using namespace sool;

TemplInstantiator::TemplInstantiator(ClassNameMap map)
{
	tmap = map;
}

Member *TemplInstantiator::InstMember(Member *m)
{
	Member *m2 = new Member(*m);
	
	m2->type = m2->type.ReplaceTemplateParams(tmap);
	
	// TODO member init
	
	return m2;
}

Method *TemplInstantiator::InstMethod(Method *m)
{
	Method *m2 = new Method(*m);
	
	m2->rtype = m2->rtype.ReplaceTemplateParams(tmap);
	
	for(uint i = 0 ; i < m2->args.size() ; i++)
		m2->args[i].type = m2->args[i].type.ReplaceTemplateParams(tmap);
	
	// TODO body
	
	return m2;
}

Class *TemplInstantiator::InstClass(Class *c)
{
	Class *c2 = new Class(*c);
	
	c2->pname = c2->pname->ReplaceTemplateParams(tmap);
	
	for(uint i = 0 ; i < c2->members.size() ; i++)
		c2->members[i] = InstMember(c2->members[i]);
	
	for(uint i = 0 ; i < c2->methods.size() ; i++)
		c2->methods[i] = InstMethod(c2->methods[i]);
	
	// This is a real class, now, make it look so:
	// use the complete name, and erase template parameters
	
	std::vector<ClassName*> params;
	for(uint i = 0 ; i < c2->params.size() ; i++)
		params.push_back(tmap[c2->params[i]]);
	
	c2->name = ClassName::Build(c2->name,params)->signature;
	c2->params.clear();
	
	return c2;
}

