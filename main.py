import copy
import my_lang.types as types

from pprint import pprint
from my_lang.lexer import lexer
from my_lang.models import *
from my_lang.parser import parser, ParserState
from funcparserlib.parser import (
    some,
    skip,
    many,
    oneplus,
    maybe,
    finished,
    Parser,
    NoParseError,
    State,
)
from functools import reduce
from operator import add
from itertools import tee
from math import isinf




def pairwise(iterable):
    "s -> (s0,s1), (s1,s2), (s2, s3), ..."
    a, b = tee(iterable)
    next(b, None)
    return zip(a, b)


types.load_types('types')

text = """
(= "hello" (if true "hello" "world"))
(def some_num (+ 2 -5 (/ 2.4 30 3.3) (- 20 33)))

(select (count (allUnits)) 2)

(def some_arr [1 2 3 4 5 6])
(if (or (>= some_num 223) (= (% some_num 2) 0))
    (str some_num)
    (if true "Hello" "World"))


(def my_val ( my_func "hello" "world" 24.3 ))

(fn [a b c] (hint (str [a b c])))

"""

tokens = parser.parse(lexer.lex(text), state=ParserState())
ast = SQFExpression([SQFSymbol("do")] + tokens)

FORM = some(lambda _: True)


def whole(parsers):
    """Parse the parsers in the given list one after another, then
    expect the end of the input."""
    if len(parsers) == 0:
        return finished >> (lambda x: [])
    if len(parsers) == 1:
        return parsers[0] + finished >> (lambda x: x[:-1])
    return reduce(add, parsers) + skip(finished)


def times(lo, hi, parser):
    """Parse `parser` several times (`lo` to `hi`) in a row. `hi` can be
    float('inf'). The result is a list no matter the number of instances."""

    @Parser
    def f(tokens, s):
        result = []
        for _ in range(lo):
            (v, s) = parser.run(tokens, s)
            result.append(v)
        end = s.max
        try:
            for _ in repeat(1) if isinf(hi) else range(hi - lo):
                (v, s) = parser.run(tokens, s)
                result.append(v)
        except NoParseError as e:
            end = e.state.max
        return result, State(s.pos, end)

    return f


_model_compilers = {}
_special_form_compilers = {}
_operator_lookup = {
    "=": "==",
    "and": "&&",
    "or": "||",
    ">": ">",
    ">=": ">=",
    "<=": "<=",
    "<": "<",
    "%": "%",
}


def special(names, pattern):
    """Declare special operators. The decorated method and the given pattern
    is assigned to _special_form_compilers for each of the listed names."""
    pattern = whole(pattern)

    def dec(fn):
        for name in names if isinstance(names, list) else [names]:
            _special_form_compilers[str(name)] = (fn, pattern)
        return fn

    return dec


def builds_model(*model_types):
    def _dec(fn):
        for t in model_types:
            _model_compilers[t] = fn
        return fn

    return _dec


