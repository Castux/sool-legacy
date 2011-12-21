#include <iostream>
#include "Report.hpp"

using namespace sool;

Report::Report() : numinfo(0), numwarning(0), numerror(0)
{
}

void Report::Add(Diagnostic d)
{
	switch(d.severity)
	{
		case Diagnostic::Info:
			numinfo++;
			break;
		case Diagnostic::Warning:
			numwarning++;
			break;
		case Diagnostic::Error:
			numerror++;
			break;
	}
	
	diags.push_back(d);
}

void Report::Print()
{
	for(uint i = 0 ; i < diags.size() ; i++)
		std::cout << diags[i].ToString();
}
