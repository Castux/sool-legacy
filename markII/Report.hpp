#ifndef REPORT_HPP
#define REPORT_HPP

#include <vector>
#include "SourceFile.hpp"

// The report is basically a list of diagnostics, with statistics added...

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
		
		// Colorize with ANSI escapes, from column begin to end
		// Defaults to the whole string
		// Cd is for the dark colors
		static std::string C(std::string s, uint color, uint begin = 1, uint end = 0);
		static std::string Cd(std::string s, uint color, uint begin = 1, uint end = 0);
	};
	
	class Report
	{
		private:
		
		std::vector<Diagnostic> diags;
		
		public:
		
		uint numinfo,numwarning,numerror;
		
		Report();
		void Add(Diagnostic d);
		void Add(std::string e, Diagnostic::Severity s, std::string m, SourcePos p = SourcePos());
		void Print();
	};
}

#endif // REPORT_HPP

