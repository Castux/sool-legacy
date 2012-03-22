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
	
	class Member : public AST
	{
		public:
		
		bool		shared;
		bool		internal;
		
		Type		type;
		std::string	name;
		
		// Initialization
		// Expr *init;
		
		// Useful source code positions
		SourcePos	shared_pos;
		SourcePos	internal_pos;
		SourcePos	type_pos;
		SourcePos	name_pos;
		
		Member();
		~Member();
	};
	
	class Method : public AST
	{
		public:
		
		struct Argument
		{
			Type type;
			std::string name;
			SourcePos type_pos;
			SourcePos name_pos;
		};
		
		// Interface
		
		bool					internal;
		bool					selfless;
		bool					foreign;
		
		MultiType				rtype;
		
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
		SourcePos	name_pos;
		SourcePos	args_pos;
		SourcePos	interface_pos;
		
		Method();
		~Method();
	};
	
	typedef std::map<std::string,Member*> MemberMap;
	typedef std::map<std::string,Method*> MethodMap;
	
	// Unified node for classes (object and value) and extensions
	// It serves for:
	// - normal classes (object and value)
	// - templates (in which case the 'params' vector is filled with TypeDecl's)
	
	class Class : public AST
	{
		public:
		
		bool	value;		// Value class, or normal object class?
		
		std::string					name;		// In instances, this is the full name
		std::vector<std::string>	params;		// For templates only: template parameters, owned
		
		ClassName	*pname;		// Parent's name
		
		std::vector<Member*> members;	// owned
		std::vector<Method*> methods;	// owned
		
		// Indexing by name or signature
		MemberMap mem_map;
		MethodMap meth_map;
		
		// Useful source code positions
		SourcePos	name_pos;
		SourcePos	fullname_pos;
		std::vector<SourcePos> params_pos;
		SourcePos	parent_pos;
		
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
	
	typedef std::map<std::string,Class*> ClassMap;

	class Extension : public AST
	{
		public:
		
		ClassName				*cname;
		std::vector<Method*>	methods;
		
		Extension();
		~Extension();
	};
}

#endif // INTERFACEAST_HPP

