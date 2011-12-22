#include "common.hpp"
#include "Token.hpp"

using namespace sool;

static const char *tokenNames[] =
{
	#define TOKEN(x,y) #x,
	#include "Token.def"
	#undef TOKEN
};

static const char *tokenStrings[] =
{
	#define TOKEN(x,y) y,
	#include "Token.def"
	#undef TOKEN
};

const char *Token::GetTokenName(Kind k)
{
	if(k >= NUM_TOKENS)
		error("Token::GetTokenName() - unknown token kind");
	
	return tokenNames[k];
}

const char *Token::GetTokenString(Kind k)
{
	if(k >= NUM_TOKENS)
		error("Token::GetTokenString() - unknown token kind");
	
	return tokenStrings[k];
}
