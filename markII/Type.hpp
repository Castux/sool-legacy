#ifndef TYPE_HPP
#define TYPE_HPP

#include <map>

#include "common.hpp"

namespace sool
{
	// The internal representation for types, internized
	// Types can only be built through the Type::Get() static methods
	
	class Validator;
	class Class;
	class TypeDecl;
	
	class Type;
	typedef std::map<std::string,Type*> TypeMap;
	
	class Type
	{
		friend class Validator;
		
		// Internalization stuff
		private:
		
		static TypeMap tmap;				// Owned types, indexed by signature
		static Validator *v;				// Shortcut to the Validator
		
		static Type *Internize(Type *t);	// The passed object is deleted if one with same signature is already there
		
		static void Cleanup();				// Free types at program end, called by Validator destructor
		
		public:
		
		// Return internized type from declaration or signature.
		// Type resolution depends on which class we are in. Some "types" might just be
		// template parameters. In an instance class, these are mapped to types.
		// Hence the instmap argument, which is filled in an instance class.
		
		static Type* Get(TypeDecl* decl, TypeMap *instmap);
		static Type* Get(std::string sig, TypeMap *instmap);
		
		// Type interface
		
		protected:
		
		Type();
		
		public:
		
		std::string signature;
		virtual Class *GetClass() = 0;
	};
	
	class ClassType : public Type
	{
		friend class Type;
		
		private:
		
		Class *cl;
		ClassType(Class* c);
		
		public:
		
		Class *GetClass();
	};
}

#endif // TYPE_HPP
