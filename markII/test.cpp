#include <iostream>

#include "error.hpp"
#include "SourceFile.hpp"
#include "Diagnostic.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "Lexer.hpp"
#include "Parser.hpp"


using namespace sool;

int main()
{
	SourceFile file;
	bool success = file.Load("example.sool");
	
	if(!success)
	{
		std::cout << "Meh, failure to load" << std::endl;
		return 1;
	}
	
	Lexer lex(&file);
	lex.Lex();
	
    
	for(uint i = 0 ; i < lex.tokens->size() ; i++)
	{
		Token *t = &(*lex.tokens)[i];
		Diagnostic diag("test", Diagnostic::Info, Token::GetTokenName(t->kind), t->pos);
		std::cout << diag.ToString();
		if(t->kind == Token::t_number)
			std::cout << t->number << std::endl;
		else if(t->kind == Token::t_string)
			std::cout << t->string << std::endl;
	}
	
	
	lex.report.Print();
	
	if(lex.report.numerror > 0)
		return 1;
	
	Parser parser(lex.tokens);
	parser.Parse();
	
	parser.report.Print();
	
	return 0;
}
