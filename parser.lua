local tokens

local current

-- look ahead
local function peek(n)
	local n = n or 1

	if not tokens[current + n - 1] then
		return nil
	else
		return tokens[current + n - 1][1]
	end
end

local function peekval()
	if not tokens[current] then
		return nil
	else
		return tokens[current][2]
	end
end

-- advance by one token
local function consume()
	debug('Consumed ' .. (tokens[current][2] or tokens[current][1]))
	current = current + 1
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
		error("Parse error: expected " .. tok .. ", found " .. peek() .. " instead (value:" .. (tokens[1][2] or '') .. ")")
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
		error("Parse error: expected digraph" .. s .. ", found " .. peek() .. " instead (value:" .. (tokens[current][2] or '') .. ")")
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
		
		error("Malformed binary operator: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
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
	
	debug'Entering chunk'
	
	local t = { node = 'chunk' }
	
	-- block
	if peek() ~= 'class' then
		t.block = block()
	
	-- { class }
	else
		while( peek() == 'class' ) do
			local cl = class()
			t[#t+1] = cl
		end
	end

	debug'Leaving chunk'
	
	return t
end

--[[
class :=		'class' ClassName [ ':' ClassName ]
				{ [ 'private' ] type Name }
				[ 'methods' { method } ]
				'end'
]]

class = function()
	
	debug'Entering class'
	
	local t = { node = 'class' }
	
	-- 'class'
	expect 'class'
	
	-- ClassName
	t.name = expect 'ClassName'
	
	-- [ ':' ClassName ]
	if accept ':' then
		t.parent = expect 'ClassName'
	end
	
	-- { [ 'private' ] type Name }
	t.members = {}
	
	while peek() ~= 'methods' and peek() ~= 'end' do
		local mem = {}
		
		if accept 'private' then
			mem.private = true
		end
		
		mem.type = type()
		
		mem.name = expect 'Name'
		
		t.members[#t.members+1] = mem
	end
	
	-- [ 'methods' { meth_def } ]
	t.methods = {}
	
	if accept 'methods' then
		while peek() ~= 'end' do
			t.methods[#t.methods+1] = method()
		end
	end
	
	-- 'end'
	expect 'end'
	
	debug'Leaving class'
	
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
	
	debug'Entering type'
	
	local t = { node = 'type' }
	
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
		expect ']'
		
	-- '/' type '/'
	
	elseif accept '/' then
		t.list = type()
		expect '/'
	
	-- '{' { type  [ ',' ] } '}'
	
	elseif accept '{' then
		
		t.pack = {}
		
		while peek() ~= '}' do
			t.pack[#t.pack+1] = type()
			accept ','
		end
		
		expect '}'
		
	else
		error("Malformed type: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
	end
	
	debug'Leaving type'
	
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
	
	debug'Entering method'
	
	local t = { node = 'method' }
	
	-- [ 'private' ]
	if accept 'private' then
		t.private = true
	end
	
	-- [ type { ',' type } ]
	t.ret = {}
	
	if peek() ~= 'Name' then
		
		t.ret[#t.ret+1] = type()
		
		while peek() == ',' do
			expect ','
			t.ret[#t.ret+1] = type()
		end
	end	
	
	-- Name
	t.name = expect 'Name'
	
	-- '(' { type Name [ ',' ] } ')'
	t.args = {}
	
	expect '('
	while peek() ~= ')' do
		local arg = { node = 'arg' }
		
		arg.type = type()
		arg.name = expect 'Name'
		
		accept ','
		
		t.args[#t.args+1] = arg
	end
	expect ')'
	
	-- block
	t.body = block()
	
	-- 'end'
	expect 'end'
	
	debug'Leaving method'
	
	return t
end

--[[
block :=		{ stat [ ';' ] }
				[ break | continue | return [ listexp ] ]
]]

block = function()
	
	debug'Entering block'
	
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
		
	debug'Leaving block'
	
	return t
end

stat = function()
	
	local t = {}
	
	debug'Entering stat'
	
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
		else
			if #lval == 1 and lval[1].node == 'call' then
				t = lval[1]
			else
				error("Malformed call: " .. peek())
			end
		end
	
	-- no empty statement
	else
		error("Malformed statement: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
	end
	
	debug'Leaving stat'
	
	return t
end

--[[
listexp :=		exp { ',' exp }
]]

-- Does not return a node, just a list

listexp = function()
	
	debug'Entering listexp'
	
	local t = {}
	
	t[1] = exp()
	
	while accept ',' do
		t[#t+1] = exp()
	end
	
	debug'Leaving listexp'
	
	return t
end

--[[
listbasicexp :=	basicexp { ',' basicexp }
]]

-- Does not return a node, just a list

listbasicexp = function()
	
	debug'Entering listbasicexp'
	
	local t = {}
	
	t[1] = basicexp()
	
	while accept ',' do
		t[#t+1] = basicexp()
	end
	
	debug'Leaving listbasicexp'
	
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
	
	debug'Entering atomicexp'
	
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
		error("Malformed expression: " .. peek() .. "(value: " .. (tokens[current][2] or '') .. ")")
	end
	
	debug'Leaving atomicexp'
	
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
	
	debug'Entering basicexp'
	
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

	debug'Leaving basicexp'
	
	return t
end

--[[
exp := 			basicexp { Binop basicexp }
]]

-- Happily produces a leftmost derivation! Operators are naturally
-- left associative.

exp = function()
	
	debug'Entering exp'
	
	local t
	
	-- basicexp { Binop basicexp }
	t = basicexp()
	
	while binop(true) do	-- true for only peeking
		t = { node = 'binop', left = t }
		t.binop = binop()
		t.right = basicexp()
	end
	
	debug'Leaving exp'
	
	return t
end

function parse(toks)
	tokens = toks
	current = 1
	
	-- add end mark
	tokens[#tokens+1] = {'EOF'}
	
	-- apply top level rule
	local tree = chunk()
	
	expect 'EOF'
	
	return tree
end
