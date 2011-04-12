require 'parser'	-- nodes are defined here
require 'types'
require 'Selector'

local errors

-- Push error to list.
local function add_err(typ,mess,pos)
	
	local err =  {
		'Analyzer',
		typ,
		mess,
		pos
	}
	
	table.insert(errors,err)
end

---------------------
-- Base Node class --
---------------------

--self.children = {}
--self.parent = nil

-- Get the first parent node whose class matches one of the arguments
function Node:getParent(...)
	
	for i,node in ipairs{...} do
		if self.class == node then
			return self
		end
	end
	
	if not self.parent then
		return nil
	end
	
	return self.parent:getParent(...)
end

-- Default variable name searcher: up the parse tree
-- (overloaded for classes who search up the class tree)
function Node:in_scope(name)
	
	-- Check self
	if self.variables and self.variables[name] then
		return self.variables[name]
	end
	
	-- Forward up
	if self.parent then
		return self.parent:in_scope(name)
	end
	
	return nil
end

-- Default check for name availability: 
function Node:taken_name(name,pos,what)
	
	-- Either a variable
	local taken = self:in_scope(name)
	
	if taken and taken.deftype == 'member' then
		add_err('error',what .. ' ' .. name ..
			' shadows class member',pos)
		add_err('info','defined here',taken.defpos)
	end
	
	if taken and taken.deftype == 'argument' then
		add_err('error',what .. ' ' .. name ..
			' shadows argument',pos)
		add_err('info','defined here',taken.defpos)
	end
	
	if taken and taken.deftype == 'local' then
		add_err('error',what .. ' ' .. name ..
			' shadows local variable',pos)
		add_err('info','defined here',taken.defpos)
	end
	
	if taken then
		return true
	end
	
	-- Or a method name
	local cl = self:getParent(Class)
	taken = cl:meths_by_name(name)
	
	if #taken > 0 then
		add_err('error',what .. ' ' .. name ..
			' shadows method name',pos)
		add_err('info','defined here',taken[1].namepos)
		return true
	end
	
	return false
end

-- To overload
function Node:validate()
	error('Node:validate() - please overload me!')
end

--------------------
-- Variable class --
--------------------

-- Is used to keep all information possible about variables

Variable = class()

function Variable:init()
	
	self.name = nil		-- obvious?
	self.scope = nil	-- where does it belong? can be a class, or a block
	
	self.type = nil		-- TType object
	
	self.defpos = nil	-- where was it defined? can be a member definition, an argument definition, or an assignment
	self.deftype = nil	-- can be 'member', 'argument', 'local'
	self.assnum = nil	-- in case of (multi) assignment, assignment number
	
	self.const = nil	-- if has a compile-time known value, put it here (represent array, lists, vectors and packs
						-- with tables; number and strings by the Lua counterpart)
	
	return self
end

-----------
-- Chunk --
-----------

--self.block = nil
--self.classes = {}

function Chunk:validate()
	
	-- Index classes by name and check they are unique
	for i,v in ipairs(self.classes) do
		
		local name = v.name
		
		if self.classes[name] then
			add_err('error','class ' .. name .. ' is already defined',v:pos(1,2))
			add_err('info','(here)',self.classes[name]:pos(1,2))
		end
		
		self.classes[name] = v
	end
	
	-- Recurse breadth first: validate all interfaces first...
	for i,v in ipairs(self.classes) do
		v:validate_interface()
	end
	
	-- ...then only the inner methods
	for i,v in ipairs(self.classes) do
		v:validate_implementation()
	end
	
end

-----------
-- Class --
-----------

--self.name = ""
--self.base = nil

--self.members = {}	-- small Node with fields {type,name} (and proper children)
--self.methods = {}

-- Added by validate():
-- self.variables = {}		members in the form of Variable
-- self.valid_iface = bool	set to true once validation of interface has passed

