#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "common.hpp"
#include "InterfaceAST.hpp"
#include "Report.hpp"
#include "Type.hpp"

namespace sool
{
	// The main semantic analyzer
	// It is passed a Context, and decides if it is valid or not,
	// adding some information on the way
	
	class Validator
	{
		friend class TypeForge;
		
		public:
		
		Report report;
		TypeForge tforge;
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
		bool TreatMembers(Class *c);
		
		// Shortcuts
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
	};
}

#endif // VALIDATOR.HPP
