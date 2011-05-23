module(..., package.seeall)

----------------------
-- Set computations --
----------------------

function set_copy(a)
	
	local res = {}
	for k,v in pairs(a) do
		res[k] = v
	end
	
	return res
end

function set_intersection(a,b)
	
	local res = {}
	
	for k,v in pairs(a) do
		if b[k] then
			res[k] = v
		end
	end
	
	return res
end

function set_union(a,b)
	
	local res = set_copy(a)
	
	for k,v in pairs(b) do
		res[k] = v
	end
	
	return res
end

function set_empty(a)
	
	for k,v in pairs(a) do
		return false
	end
	
	return true
end

function set_print(a)
	
	io.write('{')
	for k,v in pairs(a) do
		io.write("'",k,"' ")
	end
	io.write('}\n')
	
end

-------------------------
-- Grammar preparation --
-------------------------

function validate_grammar(g)
	
	for k,v in pairs(g) do
		if not validate_rule(r,g) then
			return false
		end
	end
	
	return true
end

function rule_type(r,g)
	
	if type(r) == 'string' then
		if g[r] then
			return 'named rule', g[r]
		else
			return 'terminal'
		end
	
	elseif type(r) == 'table' then
		return 'rule', r
	
	else
		error('Rule is neither a string or a table: ' .. type(r))
	end
end

function first_set(r,g)
	
	local first = {}
	
	-- Terminal
	if rule_type(r,g) == 'terminal' then
		first[r] = true
		return first
	
	-- Named rule
	elseif rule_type(r,g) == 'named rule' then
		return first_set(g[r],g)
	
	end
	
	-- Table, do the work
	
	-- Use memoized if any
	if r.first_set then
		return r.first_set
	end
	
	-- Empty sequence
	if #r == 0 then
		return {}
	end
	
	-- Simple: sequence
	if not r.choice then
	
		first = first_set(r[1],g)
		
		-- For each consecutive optional rule we need to add the ones that follow
		for i = 1,#r-1 do
			
			if not r[i].optional then
				break
			end
			
			local follow = first_set(r[i+1],g)
			first = set_union(first,follow)
		end
		
		
	-- Choice: merge sets for all choices
	else
		
		first = first_set(r[1],g)
		
		for i = 2,#r do
			
			local follow = first_set(r[i],g)
			first = set_union(first,follow)
		end
		
	end
	
	-- Memoize
	r.first_set = first
	
	return first
end

function validate_rule(r,g)
	
	-- Terminal
	if rule_type(r,g) == 'terminal' then
		return true
	
	-- Named rule
	elseif rule_type(r,g) == 'named rule' then
		return validate_rule(g[r],g)
	end
	
	-- Table, do the work
	
	-- Use memoized if any
	if r.valid then
		return true
	end
	
	-- Sequence
	if not r.choice then
		
		-- Need to check that for any optional subrule, its first set doesn't collide with the one of the following subrule
		
		for i,v in ipairs(r) do
			local typ,rul = rule_type(v,g)
			if rul and rul.optional and r[i+1] then
				local inter = set_intersection(first_set(rul),first_set(r[i+1]))
				
				if not set_empty(inter) then
					error('First/Follow conflict with ' .. rul.name .. ' and ' .. r[i+1])
				end
			end
			
		end
		
	
	-- Choice
	else
	
	end
	
	-- Memoize
	r.valid = true
	
	return true
end
