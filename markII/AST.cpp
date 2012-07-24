#include "AST.hpp"
#include "Type.hpp"

using namespace sool;
using namespace AST;

Member::Member() : shared(false)
{
}

Member::ptr Member::ReplaceTemplateParams(ClassNameMap &tmap)
{
	Member::ptr m(new Member(*this));
	m->type = type.ReplaceTemplateParams(tmap);
	
	return m;
}

std::string Class::KindToString()
{
	std::string res;
	if(kind == k_value)
		res = "value class";
	else
		res = "object class";
	
	return res;
}

std::string Class::FancyName()
{
	return KindToString() + " " + name;
}

std::string Interface::FancyName()
{
	return std::string("interface ") + name;
}

void Prototype::ComputeSignature()
{
	std::vector<Type> atypes;
	for(uint i = 0 ; i < args.size() ; i++)
		atypes.push_back(args[i].type);
	
	atype = MultiType(atypes);
	selector = name + (setter ? "=" : "") + ":" + atype.signature;
	signature = rtype.signature + ":" + selector;
}

bool Prototype::SameSelector(Prototype::ptr other)
{
	return (name == other->name &&
			setter == other->setter &&
			atype == other->atype);
}

bool Prototype::operator==(Prototype::ptr other)
{
	return (rtype == other->rtype) && SameSelector(other);
}

Prototype::ptr Prototype::ReplaceTemplateParams(ClassNameMap &tmap)
{
	Prototype::ptr p(new Prototype(*this));
	
	p->rtype = rtype.ReplaceTemplateParams(tmap);
	
	for(uint i = 0 ; i < args.size() ; i++)
		p->args[i].type = args[i].type.ReplaceTemplateParams(tmap);
	
	p->ComputeSignature();
	return p;
}
