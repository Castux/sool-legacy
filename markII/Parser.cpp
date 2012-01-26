#include "Parser.hpp"

using namespace sool;

Parser::Parser(std::vector<Token> *t) : tokens(t), context(NULL), curr_decls(NULL), noinfo(false)
{
	head = &tokens->front();
}

Parser::~Parser()
{
	delete tokens;
}

bool Parser::Parse()
{
	context = new Context;
	Class *c;
	Extension *e;
	
	while(head->kind != Token::t_eof)
	{
		switch(head->kind)
		{
			case Token::t_extend:
				e = ParseExtension();
				if(!e)
					return false;
				else
					context->extensions.push_back(e);
				break;
			case Token::t_class:
			case Token::t_struct:
				c = ParseClass();
				if(!c)
					return false;
				else
					context->classes.push_back(c);
				break;
			default:
				AddError("expected class, structure or extension definition", head->pos);
				return false;
		}
	}
	
	return true;
}

Class* Parser::ParseClass()
{
	Class *c = new Class();
	curr_decls = &c->type_decls;
	
	SourcePos start = head->pos;
	
	switch(head->kind)
	{
		case Token::t_class:
			break;
		case Token::t_struct:
			c->structure = true;
			break;
		default:
			error(std::string("Parser::ParseClass() - wrong class token: ") + head->FancyName());
	}
	
	head++;
	
	// Class name, split into string and template params
	
	TypeDecl *t = ParseClassName();
	if(!t)
	{
		delete c;
		return NULL;
	}
	
	c->name = t->name;
	c->name_pos = t->name_pos;
	c->fullname_pos = t->pos;
	
	// Check that parameters consist in single names
	for(uint i = 0; i < t->params.size(); i++)
	{
		TypeDecl *p = t->params[i];
		if(p->params.size() > 0 || !isupper(p->name[0]))
		{
			AddError("invalid template parameter", p->pos);
			AddInfo("(expected single class name)");
			delete t;
			delete c;
			return NULL;
		}
		
		c->params.push_back(p->name);
		c->params_pos.push_back(p->name_pos);
	}
	
	delete t;
	
	// Class parent
	
	if(Accept(Token::t_colon))
	{
		c->ptype = ParseClassName();
		if(!c->ptype)
		{
			AddInfo("as parent class for class started here:", start, true);
			delete c;
			return NULL;
		}
	}
	
	// Definitions
	
	while(head->kind != Token::t_end && head->kind != Token::t_eof)
	{
		// Methods
		if( head->kind == Token::t_method ||
			head->kind == Token::t_selfless ||
			head->kind == Token::t_foreign ||
			( head[0].kind == Token::t_internal && (
				head[1].kind == Token::t_method ||
				head[1].kind == Token::t_selfless ||
				head[1].kind == Token::t_foreign ))
			)
		{
			Method *m = ParseMethod();
			if(!m)
			{
				delete c;
				return NULL;
			}
			c->methods.push_back(m);
		}
		else
		{
			Member *m = ParseMember();
			if(!m)
			{
				delete c;
				return NULL;
			}
			c->members.push_back(m);
		}
	}
	
	// End
	
	if(!Expect(Token::t_end))
	{
		AddInfo("to close class definition started here:", start);
		delete c;
		return NULL;
	}
	
	c->pos = start.To(head[-1].pos);
	
	curr_decls = NULL;
	return c;
}

Extension *Parser::ParseExtension()
{
	Extension *e = new Extension;
	SourcePos start = head->pos;
	
	curr_decls = &e->type_decls;
	
	Expect(Token::t_extend);
	
	// Extended type
	
	TypeDecl *t = ParseClassName();
	if(!t)
	{
		AddInfo("in extension started here:", start);
		delete e;
		return NULL;
	}
	
	e->type = t;
	
	// Method definitions
	
	while(head->kind != Token::t_end && head->kind != Token::t_eof)
	{
		Method *m = ParseMethod();
		if(!m)
		{
			delete e;
			return NULL;
		}
		e->methods.push_back(m);
	}
	
	// End
	
	if(!Expect(Token::t_end))
	{
		AddInfo("to close extension started here:", start);
		delete e;
		return NULL;
	}
	
	e->pos = start.To(head[-1].pos);
	
	curr_decls = NULL;
	return e;
}

