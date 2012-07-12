#ifndef TYPE_HPP
#define TYPE_HPP

#include "common.hpp"

namespace sool
{
	// A handler for the internal representation for types
	// It internizes them
	// Types can only be built through the TypeForge::Get() static methods
	
	class Validator;
	class Class;
	
	class ClassName;
	typedef std::map<std::string,shared_ptr<ClassName> > ClassNameMap;
	typedef shared_ptr<ClassNameMap> ClassNameMapPtr;
	
	class ClassName
	{
		public:
		
		typedef shared_ptr<ClassName> ptr;
		typedef std::vector<ptr> vec;
		
		private:
		
		static ClassNameMapPtr map;	// The map used for internizing: indexed by signature
		
		ClassName();
		
		public:
		
		std::string		name;		// The base name of the class
		ClassName::vec	params;
		
		std::string signature;	// The full canonical name of the class, with '|' and parameters
		
		// Build an internized ClassName
		static ClassName::ptr Build(std::string name);
		static ClassName::ptr Build(std::string name, ClassName::vec params);
		// Get a ClassName by signature
		static ClassName::ptr Get(std::string sig);
		
		// Create new class name by replacing occurences of the keys in the tmap by their values
		ClassName::ptr ReplaceTemplateParams(ClassNameMap &tmap);
	};
	
	// Type is a wider concept: qualifies variables, can be multiple, and void
	
	class Type
	{
		public:
		
		ClassName::ptr	cname;
		bool			optional;
		
		std::string	signature;
		
		Type();
		Type(ClassName::ptr c, bool opt);
		
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
