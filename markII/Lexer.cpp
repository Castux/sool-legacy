#include <sstream>
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
		return LexName();
	}
	else if(isdigit(c))
	{
		return LexNumber();
	}
	
	AddError(std::string("unexpected symbol '") + head[0] + "'", SourcePos(file, head - bufstart, head - bufstart));
	return false;
}

bool Lexer::LexName()
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
	const char *end = head;
	num value;
	
	while(isalnum(*end))
		end++;
	
	SourcePos pos(file, head-bufstart, end-1-bufstart);
	
	std::string str(head, end-head);
	
	// Try an integer
	char *endptr;
	unsigned long int i = strtoul(str.c_str(), &endptr, 0);
	value = i;
	
	if(*endptr != 0)
	{
		// Failed, try double
		double d = strtod(str.c_str(), &endptr);
		value = d;
		
		if(*endptr != 0)
		{
			// Super failed, report
			AddError("malformed number", pos);
			return false;
		}
	}
	
	// Success, build token
	Token tok;
	tok.kind = Token::t_number;
	tok.pos = pos;
	tok.number = value;
	
	// Memorise token
	tokens->push_back(tok);
	
	// Finally, advance head
	head = end;
	
	return true;
}

bool Lexer::LexNumber()
{
	
}

void Lexer::AddError(std::string message, SourcePos position)
{
	report.Add("lexer", Diagnostic::Error, message, position);
}
