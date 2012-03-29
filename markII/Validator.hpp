#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "AST.hpp"
#include "Report.hpp"

namespace sool
{
	class IfaceInst
	{
		public:
		
		Interface*		iface;		// The interface template
		ClassNameMap	map;		// Maps template parameters to their actual binding (can be empty)
		
		std::string		name;		// The full name, with template arguments
		
		IfaceInst(Interface *i);	// No parameter
	};
	
	typedef std::map<std::string,IfaceInst*> IfaceInstMap;
	
	class Validator
	{
		public:
		
		Report		report;
		Context*	context;
		
		Validator(Context *c);
		~Validator();
		
		// Validation entry point
		bool Validate();
		
		private:
		
		// Reindexing of AST nodes
		
		ClassMap				rawcmap;		// Indexing by name of raw classes (which are all considered templates)
		InterfaceMap			rawimap;		// Indexing by name of raw interfaces (which are all considered templates)
		std::vector<Global*>	globals;		// Shortcut list of all classes and interfaces
		
		// Validator owned in-the-middle helper objects: the "real" classes and interfaces
		
		IfaceInstMap			imap;			// Indexing by full name of interface instances
		
		bool CheckGlobalNames();
		bool CheckTemplateParams();
		
		void InstantiateParameterlessInterfaces();
		
		// Helpers
		Global* LookupGlobal(std::string name);		// check both classes and interfaces in cmap and imap
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
	};
};

#endif // VALIDATOR_HPP
