local tokens

-- look ahead
local function peek()
	if #tokens == 0 then
		return nil
	else
		return tokens[1][1]
	end
end

local function peekval()
	if #tokens == 0 then
		return nil
	else
		return tokens[1][2]
	end
end

-- advance by one token
local function consume()
	table.remove(tokens,1)
end

-- parse optionnal token
local function accept(tok)
	if peek() == tok then
		local val = tokens[1][2] or tok
		consume()
		return val
	else
		return nil
	end
end

-- parse mandatory token
local function expect(tok)
	if peek() == tok then
		local val = tokens[1][2]
		consume()
		return val
	else
		error("Parse error: expected " .. tok .. ", found " .. peek() .. " instead (value:" .. (tokens[1][2] or '') .. ")")
		return nil
	end
end

-------------------
-- Grammar rules --
-------------------

local chunk, class, type, block, method

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
		error("Malformed type: " .. peek() .. "(value: " .. (tokens[1][2] or '') .. ")")
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

block = function()
	local t = { node = 'block' }
	
	return t
end

function parse(toks)
	tokens = toks
	
	-- add end mark
	tokens[#tokens+1] = {'EOF'}
	
	-- apply top level rule
	local tree = chunk()
	
	expect 'EOF'
	
	return tree
end
