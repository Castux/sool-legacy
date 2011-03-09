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
	
	-- from and to should really be in the same file
	assert(from.file == to.file)
	local file = from.file
	
	return {fline = fline, lline = lline, fcol = fcol, lcol = lcol, file = file}
end

-- helper function

local begin_exp = function(s)
	
	local toks = {'Name','Number','String','Symbol','nil','false','true',
		'(','[','/','<','{','ClassName','not','#','-'}
	
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
	self.parent = nil
	
	return self
end

-- Add token or node to children
function Node:add(child)
	table.insert(self.children,child)
	child.parent = self
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
			"expected '" .. toktype .. "', found '" .. peek() .. "' instead",
			peekpos()
		)
		return false
	end
end

function Node:binop(only_peek)

	local ops = {'+','-','*','/','%','<','>','^','|','xor','and','or',
		'<=','>=','==','~=','<<','>>','<-','<~','~~','+=','-=','*=',
		'/=','%=','^=','|=','xor!'}
	
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

-- Return line,col,file of first/last symbol. Read in token if token, call
-- recursively if node
function Node:firstlc(n)
	local fi = self.children[n or 1]
	
	if fi.token then
		return fi[3].fline,fi[3].fcol,fi[3].file
	else
		return fi:firstlc()
	end
end

function Node:lastlc(n)
	local la = self.children[n or #self.children]
	
	if la.token then
		return la[3].lline,la[3].lcol,la[3].file
	else
		return la:lastlc()
	end
end

function Node:pos(a,b)
	local fline,fcol,file1 = self:firstlc(a)
	local lline,lcol,file2 = self:lastlc(b)
	
	assert(file1 == file2)
	
	return {fline = fline, lline = lline, fcol = fcol, lcol = lcol, file = file1}
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
	
	--[[ block
	if peek() ~= 'class' then
		self.block = Block()
		if not self.block then
			return
		else
			self:add(self.block)
		end
	]]
	-- { class }
	--else
		while peek() ~= 'EOF' do
			local cl = Class()
			if not cl then
				return
			else
				table.insert(self.classes,cl)
				self:add(cl)
			end
		end
	--end
	
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
	self.base = nil		-- string
	
	self.members = {}	-- small Node with fields {type,name} (and proper children)
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
			self.base = self:lastval()
		else
			add_err('info','as parent class for class started at',self:pos())
			return
		end
	end
	
	-- { [ 'private' ] type Name }
	
	while peek() ~= 'methods' and peek() ~= 'end' do
		local open
		local mem = Node()
		
		if mem:accept 'private' then
			mem.private = true
			open = mem:lastpos()
		end
		
		open = open or peekpos()
		mem.type = Type()
		if not mem.type then
			add_err('info','in member definition started here',open)
			return
		else
			mem:add(mem.type)
		end
		
		if mem:expect 'Name' then
			mem.name = mem:lastval()
		else
			add_err('info','for member name in member definition',range(open,peekpos()))
			return
		end
		
		table.insert(self.members,mem)
		self:add(mem)
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
	
	if self.base then
		s = s .. ' : ' .. self.base
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

function Type:init(no_parsing)
	
	Type.super.init(self)
	
	self.type = ""
	self.val = nil
	
	if no_parsing then
		return self
	else
		return self:parse()
	end
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
	self.args = {}		-- small Node with fields {type,name} (and proper children)
	self.body = nil
	
	self.namepos = nil
	
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
			self.namepos = self:lastpos()
		else
			add_err('info','for method name in method definition',range(open,peekpos()))
			return
		end
	else
		if self:expect 'Name' then
			self.name = self:lastval()
			self.namepos = self:lastpos()
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
			local arg = Node()
			
			arg.type = Type()
			if not arg.type then
				add_err('info','in argument list of method definition',range(open,peekpos()))
				return
			else
				arg:add(arg.type)
			end
			
			if arg:expect 'Name' then
				arg.name = arg:lastval()
			else
				add_err('info','for argument name in method definition',range(open,peekpos()))
				return
			end
			
			table.insert(self.args,arg)
			self:add(arg)
			
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
	else
		self:add(self.body)
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
		if not st then
			return
		end
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
exp | listbasicexp '=' listexp
]]

Assignment = class(Stat)

function Assignment:init()
	Assignment.super.init(self)
	
	self.lval = nil
	self.rval = nil
	
	return self:parse()
end

function Assignment:parse()
	
	-- all cases start with basic expression(s)
	self.lval = self:listbasicexp()
	if not self.lval then
		return
	end
	
	-- normal case: assignment
	if self:accept '=' then
		self.rval = self:listexp()
		if not self.rval then
			return
		end
	
	-- special case: lone expression
	elseif #self.lval == 1 then
	
		-- parse an expression with preparsed left term
		return Exp(self.lval[1])
	
	else
		self:expect '=' -- we know it's going to fail, but nicer error message
		add_err('info','in assignment',self:pos())
		return
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
	
	t[1] = self:basicexp()
	if not t[1] then
		return
	else
		self:add(t[1])
	end
	
	while self:accept ',' do
		local ex = self:basicexp()
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
atomicexp :=	Name | Number | String | 'nil' | 'false' | 'true' | Symbol
]]

