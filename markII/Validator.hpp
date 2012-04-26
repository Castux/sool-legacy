#ifndef VALIDATOR_HPP
#define VALIDATOR_HPP

#include "AST.hpp"
#include "Report.hpp"

namespace sool
{
	class Validator;
	
	// A unified interface to ifaces and classes, since both can be used
	// in types. It's only used to lookup what methods the class answers to.
	
	class GlobalInst
	{
		public:
		
		virtual bool AnswersTo(std::string selector, MultiType *rtype = NULL) = 0;
		virtual bool Validate() = 0;
	};
	
	class IfaceInst : public GlobalInst
	{
		public:
		
		Validator*		v;			// Shortcut to validator
		
		// Filled by constructor
		
		Interface*		iface;		// The interface template
		ClassNameMap	tmap;		// Maps template parameters to their actual binding (can be empty)
		ClassName*		name;		// The full name, with template arguments
		
		// Filled by Validate() - don't write directly to them, use AddProto()
		
		std::vector<Prototype*>				pvec;		// the instance's prototypes
		ProtoMap							pmap;		// prototypes indexed by selector
		std::map<Prototype*,IfaceInst*>		porigin;	// map from prototypes to the interface they were defined in (useful for embedded ones)
		
		IfaceInst(Validator *vali, Interface *i);
		IfaceInst(Validator *vali, Interface *i, std::vector<ClassName*> params);	// With parameters, given in declaration order
		~IfaceInst();
		
		bool Validate();
		void AddProto(Prototype* p, IfaceInst* origin = NULL);		// Insert prototype in pmap and porigin. By default, origin is oneself
		
		// After validation lookup methods
		// They should all assert validation before doing anything,
		// because some interfaces can be spawned on the fly after the
		// first round of validations, and we might have forgotten to do it
		
		bool Contains(Prototype *p);
		bool AnswersTo(std::string selector, MultiType *rtype = NULL);
		
		// Recursion guards
		bool validated;
		bool validating;
		static std::vector<IfaceInst*> validation_stack;
	};
	
	class ClassInst : public GlobalInst
	{
		public:
		
		// The different possibilities on how an instance can answer to a message
		
		typedef enum
		{
			a_unknown,			// Not yet checked (default value when accessing map)
			a_not,				// We don't answer to this selector
			a_self,				// We implement it ourself
			a_selfless,			// We have a selfless method for it
			a_member,			// It is an accessor for a member
			a_shared_member,	// It is an accessor for a shared member
			a_embed,			// We can forward it to an embedded member
			a_generic,			// We comply with an interface extended with it
			a_shortcut			// We answer to a method with optional arguments which fits
		} AnswerMode;
		
		class AnswerInfo
		{
			public:
			
			AnswerMode		mode;
			union
			{
				Member*		member;		// Points at the member this is an accessor for
				ClassName*	target;		// Contains the name of the embedded member or the generic class
				Prototype*	proto;		// Contains the actual prototype for self, selfless and shortcuts
			};
			MultiType		rtype;
			
			AnswerInfo() : mode(a_unknown), member(NULL)
			{
			}
			
			std::string ToString();
		};
		
		Validator*		v;
		
		// Filled by constructor
		
		Class*			cl;		// Class template
		ClassNameMap	tmap;	// Type parameters map
		ClassName*		name;	// Full name
		
		// Added by Validate() - do not write, use AddMember() and AddProto()
		
		std::vector<Member*>	members;		// The type corrected members (owned)
		std::vector<Prototype*>	pvec;			// the instance's prototypes (owned)
		ProtoMap				pmap;			// prototypes indexed by selector
		
		// Memoization of what we answer to, indexed by selector
		
		std::map<std::string,AnswerInfo>	answers;
		
		
		ClassInst(Validator *vali, Class *c);	// No parameter
		ClassInst(Validator *vali, Class *c, std::vector<ClassName*> params);	// With parameters, given in order
		~ClassInst();
		
		bool Validate();
		bool CheckShortcutConflicts();
		void AddMember(Member *m);		// This takes care of adding the accessors' prototypes
		void AddProto(Prototype *p);	// This adds to both pvec and pmap
		
		// Lookup
		
		bool AnswersTo(std::string selector, MultiType *rtype = NULL);
		
		// Recursion guards
		bool validated;
		bool validating;
		static std::vector<ClassInst*> validation_stack;
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
		bool ValidateParameterlessInterfaces();
		bool ValidateParameterlessClasses();
		
		bool ValidateClassName(ClassName *cname, SourcePos pos = SourcePos());
		bool ValidateType(Type &t, SourcePos pos = SourcePos());
		bool ValidateType(MultiType &t, SourcePos pos = SourcePos());
		
		// Helpers
		void AddIface(IfaceInst* iface);			// add to both vector and name map
		void AddClass(ClassInst* cl);				// add to both vector and name map
		GlobalInst* GetGlobal(ClassName *name);		// lookup in both imap and cmap
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos());
		void AddError(std::string message, ClassInst *inst, SourcePos position = SourcePos());	// with class instance info bonus if needed
		void AddError(std::string message, IfaceInst *inst, SourcePos position = SourcePos());	// with iface instance info bonus if needed
		void AddInfo(std::string message, ClassInst *inst, SourcePos position = SourcePos());	// with class instance info bonus if needed
		void AddInfo(std::string message, IfaceInst *inst, SourcePos position = SourcePos());	// with iface instance info bonus if needed
		
	};
};

#endif // VALIDATOR_HPP
