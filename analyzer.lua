require 'parser'	-- nodes are defined here

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
	
	self.type = nil		-- type node, or nil if not yet known
	
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
		v:validate()
	end
	
	-- ...then only the inner methods
	for i,v in ipairs(self.classes) do
		v:validate_methods()
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
-- self.variables = {}	members in the form of Variable

function Class:validate()
	
	-- Check that base class exists
	if self.base and not self.parent.classes[self.base] then
		add_err('error','base class ' .. self.base .. ' does not exist',self:pos(4,4))
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
			
			type = mem.type,
			
			defnode = mem,
			deftype = 'member',
			assnum = nil,
			
			const = nil
		}
		
		self.variables[var.name] = var
	end
	
	-- Same for methods
	for i,meth in ipairs(self.methods) do
		
		-- Check for duplicates (use signatures, not just name)
		if self.methods[meth:signature()] then
			add_err('error','method ' .. meth:signature() .. ' is already defined',meth.namepos)
			add_err('info','(here)',self.methods[meth:signature()].namepos)
		end
		
		-- Check member-method name collision as well
		local taken = self:in_scope(meth.name)
		if taken then
			add_err('error','method ' .. meth.name .. ' shadows member of the same name',meth.namepos)
			add_err('info','defined here',taken.defnode:pos())
		end
		
		-- Add to reverse table
		self.methods[meth:signature()] = meth
	end
	
end

function Class:validate_methods()
	
	for _,meth in ipairs(self.methods) do
		meth:validate()
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

----------
-- Type --
----------

--self.type = ""
--self.val = nil

function Type:validate()
	
	if self.type == 'class' then
		local classes = self:getParent(Chunk).classes
		
		if not classes[self.val] then
			add_err('error','unknown class ' .. self.val, self:pos())
		end
	
	elseif self.type == 'array' or self.type == 'list' then
		self.val:validate()
	
	elseif self.type == 'pack' then
		for i,v in ipairs(self.val) do
			v:validate()
		end
	end
	
end

function Type:equals(other)
	
	if self.type ~= other.type then
		return false
	end
	
	if self.type == 'class' then
		return self.val == other.val
	end
	
	if self.type == 'array' or self.type == 'list' then
		return self.val:equals(other.val)
	end
	
	if self.type == 'pack' then
		return Type.list_equals(self.val,other.val)
	end
	
	error('Type:equal() - unknown type ' .. self.type)
end

function Type.list_equals(a,b)
	
	if #a ~= #b then
		return false
	end
	
	for i = 1,#a do
		if not a[i]:equals(b[i]) then
			return false
		end
	end
	
	return true
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

function Method:signature()
	
	if self.sig then
		return self.sig
	end
	
	local sig = ''
	
	for i,v in ipairs(self.ret) do
		sig = sig .. v:str()
		if i < #self.ret then
			sig = sig .. ','
		end
	end
	
	sig = sig .. ':' .. self.name .. ':'
	
	for i,v in ipairs(self.args) do
		sig = sig .. v.type:str()
		if i < #self.args then
			sig = sig .. ','
		end
	end
	
	-- Memoize
	self.sig = sig
	
	return sig
end

function Method:validate()
	
	-- Check return types
	for _,ret in ipairs(self.ret) do
		ret:validate()
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
			
			type = arg.type,
			
			defnode = arg,
			deftype = 'argument',
			assnum = nil,
			
			const = nil
		}
		
		self.variables[var.name] = var
	end
	
	-- Recurse
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

function Break:validate()
	
	local loop = self:getParent(While,For,GenericFor)
	
	if not loop then
		add_err('error','break statement is not inside a loop',self:pos())
	end
end

function Continue:validate()
	
	local loop = self:getParent(While,For,GenericFor)
	
	if not loop then
		add_err('error','continue statement is not inside a loop',self:pos())
	end
end

function Return:validate()
	
	-- Get method return types
	local meth = self:getParent(Method).ret
	
	-- Resolve types of expressions
	--local types = Exp.type_list(self.vals)
	
end


-----------------
-- Expressions --
-----------------

-- When validating an expression, we also compute its type and store it
-- in self.type. If the type is unknown yet, use '?'

---------------
-- AtomicExp --
---------------

--self.kind = ""
--self.val = nil
--self.args = nil		-- for instanciation only

function AtomicExp:validate()
	
	if self.kind == 'var' then
		
		local var = self:in_scope(self.val)
		self.type = var and var.type or '?'
		
	elseif self.kind == 'number' then
	
		local num = Type(true)
		num.type = 'num'
		self.type = num
	
	end
	
	print('debuuug ' .. ( self.type == '?' and '?' or self.type:str() ) )
end

--------------
-- BasicExp --
--------------

--self.atom = nil
--self.tails = {}

function BasicExp:validate()
	
	self.atom:validate()
	
end

---------
-- Exp --
---------

--self.left = nil
--self.terms = {}

function Exp:validate()
	
	self.left:validate()
	
end

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