TypeDecl* Parser::ParseClassName()
{
	TypeDecl *t = new TypeDecl;
	
	// Built-in
	
	if(head->kind >= Token::t_num && head->kind <= Token::t_blob)
	{
		t->name = Token::GetTokenString(head->kind);
		t->pos = head->pos;
		t->name_pos = head->pos;
		head++;

		curr_decls->push_back(t);
		return t;
	}
	
	// Array type
	
	if(head->kind == Token::t_hash)
	{
		t->name_pos = head->pos;
		head++;
		
		TypeDecl *sub = ParseClassName();
		if(!sub)
		{
			AddInfo("in array class name started here:", t->name_pos, true);
			delete t;
			return NULL;
		}
		
		t->name = "#";
		t->pos = t->name_pos.To(sub->pos);
		t->params.push_back(sub);
		
		curr_decls->push_back(t);
		return t;
	}
	
	// Last try: CName
	
	if(head->kind != Token::t_cname)
	{
		AddError("malformed class name", head->pos);
		delete t;
		return NULL;
	}
	
	t->name = head->string;
	t->name_pos = head->pos;
	head++;
	
	// Template parameters
	
	if(Accept(Token::t_pipe))
	{
		if(Accept(Token::t_lparens))
		{
			SourcePos lparens = head[-1].pos;
			
			// List of types
			TypeDecl *sub = ParseClassName();
			if(!sub)
			{
				AddInfo("in template parameters list started here:", lparens, true);
				delete t;
				return NULL;
			}
			
			t->params.push_back(sub);
			
			while(Accept(Token::t_comma))
			{
				TypeDecl *sub = ParseClassName();
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
			TypeDecl *sub = ParseClassName();
			if(!sub)
			{
				AddInfo("as template parameter for class name started here:", t->name_pos, true);
				delete t;
				return NULL;
			}
			
			t->params.push_back(sub);
		}
	}
	
	t->pos = t->name_pos.To(head[-1].pos);

	curr_decls->push_back(t);
	return t;
}

TypeDecl* Parser::ParseType()
{
	TypeDecl *t = ParseClassName();
	if(!t)
	{
		return NULL;
	}
	
	if(Accept(Token::t_question))
	{
		t->optional = true;
		t->pos = t->name_pos.To(head[-1].pos);
	}
	
	return t;
}

Method* Parser::ParseMethod()
{
	Method* m = new Method;
	SourcePos start = head->pos;
	
	// Attributes
	
	if(Accept(Token::t_internal))
	{
		m->internal = true;
		m->internal_pos = head[-1].pos;
	}
	
	switch(head->kind)
	{
		case Token::t_method:
			break;
		case Token::t_selfless:
			m->selfless = true;
			m->selfless_pos = head->pos;
			break;
		case Token::t_foreign:
			m->foreign = true;
			break;
		default:
			AddError("malformed method definition", head->pos);
			AddInfo("expected 'method', 'selfless' or 'foreign'");
			delete m;
			return NULL;
	}
	head++;
	
	// Return type(s)
	
	if(head->kind != Token::t_name && !IsBinop(head->kind) && head->kind != Token::t_lbracket)
	{
		TypeDecl *t = ParseType();
		if(!t)
		{
			AddInfo("as return type for method started here:", start);
			delete m;
			return NULL;
		}
		m->ret_decls.push_back(t);
		
		while(Accept(Token::t_comma))
		{
			TypeDecl *t = ParseType();
			if(!t)
			{
				AddInfo("as return type for method started here:", start);
				delete m;
				return NULL;
			}
			m->ret_decls.push_back(t);
		}
	}
	
	// Name
	
	if(head->kind == Token::t_name)
	{
		m->name = head->string;
		m->name_pos = head->pos;
		head++;
		if(Accept(Token::t_equal))
			m->setter = true;
	}
	else if(IsBinop(head->kind))
	{
		m->name = Token::GetTokenString(head->kind);
		m->name_pos = head->pos;
		head++;
	}
	else if(head[0].kind == Token::t_lbracket && head[1].kind == Token::t_rbracket)
	{
		m->name = "[]";
		m->name_pos = head->pos.To(head[1].pos);
		head += 2;
		if(Accept(Token::t_equal))
			m->setter = true;
	}
	else
	{
		AddError("invalid method name", head->pos);
		AddInfo("expected name, operator or '[]'");
		delete m;
		return NULL;
	}
	
	// Arguments
	
	SourcePos lparens = head->pos;
	
	if(!Expect(Token::t_lparens))
	{
		AddInfo("in method definition started here:", start);
		delete m;
		return NULL;
	}
	
	if(head->kind != Token::t_rparens)
	{
		TypeDecl *t = ParseType();
		if(!t)
		{
			AddInfo("as argument type in method started here:", start);
			delete m;
			return NULL;
		}
		
		if(!Expect(Token::t_name))
		{
			AddInfo("as argument name in method started here:", start);
			delete m;
			return NULL;
		}
		
		Method::Argument arg;
		arg.type = t;
		arg.name = head[-1].string;
		arg.pos = t->pos.To(head[-1].pos);
		m->args.push_back(arg);
		
		while(Accept(Token::t_comma))
		{
			TypeDecl *t = ParseType();
			if(!t)
			{
				AddInfo("as argument type in method started here:", start);
				delete m;
				return NULL;
			}
			
			if(!Expect(Token::t_name))
			{
				AddInfo("as argument name in method started here:", start);
				delete m;
				return NULL;
			}
			
			Method::Argument arg;
			arg.type = t;
			arg.name = head[-1].string;
			arg.pos = t->pos.To(head[-1].pos);
			m->args.push_back(arg);
		}
	}
	
	if(!Expect(Token::t_rparens))
	{
		AddInfo("to close argument list started here:", lparens);
		delete m;
		return NULL;
	}
	
	m->args_pos = lparens.To(head[-1].pos);
	m->interface_pos = start.To(head[-1].pos);
	
	// Body
	
	// And finish
	
	if(!Expect(Token::t_end))
	{
		AddInfo("to close method definition started here:", start);
		delete m;
		return NULL;
	}
	
	m->pos = start.To(head[-1].pos);
	
	return m;
}

Member* Parser::ParseMember()
{
	Member *m = new Member;
	SourcePos start = head->pos;
	
	if(Accept(Token::t_shared))
	{
		m->shared = true;
		m->shared_pos = head[-1].pos;
	}
	
	if(Accept(Token::t_internal))
	{
		m->internal = true;
		m->internal_pos = head[-1].pos;
	}
	
	TypeDecl *t = ParseType();
	if(!t)
	{
		AddInfo("in member definition");
		delete m;
		return NULL;
	}
	m->tdecl = t;
	
	if(!Expect(Token::t_name))
	{
		AddInfo("in member definition started here:", start);
		delete m;
		return NULL;
	}
	m->name = head[-1].string;
	m->name_pos = head[-1].pos;
	
	m->pos = start.To(head[-1].pos);
	
	return m;
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

bool Parser::IsBinop(Token::Kind k)
{
	switch(k)
	{
		case Token::t_plus:
		case Token::t_minus:
		case Token::t_star:
		case Token::t_slash:
		case Token::t_percent:
		case Token::t_less:
		case Token::t_more:
		case Token::t_lessequal:
		case Token::t_moreequal:
		case Token::t_caret:
		case Token::t_tilde:
		case Token::t_arrow:
		case Token::t_equalequal:
		case Token::t_tildeequal:
		case Token::t_and:
		case Token::t_or:
		case Token::t_is:
		case Token::t_isnot:
			return true;
		default:
			return false;
	}
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
