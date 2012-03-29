#ifndef PARSER_HPP
#define PARSER_HPP

#include "common.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "AST.hpp"

namespace sool
{
	struct ParseResult
	{
		std::vector<Class*> 	*classes;
		std::vector<Extension*>	*extensions;
	};
	
	class Parser
	{
		public:
		
		Report report;
		ParseResult result;
		
		// Parsing context
		std::vector<Token>		*tokens;	//owned
		Token					*head;
		
		Parser(std::vector<Token> *t);
		~Parser();
		
		bool Parse();
		
		private:
		
		Class* ParseClass();
		bool ParseNameOfClass(Class *c);
		Extension* ParseExtension();
		Type ParseType(SourcePos *pos = NULL);
		ClassName* ParseClassName();
		Method* ParseMethod();
		Member* ParseMember();
		
		bool Expect(Token::Kind k);
		bool Accept(Token::Kind k);
		bool IsBinop(Token::Kind k);
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos(), bool stop = false);
		bool noinfo;	// Stop propagation of context information
	};
}

#endif // PARSER_HPP
