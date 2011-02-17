require 'class'

-----------------------------------------------------------------------
-- Shared context for all nodes, initialized by the parse() function --
-----------------------------------------------------------------------

local tokens, current, errors

-- Look ahead: type
local function peek(n)
	local n = n or 1

	if not tokens[current + n - 1] then
		return nil
	else
		return tokens[current + n - 1][1]
	end
end

-- Look ahead: value
local function peekval()
	if not tokens[current] then
		return nil
	else
		return tokens[current][2]
	end
end

-- Look ahead: position
local function peekpos()
	if not tokens[current] then
		return nil
	else
		return tokens[current][3]
	end
end

-- Look ahead: hole token
local function head()
	return tokens[current]
end

-- Advance by one token
local function consume()
	current = current + 1
end

-- Push error to list.
local function add_err(typ,mess,pos)
	
	local err =  {
		'Parser',
		typ,
		mess,
		pos
	}
	
	table.insert(errors,err)
end

-- Position range, with to full positions
local function range(from,to)
	local fline,fcol = from.fline,from.fcol
	local lline,lcol = to.lline,to.lcol
	
	return {fline = fline, lline = lline, fcol = fcol, lcol = lcol}
end

-- helper function

local begin_exp = function(s)
	
	local toks = {'Name','Number','String','nil','false','true',
		'(','[','/','<','not','+','-'}
	
	for i,v in ipairs(toks) do
		if s == v then return true end
	end
	
	return false
end

---------------------
-- Base Node class --
---------------------

Node = class()

function Node:init()
	
	self.children = {}
	
	return self
end

-- Add token or node to children
function Node:add(child)
	table.insert(self.children,child)
end

-- Parse optional token
function Node:accept(toktype)
	if peek() == toktype then
		self:add(head())
		consume()
		return true
	else
		return false
	end
end

-- Parse mandatory token
function Node:expect(toktype)
	if peek() == toktype then
		self:add(head())
		consume()
		return true
	else
		add_err("error",
			"expected " .. toktype .. ", found '" .. peek() .. "' instead",
			peekpos()
		)
		return false
	end
end

function Node:binop(only_peek)

	local ops = {'+','-','*','/','%','<','>','^','|','xor','and','or',
		'<=','>=','==','~=','<<','>>'}
	
	if only_peek then
	-- don't consume
		
		for i,v in ipairs(ops) do
			if peek() == v then
				return true
			end
		end
		
		return false
	-- consume
	else
		
		for i,v in ipairs(ops) do
			if self:accept(v) then
				return true
			end
		end
		
		add_err("error", "malformed binary operator",peekpos())
		return nil
	end

end

