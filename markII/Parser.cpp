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
	Class *c;
	Extension *e;
	Interface *i;
	
	context = new Context();
	
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
			case Token::t_object:
			case Token::t_value:
				c = ParseClass();
				if(!c)
					return false;
				else
					context->classes.push_back(c);
					context->globals.push_back(c);
				break;
			case Token::t_interface:
				i = ParseInterface();
				if(!i)
					return false;
				else
					context->interfaces.push_back(i);
					context->globals.push_back(i);
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
			c->kind = Class::k_object;
			break;
		case Token::t_value:
			c->kind = Class::k_value;;
			break;
		default:
			error(std::string("Parser::ParseClass() - wrong class token: ") + head->FancyName());
	}
	
	head++;
	
	// Class name
	
	if(!Expect(Token::t_cname))
	{
		AddInfo("as class name in class definition started here:", start);
		delete c;
		return NULL;
	}
	c->name = head[-1].string;
	c->name_pos = head[-1].pos;
	
	// Template params
	
	std::vector<TemplateParam>* params = ParseTemplateParams();
	if(!params)
	{
		delete c;
		return NULL;
	}
	c->params = *params;
	delete params;
	
	// Definitions
	
	while(head->kind != Token::t_end && head->kind != Token::t_eof)
	{
		// Methods
		if( head->kind == Token::t_method ||
			head->kind == Token::t_selfless ||
			head->kind == Token::t_foreign )
		{
			Method *m = ParseMethod();
			if(!m)
			{
				delete c;
				return NULL;
			}
			c->methods.push_back(m);
		}
		else if (head->kind == Token::t_embed )
		{
			std::vector<ClassName*> *embeds = ParseEmbed();
			if(!embeds)
			{
				delete c;
				return NULL;
			}
			c->embeds.insert(c->embeds.end(), embeds->begin(), embeds->end());
			delete embeds;
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

TemplateParam Parser::ParseTemplateParam()
{
	// An invalid template param is represented by having two empty strings in it
	
	TemplateParam res;
	SourcePos start = head->pos;
	
	ClassName *c = ParseClassName();
	if(!c)
	{
		AddInfo("as template parameter bound");
		return res;
	}
	res.bound = c;
	
	if(!Expect(Token::t_cname))
	{
		AddInfo("as name for template parameter started here:", head[-1].pos, true);
		return res;
	}
	res.name = head[-1].string;
	
	res.pos = start.To(head[-1].pos);
	return res;
}

std::vector<TemplateParam>* Parser::ParseTemplateParams()
{
	std::vector<TemplateParam>* params = new std::vector<TemplateParam>;
	
	if(Accept(Token::t_pipe))
	{
		SourcePos pipe = head[-1].pos;
		
		if(!Expect(Token::t_lparens))
		{
			AddInfo("to open template parameter list introduced here:", pipe);
			delete params;
			return NULL;
		}
		
		SourcePos lparens = head[-1].pos;
		
		// List of params
		
		do
		{
			TemplateParam res = ParseTemplateParam();
			if(res.bound == NULL)
			{
				AddInfo("in template parameter list started here:", lparens, true);
				delete params;
				return NULL;
			};
			params->push_back(res);
			
		} while(Accept(Token::t_comma));
		
		if(!Expect(Token::t_rparens))
		{
			AddInfo("to close template parameters list started here:", lparens, true);
			delete params;
			return NULL;
		}
	}
	
	return params;
}

Extension *Parser::ParseExtension()
{
	Extension *e = new Extension;
	SourcePos start = head->pos;
	
	if(head->kind != Token::t_extend)
		error(std::string("Parser::ParseExtension() - wrong interface token: ") + head->FancyName());
	
	head++;
	
	// Two possibilities here:
	// class-name | CName template-def
	// Super not LL(1)! Behold, mega look-ahead!
	
	// FIXME, this is broken, because the bound can be the application of a template itself
	
	if( head + 4 <= &tokens->back() &&
		head[0].kind == Token::t_cname &&
		head[1].kind == Token::t_pipe &&
		head[2].kind == Token::t_lparens &&
		head[3].kind == Token::t_cname &&
		head[4].kind == Token::t_cname )
	{
		// Template name
		
		e->name = head[0].string;
		head++;
		
		// Template params
		
		std::vector<TemplateParam>* params = ParseTemplateParams();
		if(!params)
		{
			delete e;
			return NULL;
		}
		e->params = *params;
		delete params;
	}
	else
	{
		ClassName *cname = ParseClassName();
		if(!cname)
		{
			delete e;
			return NULL;
		}
		e->cname = cname;
	}
	
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
			
			do
			{
				ClassName *sub = ParseClassName();
				if(!sub)
				{
					AddInfo("in template parameters list started here:", lparens, true);
					return NULL;
				}
				params.push_back(sub);
				
			} while(Accept(Token::t_comma));
			
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

Prototype* Parser::ParsePrototype(bool expect_arg_names)
{
	Prototype *p = new Prototype();
	SourcePos start = head->pos;
	
	if(head->kind != Token::t_name && !IsBinop(head->kind) && head->kind != Token::t_lbracket)
	{
		std::vector<Type> rtypes;
		
		SourcePos rtype_start = head->pos;
		
		do
		{
			Type t = ParseType();
			if(!t.cname)
			{
				AddInfo("as return type for method");
				delete p;
				return NULL;
			}
			rtypes.push_back(t);
			
		} while(Accept(Token::t_comma));
		
		p->rtype = MultiType(rtypes);
		p->rtype_pos = rtype_start.To(head[-1].pos);
	}
	
	// Name
	
	if(head->kind == Token::t_name)
	{
		p->name = head->string;
		head++;
		if(Accept(Token::t_equal))
			p->setter = true;
	}
	else if(IsBinop(head->kind))
	{
		p->name = Token::GetTokenString(head->kind);
		head++;
	}
	else if(head[0].kind == Token::t_lbracket && head[1].kind == Token::t_rbracket)
	{
		p->name = "[]";
		head += 2;
		if(Accept(Token::t_equal))
			p->setter = true;
	}
	else
	{
		AddError("invalid method name", head->pos);
		AddInfo("expected name, operator or '[]'");
		delete p;
		return NULL;
	}
	
	// Arguments
	
	SourcePos lparens = head->pos;
	
	if(!Expect(Token::t_lparens))
	{
		AddInfo("to open argument list in method started here:", start, true);
		delete p;
		return NULL;
	}
	
	if(head->kind != Token::t_rparens)
	{
		do
		{
			Prototype::Argument arg;
			SourcePos argstart = head->pos;
			
			Type t = ParseType();
			if(!t.cname)
			{
				AddInfo("as argument type in list started here:", lparens, true);
				delete p;
				return NULL;
			}
			arg.type = t;
			
			if(expect_arg_names)
			{
				if(!Expect(Token::t_name))
				{
					AddInfo("as name for argument started here:", argstart, true);
					delete p;
					return NULL;
				}
				arg.name = head[-1].string;
			}
			else
			{
				if(Accept(Token::t_name))
				{
					arg.name = head[-1].string;
				}
			}
			arg.pos = argstart.To(head[-1].pos);
			p->args.push_back(arg);
			
		} while(Accept(Token::t_comma));
	}
	
	if(!Expect(Token::t_rparens))
	{
		AddInfo("to close argument list started here:", lparens);
		delete p;
		return NULL;
	}
	
	p->pos = start.To(head[-1].pos);
	p->ComputeSignature();
	
	return p;
}

Method* Parser::ParseMethod()
{
	Method* m = new Method;
	SourcePos start = head->pos;
	
	// Attributes
	
	switch(head->kind)
	{
		case Token::t_method:
			m->kind = Method::k_normal;
			break;
		case Token::t_selfless:
			m->kind = Method::k_selfless;
			break;
		case Token::t_foreign:
			m->kind = Method::k_foreign;
			break;
		default:
			AddError("malformed method definition", head->pos);
			AddInfo("expected 'method', 'selfless' or 'foreign'");
			delete m;
			return NULL;
	}
	m->kind_pos = head->pos;
	head++;
	
	// Proto
	
	Prototype *proto = ParsePrototype(true);	// true to require argument names
	if(!proto)
	{
		AddInfo("for method started here:", start, true);
		delete m;
		return NULL;
	}
	
	m->proto = proto;
	
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

Interface* Parser::ParseInterface()
{
	Interface *i = new Interface;
	SourcePos start = head->pos;
	
	if(head->kind != Token::t_interface)
		error(std::string("Parser::ParseInterface() - wrong interface token: ") + head->FancyName());
	
	head++;
	
	// Interface name
	
	if(!Expect(Token::t_cname))
	{
		AddInfo("as name in interface definition started here:", start);
		delete i;
		return NULL;
	}
	i->name = head[-1].string;
	i->name_pos = head[-1].pos;
	
	// Template params
	
	std::vector<TemplateParam>* params = ParseTemplateParams();
	if(!params)
	{
		delete i;
		return NULL;
	}
	i->params = *params;
	delete params;
	
	// Content
	
	while(head->kind != Token::t_end && head->kind != Token::t_eof)
	{
		if(head->kind == Token::t_embed)
		{
			std::vector<ClassName*> *embeds = ParseEmbed();
			if(!embeds)
			{
				delete i;
				return NULL;
			}
			i->embeds.insert(i->embeds.end(), embeds->begin(), embeds->end());
			delete embeds;
		}
		else
		{
			Prototype *p = ParsePrototype(false);	// false for optional argument names
			if(!p)
			{
				delete i;
				return NULL;
			}
			i->protos.push_back(p);
		}
	}
	
	// End
	
	if(!Expect(Token::t_end))
	{
		AddInfo("to close interface definition started here:", start);
		delete i;
		return NULL;
	}
	
	i->pos = start.To(head[-1].pos);
	
	return i;
}

std::vector<ClassName*>* Parser::ParseEmbed()
{
	SourcePos start = head->pos;
	
	if(head->kind != Token::t_embed)
		error(std::string("Parser::ParseEmbed() - wrong embed token: ") + head->FancyName());
	
	head++;
	
	std::vector<ClassName*> *classes = new std::vector<ClassName*>;
	
	do
	{
		ClassName *c = ParseClassName();
		if(!c)
		{
			AddInfo("in embedding", start, true);
			return NULL;
		}
		classes->push_back(c);
		
	} while(Accept(Token::t_comma));
	
	return classes;
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
