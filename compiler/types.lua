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

--[[ Void type, used for function calls that return nothing ]]

TVoid = class(TType)

function TVoid:init()
	
	self.sig = 'void'
	
	return self:internize()
end

function TVoid:answers(sel)
	-- cannot call anything on void
	return false
end

--[[ Num ]]

TNum = class(TType)

function TNum:init()
	
	self.sig = 'num'
	
	return self:internize()
end

function TNum:answers(sel)
	
	local meths = {
		['+:num'] = TNum(),
		['-:num'] = TNum(),
		['/:num'] = TNum(),
		['*:num'] = TNum(),
		['+=:num'] = TVoid(),
		['-=:num'] = TVoid(),
		['/=:num'] = TVoid(),
		['*=:num'] = TVoid()
	}
	
	return meths[sel.sig]
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

function TObject:init(cl)
	
	self.cl = cl
	self.sig = cl.name
	
	return self:internize()
end

function TObject:answers(sel)
	
	local meth = self.cl:answers(sel)
	
	if meth then
		return meth.ret
	else
		return false
	end
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

function TArray:answers(sel)
	
	local meths = {
		['index:num'] = self.subtype
	}
	
	return meths[sel.sig]
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

function TList:answers(sel)
	
	local meths = {
		['index:num'] = self.subtype
	}
	
	return meths[sel.sig]
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

--[[ Multiple values ]]

-- Automagically falls back to the proper type when used with only one element
-- And to void with zero

TMulti = class(TType)

function TMulti:init(subtypes)
	
	if #subtypes == 0 then
		return TVoid()
	end
	
	for i,v in ipairs(subtypes) do
		if not v:isa(TType) then
			error('TPack:init(subtypes) - one of given subtype is not a type')
		end
	end
	
	self.subtypes = subtypes
	
	self.sig = ''
	for i,v in ipairs(subtypes) do
		self.sig = self.sig .. v.sig .. (i < #subtypes and ',' or '')
	end
	
	return self:internize()
end
