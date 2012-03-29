#include <iostream>
#include <sstream>

#include "Report.hpp"

using namespace sool;

Diagnostic::Diagnostic(std::string e, Severity s, std::string m, SourcePos p) :
	emitter(e), severity(s), message(m), position(p)
{
}

std::string Diagnostic::ToString()
{
	std::stringstream tmp;
	
	// First line
	
	tmp << emitter << " ";
	
	int col = 0;
	std::string sev;
	
	switch(severity)
	{
		case Info:
			sev = "info";
			col = 4;
			break;
		case Warning:
			sev = "warning";
			col = 3;
			break;
		case Error:
			sev = "error";
			col = 1;
			break;
		default:
			error("Diagnostic::ToString() - unknown severity");
	}
	
	tmp << C(sev,col) << ": ";
	
	LineCol beg,end;
	if(position.file)
	{
		position.ToLineCol(&beg,&end);
		
		tmp << Cd(position.file->name,5) << ":";
		
		std::stringstream nums;
		if(beg.line == end.line)
			nums << beg.line;
		else
			nums << beg.line << "-" << end.line;
		
		
		tmp << Cd(nums.str(),2) << ": ";
	}
	
	tmp << message << std::endl;
	
	// Source code reminder
	
	if(position.file)
	{
		for(uint l = beg.line ; l <= end.line ; l++)
		{
			std::string line = position.file->lines[l-1].Text();
			
			// Compute limits for marks
			
			uint mstart, mend;
			
			if(l == beg.line)
				mstart = beg.col;
			else
				mstart = 1;
			
			if(l == end.line)
				mend = end.col;
			else
				mend = line.size();
			
			// Create mark line
			// Replace chars by spaces or marks, but leave tabs as tabs
			
			std::string marks;
			for(uint i = 0 ; i < line.size()-1 ; i++ )
			{
				if(i+1 >= mstart && i+1 <= mend)
				{
					marks += (line[i] == '\t' ? '\t' : '^');
				}
				else
				{
					marks += (line[i] == '\t' ? '\t' : ' ');
				}
			}
			
			// Print them with color
			
			tmp << C(line,col,mstart,mend);
			tmp << C(marks,col,mstart,mend) << std::endl;
		}
	}
	
	return tmp.str();
}

std::string Diagnostic::C(std::string s, uint col, uint begin, uint end)
{
	if(end == 0)
		end = s.size();

	std::stringstream tmp;
	
	for(uint i = 0 ; i < s.size() ; i++)
	{
		if(i+1 == begin)
			tmp << "\x1b[1;" << 30 + col << "m";
		
		tmp << s[i];
		
		if(i+1 == end || i+1 == s.size())
			tmp << "\x1b[0m";
	}
	
	return tmp.str();
}

std::string Diagnostic::Cd(std::string s, uint col, uint begin, uint end)
{
	if(end == 0)
		end = s.size();

	std::stringstream tmp;
	
	for(uint i = 0 ; i < s.size() ; i++)
	{
		if(i+1 == begin)
			tmp << "\x1b[" << 30 + col << "m";
		
		tmp << s[i];
		
		if(i+1 == end || i+1 == s.size())
			tmp << "\x1b[0m";
	}
	
	return tmp.str();
}

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

void Report::Add(std::string e, Diagnostic::Severity s, std::string m, SourcePos p)
{
	Add(Diagnostic(e,s,m,p));
}

void Report::Print()
{
	for(uint i = 0 ; i < diags.size() ; i++)
		std::cout << diags[i].ToString();
}