function Class:validate_interface()
	
	-- Don't do validation if it's been done already
	if self.valid_iface then
		return
	end
	
	-- Check that base class exists
	if self.base and not self.parent.classes[self.base] then
		add_err('error','base class ' .. self.base .. ' does not exist',self:pos(4,4))
	end
	
	-- And make sure it's been validated first (to be able to call in_scope())
	if self.base and self.parent.classes[self.base] then
		self.parent.classes[self.base]:validate_interface()
	end
	
	-- Members
	self.variables = {}
	
	for i,mem in ipairs(self.members) do
		
		-- Validate type
		mem.type:validate()
		
		-- Check for duplicates
		
		if not self:taken_name(mem.name, mem:pos(), 'member') then
		
			-- Build inverse member table
			self.members[mem.name] = mem
			
			-- Build variables table
			local var = {
				name = mem.name,
				scope = self,
				
				type = mem.type.ttype,
				
				defpos = mem:pos(),
				deftype = 'member',
				assnum = nil,
				
				const = nil
			}
			
			self.variables[var.name] = var
		end
	end
	
	-- Same for methods
	for i,meth in ipairs(self.methods) do
		
		meth:validate_interface()
		
		-- Check for duplicates (use selector, not just name)
		if self.methods[meth.sel] then
			add_err('error','method ' .. meth.sel.sig .. ' is already defined',meth.namepos)
			add_err('info','(here)',self.methods[meth.sel].namepos)
		end
		
		-- Check member-method name collision as well
		local taken = self:in_scope(meth.name)
		if taken then
			add_err('error','method ' .. meth.name .. ' shadows member of the same name',meth.namepos)
			add_err('info','defined here',taken.defnode:pos())
		end
		
		-- Add to reverse table, index by selector
		self.methods[meth.sel] = meth
	end
	
	-- "memoize"
	self.valid_iface = true
end

function Class:validate_implementation()
	
	for _,meth in ipairs(self.methods) do
		meth:validate_body()
	end
end

-- Returns variable with given name if it is in current scope
-- (for a class: member, or member in a base class)
-- or nil if there is none
function Class:in_scope(name)
	
	if self.variables[name] then
		return self.variables[name]
	end
	
	if self.base then
		return self.parent.classes[self.base]:in_scope(name)
	end
	
	return nil
end

-- Checks if the class implements the given selector
-- Return false if not, or the method if it does

function Class:answers(sel)
	
	local meth = self.methods[sel]
	
	if meth then
		return meth
	end
	
	if self.base and self.parent.classes[self.base] then
		return self.parent.classes[self.base]:answers(sel)
	end
	
	return false
end

-- Returns a list of methods that have the given name

function Class:meths_by_name(name,l)
	
	local l = l or {}
	
	for i,v in ipairs(self.methods) do
		if v.name == name then
			table.insert(l,v)
		end
	end
	
	if self.base and self.parent.classes[self.base] then
		return self.parent.classes[self.base]:meths_by_name(name,l)
	end
	
	return l
end

----------
-- Type --
----------

--self.type = ""
--self.val = nil

-- Build associated TType and store in self.ttype

function Type:validate()
	
	if self.type == 'class' then
		local classes = self:getParent(Chunk).classes
		
		if not classes[self.val] then
			add_err('error','unknown class ' .. self.val, self:pos())
		end
		
		self.ttype = TObject(classes[self.val])
	
	elseif self.type == 'array' then
		self.val:validate()
		self.ttype = TArray(self.val.ttype)
	
	elseif self.type == 'list' then
		self.val:validate()
		self.ttype = TList(self.val.ttype)
	
	elseif self.type == 'pack' then
		
		local ttypes = {}
		for i,v in ipairs(self.val) do
			v:validate()
			table.insert(ttypes,v.ttype)
		end
		
		self.ttype = TPack(ttypes)
		
		if #self.val < 2 then
			add_err('warning','packing less than 2 elements is useless',self:pos())
		end
	
	elseif self.type == 'num' then
			self.ttype = TNum()
	
	elseif self.type == 'vec' then
			self.ttype = TVec()
	
	elseif self.type == 'str' then
			self.ttype = TStr()
	end
	
end

------------
-- Method --
------------

--self.private = false
--self.ret = {}
--self.name = ""
--self.args = {}
--self.body = nil

-- validate() adds:
-- self.variables
-- self.ret			return type (potentially TMulti)
-- self.sel			selector
-- self.sig			signature (rtypes .. ':' .. selector)

-- Build return types and selector and signature

