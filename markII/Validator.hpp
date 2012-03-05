#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "common.hpp"
#include "InterfaceAST.hpp"
#include "Report.hpp"
#include "Type.hpp"
#include "Parser.hpp"

namespace sool
{
	// Context is the top level object, it basically holds the global
	// scope. That is, classes and templates.
	
	class Context
	{
		public:
		
		ClassMap cmap;				// An indexing of classes and templates by name, owned
		
		Class* Get(std::string);	// Find class or template by name
		Class *Instantiate(Class *templ, std::vector<Type*> params);
		
		~Context();
	};
	
	// The main semantic analyzer
	// It is passed a Context, and decides if it is valid or not,
	// adding some information on the way
	
	class Validator
	{
		public:
		
		Report report;
		Context *context;	// not owned, will be passed to codegen
		
		Validator();
		~Validator();
		
		// Validation entry point
		bool Validate(ParseResult result);
		
		private:
		
		// Global work before doing individual classes
		bool FillContextWithClasses(ParseResult result);		// Check unicity, and index by name
		
		// Work on individual classes
		/*
		bool ValidateInterface(Class *c);
		bool CheckParentClass(Class *c);	// Check existence of parent class, and resolve type
		bool TreatMembers(Class *c);
		*/
		
		// Shortcuts
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
	};
}

#endif // VALIDATOR.HPP
