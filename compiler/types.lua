require 'class'

local intern = {}

TType = class()

function TType:init()
	
	self.sig = nil
	
	return self
end

function TType:internize()
	
	if intern[self.sig] then
		return intern[self.sig]
	else
		intern[self.sig] = self
		return self
	end
end

function TType.getAll()
	return intern
end

-- Check if given type implements a certain method
function TType:answers(sel)
	error('TType:answers(sel) - please overload me')
end

--[[ Undef type, used within constructed types before we know the subtype ]]

TUndef = class(TType)

function TUndef:init()
	
	self.sig = '?'
	
	return self:internize()
end

--[[ Num ]]

TNum = class(TType)

function TNum:init()
	
	self.sig = 'num'
	
	return self:internize()
end

--[[ Vec ]]

TVec = class(TType)

function TVec:init()
	
	self.sig = 'vec'
	
	return self:internize()
end

--[[ Str ]]

TStr = class(TType)

function TStr:init()
	
	self.sig = 'str'
	
	return self:internize()
end

--[[ Object ]]

TObject = class(TType)

function TObject:init(classname)
	
	self.name = classname
	self.sig = classname
	
	return self:internize()
end

--[[ Array ]]

TArray = class(TType)

function TArray:init(subtype)
	
	if not subtype:isa(TType) then
		error('TArray:init(subtype) - given subtype is not a type')
	end
	
	self.subtype = subtype
	
	self.sig = '[' .. subtype.sig .. ']'
	
	return self:internize()
end

--[[ List ]]

TList = class(TType)

function TList:init(subtype)
	
	if not subtype:isa(TType) then
		error('TList:init(subtype) - given subtype is not a type')
	end
	
	self.subtype = subtype
	
	self.sig = '/' .. subtype.sig .. '/'
	
	return self:internize()
end

--[[ Pack ]]

TPack = class(TType)

function TPack:init(subtypes)
	
	for i,v in ipairs(subtypes) do
		if not v:isa(TType) then
			error('TPack:init(subtypes) - one of given subtype is not a type')
		end
	end
	
	self.subtypes = subtypes
	
	self.sig = '{'
	for i,v in ipairs(subtypes) do
		self.sig = self.sig .. v.sig .. (i < #subtypes and ',' or '')
	end
	self.sig = self.sig .. '}'
	
	return self:internize()
end
