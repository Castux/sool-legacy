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
		
		self.ttype = TObject(self.val)
	
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
-- self.sig			signature (rtypes:selector)

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

-- All nodes that look like expressions get a TType through validation:
-- self.type

---------------
-- AtomicExp --
---------------

--self.kind = ""	Name | Number | String | nil | false | true | Symbol
--self.val = nil

function AtomicExp:validate()
	
	if self.kind == 'Name' then
	
		local found = self:in_scope(self.val)
		if not found then
			add_err('error','unknown variable ' .. self.val,self:pos())
			self.type = TUndef()
		else
			self.type = found.type
		end
	
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
	
end

---------------
-- PackConst --
---------------

function PackConst:validate()
	
	local types = {}
	
	for i,v in ipairs(self.vals) do
		v:validate()
		table.insert(types,v.type)
	end
	
	self.type = TPack(types)
end

----------------
-- ArrayConst --
----------------

function ArrayConst:validate()
	
	local subtype = TUndef()
	local pos
	
	for i,v in ipairs(self.vals) do
		v:validate()
		
		local typ = v.type
		
		if typ == TUndef() then
			add_err('error','cannot use expression of unknown type in array constructor',v:pos())
			self.type = TUndef()
			return
		end
		
		if subtype == TUndef() then
			subtype = typ
			pos = v:pos()
		end
		
		if typ ~= subtype then
			add_err('error','expression of type ' .. typ.sig .. ' does not fit into array of ' .. subtype.sig, v:pos())
			add_err('info','(type of array inferred by expression:)',pos)
			return
		end
	end
	
	self.type = TArray(subtype)
end

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
