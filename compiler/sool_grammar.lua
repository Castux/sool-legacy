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

g.chunk = S {
	name = 'chunk',
	R { 'class_def' },
	T 'EOF'
}

g.class_def = S {
	name = 'class definition',
	T 'class',
	T 'ClassName',
	O {
		name = 'parent class declaration',
		S { T ':', T 'ClassName' }
	},
	R { C { 'member_def', 'method_def' } },
	T 'end'
}

g.member_def = S {
	name = 'member definition',
	O { T 'private' },
	T 'type',
	T { name = 'member name', 'Name' }
}

g.list_type = S {
	'type',
	R { S { T ',', 'type' } }
}

g.arg_def = S {
	name = 'argument definition',
	N { name = 'argument type', 'type' },
	T { name = 'argument name', 'Name' }
}

g.list_arg_def = S {
	'arg_def',
	R { S { T ',', 'arg_def' } }
}

g.method_def = S {
	name = 'method definition',
	T 'meth',
	O { T 'private' },
	O { name = 'return types', 'list_type' },
	C {
		name = 'method name',
		S { T 'Name', O { T '=' } },
		S { T 'op', 'binop' }
	},
	T '(', O { 'list_arg_def' }, T ')',
	'block',
	T 'end'
}

g.type = S {
	name = 'type declaration',
	O { T '~' },
	C {
		name = 'type',
		T 'num',
		T 'vec',
		T 'sym',
		T 'str',
		T 'ClassName',
		S { name = 'array type', T '[', N { name = 'subtype', 'type' }, T ']' },
		S { name = 'list type', T '/', N { name = 'subtype', 'type' }, T '\\' },
		S { name = 'table type', T '{', N { name = 'key subtype', 'type' }, T ',', N { name = 'value subtype', 'type' }, T '}' }
	}
}

g.block = S {
	name = 'block',
	R { S {	'statement', O { T ';' } } },
	O { C {
		name = 'final statement',
		T 'break',
		T 'continue',
		S { name = 'return statement', T 'return', O { name = 'list of return values', 'list_exp' } }
	} }
}

g.statement = C {
	name = 'statement',
	S { name = 'do block', T 'do', 'block', T 'end' },
	S { name = 'while loop', T 'while', 'exp', O { S { name = 'local name of condition', T 'as', T 'Name' } }, T 'do', 'block', T 'end' },
	S { name = 'if construct', T 'if', 'exp', O { S { name = 'local name of condition', T 'as', T 'Name' } }, T 'then', 'block',
		R { S { T 'elseif', 'exp', T 'then', 'block' } },
		O { S { T 'else', 'block' } },
		T 'end'
	},
	S { name = 'for loop', T 'for', N { name = 'list of names', 'list_name' }, T 'in', N { name = 'list of expressions', 'list_exp' }, T 'do', 'block', T 'end' },
	'unified_assignment_call'
}

g.list_name = S {
	T 'Name',
	R { S { T ',', T 'Name' } }
}

g.atomic_exp = C {
	name = 'atomic expression',
	T 'Number', T 'String', T 'nil', T 'false', T 'true', T 'Symbol'
}

g.list_constructor = S {
	name = 'list constructor',
	T '/', O { 'list_operand' }, T '\\'
}

g.array_constructor = S {
	name = 'array constructor',
	T '[', O { 'list_operand' }, T ']'
}

g.vector_constructor = S {
	name = 'vector constructor',
	T '<', O { 'list_operand' }, T '>'
}

g.table_pair = S {
	name = 'table constructor pair',
	'operand', T ':', 'operand'
}

g.list_table_pair = S {
	'table_pair',
	R { S { T ',', 'table_pair' } }
}

g.table_constructor = S {
	name = 'table constructor',
	T '{', O { 'list_table_pair' }, T '}'
}

g.object_constructor = S {
	name = 'object constructor',
	T 'ClassName', O { 'call_arguments' }
}

g.constructor = C {
	name = 'constructor',
	'list_constructor',
	'array_constructor',
	'vector_constructor',
	'table_constructor',
	'object_constructor'
}

g.method_call = S {
	name = 'method call',
	T 'Name',
	O { 'call_arguments' }
}

g.call_arguments = C {
	name = 'argument',
	S { name = 'parenthesised argument list', T '(', O { 'list_exp' }, T ')' },
	'atomic_exp',
	'object_constructor',
	'table_constructor'
}

g.basic_exp = S {
	name = 'basic expression',
	C {
		'atomic_exp',
		S { T '(', 'exp', T ')' },
		'constructor',
		'method_call'
	},
	'exp_tail'
}

g.exp_tail = R { C {
	name = 'basic expression tail',
	S { name = 'message passing', T '.', 'method_call' },
	S { name = 'indexing', T '[', 'exp', T ']' }
} }

g.unary_operation = S {
	name = 'unary operation',
	C { T '-', T '#', T 'not' },
	'operand'
}

g.operand = C {
	name = 'operand',
	'basic_exp',
	'unary_operation'
}

g.list_operand = S {
	'operand',
	R { S { T ',', 'operand' } }
}

g.exp = S {
	name = 'expression',
	'operand',
	R { S { name = 'binary operation', 'binop', 'operand' } }
}

g.binop = C {
	name = 'binary operator',
	T '+', T '-', T '*', T '/', T '%', T '<', T '>', T '<=', T '>=', T '==', T 'and', T 'or', T 'xor', T '&', T '|', T '^'
}

g.list_exp = S {
	'exp',
	R { S { T ',', 'exp' } }
}

g.lvalue = S {
	name = 'left value',
	'method_call',
	'exp_tail'
}

g.list_lvalue = S {
	'lvalue',
	R { S { T ',', 'lvalue' } }
}

g.unified_assignment_call = S {
	name = 'unified assignment and lone method call',
	'list_lvalue',
	O { S { T '=', 'list_exp' } }
}

SoolGrammar = Grammar(g,'chunk')