AtomicExp = class(Node)

function AtomicExp:init()
	AtomicExp.super.init(self)
	
	self.kind = nil
	self.val = nil
	
	return self:parse()
end

function AtomicExp:parse()
	
	-- Name | Number | String | 'nil' | 'false' | 'true' | Symbol
	if 	self:accept 'Name' or
	 	self:accept 'Number' or
	 	self:accept 'String' or
		self:accept 'Symbol' or
		self:accept 'nil' or
		self:accept 'true' then
		
		self.kind = self.children[#self.children][1]
		self.val = self:lastval()
	
	else
		add_err('error','malformed atomic expression: ' .. peek(),peekpos())
		return
	end
	
	return self
	
end

function AtomicExp:str()
	
	return self.val
end


--[[
	'{' [ listbasicexp ] '}'
]]

PackConst = class(Node)

function PackConst:init()
	PackConst.super.init(self)
	
	self.vals = {}
	
	return self:parse()
end

function PackConst:parse()
	
	local open = peekpos()
	
	-- '{' [ listbasicexp ] '}'
	if not self:expect '{' then
		add_err('info','to start pack constructor',peekpos())
		return
	end
	
	if peek() ~= '}' then
		self.vals = self:listbasicexp()
		if not self.vals then
			add_err('info','in pack constructor started at',open)
			return
		end
	end
	
	if not self:expect '}' then
		add_err('info','to match',open)
		add_err('info','(pack constructor)')
		return
	end
	
	return self
end

function PackConst:str()
	local open,close = '{','}'
	local s = open 

	if #self.vals > 0 then
		s = s .. self.vals[1]:str()
		for i = 2,#self.vals do
			s = s .. ',' .. self.vals[i]:str()
		end
	end
	return s .. close
end


--[[
	'[' [ listbasicexp ] ']'
]]

ArrayConst = class(Node)

function ArrayConst:init()
	ArrayConst.super.init(self)
	
	self.vals = {}
	
	return self:parse()
end

function ArrayConst:parse()
	
	local open = peekpos()
	
	if not self:expect '[' then
		add_err('info','to start array constructor',peekpos())
		return
	end
	
	if peek() ~= ']' then
		self.vals = self:listbasicexp()
		if not self.vals then
			add_err('info','in array constructor started at',open)
			return
		end
	end
	
	if not self:expect ']' then
		add_err('info','to match',open)
		add_err('info','(array constructor)')
		return
	end
	
	return self
end

function ArrayConst:str()
	local open,close = '[',']'
	local s = open 

	if #self.vals > 0 then
		s = s .. self.vals[1]:str()
		for i = 2,#self.vals do
			s = s .. ',' .. self.vals[i]:str()
		end
	end
	return s .. close
end


--[[
	'/' [ listbasicexp ] '/'
]]

ListConst = class(Node)

function ListConst:init()
	ListConst.super.init(self)
	
	self.vals = {}
	
	return self:parse()
end

function ListConst:parse()
	
	local open = peekpos()
	
	if not self:expect '/' then
		add_err('info','to start list constructor',peekpos())
		return
	end
	
	if peek() ~= '/' then
		self.vals = self:listbasicexp()
		if not self.vals then
			add_err('info','in list constructor started at',open)
			return
		end
	end
	
	if not self:expect '/' then
		add_err('info','to match',open)
		add_err('info','(list constructor)')
		return
	end
	
	return self
end

function ListConst:str()
	local open,close = '/','/'
	local s = open 

	if #self.vals > 0 then
		s = s .. self.vals[1]:str()
		for i = 2,#self.vals do
			s = s .. ',' .. self.vals[i]:str()
		end
	end
	return s .. close
end


--[[
	'<' [ listbasicexp ] '>'
]]

VectorConst = class(Node)

function VectorConst:init()
	VectorConst.super.init(self)
	
	self.vals = {}
	
	return self:parse()
end

function VectorConst:parse()
	
	local open = peekpos()
	
	if not self:expect '<' then
		add_err('info','to start vector constructor',peekpos())
		return
	end
	
	if peek() ~= '>' then
		self.vals = self:listbasicexp()
		if not self.vals then
			add_err('info','in vector constructor started at',open)
			return
		end
	end
	
	if not self:expect '>' then
		add_err('info','to match',open)
		add_err('info','(vector constructor)')
		return
	end
	
	return self
end

function VectorConst:str()
	local open,close = '<','>'
	local s = open 

	if #self.vals > 0 then
		s = s .. self.vals[1]:str()
		for i = 2,#self.vals do
			s = s .. ',' .. self.vals[i]:str()
		end
	end
	return s .. close
end

--[[
	ClassName [ '(' [ listexp ] ')' ]
]]

ObjConst = class(Node)

function ObjConst:init()
	ObjConst.super.init(self)
	
	self.class = nil
	self.args = {}
	
	return self:parse()
end

function ObjConst:parse()

	-- ClassName [ '(' [ listexp ] ')' ]
	if not self:expect 'ClassName' then
		add_err('info','in insstanciation',peekpos())
		return
	end

	self.class = self:lastval()
	
	if self:accept '(' then
		local open = self:lastpos()
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

	return self
end

function ObjConst:str()

	local s = self.class .. '('
	if #self.args > 0 then
		s = s .. self.args[1]:str()
		for i = 2,#self.args do
			s = s .. ',' .. self.args[i]:str()
		end
		
	end
	
	return s .. ')'
end

--[[
exptail :=		'.' Name |
				'(' [ listexp ] ')' |
				'[' exp ']'
				
basicexp :=		( atomicexp | '(' exp ')' | constructor )
				{ exptail }
]]

Indexing = class(Node)

function Indexing:init()
	Indexing.super.init(self)
	
	self.index = nil	-- Exp node
	
	return self
end

function Indexing:str()
	return self.left:str() .. '[' .. self.index:str() .. ']'
end

MemberAccess = class(Node)

function MemberAccess:init()
	MemberAccess.super.init(self)
	
	self.name = nil		-- string
	
	return self
end

function MemberAccess:str()
	return self.left:str() .. '.' .. self.name
end

Call = class(Node)

function Call:init()
	Call.super.init(self)
	
	self.args = nil		-- list of Exp
	
	return self
end

function Call:str()
	local s = self.left:str() .. '('
	
	if self.args then
		s = s .. self.args[1]:str()
		for i = 2,#self.args do
			s = s .. ',' .. self.args[i]:str()
		end
	end
	
	return s .. ')'
end

-- Unique function that produces a leftmost derivation and the proper
-- nodes

function Node:basicexp()
	
	local open = peekpos()
	local left
	
	-- '(' exp ')'
	if self:accept '(' then
		left = Exp()
		
		if not self:expect ')' then
			add_err('info','to match',open)
			return
		end
		
	-- constructor
	elseif peek() == '{' then
		left = PackConst()
		
	elseif peek() == '[' then
		left = ArrayConst()
		
	elseif peek() == '/' then
		left = ListConst()
		
	elseif peek() == '<' then
		left = VectorConst()
	
	elseif peek() == 'ClassName' then
		left = ObjConst()
	
	else
		-- atomicexp
		left = AtomicExp()
	end

	if not left then
		return
	end
	
	-- { exptail }
	while peek() == '.' or peek() == '[' or peek() == '(' do
		local tail
		local open = peekpos()
		
		-- '[' exp ']'
		if peek() == '[' then
			tail = Indexing()
			
			tail.left = left
			tail:add(left)
			
			tail:expect '['
			
			tail.index = Exp()
			if not tail.index then
				add_err('info','as index in indexing started at',open)
				return
			else
				tail:add(tail.index)
			end
			
			if not self:expect ']' then
				add_err('info','to match (indexing)',open)
				return
			end
		
		-- '.' Name
		elseif peek() == '.' then
			
			tail = MemberAccess()
			
			tail.left = left
			tail:add(left)
			
			tail:expect '.' 
			
			if tail:expect 'Name' then
				tail.name = tail:lastval()
			else
				add_err('info','in member access started at',open)
				return
			end
		
		-- '(' [ listexp ] ')'
		elseif peek() == '(' then
			
			tail = Call()
			
			tail.left = left
			tail:add(left)
			
			tail:expect '('
			open = tail:lastpos()
			
			if peek() ~= ')' then
				tail.args = tail:listexp()
				if not tail.args then
					return
				end
			end
			
			if not tail:expect ')' then
				add_err('info','to match (method call)',open)
				return
			end
		end
		
		-- magic left derivation
		left = tail
	end
	
	return left
end

--[[
exp := 			basicexp { Binop basicexp }
]]

Exp = class(Node)

-- can pass a pre-parsed left term (from Assignment())
function Exp:init(left)
	Exp.super.init(self)
	
	-- binop
	self.left = nil
	self.terms = {}
	
	return self:parse(left)
end

--[[ TODO: transform this into Node:exp() which produces a
leftmost derivation with Nodes at each step (Binop, Unop)
]]

function Exp:parse(left)
	
	-- basicexp { Binop basicexp }
	self.left = left or self:basicexp()
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
		
		term.right = self:basicexp()
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
	
	-- unop
	if self.unop then
		return self.unop .. ' ' .. self.exp:str()
	end
	
	-- binops
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
	local chunk = Chunk()
	
	return chunk,errors
end
