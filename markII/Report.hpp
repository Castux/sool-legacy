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
		void Print();
	};
}

#endif // REPORT_HPP

