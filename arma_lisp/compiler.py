import copy

from .types import is_builtin
from .model_patterns import FORM, whole, times
from .utils import mangle, pairwise
from .models import *
from funcparserlib.parser import many, oneplus, maybe, NoParseError

NEWLINE = '\n'
INDENT = '\t'

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
    def __init__(self, pretty=False):
        self.pretty = pretty
        self._seperator = NEWLINE if pretty else ' '

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
    def compile_def_expression(self, expr, root, name: str, value):
        name = self.compile_if_not_str(name)
        name = name if name.startswith("_") else "_" + name
        value = self.compile_if_not_str(value)

        return f"private {name} = {value}"

    @special("defglobal", [FORM, FORM])
    def compile_defglobal_expression(self, expr, root, name, value):
        name = self.compile_if_not_str(name)
        name = name.lstrip("_")
        value = self.compile_if_not_str(value)

        return f"{name} = {value}"

    def _compile_implicit_do(self, body,):
        expr = SQFExpression([SQFSymbol("do")] + body)
        root = SQFSymbol("do")
        return self.compile_do_expression(expr, root, body,)

    @special("fn", [FORM, many(FORM)])
    def compile_fn_expression(self, expr, root, args, body):
        if not isinstance(args, SQFList):
            raise SyntaxError("args must be a list")

        sargs = map(self.compile_if_not_str, args)
        sargs = ", ".join(f'"{arg}"' for arg in args)

        buffer = []
        buffer += ["{"]
        buffer += [f"params [{sargs}];"]
        buffer += [self._compile_implicit_do(body)]
        buffer += ["}"]

        return self._seperator.join(buffer)

    @special("do", [many(FORM)])
    def compile_do_expression(self, expr, root, body,):
        return f"; {self._seperator}".join(self.compile(expression) for expression in body)

    @special("if", [FORM, FORM, maybe(FORM)])
    def compile_if(self, expr, root, cond, body, else_expr):
        cond = self.compile(cond)
        body = self.compile(body)
        else_expr = self.compile(else_expr) if else_expr else None

        buff = [f"if ({cond}) then", "{", f"{body}", f"}}{'' if else_expr else ';'}"]
        if else_expr:
            buff += ["else {", f"{else_expr}", "}"]
        return self._seperator.join(buff)

    @special("for", [FORM, many(FORM)])
    def compile_for_expression(self, expr, root, cond, body):
        if not isinstance(cond, SQFList):
            raise SyntaxError("condition must be a list")

        if len(cond) not in range(3, 4 + 1):
            raise SyntaxError(f"for takes 3 to 4 arguments. {len(cond)} given")

        cond = [self.compile_if_not_str(val) for val in cond]

        iterator = mangle(cond[0])
        start = cond[1]
        end = cond[2]
        step = cond[3] if len(cond) == 4 else None

        body = self._compile_implicit_do(body)

        buffer = []
        buffer += [
            f"for \"{iterator}\" from {start} to {end} {f'step {step} ' if step else ''}do"
        ]
        buffer += []
        buffer += ["{", body, "}"]

        return self._seperator.join(buffer)

    @special("while", [FORM, many(FORM)])
    def compile_while_expression(self, expr, root, cond, body):
        if not isinstance(cond, SQFExpression):
            raise SyntaxError("while condition must be an expression")

        cond = self.compile_if_not_str(cond)
        body = self._compile_implicit_do(body)

        buffer = [f"while {{{cond}}} do"]
        buffer += ["{", body, "}"]

        return self._seperator.join(buffer)

    @special("doseq", [FORM, many(FORM)])
    def compile_doseq_expression(self, expr, root, initializer, body):

        if not isinstance(initializer, SQFList):
            raise SyntaxError("initializer must be a list")

        if len(initializer) != 2:
            raise SyntaxError(
                "initializer must contain only the binding name and the sequence"
            )

        binding, seq = initializer
        binding = self.compile_if_not_str(binding)
        binding_expr = SQFExpression(
            [SQFSymbol("def"), SQFSymbol(binding), SQFSymbol("_x")]
        )
        seq = self.compile_if_not_str(seq)
        body = self._compile_implicit_do([binding_expr] + body)

        buffer = ["{", body, "}"]
        buffer += [f"forEach {seq}"]

        return self._seperator.join(buffer)

    @builds_model(SQFString)
    def compile_string(self, string):
        return f'"{string}"'

    @builds_model(SQFSymbol)
    def compile_symbol(self, symbol):
        return mangle(symbol)

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
        if is_builtin(sroot):
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
