#ifndef TOKEN_HPP
#define TOKEN_HPP

#include "common.hpp"
#include "SourcePos.hpp"

namespace sool
{
	class Token
	{
		public:
		
		typedef enum
		{
			#define TOKEN(x,y) t_ ## x,
			#include "Token.def"
			#undef TOKEN
			
			NUM_TOKENS
		} Kind;
		
		static const char *GetTokenName(Kind k);
		static const char *GetTokenString(Kind k);
		static std::string GetFancyName(Kind k);		// Formated for printed output (quotes around litteral ones)
		
		public:
		
		Kind			kind;
		std::string		string;		// Only used in name, cname and string tokens
		num				number;		// Only used in number tokens
		SourcePos		pos;
		
		std::string FancyName();
	};
}

#endif // TOKEN_HPP
