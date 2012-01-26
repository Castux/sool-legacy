#ifndef INTERFACEAST_HPP
#define INTERFACEAST_HPP

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
	
	
	class TypeDecl : public AST
	{
		public:
		
		std::string				name;		// Use "#" for arrays
		std::vector<TypeDecl*>	params;		// For template parameters, owned. Only with t_named
		bool					optional;
		
		// Useful source code positions
		SourcePos	name_pos;
		
		TypeDecl();
		~TypeDecl();
		
		TypeDecl *Copy();
	};
	
	class Member : public AST
	{
		public:
		
		bool		shared;
		bool		internal;
		
		TypeDecl	*tdecl;		// owned, type as parsed
		Type		*type;		// shortcut to resolved type
		std::string	name;
		
		// Initialization
		// Expr *init;
		
		// Useful source code positions
		SourcePos	shared_pos;
		SourcePos	internal_pos;
		SourcePos	name_pos;
		
		Member();
		~Member();
		
		Member *Copy();
	};
	
	class Method : public AST
	{
		public:
		
		struct Argument
		{
			TypeDecl *type;		// owned
			std::string name;
			SourcePos pos;
		};
		
		// Interface
		
		bool					internal;
		bool					selfless;
		bool					foreign;
		
		std::vector<TypeDecl*>	ret_decls;		//owned
		Type					*rtype;
		
		std::string				name;
		bool					setter;
		
		std::vector<Argument>	args;
		
		std::string				signature;
		
		// In case it's automaticaly built from a member
		Member					*member;
		
		// Body
		// Block *body;
		
		// Useful source code positions
		SourcePos	internal_pos;
		SourcePos	selfless_pos;
		SourcePos	rtype_pos;
		SourcePos	rbyref_pos;
		SourcePos	name_pos;
		SourcePos	args_pos;
		SourcePos	interface_pos;
		
		Method();
		~Method();
		
		Method *Copy();
	};
	
	typedef std::map<std::string,Member*> MemberMap;
	typedef std::map<std::string,Method*> MethodMap;
	
	// Unified node for classes (object and value) and extensions
	// It serves for:
	// - normal classes (object and value)
	// - templates (in which case the 'params' vector is filled with TypeDecl's)
	// - template instances (in which case 'params' is empty, and 'instmap' maps names to types)
	
	class Class : public AST
	{
		public:
		
		bool	value;		// Value class, or normal object class?
		
		std::string					name;		// In instances, this is the full name
		std::vector<std::string>	params;		// For templates only: template parameters, owned
		TypeMap						instmap;	// For instances only: map to types
		
		TypeDecl	*ptype;		// Parent's name as is parsed, owned
		Class		*pclass;	// Parent class, resolved, not owned
		
		std::vector<Member*> members;	// owned
		std::vector<Method*> methods;	// owned
		
		// Indexing by name or signature
		MemberMap mem_map;
		MethodMap meth_map;
		
		// Useful source code positions
		SourcePos	name_pos;
		SourcePos	fullname_pos;
		std::vector<SourcePos> params_pos;
		
		// Shortcut to all types used in this class
		std::vector<TypeDecl*> type_decls;
		
		// Validation steps
		bool validating_interface;		// circular inheritance guard
		bool valid_interface;
		bool valid_code;
		
		// Lookup
		Member *GetMember(std::string name);
		
		Class();
		~Class();
		
		Class *Copy();
		
		bool IsTemplate();
		bool IsInstance();
		
		std::string Kind();
	};
	
	typedef std::map<std::string,Class*> ClassMap;

	class Extension : public AST
	{
		public:
		
		TypeDecl				*type;
		std::vector<Method*>	methods;
		
		std::vector<TypeDecl*>	type_decls;		// shortcut to all types within extension
		
		Extension();
		~Extension();
	};
	
	// Context is the top level object, it basically holds the global
	// scope. That is, classes and templates.
	
	class Context
	{
		public:
		
		// Parsed
		
		std::vector<Class*> classes;	// owned
		std::vector<Extension*> extensions;	// owned
		
		// Analyzed

		std::vector<Class*> templates;	// owned
		std::vector<Class*> instances;	// owned
		ClassMap cmap;					// An indexing of classes and templates by name
		
		Class* Get(std::string);	// Find class or template by name
		Class *Instantiate(Class *templ, std::vector<Type*> params);
		
		~Context();
	};
}

#endif // INTERFACEAST_HPP

