#ifndef REPORT_HPP
#define REPORT_HPP

#include <vector>
#include "Diagnostic.hpp"

// The report is basically a list of diagnostics, with statistics added...

namespace sool
{
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

