from .types import load_types
from .lexer import lexer
from .models import SQFExpression, SQFSymbol
from .parser import parser, ParserState
from .compiler import SQFASTCompiler


def compile(text):
    load_types("types")
    tokens = parser.parse(lexer.lex(text.replace(",", "")), state=ParserState())
    ast = SQFExpression([SQFSymbol("do")] + tokens)

    compiler = SQFASTCompiler()
    compiled_sqf = compiler.compile(ast)
    return compiled_sqf
