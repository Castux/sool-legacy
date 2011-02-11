require 'lexer'
require 'parser'

pp = function(t)
	
	if type(t) == 'table' then
		io.write'{'
		
        --[[for i,v in ipairs(t) do
			pp(v)
			if i < #t then
				io.write','
			end
		end]]
        
        for k,v in pairs(t) do
            io.write(k,'=')
            pp(v)
            io.write','
        end
		io.write'}'
	
    elseif type(t) == 'boolean' then
        io.write(t and 'true' or 'false')
	else
		io.write(t or 'nil')
	end
end

debug = function(s)
    print("Debug:",s)
end


lex_test = [[


class Blah : Root
	num a
	vec v
	private vec v2
methods
	num,num getSomething(vec v)
        return v.x, v.y
    end
    
    {/num/,/vec/} youSuck_Man()
    
		a = Blah()
		
		for x,y in a do
			x2,y2 = a.getSomething(<x,y>)
			if x2 == y2 then break end
		end
		
		while priv do
			priv = a.getPriv()
			if priv.ahah?() then continue end
		end
				
		a,b = <1,3,4>,<2,4,5>
		
		a.sing()	-- lone method call is a statement
		
		sym = @aoisj_%&¤
		
		c = a * b -- dot product
		
		d = [1,2,a,b.c(e)] -- array (no operators in constructor)
		
		l = /1,2,3,4/	-- list
			   
		e = {1,Blah(),<3,4,5>}  -- pack
		
		somenum = 5 + 4
		
		5.double()[3] = @meh
	end
	
	num op<<(num b)
		return i + b.i
	end
end
]]

--[=[
lex_test = [[
a,b,c = Yay(),3,<a,b>
c.kill(/1,2,3/)
]]
]=]
tokens = lex(lex_test)

print "Tokens\n======"
pp(tokens)

print"\n"
print "Parsing\n======="

par = parse(tokens)
pp(par)
print ''
