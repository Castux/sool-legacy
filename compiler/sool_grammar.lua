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
	
	abstr = function(n) return Method(n[2] ~= nil,n[3] or {},n[4].name,n[4].setter,n[6] or {},n[8]) end
}

g.type = C {
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
		name = 'table type',
		T '{', N { name = 'key subtype', 'type' }, T ',', N { name = 'value subtype', 'type' }, T '}',
		
		abstr = function(n) return TableType(n[2],n[4]) end
	}
}

g.block = S {
	name = 'block',
	R { S { 'statement', O { T ';' }, abstr = function(n) return n[1] end } },
	O { C {
		name = 'final statement',
		T { 'break', abstr = function(val) return Break() end },
		T { 'skip', abstr = function(val) return Skip() end },
		
		S {
			name = 'return statement',
			T 'return', O { name = 'list of return values', 'list_exp' },
			
			abstr = function(n) return Return(n[2] or {}) end
		}
	} },
	
	abstr = function(n) return Block(n[1],n[2]) end
}

g.statement = C {
	name = 'statement',
	
	S {
		name = 'do block', T 'do', 'block', T 'end',
		abstr = function(n) return Do(n[2]) end
	},
	
	S {
		name = 'while loop',
		T 'while',
		'exp',
		O { S { name = 'local name of condition', T 'as', T 'Name', abstr = function(n) return n[2] end } },
		T 'do',
		'block',
		T 'end',
		
		abstr = function(n) return While(n[2],n[3],n[5]) end
	},
	
	S {
		name = 'if construct',
		T 'if',
		N { name = 'condition', 'exp' },
		O { S { name = 'local name of condition', T 'as', T 'Name', abstr = function(n) return n[2] end } },
		T 'then',
		'block',
		R { S { T 'elseif', 'exp', T 'then', 'block', abstr = function(n) return { cond = n[2], body = n[4] } end } },
		O { S { T 'else', 'block', abstr = function(n) return n[2] end } },
		T 'end',
		
		abstr = function(n)
			local alts = n[6]
			table.insert(alts, 1, { cond = n[2], body = n[5] })
			return If(alts,n[7],n[3])
		end
	},
	
	S {
		name = 'for loop',
		T 'for',
		N { name = 'list of names', 'list_name' },
		T 'in',
		N { name = 'list of expressions', 'list_exp' },
		T 'do',
		'block',
		T 'end',
		
		abstr = function(n) return For(n[2],n[4],n[6]) end
	},
	
	'name_statement'
}

g.list_name = S {
	T 'Name',
	R { S { T ',', T 'Name' } },
	
	abstr = flatten
}

g.atomic_exp = C {
	name = 'atomic expression',
	T { 'Number', abstr = function(val) return AtomicNumber(val) end },
	T { 'String', abstr = function(val) return AtomicString(val) end },
	T { 'false', abstr = function(val) return AtomicBool(false) end },
	T { 'true', abstr = function(val) return AtomicBool(true) end },
	T { 'Symbol', abstr = function(val) return AtomicSymbol(val) end },
	T { 'nil', abstr = function(val) return AtomicNil() end },
}

g.array_constructor = S {
	name = 'array constructor',
	T '[', O { 'list_operand' }, T ']',
	
	abstr = function(n) return ArrayCons(n[2] or {}) end
}

g.vector_constructor = S {
	name = 'vector constructor',
	T '<', O { 'list_operand' }, T '>',
	
	abstr = function(n) return VectorCons(n[2] or {}) end
}

g.table_pair = S {
	name = 'table constructor pair',
	'operand', T ':', 'operand',
	
	abstr = function(n) return { key = n[1], value = n[3] } end
}

g.list_table_pair = S {
	'table_pair',
	R { S { T ',', 'table_pair' } },
	
	abstr = flatten
}

g.table_constructor = S {
	name = 'table constructor',
	T '{', O { 'list_table_pair' }, T '}',
	
	abstr = function(n) return TableCons(n[2] or {}) end
}

