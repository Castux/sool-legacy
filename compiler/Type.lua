require 'class'

-- The Type is a fancy internal object (not part of the AST) which does
-- all the magic of checking compatibility in assignment, message answering
-- checks, coercion, etc.
-- A Type object can hold multiple single types, as it is used for method
-- arguments, method returns, multiple assignments, etc.

Type = class()

local types = {}

function Type:init(sig)
	
	if sig then
		if types[sig] then
			return types[sig]
		else
			error("No type with signature " .. sig)
		end
	end
	
	self.sig = nil
	self.interface = Interface()
	
	return self
end

-- Does this type answer to the given selector, and what type is returned?
function Type:answers(sel)
	return self.interface:sel_match(sel)
end

---------------
-- MultiType --
---------------

MultiType = class(Type)

function MultiType:init(types)
	
	self.types = {}
	
	-- Flatten other multitypes
	for i,v in ipairs(types) do
		if v:isa(MultiType) then
			table.append(self.types,v.types)
		else
			table.insert(self.types,v)
		end
	end
	
	-- Make sig
	self.sig = ""
	for i,v in ipairs(self.types) do
		self.sig = self.sig .. v.sig
	end
	
	-- Internize
	local other = types[self.sig]
	if other then
		return other
	else
		types[self.sig] = self
	end
	
	-- Return lone type if relevant
	if #self.types > 1 then
		return self
	else
		return self.types[1]
	end
end

function MultiType:answers()
	error("MultiType cannot answer to messages, fix upstream!")
end

---------------
-- ArrayType --
---------------

ArrayType = class(Type)

function ArrayType:init(subtype)
	
	self.subtype = subtype
	self.sig = '[' .. subtype.sig .. ']'

	-- Internize
	local other = types[self.sig]
	if other then
		return other
	else
		types[self.sig] = self
	end
	
	-- Built-in template for methods
	self.interface = Interface()
	self.interface:add(Selector("insert",subtype), Type"void")
	self.interface:add(Selector("index",Type"num"), subtype)
	--etc
	
	return self
end

---------------
-- TableType --
---------------

TableType = class(Type)

function TableType:init(keytype,valtype)
	
	self.keytype = keytype
	self.valtype = valtype
	self.sig = '{' .. keytype.sig .. ',' .. valtype.sig .. '}'
		
	-- Internize
	local other = types[self.sig]
	if other then
		return other
	else
		types[self.sig] = self
	end
	
	return self
end

---------------
-- ValueType --
---------------

-- These have a fixed set of methods, so a simple list will do

ValueType = class(Type)

function ValueType:init(sig)
	
	self.sig = sig
	self.interface = Interface()
	
	-- Internize
	local other = types[self.sig]
	if other then
		return other
	else
		types[self.sig] = self
	end
		
	return self
end

----------------
-- ObjectType --
----------------

-- This simply wraps user defined classes

ObjectType = class(Type)

function ObjectType:init(cl)
	
	self.cl = cl
	self.sig = cl.name
	self.interface = cl.interface
	
	-- Internize
	local other = types[self.sig]
	if other then
		return other
	else
		types[self.sig] = self
	end
		
	return self
end

--------------
-- Selector --
--------------

-- Just a name and a type, but internized

local selectors = {}

Selector = class()

function Selector:init(name,typ)
	
	self.name = name
	self.typ = typ
	
	self.sig = name .. ':' .. typ.sig
	
	-- Internize
	local other = selectors[self.sig]
	if other then
		return other
	else
		selectors[self.sig] = self
		return self
	end
end


---------------
-- Interface --
---------------

-- A unified object for built-in values, composite types, and user-defined
-- classes. It associates selectors with return types.

Interface = class()

function Interface:init()
	
	self.selectors = {}
	
	return self
end

function Interface:add(sel,rtype)
	self.selectors[sel] = rtype
end

function Interface:sel_match(sel)
	return self.selectors[sel]
end

function Interface:name_match(sel)
	local matches = {}
	for k,v in pairs(self.selectors) do
		if sel.name == v.name then
			table.insert(matches,v)
		end
	end
	return matches
end

---------------------------
-- Built-in value types! --
---------------------------

-- Finally, here they are, ready to be used in real life
-- Let's not make them global though, use the shortcut Type("type")

-- First build them all (so that we can use them by name even if
-- they are incomplete)

local void = ValueType("void")
local num = ValueType("num")
local vec = ValueType("vec")

-- Then give them interfaces

num.interface:add(Selector("+",num), num)

vec.interface:add(Selector("+",vec), vec)
vec.interface:add(Selector("index",num), num)
