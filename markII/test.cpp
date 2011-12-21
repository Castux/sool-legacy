#include <iostream>

#include "error.hpp"
#include "SourceFile.hpp"
#include "Diagnostic.hpp"
#include "Report.hpp"
#include "Token.hpp"

using namespace sool;

int main()
{
	SourceFile file;
	bool success = file.Load("test.cpp");
	
	if(!success)
	{
		std::cout << "Meh" << std::endl;
		return 1;
	}
	
	std::cout << file.name << std::endl;
	std::cout << file.text;
	
	for(uint i = 0; i < file.lines.size(); i++)
	{
		std::cout << i << ": " << file.lines[i].begin << ","
			<< file.lines[i].end << "\t\t"
			<< file.lines[i].Text();
	}
	
	LineCol lc = file.ToLineCol(375);
	std::cout << lc.line << "," << lc.col << ": " << file.text[375] << std::endl;
	
	Diagnostic diag("test", Diagnostic::Error, "lololol");
	diag.position.file = &file;
	diag.position.begin = 700;
	diag.position.end = 713;
	
	Report r;
	r.Add(diag);
	
	r.Print();
	
	std::cout << Token::GetTokenName(Token::t_lessequal) << std::endl;
	
	return 0;
}
