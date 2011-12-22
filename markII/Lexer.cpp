#include "Lexer.hpp"

using namespace sool;

Lexer::Lexer(SourceFile *f)
{
	file = f;
	bufstart = file->text.c_str();
	head = bufstart;
	tokens = new std::vector<Token>;
}

bool Lexer::Lex()
{
	while(*head)
	{
		// Eat all white space between tokens
		if(isspace(*head))
		{
			while(isspace(*head))
				head++;
			
			continue;
		}
		
		// Get rid of comments
		if(head[0] == '-' && head[1] == '-')
		{
			while(*head != '\n')
				head++;
			
			continue;
		}
		
		// Finally, lex the next token
		bool success = LexOne();
		if(!success)
		{
			AddError(std::string("unexpected symbol '") + head[0] + "'", SourcePos(file, head - bufstart, head - bufstart));
			return false;
		}
	}
	
	return true;
}

bool Lexer::LexOne()
{
	char c = *head;
	
	if(isalpha(c) || c == '_')
	{
		return LexNameOrKeyword();
	}
	else if(isdigit(c))
	{
		return LexNumber();
	}
	
	return false;
}

bool Lexer::LexNameOrKeyword()
{
	Token tok;
	tok.kind = Token::t_unknown;
	
	// Eat as many valid chars as possible
	const char *end = head;
	while(isalnum(*end) || *end == '_')
		end++;
	
	int length = end - head;
	std::string name(head,length);
	
	// Check if it is a reserved keyword
	if(islower(*head))
	{
		for(uint k = Token::t_class ; k <= Token::t_end ; k++)
		{
			if(name.compare(Token::GetTokenString((Token::Kind) k)) == 0)
			{
				// Found it!
				tok.kind = (Token::Kind) k;
				break;
			}
		}
	}
	
	if(tok.kind == Token::t_unknown)
	{
		// Not a keyword, that's a real name
		tok.string = name;
		
		// Sort CName and Name
		if(isupper(*head))
			tok.kind = Token::t_cname;
		else
			tok.kind = Token::t_name;
	}
	
	// Fill in source position
	tok.pos.file = file;
	tok.pos.begin = head - bufstart;
	tok.pos.end = end - 1 - bufstart;
	
	// Memorise token
	tokens->push_back(tok);
	
	// Finally, advance head
	head = end;
	
	return true;
}

bool Lexer::LexNumber()
{
	return false;
}

void Lexer::AddError(std::string message, SourcePos position)
{
	report.Add("lexer", Diagnostic::Error, message, position);
}
