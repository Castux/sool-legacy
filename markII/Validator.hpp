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
		ClassName*		name;		// The full name, with template arguments
		
		std::vector<Prototype*>				pvec;		// the instance's prototypes		DONT WRITE (use AddProto)
		ProtoMap							pmap;		// prototypes indexed by selector	DONT WRITE (use AddProto)
		std::map<Prototype*,IfaceInst*>		porigin;	// map from prototypes to the interface they were defined in (useful for embedded ones) DONT WRITE (use AddProto)
		
		IfaceInst(Validator *vali, Interface *i);	// No parameter
		IfaceInst(Validator *vali, Interface *i, std::vector<ClassName*> params);	// With parameters, given in order
		~IfaceInst();
		
		bool Validate();
		void AddProto(Prototype* p, IfaceInst* origin = NULL);		// Insert prototype in pmap and porigin. By default, origin is oneself
		
		// Guards
		bool validated;
		bool validating;
		static std::vector<IfaceInst*> validation_stack;
	};
	
	class ClassInst
	{
		public:
		
		Validator*		v;
		
		Class*			cl;		// Class template
		ClassNameMap	tmap;	// Type parameters map
		ClassName*		name;	// Full name
		
		ClassInst(Validator *vali, Class *c);	// No parameter
		ClassInst(Validator *vali, Class *c, std::vector<ClassName*> params);	// With parameters, given in order
		bool validated;
		bool validating;
	};
	
	typedef std::map<ClassName*,IfaceInst*> IfaceInstMap;
	typedef std::map<ClassName*,ClassInst*> ClassInstMap;
	
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
		
		GlobalMap				global_map;		// Indexing by name of globals
		
		// Validator owned in-the-middle helper objects: the "real" classes and interfaces
		// Don't write to them! Use AddIface() instead.
		
		std::vector<IfaceInst*>	ivec;			// Linear storage of interface instances
		IfaceInstMap			imap;			// Indexing by full name (as ClassName) of interface instances
		
		std::vector<ClassInst*> cvec;			// Linear storage of class instances
		ClassInstMap			cmap;			// Indexing by ClassName of class instances
		
		bool CheckGlobalNames();
		bool CheckTemplateParams();
		void InstantiateParameterlessInterfaces();
		
		bool ValidateClassName(ClassName *cname, SourcePos pos = SourcePos());
		bool ValidateType(Type &t, SourcePos pos = SourcePos());
		bool ValidateType(MultiType &t, SourcePos pos = SourcePos());
		
		// Helpers
		void AddIface(IfaceInst* iface);			// add to both vector and name map
		void AddClass(ClassInst* cl);				// add to both vector and name map
		
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
		void AddError(std::string message, ClassInst *inst, SourcePos position = SourcePos());	// with class instance info bonus if needed
		void AddError(std::string message, IfaceInst *inst, SourcePos position = SourcePos());	// with iface instance info bonus if needed
		void AddInfo(std::string message, ClassInst *inst, SourcePos position = SourcePos());	// with class instance info bonus if needed
		void AddInfo(std::string message, IfaceInst *inst, SourcePos position = SourcePos());	// with iface instance info bonus if needed
		
	};
};

#endif // VALIDATOR_HPP
