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
    
    if self.block then
        -- Transform block into main method. TODO
    end
    
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
        v:validate()
    end
    
end

-----------
-- Class --
-----------

--self.name = ""
--self.parent = nil

--self.members = {}	-- {type,name}
--self.methods = {}

function Class:validate()


end


---------------------------
-- Main analyzing driver --
---------------------------

function validate(chunk)
	errors = {}
	
	chunk:validate()
	
	return errors
end