-- Return last parsed value (assuming it's a token)
function Node:lastval()
	return self.children[#self.children][2]
end

function Node:lastpos()
	if self.children[#self.children].token then
		return self.children[#self.children][3]
	else
		return self.children[#self.children]:lastpos()
	end
end

function Node:firstpos()
	if self.children[1].token then
		return self.children[1][3]
	else
		return self.children[1]:firstpos()
	end
end

-- Return line,col of first/last symbol. Read in token if token, call
-- recursively if node
function Node:firstlc()
	local fi = self.children[1]
	
	if fi.token then
		return fi[3].fline,fi[3].fcol
	else
		return fi:firstlc()
	end
end

function Node:lastlc()
	local la = self.children[#self.children]
	
	if la.token then
		return la[3].lline,la[3].lcol
	else
		return la:lastlc()
	end
end

function Node:pos()
	local fline,fcol = self:firstlc()
	local lline,lcol = self:lastlc()
	
	return {fline = fline, lline = lline, fcol = fcol, lcol = lcol}
end



------------------------
-- Other Node classes --
------------------------

--[[
chunk := 		block |
				{ class_def }
]]

Chunk = class(Node)

function Chunk:init()
	
	Chunk.super.init(self)
	
	self.block = nil
	self.classes = {}
	
	return self:parse()
end

function Chunk:parse()
	
	-- block
	if peek() ~= 'class' then
		self.block = Block()
		if not self.block then
			return
		else
			self:add(self.block)
		end
	
	-- { class }
	else
		while peek() == 'class' do
			local cl = Class()
			if not cl then
				return
			else
				table.insert(self.classes,cl)
				self:add(cl)
			end
		end
	end
	
	if not self:expect 'EOF' then
		return
	end
	
	return self
end

function Chunk:str()
	if self.block then
		return self.block:str()
	else
		local s = ""
		for i,v in ipairs(self.classes) do
			s = s .. v:str() .. '\n'
		end
		return s
	end
end

--[[
class :=		'class' ClassName [ ':' ClassName ]
				{ [ 'private' ] type Name }
				[ 'methods' { method } ]
				'end'
]]

Class = class(Node)

function Class:init()
	
	Class.super.init(self)
	
	self.name = ""
	self.parent = nil
	
	self.members = {}
	self.methods = {}
	
	return self:parse()
end

function Class:parse()
	
	-- 'class'
	if not self:expect 'class' then
		return
	end
	
	-- ClassName
	if self:expect 'ClassName' then
		self.name = self:lastval()
	else
		add_err('info','for class definition started at',self:pos())
		return
	end
	
	-- [ ':' ClassName ]
	if self:accept ':' then
		if self:expect 'ClassName' then
			self.parent = self:lastval()
		else
			add_err('info','as parent class for class started at',self:pos())
			return
		end
	end
	
	-- { [ 'private' ] type Name }
	
	while peek() ~= 'methods' and peek() ~= 'end' do
		local open
		local mem = {}
		
		if self:accept 'private' then
			mem.private = true
			open = self:lastpos()
		end
		
		open = open or peekpos()
		mem.type = Type()
		if not mem.type then
			add_err('info','in member definition started here',open)
			return
		else
			self:add(mem.type)
		end
		
		if self:expect 'Name' then
			mem.name = self:lastval()
		else
			add_err('info','for member name in member definition',range(open,peekpos()))
			return
		end
		
		table.insert(self.members,mem)
	end
	
	-- [ 'methods' { meth_def } ]
	
	if self:accept 'methods' then
		while peek() ~= 'end' do
			local meth = Method()
			if not meth then
				return
			else
				self:add(meth)
				table.insert(self.methods,meth)
			end
		end
	end
	
	-- 'end'
	
	if not self:expect 'end' then
		return
	end
	
	return self
end

function Class:str()
	local s = 'class ' .. self.name
	
	if self.parent then
		s = s .. ' : ' .. self.parent
	end
	
	s = s .. '\n'
	
	for i,v in ipairs(self.members) do
		if v.private then
			s = s .. 'private '
		end
		s = s .. v.type:str() .. ' ' .. v.name .. '\n'
	end
	
	s = s .. 'methods\n'
	
	for i,v in ipairs(self.methods) do
		s = s .. v:str() .. '\n'
	end
	
	return s .. 'end\n'
end

--[[
type :=			'num' | 'vec' | 'str' |
				ClassName |
				'[' type ']' |
				'/' type '/' |
				'{' { type  [ ',' ] } '}'
]]

Type = class(Node)

function Type:init()
	
	Type.super.init(self)
	
	self.type = ""
	self.val = nil
	
	return self:parse()
end

function Type:parse()
	
	-- 'num' | 'vec' | 'str'
	
	if self:accept 'num' or self:accept 'vec' or self:accept 'str' then
		self.type = self:lastval()
	
	-- ClassName
	
	elseif self:accept 'ClassName' then
		self.type = 'class'
		self.val = self:lastval()
	
	-- '[' type ']'
	
	elseif self:accept '[' then
		local open = self:lastpos()
		self.type = 'array'
		self.val = Type()
		if not self.val then
			add_err('info','in array type definition',range(open,peekpos()))
			return
		else
			self:add(self.val)
		end
		if not self:expect ']' then
			add_err('info','to close array type definition',open)
			return
		end
		
	-- '/' type '/'
	
	elseif self:accept '/' then
		local open = self:lastpos()
		self.type = 'list'
		self.val = Type()
		if not self.val then
			add_err('info','in list type definition',range(open,peekpos()))
			return
		else
			self:add(self.val)
		end
		if not self:expect '/' then
			add_err('info','to close list type definition',open)
			return
		end
	
	-- '{' { type  [ ',' ] } '}'
	
	elseif self:accept '{' then
		local open = self:lastpos()
		self.type = 'pack'
		self.val = {}
		
		while peek() ~= '}' do
			local typ = Type()
			if not typ then
				add_err('info','in pack type definition',range(open,peekpos()))
				return
			else
				table.insert(self.val,typ)
				self:add(typ)
			end
			self:accept ','
		end
		
		if not self:expect '}' then
			add_err('info','to close pack type definition',open)
			return
		end
		
	else
		add_err('error','malformed type ' .. peekval(),peekpos())
		return
	end
	
	return self
end

function Type:str()
	
	if self.type == 'num' or self.type == 'vec' or self.type == 'str' then
		return self.type
	end
	
	if self.type == 'class' then
		return self.val
	end
	
	if self.type == 'array' then
		return '[' .. self.val:str() .. ']'
	elseif self.type == 'list' then
		return '/' .. self.val:str() .. '/'
	elseif self.type == 'pack' then
		local s = '{'
		for i,v in ipairs(self.val) do
			s = s .. v:str()
			if i < #self.val then
				s = s .. ','
			end
		end
		return s .. '}'
	end
end

--[[
method :=		[ 'private' ] [ type { ',' type } ]
				Name
				'(' { type Name [ ',' ] } ')'
				block
				'end'
]]

Method = class(Node)

function Method:init()
	
	Method.super.init(self)
	
	self.private = false
	self.ret = {}
	self.name = ""
	self.args = {}
	self.body = nil
	
	return self:parse()
end

function Method:parse()
	
	local open
	
	-- [ 'private' ]
	if self:accept 'private' then
		self.private = true
		open = self:lastpos()
	end
	
	open = open or peekpos()
	
	-- [ type { ',' type } ]
	
	if peek() ~= 'Name' and peek() ~= 'op' then
		
		local typ = Type()
		if not typ then
			add_err('info','as return type for method started at',open)
			return
		else
			table.insert(self.ret,typ)
			self:add(typ)
		end
		
		while peek() == ',' do
			if not self:expect ',' then
				return
			end
			
			local typ = Type()
			if not typ then
				return
			else
				table.insert(self.ret,typ)
				self:add(typ)
			end
		end
	end	
	
	-- ( Name | 'op' Binop )
	if self:accept 'op' then
		if self:binop() then
			self.name = self:lastval()
		else
			add_err('info','for method name in method definition',range(open,peekpos()))
			return
		end
	else
		if self:expect 'Name' then
			self.name = self:lastval()
		else
			add_err('info','for method name in method definition',range(open,peekpos()))
			return
		end
	end
	
	-- '(' [ type Name { ',' type Name } ] ')'
	
	if not self:expect '(' then
		add_err('info','to open argument list in method definition',range(open,self:lastpos()))
		return
	end
	
	local paren = self:lastpos()
	
	if peek() ~= ')' then
		while true do
			local arg = {}
			
			arg.type = Type()
			if not arg.type then
				add_err('info','in argument list of method definition',range(open,peekpos()))
				return
			end
			
			if self:expect 'Name' then
				arg.name = self:lastval()
			else
				add_err('info','for argument name in method definition',range(open,peekpos()))
				return
			end
			
			table.insert(self.args,arg)
			
			if not self:accept ',' then
				break
			end
		end
	end
	
	if not self:expect ')' then
		add_err('info','to close argument list started at',paren)
		return
	end
	
	-- block
	self.body = Block()
	if not self.body then
		return
	end
	
	-- 'end'
	if not self:expect 'end' then
		add_err('info','to complete method started at',self:firstpos())
		return
	end
	
	return self
end

function Method:str()
	local s = self.private and 'private ' or ''
	
	for i,v in ipairs(self.ret) do
		s = s .. v:str()
		if i < #self.ret then
			s = s .. ','
		end
	end
	
	if #self.ret > 0 then s = s .. ' ' end
	
	s = s .. self.name .. '('
	
	for i,v in ipairs(self.args) do
		s = s .. v.type:str() .. " " .. v.name
		if i < #self.args then
			s = s .. ','
		end
	end
	
	s = s .. ')\n'
	
	s = s .. self.body:str() .. 'end'
	
	return s
end

--[[
block :=		{ stat [ ';' ] }
				[ break | continue | return [ listexp ] ]
]]

Block = class(Node)

function Block:init()
	
	Block.super.init(self)
	
	self.stats = {}
	
	return self:parse()
end

function Block:parse()
	
	-- { stat }
	while peek() ~= 'end' and peek() ~= 'else' and peek() ~= 'elseif' and 
		peek() ~= 'break' and peek() ~= 'continue' and peek() ~= 'return' and
		peek() ~= ';' and peek() ~= 'EOF' do
		
		local st
		
		if peek() == 'do' then
			st = Do()
			
		elseif peek() == 'while' then
			st = While()
			
		elseif peek() == 'if' then
			st = If()
			
		elseif peek() == 'for' and peek(3) == '=' then
			st = For()
			
		elseif peek() == 'for' then
			st = GenericFor()
			
		elseif begin_exp(peek()) then
			st = Assignment()
			
		else
			add_err('error','malformed statement: ' .. peekval(),peekpos())
			if #self.stats > 0 then
				add_err('info', 'previous statement:', self.stats[#self.stats]:pos())
			end
			return
		end
		
		if not st then
			return
		else
			table.insert(self.stats,st)
			self:add(st)
		end
		
		self:accept ';'
	end
	
	-- [ break | continue | return { exp [ ',' ] } ]
	local st = nil
	
	if peek() == 'break' then
		st = Break()
	
	elseif peek() == 'continue' then
		st = Continue()
	
	elseif peek() == 'return' then
		st = Return()
	end
	
	if st then
		table.insert(self.stats,st)
		self:add(st)
	end
		
	return self
end

function Block:str()
	local s = ""
	
	for i,v in ipairs(self.stats) do
		s = s .. v:str() .. '\n'
	end
	
	return s
end

--[[
break | continue | return [ listexp ]
]]

Stat = class(Node)

Break = class(Stat)

function Break:init()
	Break.super.init(self)
	return self:parse()
end

function Break:parse()
	if not self:expect 'break' then
		return
	end
	return self
end

function Break:str()
	return 'break'
end

Continue = class(Stat)

function Continue:init()
	Continue.super.init(self)
	return self:parse()
end

function Continue:parse()
	if not self:expect 'continue' then
		return
	end
	return self
end

function Continue:str()
	return 'continue'
end

Return = class(Stat)

function Return:init()
	Return.super.init(self)
	
	self.vals = {}
	
	return self:parse()
end

function Return:parse()
	
	if not self:expect 'return' then
		return
	end
	
	if peek() ~= 'end' then
		self.vals = self:listexp()
		if not self.vals then
			add_err('info','in return statement',self:pos())
			return
		end
	end
	
	return self
end

function Return:str()
	local s = 'return '
	
	for i,v in ipairs(self.vals) do
		s = s .. v:str()
		if i < #self.vals then
			s = s .. ','
		end
	end
	
	return s
end

--[[
'do' block 'end'
]]

Do = class(Stat)

function Do:init()
	Do.super.init(self)
	
	self.body = nil
	
	return self:parse()
end

function Do:parse()
	
	if not self:expect 'do' then
		return
	end
	
	self.body = Block()
	if not self.body then
		return
	end
	
	if not self:expect 'end' then
		add_err('info','to close block started at',self:firstpos())
		return
	end
	
	return self
end

function Do:str()
	return 'do\n' .. self.body:str() .. 'end'
end

--[[
'while' exp 'dö́' block 'end'
]]

While = class(Stat)

function While:init()
	While.super.init(self)
	
	self.cond = nil
	self.body = nil
	
	return self:parse()
end

function While:parse()
	
	if not self:expect 'while' then
		return
	end
	
	self.cond = Exp()
	if not self.cond then
		add_err('info','as condition in while loop started at',self:firstpos())
		return
	else
		self:add(self.cond)
	end
	
	if not self:expect 'do' then
		add_err('info','in while loop',range(self:firstpos(),peekpos()))
		return
	end
	
	self.body = Block()
	if not self.body then
		return
	else
		self:add(self.body)
	end
	
	if not self:expect 'end' then
		add_err('info','to complete while loop',self:firstpos())
		return
	end
	
	return self
end

function While:str()
	return 'while ' .. self.cond:str() .. ' do\n' .. self.body:str() .. '\nend'
end

--[[
'if' exp 'then' block
	{ 'elseif' exp 'then' block }
	[ 'else' block ]
	'end'
]]

If = class(Stat)

function If:init()
	If.super.init(self)
	
	self.tests = {}
	self.default = nil
	
	return self:parse()
end

function If:parse()
	
	-- 'if'
	if not self:expect 'if' then
		return
	end
	
	-- exp 'then' block
	-- { 'elseif' exp 'then' block }
	repeat
		local test = {}
		local open = self:lastpos()
		
		test.cond = Exp()
		if not test.cond then
			add_err('info','as condition in if',open)
			return
		else
			self:add(test.cond)
		end
		
		if not self:expect 'then' then
			add_err('info','to match',open)
			return
		end
		
		test.body = Block()
		if not test.body then
			return
		else
			self:add(test.body)
		end
		
		table.insert(self.tests,test)
	until not self:accept 'elseif'
	
	-- [ 'else' block ]
	if self:accept 'else' then
		self.default = Block()
		if not self.default then
			return
		else
			self:add(self.default)
		end
	end
	
	if not self:expect 'end' then
		return
	end
	
	return self
end

function If:str()
	
	local s = 'if ' .. self.tests[1].cond:str() .. 
		' then\n' .. self.tests[1].body:str() .. '\n'
	
	for i = 2,#self.tests do
		s = s .. 'elseif ' .. self.tests[i].cond:str() .. 
			' then\n' .. self.tests[i].body:str() .. '\n'
	end
	
	if self.default then
		s = s .. 'else\n' .. self.default:str() .. '\n'
	end
	
	return s .. 'end'
end

--[[
'for' Name '=' exp ',' exp [ ',' exp ] do block end
]]

For = class(Stat)

function For:init()
	For.super.init(self)
	
	self.var = ""
	self[1] = nil
	self[2] = nil
	self[3] = nil
	self.body = nil
	
	return self:parse()
end

function For:parse()
	
	if not self:expect 'for' then
		return
	end
	
	if self:expect 'Name' then
		self.var = self:lastval()
	else
		add_err('info','as variable for for construct',self:lastpos())
		return
	end
	
	if not self:expect '=' then
		add_err('info','in for construct',range(self:firstpos(),peekpos()))
		return
	end
	
	self[1] = Exp()
	if not self[1] then
		return
	else
		self:add(self[1])
	end
	
	if not self:expect ',' then
		add_err('info','in for construct',range(self:firstpos(),peekpos()))
		return
	end
	
	self[2] = Exp()
	if not self[2] then
		return
	else
		self:add(self[2])
	end
	
	if self:accept ',' then
		self[3] = Exp()
		if not self[3] then
			return
		else
			self:add(self[3])
		end
	end
	
	if not self:expect 'do' then
		add_err('info','in for construct',range(self:firstpos(),peekpos()))
		return
	end
	
	self.body = Block()
	if not self.body then
		return
	else
		self:add(self.body)
	end
	
	if not self:expect 'end' then
		add_err('info','to complete for construct',self:firstpos())
		return
	end
	
	return self
end

function For:str()
	local s =  'for ' .. self.var .. ' = ' ..
		self[1]:str() .. ',' .. self[2]:str() 
	
	if self[3] then
		s = s .. ',' .. self[3]:str()
	end
	
	return s..' do\n' .. self.body:str() .. '\n' .. 'end'
end

--[[
'for' Name { ',' Name } 'in' exp 'do' block 'end'
]]

GenericFor = class(Stat)

function GenericFor:init()
	GenericFor.super.init(self)
	
	self[1] = ""
	self.exp = nil
	self.body = nil
	
	return self:parse()
end

function GenericFor:parse()
	
	if not self:expect 'for' then
		return
	end
	
	if self:expect 'Name' then
		self[1] = self:lastval()
	else
		add_err('info','as variable in generic for',self:pos())
		return
	end
	
	while self:accept ',' do
		if self:expect 'Name' then
			self[#self+1] = self:lastval()
		else
			add_err('info','as variable in generic for',self:pos())
			return
		end
	end
	
	if not self:expect 'in' then
		add_err('info','in generic for',self:pos())
		return
	end
	
	self.exp = Exp()
	if self.exp then
		self:add(self.exp)
	else
		add_err('info','as iterated in generic for',self:pos())
		return
	end
	
	if not self:expect 'do' then
		add_err('info','in generic for',self:pos())
		return
	end
	
	self.body = Block()
	if not self.body then
		return
	end
	
	if not self:expect 'end' then
		add_err('info','to complete generic for started at',self:firstpos())
		return
	end
	
	return self
end

function GenericFor:str()
	
	local s =  'for ' .. self[1]
	
	for i = 2,#self do
		s = s .. ',' .. self[i]
	end
	
	s = s .. ' in ' .. self.exp:str()
	
	return s ..' do\n' .. self.body:str() .. '\n' .. 'end'
end

--[[
basicexp | listbasicexp '=' listexp
]]

Assignment = class(Stat)

function Assignment:init()
	Assignment.super.init(self)
	
	self.lval = nil
	self.rval = nil
	
	return self:parse()
end

function Assignment:parse()
	
	local begin = current
	
	self.lval = self:listbasicexp()
	if not self.lval then
		return
	end
	
	-- normal case
	if self:accept '=' then
		self.rval = self:listexp()
		if not self.rval then
			return
		end
	
	-- special case: lone basic expression
	elseif #self.lval == 1 then
		return self.lval[1]
	
	else
		-- we know it's not going to happen, but nicer error message
		self:expect '='
		add_err('info','in assignment',self:pos())
	end
	
	return self
end

function Assignment:str()
	
	local s = self.lval[1]:str()
	
	for i = 2,#self.lval do
		s = s .. ',' .. self.lval[i]:str()
	end
	
	s = s .. ' = ' .. self.rval[1]:str()
	
	for i = 2,#self.rval do
		s = s .. ',' .. self.rval[i]:str()
	end
	
	return s
end

--[[
listexp :=		exp { ',' exp }
]]

-- Does not return a node, just a list

function Node:listexp()
	
	local t = {}
	
	t[1] = Exp()
	if not t[1] then
		return
	else
		self:add(t[1])
	end
	
	while self:accept ',' do
		local ex = Exp()
		if not ex then
			return
		else
			t[#t+1] = ex
			self:add(ex)
		end
	end
	
	return t
end

--[[
listbasicexp :=	basicexp { ',' basicexp }
]]

-- Does not return a node, just a list

function Node:listbasicexp()
	
	local t = {}
	
	t[1] = BasicExp()
	if not t[1] then
		return
	else
		self:add(t[1])
	end
	
	while self:accept ',' do
		local ex = BasicExp()
		if not ex then
			return
		else
			t[#t+1] = ex
			self:add(ex)
		end
	end
	
	return t
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

AtomicExp = class(Node)


function AtomicExp:init()
	AtomicExp.super.init(self)
	
	self.kind = ""
	self.val = nil
	self.args = nil		-- for instanciation only
	
	return self:parse()
end

function AtomicExp:parse()
	
	local open = peekpos()
	
	-- Name | Number | String | 'nil' | 'false' | 'true' | Symbol
	if self:accept 'Name' then
		self.kind = 'var'
		self.val = self:lastval()
		
	elseif self:accept 'Number' then
		self.kind = 'number'
		self.val = self:lastval()
		
	elseif self:accept 'String' then
		self.kind = 'string'
		self.val = self:lastval()

	elseif self:accept 'Symbol' then
		self.kind = 'symbol'
		self.val = self:lastval()
	
	elseif self:accept 'nil' then
		self.kind = 'nil'
		self.val = 'nil'
	
	elseif self:accept 'true' then
		self.kind = 'true'
		self.val = 'true'
	
	elseif self:accept 'false' then
		self.kind = 'false'
		self.val = 'false'
	
	-- '(' exp ')'
	elseif self:accept '(' then
		local ex = Exp()
		if not ex then
			return
		else
			self:add(ex)
		end
		if not self:expect ')' then
			add_err('info','to match',open)
			return
		end
		
		-- return directly the expression, no need for a "parentheses" node 
		return ex
		
	-- '{' [ listbasicexp ] '}'
	elseif self:accept '{' then
		self.kind = 'pack'
		if peek() ~= '}' then
			self.val = self:listbasicexp()
			if not self.val then
				add_err('info','in pack constructor started at',open)
				return
			else
				self:add(self.val)
			end
		end
		if not self:expect '}' then
			add_err('info','to match',open)
			add_err('info','(pack constructor)')
			return
		end
	
	-- '[' [ listbasicexp ] ']'
	elseif self:accept '[' then
		self.kind = 'array'
		if peek() ~= ']' then
			self.val = self:listbasicexp()
			if not self.val then
				add_err('info','in array constructor started at',open)
				return
			else
				self:add(self.val)
			end
		end
		if not self:expect ']' then
			add_err('info','to match',open)
			add_err('info','(array constructor)')
			return
		end
		
	-- '/' [ listbasicexp ] '/'
	elseif self:accept '/' then
		self.kind = 'list'
		if peek() ~= '/' then
			self.val = self:listbasicexp()
			if not self.val then
				add_err('info','in list constructor started at',open)
				add_err('info','(list constructor)')
				return
			else
				self:add(self.val)
			end
		end
		if not self:expect '/' then
			add_err('info','to match',open)
			return
		end
		
	-- '<' [ listbasicexp ] '>'
	elseif self:accept '<' then
		self.kind = 'vector'
		if peek() ~= '>' then
			self.val = self:listbasicexp()
			if not self.val then
				add_err('info','in vector constructor started at',open)
				return
			else
				self:add(self.val)
			end
		end
		if not self:expect '>' then
			add_err('info','to match',open)
			add_err('info','(vector constructor)')
			return
		end
	
	-- ClassName [ '(' [ listexp ] ')' ]
	elseif self:accept 'ClassName' then
		self.kind = 'instanciation'
		self.val = self:lastval()
		if self:accept '(' then
			open = self:lastpos()
			if peek() ~= ')' then
				self.args = self:listexp()
				if not self.args then
					add_err('info','in instanciation argument list',open)
					return
				else
					self:add(self.args)
				end
			end
			if not self:expect ')' then
				add_err('info','to match',open)
				add_err('info','(instanciation argument list)')
				return
			end
		end
	
	else
		add_err('error','malformed atomic expression: ' .. peek(),peekpos())
		return
	end
	
	return self
end

function AtomicExp:str()
	
	-- basic
	if self.val and type(self.val) ~= 'table' then
		return self.val
	end
	
	-- bracketed
	local open,close
	
	if self.kind == 'array' then
		open,close = '[',']'
	elseif self.kind == 'list' then
		open,close = '/','/'
	elseif self.kind == 'pack' then
		open,close = '{','}'
	elseif self.kind == 'vector' then
		open,close = '<','>'
	end
	
	if open and close then
		local s = open 
		
		if self.val then
			s = s .. self.val[1]:str()
			for i = 2,#self.val do
				s = s .. ',' .. self.val[i]:str()
			end
		end
		return s .. close
	end
	
	-- instanciation
	assert(self.kind == 'instanciation')
	
	local s = self.val .. '('
	if self.args then
		s = s .. self.args[1]:str()
		for i = 2,#self.args do
			s = s .. ',' .. self.args[i]
		end
		return s .. ')'
	end
	
end

--[[
exptail :=		'.' Name [ '(' [ listexp ] ')' ] |
				'[' exp ']'
				
basicexp :=		atomicexp { exptail }
]]

BasicExp = class(Node)

function BasicExp:init()
	BasicExp.super.init(self)
	
	self.atom = nil
	self.tails = {}
	
	return self:parse()
end

function BasicExp:parse()
	
	-- atomicexp
	self.atom = AtomicExp()
	if not self.atom then
		return
	else
		self:add(self.atom)
	end
	
	-- { exptail }
	while peek() == '.' or peek() == '[' do
		local tail = {}
		local open = peekpos()
		
		-- '[' exp ']'
		if self:accept '[' then
			tail.kind = 'index'
			tail.index = Exp()
			if not tail.index then
				add_err('info','as index in indexing started at',open)
				return
			else
				self:add(tail.index)
			end
			
			if not self:expect ']' then
				add_err('info','to match',open)
				return
			end
		
		-- '.' Name [ '(' [ listexp ] ')' ]
		elseif self:accept '.' then
			
			if self:expect 'Name' then
				tail.name = self:lastval()
			else
				add_err('info','in member access started at',open)
				return
			end
			
			if self:accept '(' then
				open = self:lastpos()
				tail.kind = 'call'
				if peek() ~= ')' then
					tail.args = self:listexp()
					if not tail.args then
						return
					end
				end
				
				if not self:expect ')' then
					add_err('info','to match',open)
					return
				end
			else
				tail.kind = 'member_access'
			end
		end
		
		table.insert(self.tails,tail)
	end
	
	return self
end

function BasicExp:str()
	local s = self.atom:str()
	
	for i,v in ipairs(self.tails) do
		if v.kind == 'index' then
			s = s .. '[' .. v.index:str() .. ']'
		elseif v.kind == 'member_access' then
			s = s .. '.' .. v.name
		elseif v.kind == 'call' then
			s = s .. '.' .. v.name .. '('
			if v.args then
				s = s .. v.args[1]:str()
				for i = 2,#v.args do
					s = s .. ',' .. v.args[i]:str()
				end
			end
			s = s .. ')'
		else
			error('BasicExp:str() - unknown tail kind: ' .. v.kind)
		end
	end
	
	return s
end

--[[
exp := 			basicexp { Binop basicexp }
]]

Exp = class(Node)

function Exp:init()
	Exp.super.init(self)
	
	self.left = nil
	self.terms = {}
	
	return self:parse()
end

function Exp:parse()
	
	-- basicexp { Binop basicexp }
	self.left = BasicExp()
	if not self.left then
		return
	else
		self:add(self.left)
	end
	
	while self:binop(true) do	-- true for only peeking
		local term = {}
		
		if self:binop() then
			term.binop = self:lastval()
		else
			add_err('info','as operator in expression',self:pos())
			return
		end
		
		term.right = BasicExp()
		if not term.right then
			add_err('info','as right hand term in expression',self:pos())
			return
		else
			self:add(term.right)
		end
		
		table.insert(self.terms,term)
	end
	
	return self
end

function Exp:str()
	local s = self.left:str()
	
	for i,v in ipairs(self.terms) do
		s = s .. ' ' .. v.binop .. ' ' ..'(' .. v.right:str() .. ')'
	end
	
	return s
end

-------------------------
-- Main parsing driver --
-------------------------

function parse(toks)
	tokens = toks
	current = 1
	errors = {}
	
	-- apply top level rule
	local tree = Chunk()
	if not tree then return nil,errors end
	
	return tree,errors
end
