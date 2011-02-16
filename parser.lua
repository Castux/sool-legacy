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
		"Compiler",
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

-- digraphs

local function peek2()
	return (peek() or 'argh') .. (peek(2) or 'argh')
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
			"expected " .. toktype .. ", found " .. peek() .. " instead",
			peekpos()
		)
		return false
	end
end

function Node:accept2(s)
	if peek() == s:sub(1,1) and peek(2) == s:sub(2,2) then
		-- cheat a bit: merge the two tokens
		local a = head()
		consume()
		local b = head()
		consume()
		local tok = {
			s,
			s,
			range(a[3],b[3])
		}
		self:add(tok)
		return true
	else
		return false
	end
end

function Node:expect2(s)
	if peek() == s:sub(1,1) and peek(2) == s:sub(2,2) then
		-- cheat a bit: merge the two tokens
		local a = head()
		consume()
		local b = head()
		consume()
		local tok = {
			s,
			s,
			range(a[3],b[3])
		}
		self:add(tok)
		return true
	else
		add_err("error",
			"expected digraph" .. s .. ", found " .. peek() .. " instead",
			peekpos()
		)
		return false
	end
end

function Node:binop(only_peek)

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
			if self:accept2(v) then
				return true
			end
		end
		
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
	return self.children[#self.children][3]
end

function Node:firstpos()
	return self.children[1][3]
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
				add_err('info','in class that started at',self:firstpos())
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
	
	if peek() ~= 'Name' then
		
		local typ = Type()
		if not typ then
			add_err('info','as return type for method started at',range(open,peekpos()))
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
		add_err('info','to open argument list in method definition',range(open,peekpos()))
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
	
	--[[ block
	t.body = Block()
	if not t.body then
		return
	end
	]]
	
	-- 'end'
	if not self:expect 'end' then
		add_err('info','to complete method started at',self:firstpos())
		return
	end
	
	return self
end

function Method:str()
	local s = ""
	
	for i,v in ipairs(self.ret) do
		s = s .. v:str()
		if i < #self.ret then
			s = s .. ','
		end
	end
	
	s = s .. ' ' .. self.name .. '('
	
	for i,v in ipairs(self.args) do
		s = s .. v.type:str() .. " " .. v.name
		if i < #self.args then
			s = s .. ','
		end
	end
	
	s = s .. ')'
	
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
	
	--local eof = expect 'EOF'
	--if not eof then return nil,errors end
	
	return tree,errors
end