function Method:validate_interface()
	
	-- Check return types
	local types = {}
	for _,ret in ipairs(self.ret) do
		ret:validate()
		table.insert(types,ret.ttype)
	end
	
	self.ret = TMulti(types)
	
	-- Check arguments
	self.variables = {}
	
	for _,arg in ipairs(self.args) do
	
		-- Check type
		arg.type:validate()
		
		if not self:taken_name(arg.name, arg:pos(), 'argument') then
			
			-- Add to reverse args table
			self.args[arg.name] = arg
			
			-- Add to variables table
			local var = {
				name = arg.name,
				scope = self,
				
				type = arg.type.ttype,
				
				defpos = arg:pos(),
				deftype = 'argument',
				assnum = nil,
				
				const = nil
			}
			
			self.variables[var.name] = var
		end
	end
	
	-- Build selector
	local arg_types = {}
	for _,arg in ipairs(self.args) do
		table.insert(arg_types,arg.type.ttype)
	end
	
	self.sel = Selector(self.name,TMulti(arg_types))
	
	-- Build signature

	self.sig = self.ret.sig .. ':' .. self.sel.sig
end

function Method:validate_body()
	self.body:validate()
end

-----------
-- Block --
-----------

--self.stats = {}

-- validate() adds
-- self.variables = {}

function Block:validate()
	
	-- Prepare local variables table
	self.variables = {}
	
	for i,stat in ipairs(self.stats) do
		-- Validate statement, but ignore if failed (try validating as
		-- many as possible)
		stat:validate()
	end
	
	-- TODO: automatic 'return void' if not explicit
end

---------------
-- Statement --
---------------

-- All nodes at statement level or below return true if the validation
-- succeeded, or false otherwise. Any error must be reported up and 
-- cancels validation of the whole statement

function Break:validate()
	
	local loop = self:getParent(While,For,GenericFor)
	
	if not loop then
		add_err('error','break statement is not inside a loop',self:pos())
		return false
	end
	
	return true
end

function Continue:validate()
	
	local loop = self:getParent(While,For,GenericFor)
	
	if not loop then
		add_err('error','continue statement is not inside a loop',self:pos())
		return false
	end
	
	return true
end

--self.vals = {}

