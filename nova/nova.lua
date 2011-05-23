module(..., package.seeall)

function validate_grammar(g)
    
    for k,v in pairs(g) do
        if not build_first_set(v,g) then
            return false
        end
    end
    
    return true
end

function rule_type(r,g)
    
    if type(r) == 'string' then
        if g[r] then
            return 'named rule'
        else
            return 'terminal'
        end
    
    elseif type(r) == 'table' then
        return 'rule'
    
    else
        error('Rule is neither a string or a table')
    end
end

function first_set(r,g)
    
    -- Terminal
    if rule_type(r) == 'terminal' then
        return { r = true }
    
    -- Named rule
    elseif rule_type(r) == 'named rule' then
        return first_set(g[r],g)
    
    end
    
    -- Table, do the work
    
    
    
end
