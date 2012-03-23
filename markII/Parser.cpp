#include "Parser.hpp"

using namespace sool;

Parser::Parser(std::vector<Token> *t) : tokens(t), noinfo(false)
{
	head = &tokens->front();
}

Parser::~Parser()
{
	delete tokens;
}

bool Parser::Parse()
{
	result.classes = new std::vector<Class*>;
	result.extensions = new std::vector<Extension*>;
	
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
					result.extensions->push_back(e);
				break;
			case Token::t_object:
			case Token::t_value:
				c = ParseClass();
				if(!c)
					return false;
				else
					result.classes->push_back(c);
				break;
			default:
				AddError("expected class or extension definition", head->pos);
				return false;
		}
	}
	
	return true;
}

Class* Parser::ParseClass()
{
	Class *c = new Class();
	
	SourcePos start = head->pos;
	
	switch(head->kind)
	{
		case Token::t_object:
			break;
		case Token::t_value:
			c->value = true;
			break;
		default:
			error(std::string("Parser::ParseClass() - wrong class token: ") + head->FancyName());
	}
	
	head++;
	
	// Class name, split into string and template params
	
	if(!ParseNameOfClass(c))
	{
		delete c;
		return NULL;
	}
	
	// Class parent
	
	if(Accept(Token::t_colon))
	{
		SourcePos pstart = head->pos;
		
		c->pname = ParseClassName();
		if(!c->pname)
		{
			AddInfo("as parent class for class started here:", start, true);
			delete c;
			return NULL;
		}
		
		c->parent_pos = pstart.To(head[-1].pos);
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
	
	return c;
}

bool Parser::ParseNameOfClass(Class *c)
{
	// Built-in
	
	if(head->kind >= Token::t_num && head->kind <= Token::t_blob)
	{
		c->name = Token::GetTokenString(head->kind);
		c->name_pos = head->pos;
		c->fullname_pos = head->pos;
		head++;
		return true;
	}
	
	// Array type
	
	if(head->kind == Token::t_hash)
	{
		c->name = "#";
		c->name_pos = head->pos;
		head++;
		
		if(!Expect(Token::t_cname))
		{
			AddError("invalid template parameter", head[-1].pos);
			return false;
		}
		
		c->params.push_back(head[-1].string);
		c->params_pos.push_back(head[-1].pos);
		c->fullname_pos = c->name_pos.To(head[-1].pos);
		return true;
	}
	
	// Last try: CName
	
	if(head->kind != Token::t_cname)
	{
		AddError("malformed class name", head->pos);
		return false;
	}
	
	c->name = head->string;
	c->name_pos = head->pos;
	head++;
	
	// Template parameters
	
	if(Accept(Token::t_pipe))
	{
		if(Accept(Token::t_lparens))
		{
			SourcePos lparens = head[-1].pos;
			
			// List of types
			if(!Expect(Token::t_cname))
			{
				AddError("as template parameter", head[-1].pos);
				return false;
			}
			
			c->params.push_back(head[-1].string);
			c->params_pos.push_back(head[-1].pos);
			
			while(Accept(Token::t_comma))
			{
				if(!Expect(Token::t_cname))
				{
					AddError("as template parameter", head[-1].pos);
					return false;
				}
				
				c->params.push_back(head[-1].string);
				c->params_pos.push_back(head[-1].pos);
			}
			
			if(!Expect(Token::t_rparens))
			{
				AddInfo("to close template parameters list started here:", lparens, true);
				return false;
			}
		}
		else
		{
			// Single sub type
			if(!Expect(Token::t_cname))
			{
				AddInfo("as template parameter", head[-1].pos);
				return false;
			}
			
			c->params.push_back(head[-1].string);
			c->params_pos.push_back(head[-1].pos);
		}
	}
	
	c->fullname_pos = c->name_pos.To(head[-1].pos);
	return true;
}

Extension *Parser::ParseExtension()
{
	Extension *e = new Extension;
	SourcePos start = head->pos;
	
	Expect(Token::t_extend);
	
	// Extended type
	
	ClassName *cname = ParseClassName();
	if(!cname)
	{
		AddInfo("in extension started here:", start);
		delete e;
		return NULL;
	}
	
	e->cname = cname;
	
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
	
	return e;
}

ClassName* Parser::ParseClassName()
{
	std::string name;
	std::vector<ClassName*> params;
	
	SourcePos start = head->pos;
	
	// Built-in
	
	if(head->kind >= Token::t_num && head->kind <= Token::t_blob)
	{
		name = Token::GetTokenString(head->kind);
		head++;
		
		return ClassName::Build(name,params);
	}
	
	// Array type
	
	if(head->kind == Token::t_hash)
	{
		name = "#";
		head++;
		
		ClassName *sub = ParseClassName();
		if(!sub)
		{
			AddInfo("in array class name started here:", start, true);
			return NULL;
		}
		
		params.push_back(sub);
		
		return ClassName::Build(name,params);
	}
	
	// Last try: CName
	
	if(head->kind != Token::t_cname)
	{
		AddError("malformed class name", head->pos);
		return NULL;
	}
	
	name = head->string;
	head++;
	
	// Template parameters
	
	if(Accept(Token::t_pipe))
	{
		if(Accept(Token::t_lparens))
		{
			SourcePos lparens = head[-1].pos;
			
			// List of types
			ClassName *sub = ParseClassName();
			if(!sub)
			{
				AddInfo("in template parameters list started here:", lparens, true);
				return NULL;
			}
			
			params.push_back(sub);
			
			while(Accept(Token::t_comma))
			{
				ClassName *sub = ParseClassName();
				if(!sub)
				{
					AddInfo("in template parameters list started here:", lparens, true);
					return NULL;
				}
				params.push_back(sub);
			}
			
			if(!Expect(Token::t_rparens))
			{
				AddInfo("to close template parameters list started here:", lparens, true);
				return NULL;
			}
		}
		else
		{
			// Single sub type
			ClassName *sub = ParseClassName();
			if(!sub)
			{
				AddInfo("as template parameter for class name started here:", start, true);
				return NULL;
			}
			
			params.push_back(sub);
		}
	}
	
	return ClassName::Build(name,params);
}

// We know the parsing failed if type.cname is NULL
Type Parser::ParseType(SourcePos *pos)
{
	SourcePos start = head->pos;
	
	ClassName *cname = ParseClassName();
	if(!cname)
	{
		return Type();
	}
	
	bool opt = false;
	
	if(Accept(Token::t_question))
	{
		opt = true;
	}
	
	SourcePos end = head[-1].pos;
	
	if(pos)
	{
		*pos = start.To(end);
	}
	
	return Type(cname, opt);
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
	
	std::vector<Type> rtypes;
	
	if(head->kind != Token::t_name && !IsBinop(head->kind) && head->kind != Token::t_lbracket)
	{
		Type t = ParseType();
		if(!t.cname)
		{
			AddInfo("as return type for method started here:", start);
			delete m;
			return NULL;
		}
		rtypes.push_back(t);
		
		while(Accept(Token::t_comma))
		{
			Type t = ParseType();
			if(!t.cname)
			{
				AddInfo("as return type for method started here:", start);
				delete m;
				return NULL;
			}
			rtypes.push_back(t);
		}
	}
	
	m->rtype = MultiType(rtypes);
	
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
		SourcePos type_pos;
		
		Type t = ParseType(&type_pos);
		if(!t.cname)
		{
			AddInfo("as argument type in method started here:", start);
			delete m;
			return NULL;
		}
		
		SourcePos name_pos = head->pos;
		
		if(!Expect(Token::t_name))
		{
			AddInfo("as argument name in method started here:", start);
			delete m;
			return NULL;
		}
		
		Method::Argument arg;
		arg.type = t;
		arg.name = head[-1].string;
		arg.type_pos = type_pos;
		arg.name_pos = name_pos;
		m->args.push_back(arg);
		
		while(Accept(Token::t_comma))
		{
			SourcePos type_pos;
			
			Type t = ParseType(&type_pos);
			if(!t.cname)
			{
				AddInfo("as argument type in method started here:", start);
				delete m;
				return NULL;
			}
			
			SourcePos name_pos = head->pos;
			
			if(!Expect(Token::t_name))
			{
				AddInfo("as argument name in method started here:", start);
				delete m;
				return NULL;
			}
			
			Method::Argument arg;
			arg.type = t;
			arg.name = head[-1].string;
			arg.type_pos = type_pos;
			arg.name_pos = name_pos;
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
	
	Type t = ParseType(&m->type_pos);
	if(!t.cname)
	{
		AddInfo("for type in member definition");
		delete m;
		return NULL;
	}
	m->type = t;
	
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
