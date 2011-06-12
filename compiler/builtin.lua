
-- Non compound classes are pretty simple, just make one global object
-- for each, with manually filled methods (or use nova)

-- Number

Number = Class()

Number.name = 'num'
Number.builtin = true

-- Vector

Vector = Class()

Vector.name = 'vec'
Vector.builtin = true

-- String

String = Class()

String.name = 'num'
String.builtin = true

-- Symbol

Symbol = Class()

Symbol.name = 'num'
Symbol.builtin = true

-- For compound classes there's one more level: they are like templates,
-- we build the class objects as they are requested, by using the
-- sub-type(s), and internizing.
