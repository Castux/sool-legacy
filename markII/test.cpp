#include <iostream>

#include "error.hpp"
#include "SourceFile.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "Lexer.hpp"
#include "Parser.hpp"
#include "Validator.hpp"


using namespace sool;

int main(int argc, char **argv)
{
	SourceFile file;
	
	if(argc < 2)
	{
		std::cout << "Usage: " << argv[0] << " sourcefile" << std::endl;
		exit(EXIT_FAILURE);
	}
	
	bool success = file.Load(argv[1]);
	
	if(!success)
	{
		std::cout << "Meh, failure to load " << argv[1] << std::endl;
		return 1;
	}
	
	Lexer lex(&file);
	success = lex.Lex();
	
    /*
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
	*/
	
	lex.report.Print();
	
	if(!success)
		return 1;
	
	Parser parser(lex.tokens);
	success = parser.Parse();
	
	parser.report.Print();
	
	if(!success)
		return 1;
	
	Validator validator(parser.context);
	success = validator.Validate();
	
	validator.report.Print();
	
	if(!success)
		return 1;
	
	delete validator.context;
	
	ClassName::Clear();
	
	return 0;
}
