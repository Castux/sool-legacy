--[[

Each rule table is a list of
- terminal string
- non terminal string (the name will be expected in the grammar table)
- rule table

Every rule is a sequence by default. Following modifiers change the behavior:

repetition = true: will try to parse the sequence as many times as possible. { sequence }
separator = terminal/rule: (valid only with repetition) will parse the separator before each occurence other than the first. [ sequence { separator sequence } ]
min = number: (valid only with repetition) will require at least min occurences of the sequence to succeed (default is 0)
max = number: (valid only with repetition) will require at most max occurences of the sequence to succeed (default is infinite)

optional = true: will not fail if the first token does not match. Will fail if the first token matches and a subsequent error occurs. [ sequence ]

choice = true: the list of subrules is not interpreted as a sequence but as a choice. One and only one subrule must and will match. ( subrule1 | subrule2 | subrule3 )

The modifiers are combinable. The only useless (but still valid) combination is optional + repetition with min = 0.

The 'name' field can be filled with a human readable description of the rule, used in verbose error messages

The Nova thingy will read in this grammar, validate it as LL(1), and allow parsing a list of tokens using it, producing a concrete syntax tree (= "parse tree").

Verifications of First/Follow conflicts should work even with following rules and sub/rules that can generate the empty string.
One thing that is not complely clear is when dealing with repetitions that have separators and/or main sequences that generate them.

]]

g = {}

g.chunk = {
    name = 'chunk',
    repetition = true,
    'class_def'
}

g.class_def = {
    name = 'class definition',
    'class',
    'ClassName',
    {
        name = 'parent class',
        optional = true,
        ':', 'ClassName'
    },
    {
        repetition = true,
        choice = true,
        'member_def',
        'method_def'
    },
    'end'
}

g.member_def = {
    name = 'member definition',
    {
        optional = true,
        'private'
    },
    'type',
    'Name'
}

g.method_def = {
    name = 'method definition',
    'meth',
    {
        optional = true,
        'private'
    },
    {
        repetition = true,
        separator = ',',
        'type'
    },
    {
        choice = true,
        {
            'Name',
            { optional = true, '=' }
        },
        'Binop'
    },
    '(',
    {
        repetition = true,
        separator = ',',
        'type',
        'Name'
    },
    ')',
    'block',
    'end'
}

g.type = {
    name = 'type declaration',
    choice = true,
    'num', 'vec', 'sym',
    {
        { optional = true, 'own' },
        {
            choice = true,
            'str',
            'ClassName',
            { '[', 'type', ']' },
            { '/', 'type', '/' },
            { '{', 'type', ',', 'type', '}' }
        }
    }
}

g.block = {
    name = 'block',
    {
        repetition = true,
        'statement',
        { optional = true, ';' }
    },
    {
        choice = true,
        optional = true,
        'break',
        'continue',
        { 'return', { name = 'return values', optional = true, 'list_exp' } }
    }
}

g.statement = {
    name = 'statement',
    choice = true,
    { name = 'do block', 'do', 'block', 'end' },
    { name = 'while loop', 'while', 'exp', { name = 'local name for condition', optional = true, 'as', 'Name' }, 'do', 'block', 'end' },
    { name = 'if construct', 'if', 'exp', { name = 'local name for condition', optional = true, 'as', 'Name' }, 'then', 'block',
        { repetition = true, 'elseif', 'exp', 'then', 'block' },
        { optional = true, 'else', 'block' },
        'end' },
    { name = 'for loop', 'for', 'list_name', 'in', 'list_exp', 'do', 'block', 'end' },
    { { choice = true, 'method_call', 'atomic_exp' }, 'exp_tail' },
    'assignment'
}

g.list_name = {
    name = 'list of names',
    repetition = true,
    separator = ',',
    min = 1,
    'Name'
}

g.atomic_exp = {
    name = 'atomic expression',
    choice = true,
    'Number', 'String', 'nil', 'false', 'true', 'Symbol'
}

g.constructor = {
    name = 'constructor',
    choice = true,
    { '[', { optional = true, 'list_operand' }, ']' },
    { '/', { optional = true, 'list_operand' }, '\\' },
    { '<', { optional = true, 'list_operand' }, '>' },
    { 'ClassName', { optional = true, 'call_arguments' } },
}

g.method_call = {
    name = 'method call',
    'Name',
    { optional = true, 'call_arguments' }
}

g.list_method_call = {
    name = 'list of method calls',
    repetition = true,
    separator = ',',
    min = 1,
    'method_call'
}

g.call_arguments = {
    name = 'argument list',
    '(',
    { optional = true, 'list_exp' },
    ')'
}

g.basic_exp = {
    name = 'basic expression',
    {
        choice = true,
        'atomic_exp',
        { '(', 'exp', ')' },
        'constructor',
        'method_call'
    },
    'exp_tail'
}

g.exp_tail = {
    name = 'basic expression tail',
    repetition = true,
    choice = true,
    { '.', 'method_call' },
    { '[', 'exp', ']' }
}

g.unary_operation = {
    name = 'unary operation',
    { choice = true, '-', '#', 'not' },
    'operand'
}

g.operand = {
    name = 'operand',
    choice = true,
    'basic_exp',
    'unary_operation'
}

g.list_operand = {
    name = 'list of operands',
    repetition = true,
    separator = ',',
    min = 1,
    'operand'
}

g.exp = {
    name = 'expression',
    repetition = true,
    separator = 'binop',
    min = 1,
    'operand'
}

g.binop = {
    name = 'binary operator',
    choice = true,
    '+', '-', '*', '/', '<', '>', '<=', '>='
}

g.list_exp = {
    name = 'list of expressions',
    repetition = true,
    separator = ',',
    min = 1,
    'exp'
}

g.unified_assignment_call = {
    name = 'unified assignment and method call',
    'list_method_call',
    '=',
    'list_exp'
}

require 'nova'

print(nova.validate_grammar(g))

