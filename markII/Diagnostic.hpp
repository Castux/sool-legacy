#ifndef DIAGNOSTIC_HPP
#define DIAGNOSTIC_HPP

#include <string>
#include <ostream>

#include "SourcePos.hpp"

namespace sool
{
	class Diagnostic
	{
		public:
		
		typedef enum
		{
			Info,
			Warning,
			Error
		} Severity;
		
		std::string emitter;
		Severity severity;
		std::string message;
		SourcePos position;
		
		Diagnostic(std::string e, Severity s, std::string m, SourcePos p = SourcePos());
		
		std::string ToString();
	};
	
}


#endif // DIAGNOSTIC_HPP
