#ifndef PARSER_HPP
#define PARSER_HPP

#include "common.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "InterfaceAST.hpp"

namespace sool
{
	class Parser
	{
		public:
		
		Report report;
		
		// Parsing context
		std::vector<Token>	*tokens;	//owned
		Token				*head;
		Context				*context;	//not owned, will be passed to analyzer
		Class				*curr_class;	// shortcut for deep setting
		
		Parser(std::vector<Token> *t);
		~Parser();
		
		bool Parse();
		
		private:
		
		Class* ParseClass();
		Extension* ParseExtension();
		TypeDecl* ParseType();
		TypeDecl* ParseClassName();
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
