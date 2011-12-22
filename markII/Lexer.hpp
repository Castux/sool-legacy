#ifndef LEXER_HPP
#define LEXER_HPP

#include "Token.hpp"
#include "SourceFile.hpp"
#include "Report.hpp"

namespace sool
{
	class Lexer
	{
		public:
		
		SourceFile			*file;
		Report				report;

		
		// Lexing context
		const char			*bufstart;
		const char			*head;
		std::vector<Token>	*tokens;
		
		public:
		Lexer(SourceFile *f);
		
		bool Lex();
		
		private:
		bool LexOne();
		bool LexNameOrKeyword();
		bool LexNumber();
		
		void AddError(std::string message, SourcePos position);
	};
};

#endif // LEXER_HPP
