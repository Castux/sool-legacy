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

local chunk, class, type

--[[
chunk := 		block |
				{ class_def }
]]

function chunk()
	
	debug'Entering chunk'
	
	local t = { node = 'chunk' }
	
	-- block
	
	if peek() ~= 'class' then
		t.block = block()
	
	-- { class_def }
	
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
class_def :=	'class' ClassName [ ':' ClassName ]
				{ [ 'private' ] type Name }
				[ 'methods' { meth_def } ]
				'end'
]]

function class()
	
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
	if accept 'methods' then
	
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

function type()
	
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
		
	-- '[' type ']'
	
	elseif accept '/' then
		t.array = type()
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

function block()
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