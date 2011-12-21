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
		
		// Pretty print the diagnostic with colors and all!
		std::string ToString();
		
		private:
		
		// Colorize with ANSI escapes, from column begin to end
		// Defaults to the whole string
		// Cd is for the dark colors
		static std::string C(std::string s, int color, int begin = 1, int end = -1);
		static std::string Cd(std::string s, int color, int begin = 1, int end = -1);
	};
	
}


#endif // DIAGNOSTIC_HPP
