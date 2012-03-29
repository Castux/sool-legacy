#ifndef AST_HPP
#define AST_HPP

#include <vector>
#include <map>

#include "common.hpp"
#include "SourcePos.hpp"
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
		~Member();
	};
	
	class Prototype : public AST
	{
		public:
		
		class Argument : public AST
		{
			public:
			
			Type type;
			std::string name;		// name is optional, as Prototype is also used by Interface
		};
		
		MultiType				rtype;
		
		std::string				name;
		bool					setter;
		
		std::vector<Argument>	args;
	};
	
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
		
		Kind		kind;
		Prototype*	proto;
		
		// Body
		// Block *body;
		
		// Useful source code positions
		SourcePos	kind_pos;
		
		Method();
		~Method();
	};
	
	class TemplateParam : public AST
	{
		public:
		
		std::string		bound;
		std::string		name;
	};
	
	class Class : public AST
	{
		public:
		
		typedef enum
		{
			k_value,
			k_object
		} Kind;
		
		Kind						kind;		// Value class, or object class?
		
		std::string					name;		// Base name
		std::vector<TemplateParam>	params;		// Template parameters, may be empty
		
		std::vector<Member*>	members;	// owned
		std::vector<Method*>	methods;	// owned
		std::vector<ClassName*>	embeds;
		
		// Useful source code positions
		SourcePos	name_pos;
		SourcePos	fullname_pos;		// includes template parameters
		
		~Class();
		
		std::string KindToString();
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
		
		ClassName*					cname;
		
		// or an extension to a class/interface template
		// extend Name|(Iface1 T, Iface2 U)
		
		std::string					name;
		std::vector<TemplateParam>	params;
		
		std::vector<Method*>		methods;
		
		Extension();
		~Extension();
	};
	
	class Interface : public AST
	{
		public:
		
		std::string					name;		// Base name
		std::vector<TemplateParam>	params;		// Template parameters, may be empty
		
		std::vector<ClassName*>		embeds;		// Embedded interfaces
		std::vector<Prototype*>		protos;		// Owned
		
		~Interface();
	};
	
	struct Context
	{
		public:
		
		std::vector<Class*> 		classes;
		std::vector<Extension*>		extensions;
		std::vector<Interface*>		interfaces;
		
		~Context();
	};
}



#endif // AST_HPP

