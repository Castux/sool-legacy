#ifndef TEMPLINSTANTIATOR_HPP
#define TEMPLINSTANTIATOR_HPP

#include "common.hpp"
#include "InterfaceAST.hpp"

namespace sool
{
	// The scary object that takes a template, a parameter map, and makes
	// a new class out of it.
	
	// It is a separate object to avoid clogging the AST classes, and it
	// keeps a state to simplify some writing (like avoid to pass the tmap
	// to every function).
	
	// It is basically a boring hierarchy of functions that copy AST nodes
	// and apply type transformations on the go. Nothing complex about it,
	// maybe just tedious.
	
	class TemplInstantiator
	{
		ClassNameMap tmap;
		
		public:
		
		TemplInstantiator(ClassNameMap map);
		
		// Individual functions for each type of node
		// They are mostly based on the default copy constructor, plus
		// manual call for sub-objects, and types.
		
		Member *InstMember(Member *m);
		Method *InstMethod(Method *m);
		Class *InstClass(Class *cl);
	};
};

#endif // TEMPLINSTANTIATOR_HPP
