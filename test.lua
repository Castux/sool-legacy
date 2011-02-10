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
    
    youSuck_Man()
    
		a = Blah()
		
		x,y = a.getSomething(<5,10e-4>)
		
		priv = getPriv a
		priv = a.getPriv() -- same thing!
		
		a,b = <1,3,4>,<2,4,5>
		
		sym = @aoisj_%&¤
		
		c = a x b -- cross product ~ c = a.x(b)
		c = a * b -- dot product
		
		d = [1,2,3,a*b] -- array
		
		l = /1,2,3,4/	-- list
			   
		e = {1,Blah(),<3,4,5>}  -- pack
		
		somenum = 5.+(4) -- blah
		somenum = 5 + 4  -- better
	end
end
]]

-- pp(lex(lex_test))

parse_test = [[

class Blah : Root
	
	num i
	
methods

	num,{vec,str},num fuck(num i num j, /vec/ v)
		-- yay
	end
	
	yay() end
	
end
]]

tokens = lex(parse_test)

print "Tokens\n======"
pp(tokens)

print"\n"
print "Parsing\n======="

par = parse(tokens)
pp(par)
