require 'lpeg'

pp = function(t)
	
	if type(t) == 'table' then
		io.write'{'
		for i,v in ipairs(t) do
			pp(v)
			if i < #t then
				io.write','
			end
		end
		io.write'}'
	
	else
		io.write(t)
	end
end

local P,R,S,V = lpeg.P, lpeg.R, lpeg.S, lpeg.V
local C,Ct,Cc = lpeg.C, lpeg.Ct, lpeg.Cc

-- lexical elements

local Blank = S' \n\t'
local Space = Blank ^ 0

local function token(id,patt)
	return Ct(Cc(id) * C(patt) * Space)
end

local Specials = Ct(C(
	P'class' + P'methods' + P'end' +
	P'num' + P'vec' + P'str' + P'return' +
	P'private' + S':.,()[]{}='
)) * Space

local Operators =
	P'==' + P'~=' + P'<=' + P'>=' + P'<<' + P'>>' +
	P'+=' + P'-=' + P'*=' + P'/=' + P'%=' + P'^=' +
	S'+-*/%^#=<>'

local ClassName = token( 'ClassName', R'AZ' * R('AZ','az','09','__') ^ 0 )
local Name = token( 'Name', Operators + R('az','__') * R('AZ','az','09','__') ^ 0 )

local Digit = R'09'

local Decimal = Digit ^ 1
local Hexadecimal = P '0' * S 'xX' * R('09', 'AF', 'af') ^ 1
local Float = ( Digit^1 * (P'.' * Digit^0)^-1 + P'.' * Digit^1) *
                     (S'eE' * S'-+'^-1 * Digit^1)^-1
local Number = token('Number', Hexadecimal + Float + Decimal)

local Comment = token('Comment', P'--' * (1 - P'\n') ^ 0 )

local AnyToken = Comment + Specials + Name +
	ClassName + Number

test = [[
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

G = Ct( AnyToken^0 )

pp(G:match(test))
