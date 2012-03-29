#ifndef TYPE_HPP
#define TYPE_HPP

#include <map>
#include <vector>

#include "common.hpp"

namespace sool
{
	// A handler for the internal representation for types
	// It internizes them
	// Types can only be built through the TypeForge::Get() static methods
	
	class Validator;
	class Class;
	
	class ClassName;
	typedef std::map<std::string,ClassName*> ClassNameMap;
	
	class ClassName
	{
		// private: FIXME
		public:
		
		static ClassNameMap map;	// The map used for internizing: indexed by signature
		
		ClassName();
		
		public:
		
		std::string name;		// The base name of the class
		std::vector<ClassName*> params;
		
		std::string signature;	// The full canonical name of the class, with '|' and parameters
		
		// Build an internized ClassName
		static ClassName *Build(std::string name, std::vector<ClassName*> params);
		// Get a ClassName by signature
		static ClassName *Get(std::string sig);
		
		// Empty database
		static void Clear();
		
		// Create new class name by replacing occurences of the keys in the tmap by their values
		ClassName *ReplaceTemplateParams(ClassNameMap &tmap);
	};
	
	// Type is a wider concept: qualifies variables, can be multiple, and void
	
	class Type
	{
		public:
		
		ClassName	*cname;
		bool		optional;
		
		std::string	signature;
		
		Type();
		Type(ClassName *c, bool opt);
		
		// Replace class name in place by replacing occurences of the keys in the tmap by their values
		Type ReplaceTemplateParams(ClassNameMap &tmap);
		
		bool operator==(const Type& other);
		bool operator!=(const Type& other);
	};
	
	class MultiType
	{
		public:
		
		std::vector<Type> types;
		
		std::string signature;
		
		MultiType();
		MultiType(Type t);
		MultiType(std::vector<Type> subtypes);
		
		// Replace class name in place by replacing occurences of the keys in the tmap by their values
		MultiType ReplaceTemplateParams(ClassNameMap &tmap);
		
		bool operator==(const MultiType& other);
		bool operator!=(const MultiType& other);
	};

}

#endif // TYPE_HPP
