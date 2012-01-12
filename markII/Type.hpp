#ifndef TYPE_HPP
#define TYPE_HPP

#include <map>

#include "common.hpp"

namespace sool
{
	// A handler for the internal representation for types
	// It internizes them
	// Types can only be built through the TypeForge::Get() static methods
	
	class Validator;
	class Class;
	class TypeDecl;
	
	class Type
	{
		friend class TypeForge;
		
		// Type interface
		
		private:
		
		Type(Class *cl);
		
		public:
		
		std::string signature;
		Class *GetClass();
		
		private:
		
		Class *c;
	};
	
	typedef std::map<std::string,Type*> TypeMap;
	
	class TypeForge
	{
		friend class Validator;
		
		private:
		
		TypeMap tmap;				// Owned types, indexed by signature
		Validator *v;				// Shortcut to the parent Validator, for access to context and reporting
		
		Type *Internize(Type *t);	// The passed object is deleted if one with same signature is already there
		
		public:
		
		TypeForge(Validator *validator);
		~TypeForge();
		
		// Return internized type from declaration or signature.
		// Type resolution depends on which class we are in. Some "types" might just be
		// template parameters. In an instance class, we need the instmap, which 
		// maps these simple names to types.
		
		Type* Get(TypeDecl* decl, TypeMap *instmap);
		Type* Get(std::string sig, TypeMap *instmap);
	};
	
}

#endif // TYPE_HPP
