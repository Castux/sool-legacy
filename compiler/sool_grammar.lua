-- Shortcuts

local S = Sequence
local C = Choice
local T = Terminal

local R = Repetition
local O = Optional

local N = NamedRule

-- Helper function for lists following the model: rule := subrule { ',' subrule }

local flatten = function(n)
	
	local t = {n[1]}
	
	for i,v in ipairs(n[2]) do
		table.insert(t,v[2])
	end
	
	return t
end

------------------------
-- Grammar definition --
------------------------

local g = {}

g.chunk = S {
	name = 'chunk',
	R { 'class_def' },
	T 'EOF',
	
	abstr = function(n) return Chunk(n[1]) end
}

g.class_def = S {
	name = 'class definition',
	T 'class',
	T 'ClassName',
	O { S { T ':', T 'ClassName', abstr = function(n) return n[2] end } },
	R { C { 'member_def', 'method_def' } },
	T 'end',
	
	abstr = function(n) return Class(n[2],n[3],n[4]) end
}

g.member_def = S {
	name = 'member definition',
	O { T 'private' },
	'type',
	T { name = 'member name', 'Name' },
	
	abstr = function(n) return Member(n[1] ~= nil,n[2],n[3]) end
}

g.list_type = S {
	'type',
	R { S { T ',', 'type' } },
	
	abstr = flatten
}

g.arg_def = S {
	name = 'argument definition',
	N { name = 'argument type', 'type' },
	T { name = 'argument name', 'Name' },
	
	abstr = function(n) return Argument(n[1],n[2]) end
}

g.list_arg_def = S {
	name = 'list of argument definitions',
	'arg_def',
	R { S { T ',', 'arg_def' } },
	
	abstr = flatten
}

g.method_def = S {
	name = 'method definition',
	T 'meth',
	O { T 'private' },
	O { name = 'return types', 'list_type' },
	C {
		name = 'method name',
		S { T 'Name', O { T '=' }, abstr = function(n) return { name = n[1] .. (n[2] and '=' or ''), setter = n[2] ~= nil } end },
		S { T 'op', 'binop', abstr = function(n) return { name = n[2], setter = false } end }
	},
	T '(', O { 'list_arg_def' }, T ')',
	'block',
	T 'end',
	
	abstr = function(n) return Method(n[2],n[3],n[4].name,n[4].setter,n[6],n[8]) end
}

g.type = S {
	name = 'type declaration',
	O { T '~' },
	C {
		name = 'type',
		T { 'num', abstr = function(val) return NumberType() end },
		T { 'vec', abstr = function(val) return VectorType() end },
		T { 'sym', abstr = function(val) return SymbolType() end },
		T { 'str', abstr = function(val) return StringType() end },
		T { 'ClassName', abstr = function(val) return ClassType(val) end },
		
		S {
			name = 'array type',
			T '[', N { name = 'subtype', 'type' }, T ']',
			
			abstr = function(n) return ArrayType(n[2]) end
		},
		S {
			name = 'list type',
			T '/', N { name = 'subtype', 'type' }, T '\\',
			
			abstr = function(n) return ListType(n[2]) end
		},
		S {
			name = 'table type',
			T '{', N { name = 'key subtype', 'type' }, T ',', N { name = 'value subtype', 'type' }, T '}',
			
			abstr = function(n) return TableType(n[2],n[4]) end
		}
	},
	
	abstr = function(n) return Type(n[1] ~= nil,n[2]) end
}

g.block = S {
	name = 'block',
	R { S { 'statement', O { T ';' } } },
	O { C {
		name = 'final statement',
		T 'break',
		T 'continue',
		S { name = 'return statement', T 'return', O { name = 'list of return values', 'list_exp' } }
	} },
	
	abstr = function(n) return Block() end
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

return Grammar(g,'chunk')
