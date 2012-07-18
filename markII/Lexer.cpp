#include <sstream>
#include "Lexer.hpp"

using namespace sool;

Lexer::Lexer(SourceFile::ptr f) : file(f), bufstart(file->text.c_str()),
	head(bufstart), tokens(new std::vector<Token>)
{
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
	
	// Once we're done, add the EOF token, with no position
	Token tok;
	tok.kind = Token::t_eof;
	tokens->push_back(tok);
	
	return true;
}

bool Lexer::LexOne()
{
	char c = *head;
	
	if(isalpha(c) || c == '_')
		return LexName();
	else if(isdigit(c))
		return LexNumber();
	else if(c == '"' || c == '\'')
		return LexString();
	
	return LexPunctuation();
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
		for(uint k = Token::t_object ; k <= Token::t_end ; k++)
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
	tok.pos = SourcePos(file.get(), head - bufstart, end - 1 - bufstart);
	
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
	
	while(isalnum(*end) || (*end == '.' && isdigit(end[1])))
		end++;
	
	if((end[-1] == 'E' || end[-1] == 'e') && (*end == '+' || *end == '-'))
	{
		end++;
		while(isalnum(*end))
			end++;
	}
	
	SourcePos pos(file.get(), head-bufstart, end-1-bufstart);
	
	std::string str(head, end-head);
	
	// Try hexa number
	if(str[0] == '0' && (str[1] == 'x' || str[1] == 'X'))
	{
		char *endptr;
		unsigned long int i = strtoul(str.c_str() + 2, &endptr, 16);
		value = i;
		
		if(*endptr != 0)
		{
			AddError("malformed hexadecimal number", pos);
			return false;
		}
	}
	else
	{
		// Try a decimal integer
		char *endptr;
		unsigned long int i = strtoul(str.c_str(), &endptr, 10);
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

bool Lexer::LexString()
{
	char delim = *head;
	const char *end = head + 1;
	
	std::string value;
	
	while(*end != delim)
	{
		// Complain at end of file
		if(*end == 0)
		{
			AddError("unfinished litteral string started here:", SourcePos(file.get(), head-bufstart, head-bufstart));
				return false;
		}
		
		// Deal with escapes
		if(*end == '\\')
		{
			// Hex escape
			if(end[1] == 'x')
			{
				std::string str(end+2, 2);
				char *endptr;
				char c = strtoul(str.c_str(), &endptr, 16);
				
				if(*endptr != 0)
				{
					AddError("malformed hexadecimal escape", SourcePos(file.get(), end-bufstart, end+3-bufstart));
					return false;
				}
				
				value += c;
				end += 4;
			}
			// Other escapes
			else
			{
				switch(end[1])
				{
					case '0':
						value += (char) 0;
						break;
					case 'a':
						value += '\a';
						break;
					case 'b':
						value += '\b';
						break;
					case 'e':
						value += '\x1b';
						break;
					case 'f':
						value += '\f';
						break;
					case 'n':
						value += '\n';
						break;
					case 't':
						value += '\t';
						break;
					case 'v':
						value += '\v';
						break;
					case '\\':
						value += '\\';
						break;
					case '"':
						value += '"';
						break;
					case '\'':
						value += '\'';
						break;
					default:
						AddError("unknown escape", SourcePos(file.get(), end-bufstart, end+1-bufstart));
						return false;
				}
				
				end += 2;
			}
		}
		
		// Other characters are added directly
		value += *end;
		end++;
	}
	
	end++; // Eat the closing quote
	
	// Success, build token
	Token tok;
	tok.kind = Token::t_string;
	tok.pos = SourcePos(file.get(), head-bufstart, end-1-bufstart);
	tok.string = value;
	
	// Memorise token
	tokens->push_back(tok);
	
	// Finally, advance head
	head = end;
	
	return true;
}

bool Lexer::LexPunctuation()
{
	// Try digraphs
	for(uint i = Token::t_lessequal; i <= Token::t_equalequal; i++)
	{
		const char *toks = Token::GetTokenString((Token::Kind) i);
		if(head[0] == toks[0] && head[1] == toks[1])
		{
			// Found it!
			Token tok;
			tok.kind = (Token::Kind) i;
			tok.pos = SourcePos(file.get(), head-bufstart, head+1-bufstart);
			
			tokens->push_back(tok);
			head += 2;
			
			return true;
		}
	}
	
	// Not a digraph, try single punctionation signs
	for(uint i = Token::t_plus; i <= Token::t_dot; i++)
	{
		const char *toks = Token::GetTokenString((Token::Kind) i);
		if(head[0] == toks[0])
		{
			// Found it!
			Token tok;
			tok.kind = (Token::Kind) i;
			tok.pos = SourcePos(file.get(), head-bufstart, head-bufstart);
			
			tokens->push_back(tok);
			head += 1;
			
			return true;
		}
	}
	
	// Le fail
	AddError(std::string("unexpected symbol '") + head[0] + "'", SourcePos(file.get(), head - bufstart, head - bufstart));
	return false;
}

void Lexer::AddError(std::string message, SourcePos position)
{
	report.Add("lexer", Diagnostic::Error, message, position);
}
