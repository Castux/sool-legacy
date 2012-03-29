#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "AST.hpp"
#include "Report.hpp"

namespace sool
{
	class Validator;
	
	class IfaceInst
	{
		public:
		
		Validator*		v;			// Shortcut to validator
		
		Interface*		iface;		// The interface template
		ClassNameMap	tmap;		// Maps template parameters to their actual binding (can be empty)
		std::string		name;		// The full name, with template arguments
		
		std::vector<Prototype*>		pvec;		// the instance's prototypes		Don't write! Use AddProto!
		ProtoMap					pmap;		// prototypes indexed by selector	Ditto
		
		
		IfaceInst(Validator *vali, Interface *i);	// No parameter
		bool Validate();
		void AddProto(Prototype* p);
		
		// Overwork guard
		bool validated;
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
		
		// Reindexing of AST nodes
		
		ClassMap				rawcmap;		// Indexing by name of raw classes (which are all considered templates)
		InterfaceMap			rawimap;		// Indexing by name of raw interfaces (which are all considered templates)
		std::vector<Global*>	globals;		// Shortcut list of all classes and interfaces
		
		// Validator owned in-the-middle helper objects: the "real" classes and interfaces
		// Don't write to them! Use AddIface() instead.
		
		std::vector<IfaceInst*>	ivec;			// Linear storage of interface instances
		IfaceInstMap			imap;			// Indexing by full name of interface instances
		
		bool CheckGlobalNames();
		bool CheckTemplateParams();
		void InstantiateParameterlessInterfaces();
		
		bool ValidateType(Type &t, SourcePos pos = SourcePos());
		bool ValidateType(MultiType &t, SourcePos pos = SourcePos());
		
		// Helpers
		Global* LookupGlobal(std::string name);		// check both classes and interfaces in cmap and imap
		void AddIface(IfaceInst* iface);			// add to both vector and name map
		
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
	};
};

#endif // VALIDATOR_HPP
