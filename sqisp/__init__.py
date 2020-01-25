# -*- coding: utf-8 -*-

"""Top-level package for Arma Lisp."""

__author__ = """Steve Casey"""
__email__ = 'stevecasey21@gmail.com'
__version__ = '__version__ = "0.7.5"'

import hy
from .types import load_types
from .lexer import lexer
from .models import SQFExpression, SQFSymbol
from .parser import parser, ParserState
from .compiler import SQFASTCompiler


def compile(text, pretty=False):
    load_types("types")
    tokens = parser.parse(lexer.lex(text.replace(",", "")), state=ParserState())
    ast = SQFExpression([SQFSymbol("do")] + tokens)

    compiler = SQFASTCompiler(pretty=pretty)
    compiled_sqf = compiler.compile_root(ast)
    return compiled_sqf
