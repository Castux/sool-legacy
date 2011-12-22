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

std::string Token::GetFancyName(Kind k)
{
	if(k >= NUM_TOKENS)
		error("Token::GetTokenString() - unknown token kind");
	
	if(k >= t_name && k <= t_eof)
		return tokenStrings[k];
	else
		return std::string("'") + tokenStrings[k] + "'";
}

std::string Token::FancyName()
{
	return GetFancyName(kind);
}
