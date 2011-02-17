require 'parser'    -- nodes are defined here

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
            add_err('error','class ' .. name .. ' was already defined',v:pos(1,2))
            add_err('info','(here)',self.classes[name]:pos(1,2))
        end
        
        self.classes[name] = v
    end
    
    -- Recurse
    for i,v in ipairs(self.classes) do
        v:validate(self.classes)
    end
    
    -- Check for cyclic inheritence
    
end

-----------
-- Class --
-----------

--self.name = ""
--self.parent = nil

--self.members = {}	-- {type,name}
--self.methods = {}

function Class:validate(classes)
    
    -- Check that parent class exists
    if self.parent and not classes[self.parent] then
        add_err('error','parent class ' .. self.parent .. ' does not exist',self:pos(4,4))
    end
    
    -- Build inverse member table and check for duplicates
    for i,mem in ipairs(self.members) do
        
        if self.members[mem.name] then
            add_err('error','member ' .. mem.name .. ' was already defined',mem:pos())
            add_err('info','(here)',self.members[mem.name]:pos())
        end
        
        self.members[mem.name] = mem
    end
    
    -- Build inverse method table and check for duplicates (use signatures, not just name)
    for i,meth in ipairs(self.methods) do
        
        if self.methods[meth:signature()] then
            add_err('error','method ' .. meth:signature() .. ' was already defined',meth.namepos)
            add_err('info','(here)',self.methods[meth:signature()].namepos)
        end
        
        self.methods[meth:signature()] = meth
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

---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
