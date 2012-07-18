#ifndef PARSER_HPP
#define PARSER_HPP

#include "common.hpp"
#include "Report.hpp"
#include "Token.hpp"
#include "AST.hpp"

namespace sool
{
	class Parser
	{
		public:
		
		Report report;
		
		// Parsing context
		Token::vecptr			tokens;
		Token					*head;
		Context::ptr			context;
		
		public:
		
		Parser(Token::vecptr t);
		
		bool Parse();
		
		private:
		
		Class::ptr ParseClass();
		TemplateParam ParseTemplateParam();
		TemplateParam::vecptr ParseTemplateParams();
		Extension::ptr ParseExtension();
		Type ParseType(SourcePos *pos = NULL);
		ClassName::ptr ParseClassName();
		Prototype::ptr ParsePrototype(bool expect_arg_names);
		Method::ptr ParseMethod();
		Member::ptr ParseMember();
		Interface::ptr ParseInterface();
		ClassName::vecptr ParseEmbed();
		
		bool Expect(Token::Kind k);
		bool Accept(Token::Kind k);
		bool IsBinop(Token::Kind k);
		
		void AddError(std::string message, SourcePos position = SourcePos());
		void AddInfo(std::string message, SourcePos position = SourcePos(), bool stop = false);
		bool noinfo;	// Stop propagation of context information
	};
}

#endif // PARSER_HPP
