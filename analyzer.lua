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

function Node:getParent(clas)
	
	if self.class == clas then
		return self
	end
	
	if not self.parent then
		return nil
	end
	
	return self.parent:getParent(clas)
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

function Class:validate()
	
	-- Check that base class exists
	if self.base and not self.parent.classes[self.base] then
		add_err('error','base class ' .. self.base .. ' does not exist',self:pos(4,4))
	end
	
	-- Members
	for i,mem in ipairs(self.members) do
		
		-- Validate type
		mem.type:validate()
		
		-- Check for duplicates
		if self.members[mem.name] then
			add_err('error','member ' .. mem.name .. ' is already defined',mem:pos())
			add_err('info','(here)',self.members[mem.name]:pos())
		end
		
		-- Build inverse member table
		self.members[mem.name] = mem
	end
	
	-- Same for methods
	for i,meth in ipairs(self.methods) do
		
		-- Check for duplicates (use signatures, not just name)
		if self.methods[meth:signature()] then
			add_err('error','method ' .. meth:signature() .. ' is already defined',meth.namepos)
			add_err('info','(here)',self.methods[meth:signature()].namepos)
		end
		
		-- Check member-method name collision as well
		if self.members[meth.name] then
			add_err('error','method ' .. meth.name .. ' shadows member of the same name',meth.namepos)
			add_err('info','defined here',self.members[meth.name]:pos())
		end
		
		-- Add to reverse table
		self.methods[meth:signature()] = meth
	end
	
end

function Class:validate_methods()
	
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

------------
-- Method --
------------

--self.private = false
--self.ret = {}
--self.name = ""
--self.args = {}
--self.body = nil

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
	
end

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
