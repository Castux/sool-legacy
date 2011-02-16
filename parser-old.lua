local tokens

local current

-- error handling
local errors

local function add_err(typ,mess,pos)
	
	local err =  {
		"Compiler",
		typ,
		mess,
		pos or tokens[current][3]
	}
	
	errors[#errors + 1] = err
	
end



-- parse optionnal token
local function accept(tok)
	if peek() == tok then
		local val = tokens[current][2] or tok
		consume()
		return val
	else
		return nil
	end
end

-- parse mandatory token
local function expect(tok)
	if peek() == tok then
		local val = tokens[current][2]
		consume()
		return val
	else
		add_err("error", "expected " .. tok .. 
			", found " .. peek() .. " instead")
		return nil
	end
end

-- digraphs

local function peek2()
	return (peek() or 'argh') .. (peek(2) or 'argh')
end

local function accept2(s)
	if peek() == s:sub(1,1) and peek(2) == s:sub(2,2) then
		consume()
		consume()
		return s
	else
		return nil
	end
end

local function expect2(s)
	if peek() == s:sub(1,1) and peek(2) == s:sub(2,2) then
		consume()
		consume()
		return s
	else
		add_err("error", "expected digraph" .. s ..
			", found " .. peek() .. " instead")
		return nil
	end
end

----------------------------
-- Advanced lexical rules --
----------------------------

local binop

binop = function(only_peek)

	local ops = {'+','-','*','/','%','<','>','^','|','xor','and','or'}
	local digr = {'+=','-=','*=','/=','%=','<=','>=','==','~=','<<','>>',
		'^=','|=' }
	
	if only_peek then
	-- don't consume
		
		-- test digraphs first, or they never get used
		for i,v in ipairs(digr) do
			if peek2() == v then
				return true
			end
		end	
		
		for i,v in ipairs(ops) do
			if peek() == v then
				return true
			end
		end
		
		return false
	-- consume
	else
		for i,v in ipairs(digr) do
			if accept2(v) then
				return v
			end
		end
		
		for i,v in ipairs(ops) do
			if accept(v) then
				return v
			end
		end
		
		add_err("error", "malformed binary operator")
		return nil
	end

end

-------------------
-- Grammar rules --
-------------------

local begin_exp
local chunk, class, type, block, method, stat, listexp, exp, atomicexp,
	exptail, basicexp

--[[
chunk := 		block |
				{ class_def }
]]

chunk = function()
	
	local t = { node = 'chunk' }
	
	-- block
	if peek() ~= 'class' then
		t.block = block()
		if not t.block then return end
	
	-- { class }
	else
		while( peek() == 'class' ) do
			local cl = class()
			if not cl then return end
			t[#t+1] = cl
		end
	end

	return t
end

--[[
class :=		'class' ClassName [ ':' ClassName ]
				{ [ 'private' ] type Name }
				[ 'methods' { method } ]
				'end'
]]

class = function()
	
	local t = { node = 'class' }
	
	-- 'class'
	local cl = expect 'class'
	if not cl then return end
	
	-- ClassName
	t.name = expect 'ClassName'
	if not t.name then return end
	
	-- [ ':' ClassName ]
	if accept ':' then
		t.parent = expect 'ClassName'
		if not t.parent then return end
	end
	
	-- { [ 'private' ] type Name }
	t.members = {}
	
	while peek() ~= 'methods' and peek() ~= 'end' do
		local mem = {}
		
		if accept 'private' then
			mem.private = true
		end
		
		mem.type = type()
		if not mem.type then return end
		
		mem.name = expect 'Name'
		if not mem.name then return end
		
		t.members[#t.members+1] = mem
	end
	
	-- [ 'methods' { meth_def } ]
	t.methods = {}
	
	if accept 'methods' then
		while peek() ~= 'end' do
			local meth = method()
			if not meth then return end
			
			t.methods[#t.methods+1] = meth
		end
	end
	
	-- 'end'
	
	local en = expect 'end'
	if not en then return end
	
	return t
end

--[[
type :=			'num' | 'vec' | 'str' |
				ClassName |
				'[' type ']' |
				'/' type '/' |
				'{' { type  [ ',' ] } '}'
]]

type = function()
	
	local t = { node = 'type' }
	local tok
	
	local val = peekval()
	
	-- 'num' | 'vec' | 'str'
	if accept 'num' then
		t.num = true
	elseif accept 'vec' then
		t.vec = true
	elseif accept 'str' then
		t.str = true
	
	-- ClassName
	
	elseif accept 'ClassName' then
		t.class = val
	
	-- '[' type ']'
	
	elseif accept '[' then
		t.array = type()
		if not t.array then return end
		tok = expect ']'
		if not tok then return end
		
	-- '/' type '/'
	
	elseif accept '/' then
		t.list = type()
		if not t.list then return end
		tok = expect '/'
		if not tok then
			add_err('info','to complete list constructor')
			return
		end
	
	-- '{' { type  [ ',' ] } '}'
	
	elseif accept '{' then
		
		t.pack = {}
		
		while peek() ~= '}' do
			tok = type()
			if not tok then return end
			t.pack[#t.pack+1] = tok
			accept ','
		end
		
		tok = expect '}'
		if not tok then return end
		
	else
		add_err("error","malformed type")
		return
	end
	
	return t
end

--[[
method :=		[ 'private' ] [ type { ',' type } ]
				Name
				'(' { type Name [ ',' ] } ')'
				block
				'end'
]]

method = function()
	
	local t = { node = 'method' }
	local tok
	
	-- [ 'private' ]
	if accept 'private' then
		t.private = true
	end
	
	-- [ type { ',' type } ]
	t.ret = {}
	
	if peek() ~= 'Name' then
		
		tok = type()
		if not tok then return end
		t.ret[#t.ret+1] = tok
		
		while peek() == ',' do
			tok = expect ','
			if not tok then return end
			
			tok = type()
			if not tok then return end
			t.ret[#t.ret+1] = tok
		end
	end	
	
	-- ( Name | 'op' Binop )	
	if accept 'op' then
		t.name = binop()
		if not t.name then return end
	else
		t.name = expect 'Name'
		if not t.name then return end
	end
	
	-- '(' { type Name [ ',' ] } ')'
	t.args = {}
	
	tok = expect '('
	if not tok then return end
	
	while peek() ~= ')' do
		local arg = { node = 'arg' }
		
		arg.type = type()
		if not arg.type then return end
		
		arg.name = expect 'Name'
		if not arg.name then return end
		
		accept ','
		
		t.args[#t.args+1] = arg
	end
	tok = expect ')'
	if not tok then return end
	
	-- block
	t.body = block()
	if not t.body then return end
	
	-- 'end'
	tok = expect 'end'
	if not tok then return end
	
	return t
end

--[[
block :=		{ stat [ ';' ] }
				[ break | continue | return [ listexp ] ]
]]

block = function()
	
	local t = { node = 'block' }
	
	-- { stat }
	while peek() ~= 'end' and peek() ~= 'else' and peek() ~= 'elseif' and 
		peek() ~= 'break' and peek() ~= 'continue' and peek() ~= 'return' and
		peek() ~= ';' and peek() ~= 'EOF' do
		
		t[#t+1] = stat()
		accept ';'
	end
	
	-- [ break | continue | return { exp [ ',' ] } ]
	if accept 'break' then
		t[#t+1] = { node = 'break' }
	
	elseif accept 'continue' then
		t[#t+1] = { node = 'continue' }
	
	-- return { return [ listexp ] }
	elseif accept 'return' then
		local n = { node = 'return' }
		
		if peek() ~= 'end' then
			n.vals = listexp()
		end
		
		t[#t+1] = n
	end
		
	return t
end

stat = function()
	
	local t = {}
	
	-- 'do' block 'end'
	if accept 'do' then
		t = block()
		expect 'end'
	
	-- 'while' exp 'dö́' block 'end'
	elseif accept 'while' then
		t.node = 'while'
		
		t.exp = exp()
		expect 'do'
		t.body = block()
		expect 'end'
	
	-- 'if'
	elseif accept 'if' then
		t.node = 'if'
		t.tests = {}
		
		-- exp 'then' block
		-- { 'elseif' exp 'then' block }
		repeat
			local test = {}
			test.cond = exp()
			expect 'then'
			test.body = block()
			
			t.tests[#t.tests+1] = test	
		until not accept 'elseif'
	
		-- [ 'else' block ]
		if accept 'else' then
			t.default = block()
		end
		
		expect 'end'
	
	-- 'for' Name '=' exp ',' exp [ ',' exp ] do block end
	elseif peek() == 'for' and peek(3) == '=' then
		t.node = 'num_for'
				
		expect 'for'
		t.var = expect 'Name'
		expect '='
		
		t[1] = exp()
		expect ','
		t[2] = exp()
		
		if accept ',' then
			t[3] = exp()
		end
		
		expect 'do'
		t.body = block()
		expect 'end'
	
	-- 'for' Name { [ ',' ] Name } 'in' exp 'do' block 'end'
	elseif accept 'for' then
		t.node = 'generic_for'
		
		t[1] = expect 'Name'
		
		while peek() ~= 'in' do
			accept ','
			t[#t+1] = expect 'Name'
		end
		
		expect 'in'
		t.exp = exp()
		expect 'do'
		t.body = block()
		expect 'end'
	
	-- methodcall
	-- listbasicexp '=' listexp
	elseif begin_exp(peek()) then
		local lval = listbasicexp()
		local rval
		
		if accept '=' then
			rval = listexp()
			t.node = 'assignment'
			t.lval = lval
			t.rval = rval
		elseif #lval == 1 then
				t = lval[1]
		else
			-- we have a listexp with several exps, but no "="
			add_err("error","malformed multi assignment: expected '=', found " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")	
		end
	
	-- no empty statement
	else
		add_err("error","malformed statement: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
	end
	
	return t
end

--[[
listexp :=		exp { ',' exp }
]]

-- Does not return a node, just a list

listexp = function()
	
	local t = {}
	
	t[1] = exp()
	
	while accept ',' do
		t[#t+1] = exp()
	end
	
	return t
end

--[[
listbasicexp :=	basicexp { ',' basicexp }
]]

-- Does not return a node, just a list

listbasicexp = function()
	
	local t = {}
	
	t[1] = basicexp()
	
	while accept ',' do
		t[#t+1] = basicexp()
	end
	
	return t
end

begin_exp = function(s)
	
	local toks = {'Name','Number','String','nil','false','true',
		'(','[','/','<','not','+','-'}
	
	for i,v in ipairs(toks) do
		if s == v then return true end
	end
	
	return false	
end

--[[
atomicexp :=	Name | Number | String | 'nil' | 'false' | 'true' |
				Symbol | '(' exp ')' |
				'{' [ listbasicexp ] '}' |
				'[' [ listbasicexp ] ']' |
				'/' [ listbasicexp ] '/' |
				'<' [ listbasicexp ] '>' |
				ClassName [ '(' [ listexp ] ')' ]
]]

atomicexp = function()
	
	local t = {}
	
	local val = peekval()
	
	-- Name | Number | String | 'nil' | 'false' | 'true' | Symbol
	if accept 'Name' then
		t.node = 'var'
		t.name = val
		
	elseif accept 'Number' then
		t.node = 'number'
		t.val = val
		
	elseif accept 'String' then
		t.node = 'string'
		t.val = val

	elseif accept 'Symbol' then
		t.node = 'symbol'
		t.val = val
	
	elseif accept 'nil' then
		t.node = 'nil'
	
	elseif accept 'true' then
		t.node = 'true'
	
	elseif accept 'false' then
		t.node = 'false'
	
	-- '(' exp ')'
	elseif accept '(' then
		t = exp()
		expect ')'
		
	-- '{' [ listbasicexp ] '}'
	elseif accept '{' then
		t.node = 'pack'
		if peek() ~= '}' then
			t.vals = listbasicexp()
		end
		expect '}'
	
	-- '[' [ listbasicexp ] ']'
	elseif accept '[' then
		t.node = 'array'
		if peek() ~= ']' then
			t.vals = listbasicexp()
		end
		expect ']'
		
	-- '/' [ listbasicexp ] '/'
	elseif accept '/' then
		t.node = 'list'
		if peek() ~= '/' then
			t.vals = listbasicexp()
		end
		expect '/'
		
	-- '<' [ listbasicexp ] '>'
	elseif accept '<' then
		t.node = 'vector'
		if peek() ~= '>' then
			t.vals = listbasicexp()
		end
		expect '>'
	
	-- ClassName [ '(' [ listexp ] ')' ]
	elseif accept 'ClassName' then
		t.node = 'instanciation'
		t.class = val
		if accept '(' then
			if peek() ~= ')' then
				t.args = listexp()
			end
			expect ')'
		end
	
	else
		add_err("error","malformed expression: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
	end
	
	return t
end

--[[
exptail :=		'.' Name [ '(' [ listexp ] ')' ] |
				'[' exp ']'
				
basicexp :=		atomicexp { exptail }
]]

-- Happily produces a leftmost derivation (good for access which is
-- left associative, and indexing, which is suffix )

basicexp = function()
	
	-- atomicexp
	local t = atomicexp()
	
	-- { exptail }
	while peek() == '.' or peek() == '[' do
		t = { var = t }
		
		-- '[' exp ']'
		if accept '[' then
			t.node = 'index'
			t.index = exp()
			expect ']'
		
		-- '.' Name [ '(' [ listexp ] ')' ]
		elseif accept '.' then
			
			t.name = expect 'Name'
			
			if accept '(' then
				t.node = 'call'
				if peek() ~= ')' then
					t.args = listexp()
				end
				expect ')'
			else
				t.node = 'member_access'
			end
		end
		
	end

	return t
end

--[[
exp := 			basicexp { Binop basicexp }
]]

-- Happily produces a leftmost derivation! Operators are naturally
-- left associative.

exp = function()
	
	local t
	
	-- basicexp { Binop basicexp }
	t = basicexp()
	
	while binop(true) do	-- true for only peeking
		t = { node = 'binop', left = t }
		t.binop = binop()
		t.right = basicexp()
	end
	
	return t
end

function parse(toks)
	tokens = toks
	current = 1
	errors = {}
	
	-- apply top level rule
	local tree = chunk()
	if not tree then return nil,errors end
	
	local eof = expect 'EOF'
	if not eof then return nil,errors end
	
	return tree,errors
end