function Return:validate()
	
	-- Get method return types
	local meth = self:getParent(Method)
	local meth_ret = meth.ret
	
	-- Resolve types of expressions
	local types = {}
	for i,v in ipairs(self.vals) do
		if not v:validate() then
			return false
		end
		
		table.insert(types,v.type)
	end
	
	local ret = TMulti(types)
	
	-- And compare
	if meth_ret ~= ret then
		if ret == TVoid() then
			add_err('error','trying to return void', self:pos())
		else
			add_err('error','trying to return expression of type ' .. ret.sig, self:pos(2,#self.children))
		end
		add_err('info','in method declared ' .. meth.sig, meth.interfpos)
		return false
	end
	
	return true
end


-----------------
-- Expressions --
-----------------

-- All nodes that look like expressions get a TType through validation:
-- self.type

---------------
-- AtomicExp --
---------------

--self.kind = ""	Name | Number | String | nil | false | true | Symbol
--self.val = nil

function AtomicExp:validate()
	
	if self.kind == 'Name' then
		
		-- Check if it is a variable
		local found = self:in_scope(self.val)
		if found then
			self.type = found.type
			return true
		end
		
		-- If not, maybe it's a method
		-- Check if the parent node is a call. If yes, let it handle it.
		-- If not, we might be an argumentless call ourselves
		local cl = self:getParent(Class)
		local sel = Selector(self.val)
		local meth = cl:answers(sel)
		
		if self.parent:isa(Call) and self.parent.left == self then
			-- exceptionally, we are a node without a type
			return true
		else
			if meth then
				self.type = meth.ret
				return true
			end
		end
		
		-- Failure 
		add_err('error','unknown variable ' .. self.val .. ' and class ' ..
			cl.name .. ' does not answer to ' .. sel.sig,self:pos())
		return false
		
	elseif self.kind == 'Number' then
		
		self.type = TNum()
		self.val = tonumber(self.val)
		if not self.val then
			error('AtomicExp:validate() - could not convert number string into value')
		end
		
	elseif self.kind == 'String' then
		
		self.type = TStr()
		-- TODO: unescape stuff
	
	elseif self.kind == 'nil' then
	
		self.type = TUndef()
		-- TODO: to fix once we have a proper object system
	
	elseif self.kind == 'false' then
		
		self.type = TNum()
		self.val = 0
		
	elseif self.kind == 'true' then
		
		self.type = TNum()
		self.val = 1
	
	elseif self.kind == 'Symbol' then
		
		self.type = TNum()
		-- TODO: implement actual symbols
		self.val = 0
		
	end
	
	return true
end

---------------
-- PackConst --
---------------

function PackConst:validate()
	
	local types = {}
	
	for i,v in ipairs(self.vals) do
		
		if not v:validate() then
			return false
		end
		
		table.insert(types,v.type)
	end
	
	if #self.vals < 2 then
		add_err('warning','packing less than 2 elements is useless',self:pos())
	end
	
	self.type = TPack(types)
	return true
end

----------------
-- ArrayConst --
----------------

function ArrayConst:validate()
	
	local subtype = TUndef()
	local pos
	
	for i,v in ipairs(self.vals) do
		
		if not v:validate() then
			return false
		end
		
		local typ = v.type
		
		if typ == TUndef() then
			add_err('error','cannot use expression of unknown type in array constructor',v:pos())
			return false
		end
		
		if subtype == TUndef() then
			subtype = typ
			pos = v:pos()
		end
		
		if typ ~= subtype then
			add_err('error','expression of type ' .. typ.sig .. ' does not fit into array of ' .. subtype.sig, v:pos())
			add_err('info','(type of array inferred from expression:)',pos)
			return false
		end
	end
	
	self.type = TArray(subtype)
	return true
end

---------------
-- ListConst --
---------------

function ListConst:validate()
	
	local subtype = TUndef()
	local pos
	
	for i,v in ipairs(self.vals) do
	
		if not v:validate() then
			return false
		end
		
		local typ = v.type
		
		if typ == TUndef() then
			add_err('error','cannot use expression of unknown type in list constructor',v:pos())
			return false
		end
		
		if subtype == TUndef() then
			subtype = typ
			pos = v:pos()
		end
		
		if typ ~= subtype then
			add_err('error','expression of type ' .. typ.sig .. ' does not fit into list of ' .. subtype.sig, v:pos())
			add_err('info','(type of list inferred from expression:)',pos)
			return false
		end
	end
	
	self.type = TList(subtype)
	return true
end

-----------------
-- VectorConst --
-----------------

function VectorConst:validate()
	
	for i,v in ipairs(self.vals) do
		
		if not v:validate() then
			return false
		end
		
		local typ = v.type
		
		if typ ~= TNum() then
			add_err('error','vector constructor expects expressions of type num, found a ' .. typ.sig .. ' instead', v:pos())
			return false
		end
	end
	
	self.type = TVec()
	return true
end

--------------
-- ObjConst --
--------------

--self.class = nil
--self.args = {}

function ObjConst:validate()
	
	-- Does the class exist?
	local classes = self:getParent(Chunk).classes
	local cl = classes[self.class]
	
	if not cl then
			add_err('error','unknown class ' .. self.class, self.children[1][3])
			return false
	end
	
	-- Verify arguments, build type list
	local types = {}
	for i,v in ipairs(self.args) do
		if not v:validate() then
			return false
		end
		
		table.insert(types,v.type)
	end
	
	-- Check existence of the proper constructor
	local sel = Selector('init',TMulti(types))
	
	local meth = cl:answers(sel)
	
	if not meth then
		add_err('error','class ' .. cl.name .. ' does not answer to ' .. sel.sig, self:pos())
		return false
	end
	
	self.type = TObject(cl)
	
	return true
end

------------------
-- MemberAccess --
------------------

--self.left = nil		-- Exp node
--self.name = nil		-- string

-- This is significantly like validating a Name as atomic expression,
-- except the object depends on the type of self.left
-- rtype = is a TType if we need to check member as a lvalue (adds '=' to the method lookup)

-- add self.var, the associated variable if it's a member

function MemberAccess:validate(rtype)
	
	-- Validate base expression
	if not self.left:validate() then
		return false
	end
	
	-- Check if it is really a member (only for user defined objects)
	
	if self.left.type.class == TObject then
		local cl = self.left.type.cl
		local mem = cl:in_scope(self.name)
		
		if mem then
			self.type = mem.type
			self.var = mem
			return true
		end
	end
	
	-- If not, maybe it's a method.
	
	-- Check if the parent node is a call. If yes, let it handle it.
	-- If not, we might be an argumentless call ourselves
	local sel = Selector(self.name .. (rtype and '=' or ''), rtype)
	
	if self.parent:isa(Call) then
		-- exceptionally, we are a node without a type
		return true
	else
		local ret = self.left.type:answers(sel)
		
		if ret then
			-- As lvalue lookup, don't assign a type (the setter method should return void anyway)
			if not rtype then
				self.type = ret
			end
			return true
		end
	end
	
	-- Failure 
	add_err('info','expression of type ' .. self.left.type.sig , self.left:pos())
	add_err('error','has no member ' .. self.name .. ' and does not answer to ' .. sel.sig, self:pos(2,3))
	
	return false
end

--------------
-- Indexing --
--------------

--self.left = nil	-- Exp node
--self.index = nil	-- Exp node

-- rtype for validating as a lvalue

function Indexing:validate(rtype)
	
	-- Validate base expression
	if not self.left:validate() then
		return false
	end
	
	-- Validate index
	if not self.index:validate() then
		return false
	end
	
	-- TODO: Special case: pack, for which index must be known at compile time
	
	-- Check whether type answers to index
	
	local sel
	if not rtype then
		sel = Selector('index',self.index.type)
	else
		sel = Selector('index=',TMulti({self.index.type,rtype}))
	end
	local ret = self.left.type:answers(sel)
	if not ret then
		add_err('info','expression of type ' .. self.left.type.sig , self.left:pos())
		add_err('error','does not answer to ' .. sel.sig, self:pos(2,#self.children))
		return false
	end
	
	self.type = ret
	
	return true
end

----------
-- Call --
----------

--self.left = nil		-- Exp node
--self.args = nil		-- list of Exp

function Call:validate()
	
	-- Validate base expression
	if not self.left:validate() then
		return false
	end
	
	-- Validate list of arguments and get types
	local types = {}
	for i,v in ipairs(self.args) do
		if not v:validate() then
			return false
		end
		
		table.insert(types,v.type)
	end
	
	-- Check that the last node is either a Name or a MemberAccess
	-- (can't call anything else than methods, now can we)
	
	if self.left:isa(AtomicExp) and self.left.kind == 'Name' then
		
		-- callee is self, since this is a floating method call
		
		local sel = Selector(self.left.val,TMulti(types))
		local cl = self:getParent(Class)
		local meth = cl:answers(sel)
		
		if meth then
			self.type = meth.ret
			return true
		end
		
		-- Failure
		add_err('error','class ' .. cl.name .. ' does not answer to ' .. sel.sig, self:pos())
		return false
	end
	
	if self.left:isa(MemberAccess) then
		
		local callee = self.left.left
		local name = self.left.name
		
		local sel = Selector(name,TMulti(types))
		local typ = callee.type
		local ret = typ:answers(sel)
		
		if ret then
			self.type = ret
			return true
		end
		
		-- Failure
		
		add_err('info','expression of type ' .. typ.sig, callee:pos())
		add_err('error','does not answer to ' .. sel.sig, self:range(self.left:lastpos(),self:lastpos()))
		return false
	end
	
	return true
end

----------
-- Unop --
----------

--self.op = nil			-- string
--self.expr = nil		-- Exp node

function Unop:validate()
	
	-- Validate base expression
	if not self.expr:validate() then
		return false
	end
	
	-- Check that object answers to unop method

	local sel = Selector(self.op,TVoid())
	local typ = self.expr.type
	local ret = typ:answers(sel)
	
	if ret then
		self.type = ret
		return true
	end
	
	-- Failure
	add_err('info','expression of type ' .. typ.sig, self.expr:pos())
	add_err('error','does not answer to ' .. sel.sig, self.children[1][3])
	
	return false
end

-----------
-- Binop --
-----------

--self.left = nil
--self.op = nil
--self.right = nil

function Binop:validate()
	
	-- Validate left and right expression
	if not self.left:validate() or not self.right:validate() then
		return false
	end
	
	-- Check that object answers to unop method

	local sel = Selector(self.op,self.right.type)
	local typ = self.left.type
	local ret = typ:answers(sel)
	
	if ret then
		self.type = ret
		return true
	end
	
	-- Failure
	add_err('info','expression of type ' .. typ.sig, self.left:pos())
	add_err('error','does not answer to ' .. sel.sig, self:pos(2,#self.children))
	
	return false
end

------------------------
-- Control structures --
------------------------

--------
-- Do --
--------

--self.body = nil

function Do:validate()
	
	if not self.body:validate() then
		return false
	end
	
	return true
end

-----------
-- While --
-----------

--self.cond = nil
--self.body = nil

function While:validate()
	
	local val1, val2 = self.cond:validate(), self.body:validate()
	
	if not val1 or not val2 then
		return false
	end
	
	return true
end

--------
-- If --
--------

--self.tests = {}
--self.default = nil

function If:validate()
	
	local res = true
	
	for i,v in ipairs(self.tests) do
		local val1, val2 = v.cond:validate(), v.body:validate()
		
		if not val1 or not val2 then
			res = false
		end
	end
	
	if self.default and not self.default:validate() then
		res = false
	end
	
	return res
end

---------
-- For --
---------

--self.var = ""
--self[1] = nil
--self[2] = nil
--self[3] = nil
--self.body = nil

function For:validate()
	
	local ret = true
	
	self.variables = {}
	
	-- Check that name is not already taken
	if not self:taken_name(self.var, self.children[2][3],'numeric index') then
		
		-- Add to variables table
		local var = {
			name = self.var,
			scope = self,
			
			type = TNum(),
			
			defpos = self.children[2][3],
			deftype = 'local',
			assnum = nil,
			
			const = nil
		}
		
		self.variables[var.name] = var
	else
		ret = false
	end
	
	-- Check that expressions are numbers
	local val = {}
	val[1] = self[1]:validate()
	val[2] = self[2]:validate()
	
	for i = 1,2 do
		if val[i] then
			if self[i].type ~= TNum() then
				add_err('error','boundary in numeric if is not of type num',self[i]:pos())
				add_err('info','(is of type ' .. self[i].type.sig .. ' instead)')
				ret = false
			end
		else
			ret = false
		end
	end
	
	if self[3] then
		if self[3]:validate() then
			if self[3].type ~= TNum() then
				add_err('error','step in numeric if is not of type num',self[3]:pos())
				add_err('info','(is of type ' .. self[3].type.sig .. ' instead)')
				ret = false
			end
		else
			ret = false
		end
	end
	
	-- Validate body
	if not self.body:validate() then
		ret = false
	end
	
	return ret
end

----------------
-- GenericFor --
----------------

--self[1] = ""
--self.exp = nil
--self.body = nil

function GenericFor:validate()
	
	local ret = true
	
	-- Check first the type of the expression (needed for local variables setting)
	if not self.exp:validate() then
		ret = false
	end
	
	-- Check if expression answers to iterN(), where N is the number of required names
	local num = #self
	
	local sel = Selector('iter' .. num, TVoid())
	local typ = self.exp.type:answers(sel)
	
	if not typ then
		add_err('error','expression in generic for does not answer to ' .. sel.sig, self.exp:pos())
		ret = false
	end
	
	local types = typ.subtypes or {typ}
	
	if #types ~= num then
		add_err('error','iterator returns type ' .. typ.sig .. ' which does not match ' .. num .. ' values',self.exp:pos())
		ret = false
	end
	
	-- Validate names
	self.variables = {}
	
	if ret then
		-- Check that names are not already taken
		for i,name in ipairs(self) do
			if not self:taken_name(name, self.children[i+1][3],'generic index') then
				
				-- Add to variables table
				local var = {
					name = name,
					scope = self,
					
					type = types[i],
					
					defpos = self.children[i+1][3],
					deftype = 'local',
					assnum = nil,
					
					const = nil
				}
				
				self.variables[var.name] = var
			else
				ret = false
			end
		end
	end
	
	-- Validate body
	
	if not self.body:validate() then
		ret = false
	end
	
	return true
end

----------------
-- Assignment --
----------------

--self.lval = nil
--self.rval = nil

function Assignment:validate()
	
	local ret = true
	
	-- Validate rvalues
	
	local rtypes = {}
	
	for i,v in ipairs(self.rval) do
		if not v:validate() then
			ret = false
		else
			table.insert(rtypes,v.type)
		end
	end
	
	if not ret then return false end
	
	-- Build association between Nth rtype and Mth rvalue
	local assoc = {}
	for i,v in ipairs(rtypes) do
		if v:isa(TMulti) then
			for j = 1,#v.subtypes do
				table.insert(assoc,i)
			end
		else
			table.insert(assoc,i)
		end
	end
	
	-- Build type
	local rtype = TMulti(rtypes)
	
	-- Build back list of types (solves expressions that have several types)
	local rtypes
	if rtype:isa(TMulti) then
		rtypes = rtype.subtypes
	else
		rtypes = {rtype}
	end
	
	-- Check that number of types match
	if #rtypes ~= #self.lval then
		add_err('error','wrong number of left values (' ..#self.lval .. ') in assignment',self:range(self.lval[1]:pos(),self.lval[#self.lval]:pos()))
		add_err('info','(right hand side is of type ' .. rtype.sig .. ')',self:range(self.rval[1]:pos(),self.rval[#self.rval]:pos()))
		return false
	end
	
	-- Check that all left values are indeed valid lvalues (names or member accesses or name= or []= methods)
	-- TODO: for local variables, deal with incomplete types /?/ and [?]
	
	for i,v in ipairs(self.lval) do
		
		-- Name
		if v:isa(AtomicExp) and v.kind == 'Name' then
			
			local var = self:in_scope(v.val)
			local meths = self:getParent(Class):meths_by_name(v.val .. '=')
			
			-- If it's already a variable, check type
			if var then
				if var.type ~= rtypes[i] then
					add_err('error','incompatible type (' .. self.rval[assoc[i]].type.sig .. ') in assignment',self.rval[assoc[i]]:pos())
					add_err('info','(corresponding left value is of type ' .. var.type.sig .. ')', v:pos())
					add_err('info','(as declared here)', var.defpos)
				end
			
			-- Check presence of a name= method on self
			elseif #meths > 0 then
				local found = false
				
				for j,meth in ipairs(meths) do
					if meth.sel.arg_type == rtypes[i] then
						found = true
					end
				end
				
				if not found then
					add_err('error','incompatible type (' .. rtypes[i].sig .. ') in assignment', self.rval[assoc[i]]:pos())
					add_err('info','candidate setter methods are:',v:pos())
					for j,meth in ipairs(meths) do
						add_err('info',meth.sig,meth.interfpos)
					end
					ret = false
				end
			
			-- Otherwise check if it is a valid name, make new variable
			-- (the only conflict that might be left is a 'name' method, but let's use the general name checker)
			elseif not self:taken_name(v.val,v:pos(),'new local variable') then
			
				local block = self:getParent(Block)
				
				-- Add to variables table
				local var = {
					name = v.val,
					scope = block,
					
					type = rtypes[i],
					
					defpos = self:pos(),
					deftype = 'local',
					assnum = i,
					
					const = nil
				}
				
				block.variables[var.name] = var
				
				-- Also give node a type
				v.type = rtypes[i]
				
			else
				ret = false
			end
		
		-- MemberAccess
		elseif v:isa(MemberAccess) then
			
			-- Just validate as lvalue, that will give it a type and a var (if it's a member), or fail if there is no proper member or setter
			if not v:validate(rtypes[i]) then
				-- If lvalue validation failed, we're done, but we can add info message
				add_err('info','(as required by corresponding right value of type ' .. self.rval[assoc[i]].type.sig .. ')',self.rval[assoc[i]]:pos())
				ret = false
			else
				
				if v.type and v.type ~= rtypes[i] then
					add_err('error','incompatible type (' .. self.rval[assoc[i]].type.sig .. ') in assignment',self.rval[assoc[i]]:pos())
					add_err('info','(corresponding left value is of type ' .. v.type.sig .. ')', v:pos())
					add_err('info','(as declared here)', v.var.defpos)
				end
				
			end
		
		-- Indexing
		elseif v:isa(Indexing) then
			
			if not v:validate(rtypes[i]) then
				add_err('info','(as required by corresponding right value of type ' .. self.rval[assoc[i]].type.sig .. ')',self.rval[assoc[i]]:pos())
				ret = false
			end
			
		-- All else fails
		else
			add_err('error','invalid left value',v:pos())
			add_err('info','(expected Name, member access or indexing)')
		
		end
		
	end
	
	return ret
end

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
