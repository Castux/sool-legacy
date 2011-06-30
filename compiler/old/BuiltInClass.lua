require 'class'

-- We do not make it a sub-class of Class, because they have little in
-- common. We just need to make sure they have a similar interface
-- for usage

BuiltInClass = class()

function BuiltInClass:init(name)
	
	-- Internally used name (there is no sool-side interface), for type signatures
	
	self.name = name
	
	-- List of method objects
	
	self.methods = {}
	
	return self
end

-- Non compound classes are pretty simple, just make one global object
-- for each, with manually filled methods (or use nova)

Number = BuiltInClass('num')
Vector = BuiltInClass('vec')
String = BuiltInClass('str')
Symbol = BuiltInClass('sym')

-- Compound classes are more complex, they are built from templates
-- using global functions that build a new class and internizes it

local dummy = BuiltInClass('dummy')

Array = function(subtype)
	return dummy
end

List = function(subtype)
	return dummy
end

Table = function(ktype,vtype)
	return dummy
end

-- Now that we have all these globals defined, we can start filling the methods

Number.methods = {



}
