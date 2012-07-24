#include <iostream>

#include "error.hpp"
#include "SourceFile.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "Lexer.hpp"
#include "Parser.hpp"
#include "Validator.hpp"

#include "Ident.hpp"

using namespace sool;

int main(int argc, char **argv)
{
	SourceFile::ptr file(new SourceFile);
	
	if(argc < 2)
	{
		std::cout << "Usage: " << argv[0] << " sourcefile" << std::endl;
		exit(EXIT_FAILURE);
	}
	
	bool success = file->Load(argv[1]);
	
	if(!success)
	{
		std::cout << "Meh, failure to load " << argv[1] << std::endl;
		return 1;
	}
	
	Lexer lex(file);
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
	
	vector<string> path;
	path.push_back("foo");
	path.push_back("bar");
	path.push_back("meh");
	
	vector<Ident> params;
	params.push_back(Ident("lol"));
	params.push_back(Ident("lol"));
	
	Ident id(path, "Bar", params);
	
	std::cout << (std::string) id << std::endl;
	
	return 0;
}