g.object_constructor = S {
	name = 'object constructor',
	T 'ClassName', O { 'call_arguments' },
	
	abstr = function(n) return ObjectCons(n[1],n[2]) end
}

g.constructor = C {
	name = 'constructor',
	'array_constructor',
	'vector_constructor',
	'table_constructor',
	'object_constructor'
}

g.method_call = S {
	name = 'method call',
	T 'Name',
	O { 'call_arguments' },
	
	abstr = function(n) return MethodCall(n[1],n[2]) end
}

g.call_arguments = C {
	name = 'argument',
	S { name = 'parenthesised argument list', T '(', O { 'list_exp' }, T ')', abstr = function(n) return n[2] or {} end },
	'atomic_exp',
	'object_constructor',
	'table_constructor'
}

g.basic_exp = S {
	name = 'basic expression',
	C {
		'atomic_exp',
		S { T '(', 'exp', T ')', abstr = function(n) return n[2] end },
		'constructor',
		'method_call'
	},
	'exp_tail',
	
	abstr = function(n) return LeftDerivation(n[1],n[2]) end
}

g.exp_tail = R { C {
	name = 'basic expression tail',
	S { name = 'message passing', T '.', 'method_call', abstr = function(n) return n[2] end },
	S { name = 'indexing', T '[', 'exp', T ']', abstr = function(n) return Indexing(n[2]) end }
} }

g.unary_operation = S {
	name = 'unary operation',
	C { T '-', T '#', T 'not' },
	'operand',
	
	abstr = function(n) return UnaryOperation(n[1],n[2]) end
}

g.operand = C {
	name = 'operand',
	'basic_exp',
	'unary_operation'
}

g.list_operand = S {
	'operand',
	R { S { T ',', 'operand' } },
	
	abstr = flatten
}

g.binop = C {
	name = 'binary operator',
	T '+', T '-', T '*', T '/', T '%', T '<', T '>', T '<=', T '>=', T '==', T 'and', T 'or', T 'xor', T '&', T '|', T '^'
}

g.binary_operation = S {
	name = 'binary operation',
	'binop',
	'operand',
	
	abstr = function(n) return BinaryOperation(n[1],n[2]) end
}

g.exp = S {
	name = 'expression',
	'operand',
	R { 'binary_operation' },
	
	abstr = function(n) return LeftDerivation(n[1],n[2]) end
}

g.list_exp = S {
	'exp',
	R { S { T ',', 'exp' } },
	
	abstr = flatten
}

g.lvalue = S {
	name = 'left value',
	'method_call',
	'exp_tail',
	
	abstr = function(n) return LeftDerivation(n[1],n[2]) end
}

g.list_lvalue = S {
	'lvalue',
	R { S { T ',', 'lvalue' } },
	
	abstr = flatten
}

g.name_statement = S {
	name = 'assignment',	-- the lvalue and binary operation rules have name fields, so any
							-- error there will never be propagated up here.
							-- We can safely assume that the error came from the assignment subrule
	
	'lvalue',
	
	C {
		R { 'binary_operation' },
		
		S {
			O { S { T ',', 'list_lvalue', abstr = function(n) return n[2] end } },
			S { T '=', 'list_exp', abstr = function(n) return n[2] end },
			
			abstr = function(n) n.ass = true; return n end
		}
	},
	
	abstr = function(n)
		
		-- The choice returned nothing -> single lvalue
		if not n[2] then
			return n[1]
		
		-- Assignment
		elseif n[2].ass then
			local lvals = n[2][1] or {}
			table.insert(lvals,1,n[1])
			
			local rvals = n[2][2]
			
			return Assignment(lvals,rvals)
			
		-- Operations
		else
			return LeftDerivation(n[1],n[2])
		end
		
		error('Unreachable')
	end
}

return Grammar(g,'chunk')
