#include "Parser.hpp"

using namespace sool;

Parser::Parser(std::vector<Token> *t) : tokens(t), noinfo(false)
{
	head = &tokens->front();
}

bool Parser::Parse()
{
	context = new Context;
	
	while(head->kind != Token::t_eof)
	{
		Class *c = ParseClass();
		if(!c)
			return false;
		else
			context->classes.push_back(c);
	}
	
	return true;
}

Class* Parser::ParseClass()
{
	Class *c = new Class();
	SourcePos start = head->pos;
	
	switch(head->kind)
	{
		case Token::t_class:
			break;
		case Token::t_struct:
			c->structure = true;
			break;
		case Token::t_extend:
			c->extend = true;
			break;
		default:
			AddError("malformed composite definition", head->pos);
			AddInfo("expected 'class', 'struct' or 'extend'");
			delete c;
			return NULL;
	}
	
	head++;
	
	TypeDecl *t = ParseType();
	if(!t)
	{
		AddInfo("in class definition started here:", start);
		delete c;
		return NULL;
	}
	
	return c;
}

TypeDecl* Parser::ParseType()
{
	TypeDecl *t = new TypeDecl;
	
	// Basic types
	
	switch(head->kind)
	{
		case Token::t_num:
			t->kind = TypeDecl::t_num;
			break;
		case Token::t_bool:
			t->kind = TypeDecl::t_bool;
			break;
		case Token::t_text:
			t->kind = TypeDecl::t_text;
			break;
		case Token::t_opaque:
			t->kind = TypeDecl::t_opaque;
			break;
		case Token::t_data:
			t->kind = TypeDecl::t_data;
			break;
		default:
			break;
	}
	
	if(t->kind != TypeDecl::t_unknown)
	{
		t->pos = head->pos;
		head++;
		return t;
	}
	
	// Array type
	
	if(head->kind == Token::t_hash)
	{
		t->name_pos = head->pos;
		head++;
		
		TypeDecl *sub = ParseType();
		if(!sub)
		{
			AddInfo("in array type started here:", t->name_pos, true);
			delete t;
			return NULL;
		}
		
		t->kind = TypeDecl::t_named;
		t->name = "#";
		t->params.push_back(sub);
		
		return t;
	}
	
	delete t;
	
	// Last try: class name
	
	if(head->kind == Token::t_cname)
		return ParseClassName();
	
	// Le fail
	AddError("malformed type", head->pos);
	return NULL;
}

TypeDecl* Parser::ParseClassName()
{
	TypeDecl *t = new TypeDecl;
	
	if(!Expect(Token::t_cname))
		return NULL;
	
	t->kind = TypeDecl::t_named;
	t->name = head[-1].string;
	t->name_pos = head[-1].pos;
	
	// Template parameters
	
	if(Accept(Token::t_pipe))
	{
		if(Accept(Token::t_lparens))
		{
			SourcePos lparens = head[-1].pos;
			
			// List of types
			TypeDecl *sub = ParseType();
			if(!sub)
			{
				AddInfo("in template parameters list started here:", lparens, true);
				delete t;
				return NULL;
			}
			
			t->params.push_back(sub);
			
			while(Accept(Token::t_comma))
			{
				TypeDecl *sub = ParseType();
				if(!sub)
				{
					AddInfo("in template parameters list started here:", lparens, true);
					delete t;
					return NULL;
				}
				t->params.push_back(sub);
			}
			
			if(!Expect(Token::t_rparens))
			{
				AddInfo("to close template parameters list started here:", lparens, true);
				delete t;
				return NULL;
			}
		}
		else
		{
			// Single sub type
			TypeDecl *sub = ParseType();
			if(!sub)
			{
				AddInfo("as template parameter for type started here:", t->name_pos, true);
				delete t;
				return NULL;
			}
			
			t->params.push_back(sub);
		}
	}
	
	return t;
}

bool Parser::Expect(Token::Kind k)
{
	if(head->kind != k)
	{
		AddError(std::string("expected ") + Token::GetFancyName(k) + ", found " + head->FancyName() + " instead:", head->pos);
		return false;
	}
	else
	{
		head++;
		return true;
	}
}

bool Parser::Accept(Token::Kind k)
{
	if(head->kind == k)
	{
		head++;
		return true;
	}
	else
		return false;
}

void Parser::AddError(std::string message, SourcePos position)
{
	report.Add("parser", Diagnostic::Error, message, position);
}

void Parser::AddInfo(std::string message, SourcePos position, bool stop)
{
	if(noinfo)
		return;
	
	report.Add("parser", Diagnostic::Info, message, position);
	
	if(stop)
		noinfo = true;
}
