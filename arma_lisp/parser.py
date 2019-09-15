from .lexer import lexer
from .models import (
    SQFExpression,
    SQFList,
    SQFObject,
    SQFSequence,
    SQFString,
    SQFSymbol,
    SQFInteger,
    SQFFloat,
)
from rply import ParserGenerator


pg = ParserGenerator([rule.name for rule in lexer.rules] + ["$end"])


@pg.production("main : list_contents")
def main(state, p):
    return p[0]


@pg.production("main : $end")
def main_empty(state, p):
    return []


@pg.production("paren : LPAREN list_contents RPAREN")
def paren(state, p):
    return SQFExpression(p[1])


@pg.production("paren : LPAREN RPAREN")
def empty_paren(state, p):
    return SQFExpression([])


@pg.production("list_contents : term list_contents")
def list_contents(state, p):
    return [p[0]] + p[1]


@pg.production("list_contents : term")
def list_contents_single(state, p):
    return [p[0]]


@pg.production("term : identifier")
@pg.production("term : paren")
@pg.production("term : list")
@pg.production("term : string")
def term(state, p):
    return p[0]


@pg.production("list : LBRACKET list_contents RBRACKET")
def t_list(state, p):
    return SQFList(p[1])


@pg.production("list : LBRACKET RBRACKET")
def t_empty_list(state, p):
    return SQFList([])


@pg.production("string : STRING")
def t_string(state, p):
    s = p[0].value
    # Detect and remove any "f" prefix.
    is_format = False
    if s.startswith("f") or s.startswith("rf"):
        is_format = True
        s = s.replace("f", "", 1)
    # Replace the single double quotes with triple double quotes to allow
    # embedded newlines.
    try:
        s = eval(s.replace('"', '"""', 1)[:-1] + '"""')
    except SyntaxError:
        raise LexException.from_lexer(
            "Can't convert {} to a HyString".format(p[0].value), state, p[0]
        )
    return SQFString(s)
    # return HyString(s, is_format=is_format) if isinstance(s, str) else HyBytes(s)


def symbol_like(obj):
    try:
        return SQFInteger(obj)
    except ValueError:
        pass

    try:
        return SQFFloat(obj)
    except ValueError:
        pass

    return None


@pg.production("identifier : IDENTIFIER")
def t_identifier(state, p):
    obj = p[0].value

    val = symbol_like(obj)
    if val is not None:
        return val
    return SQFSymbol(p[0].value)


class ParserState(object):
    def __init__(self):
        pass


parser = pg.build()
