#include <sstream>
#include "Diagnostic.hpp"
#include "SourceFile.hpp"

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
	
	switch(severity)
	{
		case Diagnostic::Info:
			tmp << "info";
			break;
		case Diagnostic::Warning:
			tmp << "warning";
			break;
		case Diagnostic::Error:
			tmp << "error";
			break;
	}
	
	tmp << ": ";
	
	LineCol beg,end;
	if(position.file)
	{
		position.ToLineCol(&beg,&end);
		
		tmp << position.file->name << ":";
		if(beg.line == end.line)
			tmp << beg.line;
		else
			tmp << beg.line << "-" << end.line;
		
		tmp << ": ";
	}
	
	tmp << message << std::endl;
	
	// Source code reminder
	
	if(position.file)
	{
		for(int l = beg.line ; l <= end.line ; l++)
		{
			std::string line = position.file->lines[l-1].Text();
			
			// Text itself
			tmp << line;
			
			// Marks
			
			int mstart, mend;
			
			if(l == beg.line)
				mstart = beg.col;
			else
				mstart = 1;
			
			if(l == end.line)
				mend = end.col;
			else
				mend = line.size();
			
			for(int i = 0 ; i < line.size()-1 ; i++ )
			{
				if(i+1 >= mstart && i+1 <= mend)
				{
					tmp << (line[i] == '\t' ? '\t' : '^');
				}
				else
				{
					tmp << (line[i] == '\t' ? '\t' : ' ');
				}
			}
			
			tmp << std::endl;
		}
	}
	
	return tmp.str();
}

