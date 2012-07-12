#ifndef AST_HPP
#define AST_HPP

#include "common.hpp"
#include "SourceFile.hpp"
#include "Type.hpp"

// Here we define the AST objects for the interfaces

namespace sool
{
	// Root class for nodes that come directly from parsing the source
	
	class AST
	{
		public:
		
		SourcePos pos;
	};
	
	class Member : public AST
	{
		public:
		
		bool		shared;
		Type		type;
		std::string	name;
		
		// Initialization
		// Expr *init;
		
		// Useful source code positions
		SourcePos	shared_pos;
		SourcePos	type_pos;
		SourcePos	name_pos;
		
		Member();
		
		// Build new member with type substitution
		Member *ReplaceTemplateParams(ClassNameMap &tmap);
	};
	
	class Prototype : public AST
	{
		public:
		
		typedef shared_ptr<Prototype> ptr;
		typedef std::vector<ptr> vec;
		
		class Argument : public AST
		{
			public:
			
			Type type;
			std::string name;		// name is optional, as Prototype is also used by Interface
		};
		
		// Parsed
		
		MultiType				rtype;
		std::string				name;
		bool					setter;
		std::vector<Argument>	args;
		
		SourcePos				rtype_pos;
		
		// Computed
		
		MultiType				atype;		// Combined argument types
		std::string				selector;
		std::string				signature;
		
		void ComputeSignature();	// and atype and selector
		
		// Comparison (more efficient that comparing strings...)
		
		bool SameSelector(Prototype::ptr other);
		bool operator==(Prototype::ptr other);
		
		// Build a new prototype with type substitutions
		Prototype::ptr ReplaceTemplateParams(ClassNameMap &tmap);
	};
	
	typedef std::map<std::string,Prototype::ptr> ProtoMap;
	
	class Method : public AST
	{
		public:
		
		// Interface
		
		typedef enum
		{
			k_normal,
			k_selfless,
			k_foreign
		} Kind;
		
		Kind			kind;
		Prototype::ptr	proto;
		
		// Body
		// Block *body;
		
		// Useful source code positions
		SourcePos	kind_pos;
		
		Method();
	};
	
	class TemplateParam : public AST
	{
		public:
		
		ClassName::ptr	bound;
		std::string		name;
	};
	
	class Global : public AST
	{
		public:
		
		std::string					name;		// Base name
		std::vector<TemplateParam>	params;		// Template parameters, may be empty
		
		SourcePos	name_pos;
		
		virtual std::string FancyName() = 0;
		virtual bool IsClass() = 0;
		
		bool IsInterface()
		{
			return !IsClass();
		}
	};
	
	typedef std::map<std::string,Global*> GlobalMap;
	
	class Class : public Global
	{
		public:
		
		typedef enum
		{
			k_value,
			k_object
		} Kind;
		
		Kind					kind;		// Value class, or object class?
		
		// name and parameters are inherited from Global
		
		std::vector<Member*>	members;	// owned
		std::vector<Method*>	methods;	// owned
		ClassName::vec			embeds;
		
		// Useful source code positions
		
		SourcePos				fullname_pos;		// includes template parameters
		std::vector<SourcePos>	embed_pos;
		
		~Class();
		
		std::string KindToString();
		bool IsClass()
		{
			return true;
		};
		
		std::string FancyName();
	};
	
	typedef std::map<std::string,Class*> ClassMap;
	
	class Extension : public AST
	{
		public:
		
		// Difficulty here. We can have either an extension for a full fledged class:
		// extend num
		// extend Foo
		// extend Table|(text,Bar)
		// extend #Bar
		
		ClassName::ptr				cname;
		
		// or an extension to a class/interface template
		// extend Name|(Iface1 T, Iface2 U)
		
		std::string					name;
		std::vector<TemplateParam>	params;
		
		std::vector<Method*>		methods;
		
		Extension();
		~Extension();
	};
	
	typedef std::map<std::string,Extension*> ExtensionMap;
	
	class Interface : public Global
	{
		public:
		
		// name and parameters are inherited from Global
		
		ClassName::vec				embeds;	// Embedded interfaces
		Prototype::vec				protos;
		
		std::vector<SourcePos>		embed_pos;
		
		std::string FancyName();
		bool IsClass()
		{
			return false;
		};
	};
	
	typedef std::map<std::string,Interface*> InterfaceMap;
	
	struct Context
	{
		public:
		
		std::vector<Class*>			classes;
		std::vector<Extension*>		extensions;
		std::vector<Interface*>		interfaces;
		
		std::vector<Global*>		globals;		// For the sake of knowing in what order they appeared
		
		~Context();
	};
}



#endif // AST_HPP

