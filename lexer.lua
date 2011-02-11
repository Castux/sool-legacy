require 'lpeg'

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
	P'do' + P'if' + P'then' + P'elseif' + P'else' +
	P'while' + P'for' + P'in' + P'break' + P'continue' +
	P'nil' + P'false' + P'true' +
	P'private' + S':.,;()[]{}/<>='
)) * Space

local Operators =
	P'==' + P'~=' + P'<=' + P'>=' + P'<<' + P'>>' +
	P'+=' + P'-=' + P'*=' + P'/=' + P'%=' + P'^=' +
	S'+-*/%^#=<>'

local ClassName = token( 'ClassName', R'AZ' * R('AZ','az','09','__') ^ 0 )
local Name = token( 'Name', Operators + R('az','__') * R('AZ','az','09','__') ^ 0 )

local Symbol = token( 'Symbol', P'@' * (1 - Blank)^1 )

local Digit = R'09'

local Decimal = Digit ^ 1
local Hexadecimal = P '0' * S 'xX' * R('09', 'AF', 'af') ^ 1
local Float = (Digit^1 * P'.' * Digit^1 + Digit^1) *
                     (S'eE' * S'-+'^-1 * Digit^1)^-1
local Number = token('Number', Hexadecimal + Float + Decimal)

--local Comment = token('Comment', P'--' * (1 - P'\n') ^ 0 )
local Comment = P'--' * (1 - P'\n') ^ 0 * Space -- not captured

local AnyToken = Comment + Specials + Symbol + Name +
	ClassName + Number

lex = function(s)
	return Ct( Space * AnyToken^0 * -1 ):match(s)
end
