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

-- Default name searcher: up the parse tree
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

--------------------
-- Variable class --
--------------------

-- Is used to keep all information possible about variables

Variable = class()

function Variable:init()
	
	self.name = nil		-- obvious?
	self.scope = nil	-- where does it belong? can be a class, or a block
	
	self.type = nil		-- TType object
	
	self.defnode = nil	-- where was it defined? can be a member definition, an argument definition, or an assignment
	self.deftype = nil	-- can be 'member', 'argument', 'assignment'
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
		local taken = self:in_scope(mem.name)
		if taken then
			add_err('error','member ' .. mem.name .. ' is already defined',mem:pos())
			add_err('info','(here)',taken.defnode:pos())
		end
		
		-- Build inverse member table
		self.members[mem.name] = mem
		
		-- Build variables table
		local var = {
			name = mem.name,
			scope = self,
			
			type = mem.type.ttype,
			
			defnode = mem,
			deftype = 'member',
			assnum = nil,
			
			const = nil
		}
		
		self.variables[var.name] = var
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
	
	return false
end

-- Returns a list of methods that have the given name

function Class:meths_by_name(name)
	
	local l = {}
	
	for i,v in ipairs(self.methods) do
		if v.name == name then
			table.insert(l,v)
		end
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
-- self.rtypes		return types
-- self.sel			selector
-- self.sig			signature (rtypes .. ':' .. selector)

-- Build return types and selector and signature

function Method:validate_interface()
	
	-- Check return types
	self.rtypes = {}
	for _,ret in ipairs(self.ret) do
		ret:validate()
		table.insert(self.rtypes,ret.ttype)
	end
	
	-- Check arguments
	self.variables = {}
	
	for _,arg in ipairs(self.args) do
	
		-- Check type
		arg.type:validate()
		
		-- Check that name is not already taken
		local taken = self:in_scope(arg.name)
		
		if taken and taken.deftype == 'member' then
			add_err('error','argument ' .. arg.name ..
				' shadows class member of the same name',arg:pos())
			add_err('info','defined here',taken.defnode:pos())
		end
		
		if taken and taken.deftype == 'argument' then
			add_err('error','argument ' .. arg.name ..
				' already defined',arg:pos())
			add_err('info','(here)',taken.defnode:pos())
		end
		
		-- Add to reverse args table
		self.args[arg.name] = arg
		
		-- Add to variables table
		local var = {
			name = arg.name,
			scope = self,
			
			type = arg.type.ttype,
			
			defnode = arg,
			deftype = 'argument',
			assnum = nil,
			
			const = nil
		}
		
		self.variables[var.name] = var
	end
	
	-- Build selector
	local arg_types = {}
	for _,arg in ipairs(self.args) do
		table.insert(arg_types,arg.type.ttype)
	end
	
	self.sel = Selector(self.name,arg_types)
	
	-- Build signature
	
	local sig = ""
	for i,v in ipairs(self.rtypes) do
		sig = sig .. v.sig .. (i < #self.ret and ',' or '')
	end
	
	self.sig = sig .. ':' .. self.sel.sig
end

function Method:validate_body()
	self.body:validate()
end

-- Returns variable with given name if it is in current scope
-- (for a method: argument name or upper scope)
-- or nil if there is none
function Method:in_scope(name)
	
	-- Check self
	if self.variables[name] then
		return self.variables[name]
	end
	
	-- Forward to class
	return self.parent:in_scope(name)
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
end

-- Returns variable with given name if it is in current scope
-- (for a block: locals or upper scope)
-- or nil if there is none
function Method:in_scope(name)
	
	-- Check self
	if self.variables[name] then
		return self.variables[name]
	end
	
	-- Forward to class
	return self.parent:in_scope(name)
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

function Return:validate()
	
	-- Get method return types
	local meth = self:getParent(Method).ret
	
	-- Resolve types of expressions
	--local types = Exp.type_list(self.vals)
	
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
				self.type = meth.rtypes
				return true
			end
		end
		
		-- Failure 
		add_err('error','unknown variable ' .. self.val .. ' and class ' ..
			cl.name .. ' does not answer to ' .. sel.sig ,self:pos())
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
	local sel = Selector('init',types)
	
	local meth = cl:answers(sel)
	
	if not meth then
		add_err('error','class ' .. cl.name .. ' does not answer to ' .. sel.sig, self:pos())
		return false
	end
	
		-- this should be moved to interface checking
		-- should also check if all constructors are private, which would be useless
	if #meth.rtypes ~= 0 then
		add_err('error','wut? constructor returns stuff', self:pos())
		add_err('info','(constructor has signature ' .. meth.sig .. ')', meth.interfpos)
		add_err('warning','that should be an analyzer internal error, do not blame yourself')
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

function MemberAccess:validate()
	
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
			return true
		end
	end
	
	-- If not, maybe it's a method.
	
	-- Check if the parent node is a call. If yes, let it handle it.
	-- If not, we might be an argumentless call ourselves
	local sel = Selector(self.name)
	
	if self.parent:isa(Call) then
		-- exceptionally, we are a node without a type
		return true
	else
		local meth = self.left.type:answers(sel)
		
		if meth then
			self.type = meth.rtypes
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

function Indexing:validate()
	
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
	
	local sel = Selector('index',{self.index.type})
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
		
		local sel = Selector(self.left.val,types)
		local cl = self:getParent(Class)
		local meth = cl:answers(sel)
		
		if meth then
			self.type = meth.rtypes
			return true
		end
		
		-- Failure
		add_err('error','class ' .. cl.name .. ' does not answer to ' .. sel.sig, self:pos())
		return false
	end
	
	if self.left:isa(MemberAccess) then
		
		local callee = self.left.left
		local name = self.left.name
		
		local sel = Selector(name,types)
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

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
