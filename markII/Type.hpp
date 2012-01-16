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
	typedef std::map<TypeDecl*,Type*> DeclToTypeMap;
	
	class TypeForge
	{
		friend class Validator;
		
		private:
		
		TypeMap tmap;				// Owned types, indexed by signature
		Validator *v;				// Shortcut to the parent Validator, for access to context and reporting
		DeclToTypeMap decl_map;		// Shortcut from declarations to internized types
		
		Type *Internize(Type *t);	// The passed object is deleted if one with same signature is already there
		
		public:
		
		TypeForge(Validator *validator);
		~TypeForge();
		
		// Create and return internized type from declaration
		
		Type *ConvertDecl(TypeDecl* decl);
		
		// Type resolution depends on which class we are in. Some "types" might just be
		// template parameters. In an instance class, we need the instmap, which
		// maps these simple names to types.
		
		Type* Get(TypeDecl* decl);
		Type* Get(std::string sig);
	};
	
}

#endif // TYPE_HPP
