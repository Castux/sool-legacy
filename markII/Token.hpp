#ifndef TOKEN_HPP
#define TOKEN_HPP

namespace sool
{
	class Token
	{
		public:
		
		typedef enum
		{
			#define TOKEN(x,y) t_ ## x,
			#include "tokenkinds.def"
			#undef TOKEN
			
			NUM_TOKENS
		} Kind;
		
		static const char *GetTokenName(Kind k);
	};
}

#endif // TOKEN_HPP