class SQFASTCompiler(object):
    def __init__(self,):
        self.buffer = ""

    def compile_if_not_str(self, value):
        # return value if isinstance(value, str) else self.compile(value)
        return value if type(value) is str else self.compile(value)

    def compile_atom(self, atom):
        atom = copy.copy(atom)
        return _model_compilers[type(atom)](self, atom)

    def compile(self, tree):
        if tree is None:
            return None

        return self.compile_atom(tree)

    @special("+", [many(FORM)])
    @special("/", [many(FORM)])
    @special("*", [many(FORM)])
    @special("-", [many(FORM)])
    def compile_math_expression(self, expr, root, args):
        sroot = str(root)
        sargs = [self.compile_if_not_str(arg) for arg in args]
        buff = f" {sroot} ".join(sargs)
        return f"({buff})"

    @special(["and", "or"], [many(FORM)])
    def compile_and_or_expression(self, expr, root, args):
        sroot = self.compile_if_not_str(root)
        sroot = _operator_lookup[sroot]
        args = [self.compile_if_not_str(arg) for arg in args]

        if len(args) == 0:
            return "true"
        elif len(args) == 1:
            return args[0]
        else:
            return f" {sroot} ".join(args)

    @special(["=", "<", "<=", ">", ">="], [oneplus(FORM)])
    @special("!=", [times(2, float("inf"), FORM)])
    @special("%", [times(2, 2, FORM)])
    def compile_math_expression(self, expr, root, args):
        sroot = self.compile_if_not_str(root)
        sroot = _operator_lookup[sroot]
        sargs = [self.compile_if_not_str(arg) for arg in args]

        if len(sargs) == 1:
            return "true"

        buff = []
        for left, right in pairwise(sargs):
            left = self.compile_if_not_str(left)
            right = self.compile_if_not_str(right)
            buff += [f"({left} {sroot} {right})"]
        return " && ".join(buff)

    @special("def", [FORM, FORM])
    def compile_def_expression(self, expr, root, name, value):
        name = self.compile_if_not_str(name)
        value = self.compile_if_not_str(value)

        return f"{name} = {value}"

    @special("fn", [FORM, many(FORM)])
    def compile_fn_expression(self, expr, root, args, body):
        if not isinstance(args, SQFList):
            raise SyntaxError("args must be a list")

        sargs = map(self.compile_if_not_str, args)
        sargs = ' '.join(f'"{arg}"' for arg in args)

        buffer = []
        buffer += [ "{" ]
        buffer += [ f"params [{sargs}];" ]
        buffer += [self.compile_if_not_str(expression) for expression in body]
        buffer += ["}"]
        
        # buffer += [self.compile_if_not_str(body)]


        return " ".join(buffer)

    @special("do", [many(FORM)])
    def compile_do_expression(self, expr, root, body):
        return "\n".join(map(self.compile, body))

    # @special("str", [FORM])
    # def compile_str_expression(self, expr, root, args):
    #     return f"{root} {self.compile(args)}"

    @special("if", [FORM, FORM, maybe(FORM)])
    def compile_if(self, expr, root, cond, body, else_expr):
        cond = self.compile(cond)
        body = self.compile(body)
        else_expr = self.compile(else_expr) if else_expr else None

        buff = [f"if ({cond}) then", "{", f"\t{body}", f"}}{'' if else_expr else ';'}"]
        if else_expr:
            buff += ["else {", f"\t{else_expr}", "}"]
        return " ".join(buff)

    @builds_model(SQFString)
    def compile_string(self, string):
        return f'"{string}"'

    @builds_model(SQFSymbol)
    def compile_symbol(self, symbol):
        return str(symbol)

    @builds_model(SQFList)
    def compile_list(self, lst):
        return f"[{', '.join(map(self.compile, lst))}]"

    @builds_model(SQFInteger)
    @builds_model(SQFFloat)
    def compile_integer(self, integer):
        return str(integer)

    def compile_function_call(self, root, args):
        sroot = self.compile_if_not_str(root)
        sargs = [self.compile_if_not_str(arg) for arg in args]
        if types.is_builtin(sroot):
            if len(args) == 0:
                return sroot
            elif len(args) == 1:
                return f"( {sroot} {sargs[0]} )"
            elif len(args) == 2:
                return f"( {sargs[0]} {sroot} {sargs[1]} )"
        else:
            return f"[{', '.join(sargs)}] call {sroot}"

    @builds_model(SQFExpression)
    def compile_expression(self, expr):
        if not expr:
            raise SyntaxError("empty expression")

        root, *args = list(expr)
        func = None
        if isinstance(root, SQFSymbol):
            sroot = str(root)
            if sroot in _special_form_compilers:
                build_method, pattern = _special_form_compilers[sroot]
                try:
                    parse_tree = pattern.parse(args)
                except NoParseError as e:
                    raise SyntaxError("Parse error for form")
                return build_method(self, expr, sroot, *parse_tree)
            else:
                return self.compile_function_call(sroot, args)


compiler = SQFASTCompiler()
compiled_sqf = compiler.compile(ast)

print("Input LispSQF:", '"""', text.strip(), '"""', sep="\n")
print()
print("Compiled SQF:", '"""', compiled_sqf, '"""', sep="\n")


with open("test.sqf", "w") as f:
    f.write(compiled_sqf)

