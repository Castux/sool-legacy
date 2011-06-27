--[[

Each rule table is a list of
- terminal string
- non terminal string (the name will be expected in the grammar table)
- rule table

Every rule is a sequence by default. Following modifiers change the behavior:

optional = true: will not fail if the first token does not match. Will fail if the first token matches and a subsequent error occurs. [ sequence ]

repetition = true: like optional, but tries to parse again after each match. { sequence }.

choice = true: the list of subrules is not interpreted as a sequence but as a choice. One and only one subrule must and will match. ( subrule1 | subrule2 | subrule3 )

The modifiers are combinable. It is valid (but useless) to add optional to a repetition

The 'name' field can be filled with a human readable description of the rule, used in verbose error messages

The Nova thingy will read in this grammar, validate it as LL(1), and allow parsing a list of tokens using it, producing a concrete syntax tree (= "parse tree").

Here I take the convention that "list" means comma separated with at least one element

]]

local S = Sequence		-- table of rules and 'name'
local C = Choice		-- table of rules and 'name'
local T = Terminal		-- string or table with one string and 'name'

local R = Repetition	-- table with one rule and 'name'
local O = Optional		-- table with one rule and 'name'

local N = NamedRule		-- table with one rule and 'name'	this is used only to wrap a rule for context. There is no wrapper node (inside node is returned).

local g = {}

--[[
g.chunk = {
	name = 'chunk',
	{ repetition = true, 'class_def' },
	'EOF'
}
]]

g.chunk = S {
	name = 'chunk',
	R { 'class_def' },
	T 'EOF'
}

--[[
g.class_def = {
	name = 'class definition',
	'class',
	'ClassName',
	{
		name = 'parent class declaration',
		optional = true,
		':', 'ClassName'
	},
	{
		repetition = true,
		choice = true,
		'member_def',
		'method_def'
	},
	'end'
}
]]

g.class_def = S {
	name = 'class definition',
	T 'class',
	T 'ClassName',
	O {
		name = 'parent class declaration',
		{ T ':', T 'ClassName' }
	},
	R { C { T 'member_def', T 'method_def' } },
	T 'end'
}

