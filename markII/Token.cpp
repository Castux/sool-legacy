#include "Token.hpp"
#include "common.hpp"

using namespace sool;

static const char *tokenNames[] =
{
	#define TOKEN(x,y) y,
	#include "tokenkinds.def"
	#undef TOKEN
};

const char *Token::GetTokenName(Kind k)
{
	if(k >= NUM_TOKENS)
		error("Token::GetTokenName() - unknown token kind");
	
	return tokenNames[k];
}
