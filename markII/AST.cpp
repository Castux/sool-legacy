#include "AST.hpp"
#include "Type.hpp"

using namespace sool;

Member::Member() : shared(false)
{
}

Member::~Member()
{
}

Method::Method() : proto(NULL)
{
}

Method::~Method()
{
	delete proto;
}

Class::~Class()
{
	for(uint i = 0 ; i < members.size() ; i++)
		delete members[i];
		
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
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

Extension::Extension() : cname(NULL)
{
}

Extension::~Extension()
{
	for(uint i = 0 ; i < methods.size() ; i++)
		delete methods[i];
}

std::string Interface::FancyName()
{
	return std::string("interface ") + name;
}

Interface::~Interface()
{
	for(uint i = 0 ; i < protos.size() ; i++)
		delete protos[i];
}

Context::~Context()
{
	for(uint i = 0 ; i < classes.size() ; i++)
		delete classes[i];
	
	for(uint i = 0 ; i < interfaces.size() ; i++)
		delete interfaces[i];
	
	for(uint i = 0 ; i < extensions.size() ; i++)
		delete extensions[i];
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

bool Prototype::SameSelector(Prototype *other)
{
	return (name == other->name &&
			setter == other->setter &&
			atype == other->atype);
}

bool Prototype::operator==(Prototype *other)
{
	return (rtype == other->rtype) && SameSelector(other);
}

Prototype* Prototype::ReplaceTemplateParams(ClassNameMap &tmap)
{
	Prototype *p = new Prototype(*this);
	
	p->rtype = rtype.ReplaceTemplateParams(tmap);
	
	for(uint i = 0 ; i < args.size() ; i++)
		p->args[i].type = args[i].type.ReplaceTemplateParams(tmap);
	
	p->ComputeSignature();
	return p;
}