--[[
g.member_def = {
	name = 'member definition',
	{ optional = true, 'private' },
	'type',
	{ name = 'member name', 'Name' }
}

g.list_type = {
	'type',
	{ repetition = true, ',', 'type' }
}

g.arg_def = {
	name = 'argument definition',
	{ name = 'argument type', 'type' },
	{ name = 'argument name', 'Name' }
}

g.list_arg_def = {
	'arg_def',
	{ repetition = true, ',', 'arg_def' }
}

g.method_def = {
	name = 'method definition',
	'meth',
	{ optional = true, 'private' },
	{ name = 'return types', optional = true, 'list_type' },
	{
		name = 'method name',
		choice = true,
		{
			'Name',
			{ optional = true, '=' }
		},
		{ 'op', 'binop' }
	},
	'(', { optional = true, 'list_arg_def' }, ')',
	'block',
	'end'
}

g.type = {
	name = 'type declaration',
	{ optional = true, '~' },
	{
		name = 'type',
		choice = true,
		'num',
		'vec',
		'sym',
		'str',
		'ClassName',
		{ name = 'array type', '[', { name = 'subtype', 'type' }, ']' },
		{ name = 'list type', '/', { name = 'subtype', 'type' }, '\\' },
		{ name = 'table type', '{', { name = 'key subtype', 'type' }, ',', { name = 'value subtype', 'type' }, '}' }
	}
}

g.block = {
	name = 'block',
	{
		repetition = true,
		'statement',
		{ optional = true, ';' }
	},
	{
		name = 'final statement',
		choice = true,
		optional = true,
		'break',
		'continue',
		{ name = 'return statement', 'return', { name = 'list of return values', optional = true, 'list_exp' } }
	}
}

g.statement = {
	name = 'statement',
	choice = true,
	{ name = 'do block', 'do', 'block', 'end' },
	{ name = 'while loop', 'while', 'exp', { name = 'local name of condition', optional = true, 'as', 'Name' }, 'do', 'block', 'end' },
	{ name = 'if construct', 'if', 'exp', { name = 'local name of condition', optional = true, 'as', 'Name' }, 'then', 'block',
		{ repetition = true, 'elseif', 'exp', 'then', 'block' },
		{ optional = true, 'else', 'block' },
		'end' },
	{ name = 'for loop', 'for', { name = 'list of names', 'list_name' }, 'in', { name = 'list of expressions', 'list_exp' }, 'do', 'block', 'end' },
	'unified_assignment_call'
}

g.list_name = {
	'Name',
	{ repetition = true, ',', 'Name' }
}

g.atomic_exp = {
	name = 'atomic expression',
	choice = true,
	'Number', 'String', 'nil', 'false', 'true', 'Symbol'
}

g.list_constructor = {
	name = 'list constructor',
	'/', { optional = true, 'list_operand' }, '\\'
}

g.array_constructor = {
	name = 'array constructor',
	'[', { optional = true, 'list_operand' }, ']'
}

g.vector_constructor = {
	name = 'vector constructor',
	'<', { optional = true, 'list_operand' }, '>'
}

g.table_pair = {
	name = 'table constructor pair',
	'operand', ':', 'operand'
}

g.list_table_pair = {
	'table_pair',
	{ repetition = true, ',', 'table_pair' }
}

g.table_constructor = {
	name = 'table constructor',
	'{', { optional = true, 'list_table_pair' }, '}'
}

g.object_constructor = {
	name = 'object constructor',
	'ClassName', { optional = true, 'call_arguments' }
}

g.constructor = {
	name = 'constructor',
	choice = true,
	'list_constructor',
	'array_constructor',
	'vector_constructor',
	'table_constructor',
	'object_constructor'
}

g.method_call = {
	name = 'method call',
	'Name',
	{ optional = true, 'call_arguments' }
}

g.call_arguments = {
	name = 'argument',
	choice = true,
	{ name = 'parenthesised argument list', '(', { optional = true, 'list_exp' }, ')' },
	'atomic_exp',
	'object_constructor',
	'table_constructor'
}

g.basic_exp = {
	name = 'basic expression',
	{
		choice = true,
		'atomic_exp',
		{ '(', 'exp', ')' },
		'constructor',
		'method_call'
	},
	'exp_tail'
}

g.exp_tail = {
	name = 'basic expression tail',
	repetition = true,
	choice = true,
	{ name = 'message passing', '.', 'method_call' },
	{ name = 'indexing', '[', 'exp', ']' }
}

g.unary_operation = {
	name = 'unary operation',
	{ choice = true, '-', '#', 'not' },
	'operand'
}

g.operand = {
	name = 'operand',
	choice = true,
	'basic_exp',
	'unary_operation'
}

g.list_operand = {
	'operand',
	{ repetition = true, ',', 'operand' }
}

g.exp = {
	name = 'expression',
	'operand',
	{ name = 'binary operation', repetition = true, 'binop', 'operand' }
}

g.binop = {
	name = 'binary operator',
	choice = true,
	'+', '-', '*', '/', '%', '<', '>', '<=', '>=', '==', 'and', 'or', 'xor', '&', '|', '^'
}

g.list_exp = {
	'exp',
	{ repetition = true, ',', 'exp' }
}

g.lvalue = {
	name = 'left value',
	'method_call',
	'exp_tail'
}

g.list_lvalue = {
	'lvalue',
	{ repetition = true, ',', 'lvalue' }
}

g.unified_assignment_call = {
	name = 'unified assignment and lone method call',
	'list_lvalue',
	{
		optional = true,
		'=',
		'list_exp'
	}
}
]]

SoolGrammar = Grammar(g,'chunk')
