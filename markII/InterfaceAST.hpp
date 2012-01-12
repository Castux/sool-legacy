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
		
		typedef enum
		{
			t_num,
			t_bool,
			t_text,
			t_data,
			t_opaque,
			t_named,
			t_unknown
		} Kind;
		
		Kind					kind;
		std::string				name;		// For t_named only. Use "#" for arrays
		std::vector<TypeDecl*>	params;		// For template parameters, owned. Only with t_named
		
		// Useful source code positions
		SourcePos	name_pos;
		
		TypeDecl();
		~TypeDecl();
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
		bool					rbyref;
		
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
	};
	
	typedef std::map<std::string,Member*> MemberMap;
	typedef std::map<std::string,Method*> MethodMap;
	
	// Unified node for classes, structures and extensions
	// It serves for:
	// - normal classes/structures
	// - templates (in which case the 'params' vector is filled with TypeDecl's)
	// - template instances (in which case 'params' is empty, and 'instmap' maps names to types)
	
	class Class : public AST
	{
		public:
		
		bool	structure;
		bool	extension;
		
		std::string					name;		// In instances, this is the full name
		std::vector<TypeDecl*>		params;		// For templates only: template parameters, owned
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
		
		// Validation steps
		bool validating_interface;		// circular inheritance guard
		bool valid_interface;
		bool valid_code;
		
		// Lookup
		Member *GetMember(std::string name);
		
		Class();
		~Class();
		
		bool IsTemplate();
		bool IsInstance();
		
		std::string Kind();
	};
	
	
	// Context is the top level object, it basically holds the global
	// scope. That is, classes and templates.
	
	typedef std::map<std::string,Class*> ClassMap;
	
	class Context
	{
		public:
		
		std::vector<Class*> classes;	// owned
		std::vector<Class*> templates;	// owned
		std::vector<Class*> extensions;	// owned
		
		ClassMap cmap;				// An indexing of classes and templates by name
		
		Class* Get(std::string);	// Find class or template by name
		Class *Instantiate(Class *templ, std::vector<Type*> params);
		
		~Context();
	};
}

#endif // INTERFACEAST_HPP

