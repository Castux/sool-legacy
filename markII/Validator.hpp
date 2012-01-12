#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "common.hpp"
#include "InterfaceAST.hpp"
#include "Report.hpp"

namespace sool
{
	// The internal representation for types, internized
	// Types can only be built through the Type::Get() static methods
	
	class Validator;
	
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
	
	// The main semantic analyzer
	// It is passed a Context, and decides if it is valid or not,
	// adding some information on the way
	
	class Validator
	{
		friend class Type;
		
		public:
		
		Report report;
		Context *context;	// not owned, will be passed to codegen
		
		Validator(Context *c);
		~Validator();
		
		// Validation entry point
		bool Validate();
		
		private:
		
		// Global work before doing individual classes
		void SortOutExtensions();
		bool CheckClassNames();		// Check unicity, and index by name
		void SortOutTemplates();
		bool CheckTemplateParameters();
		
		// Work on individual classes
		bool ValidateInterface(Class *c);
		bool CheckParentClass(Class *c);	// Check existence of parent class, and resolve type
		
		// Shortcuts
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
	};
}

#endif // VALIDATOR.HPP
