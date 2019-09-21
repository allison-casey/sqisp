import copy

from .types import is_builtin
from .model_patterns import FORM, whole, times
from .utils import mangle, pairwise
from .models import *
from funcparserlib.parser import many, oneplus, maybe, NoParseError
from collections import defaultdict
from anytree import Walker, Node, RenderTree, AsciiStyle

NEWLINE = "\n"
INDENT = "\t"

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


class SymbolTable(object):
    def __init__(self):
        self.global_scope = Node({})
        self._walker = Walker()

    def scope_from(self, scope):
        child_scope = Node({}, parent=scope)
        return child_scope

    def lookup(self, scope, value):
        while True:
            if value in scope.name:
                return scope.name[value]
            if scope.parent:
                scope = scope.parent
            else:
                return None

    def insert(self, scope, key, value):
        scope.name[key] = value


# mysymboltable = SymbolTable()
# myscope = mysymboltable.global_scope
# print(myscope.parent)
# childscope = mysymboltable.scope_from(myscope)
# childscope.name['something'] = 'else'
# print(mysymboltable.lookup(childscope, 'not in the scope'))


class SQFASTCompiler(object):
    def __init__(self, pretty=False):
        self.pretty = pretty
        self._seperator = NEWLINE if pretty else " "
        self.symbol_table = SymbolTable()

    def compile_if_not_str(self, scope, value):
        # return value if isinstance(value, str) else self.compile(value)
        return value if type(value) is str else self.compile(value, scope)

    def compile_atom(self, atom, scope):
        atom = copy.copy(atom)
        return _model_compilers[type(atom)](self, scope, atom)

    def compile_root(self, tree):
        scope = self.symbol_table.global_scope
        text = self.compile(tree, scope)

        # print(RenderTree(self.symbol_table.global_scope, style=AsciiStyle()))

        return text

    def compile(self, tree, scope):
        if tree is None:
            return None
        output = self.compile_atom(tree, scope)
        return output

    def _compile_implicit_do(self, scope, body):
        expr = SQFExpression([SQFSymbol("do")] + body)
        root = SQFSymbol("do")
        return self.compile_do_expression(scope, expr, root, body)

    def _mangle_private(self, scope, name):
        pname = self.compile_if_not_str(scope, name)
        pname = pname if pname.startswith("_") else "_" + pname
        return pname

    def _mangle_global(self, scope, name):
        gname = self.compile_if_not_str(scope, name)
        gname = gname.lstrip("_")
        return gname

    # def _mangle_binding(self, scope, name):
    #     # if name in self.global_symbols:
    #     #     return self._mangle_global(scope, name)
    #     if False:
    #         pass
    #     else:
    #         return self._mangle_private(scope, name)

    def compile_function_call(self, scope, root, args):
        sroot = self.compile_if_not_str(scope, root)
        # sargs = [
        #     self._mangle_binding(scope, arg) if isinstance(arg, SQFSymbol) else arg
        #     for arg in args
        # ]
        sargs = [self.compile_if_not_str(scope, arg) for arg in args]
        if is_builtin(sroot):
            if len(args) == 0:
                return sroot
            elif len(args) == 1:
                return f"( {sroot} {sargs[0]} )"
            elif len(args) == 2:
                return f"( {sargs[0]} {sroot} {sargs[1]} )"
        else:
            binding = self.symbol_table.lookup(scope, root)
            if not binding:
                raise SyntaxError(f'function {root} referenced before assignment.')
            return f"[{', '.join(sargs)}] call {binding}"

    @special("+", [many(FORM)])
    @special("/", [many(FORM)])
    @special("*", [many(FORM)])
    @special("-", [many(FORM)])
    def compile_math_expression(self, scope, expr, root, args):
        sroot = str(root)
        sargs = [self.compile_if_not_str(scope, arg) for arg in args]
        buff = f" {sroot} ".join(sargs)
        return f"({buff})"

    @special(["and", "or"], [many(FORM)])
    def compile_and_or_expression(self, scope, expr, root, args):
        sroot = self.compile_if_not_str(scope, root)
        sroot = _operator_lookup[sroot]
        args = [self.compile_if_not_str(scope, arg) for arg in args]

        if len(args) == 0:
            return "true"
        elif len(args) == 1:
            return args[0]
        else:
            return f" {sroot} ".join(args)

    @special(["=", "<", "<=", ">", ">="], [oneplus(FORM)])
    @special("!=", [times(2, float("inf"), FORM)])
    @special("%", [times(2, 2, FORM)])
    def compile_math_expression(self, scope, expr, root, args):
        sroot = self.compile_if_not_str(scope, root)
        sroot = _operator_lookup[sroot]
        sargs = [self.compile_if_not_str(scope, arg) for arg in args]

        if len(sargs) == 1:
            return "true"

        buff = []
        for left, right in pairwise(sargs):
            left = self.compile_if_not_str(scope, left)
            right = self.compile_if_not_str(scope, right)
            buff += [f"({left} {sroot} {right})"]
        return " && ".join(buff)

    @special("def", [FORM, FORM])
    def compile_def_expression(self, scope, expr, root, name: str, value):
        # if name in self.global_symbols:
        # raise SyntaxError("Attempting to shadow global name with private name.")

        # pname = self.compile_if_not_str(scope, name)
        # pname = pname if pname.startswith("_") else "_" + pname
        pname = self._mangle_private(scope, name)
        value = self.compile_if_not_str(scope, value)

        self.symbol_table.insert(scope, name, pname)

        return f"private {pname} = {value}"

    @special("defglobal", [FORM, FORM])
    def compile_defglobal_expression(self, scope, expr, root, name, value):
        value = self.compile_if_not_str(scope, value)
        gname = self._mangle_global(scope, name)
        # gname = self.compile_if_not_str(scope, name)

        # self.global_symbols[name] = gname
        self.symbol_table.insert(scope, name, gname)

        return f"{gname} = {value}"

    @special("setv", [FORM, FORM])
    def compile_setv_expression(self, scope, expr, root, name, value):
        binding = self.symbol_table.lookup(scope, name)
        if not binding:
            raise SyntaxError(f"Binding {name} referenced before assignment")

        # if name in self.global_symbols:
        #     mangled_name = self.global_symbols[name]
        # else:
        #     mangled_name = self._mangle_private(scope, name)

        value = self.compile_if_not_str(scope, value)

        return f"{binding} = {value}"

    @special("fn", [FORM, many(FORM)])
    def compile_fn_expression(self, scope, expr, root, args, body):
        if not isinstance(args, SQFList):
            raise SyntaxError("args must be a list")

        # sargs = [self.compile_if_not_str(scope, arg) for arg in args]
        new_scope = self.symbol_table.scope_from(scope)

        sargs = [self._mangle_private(new_scope, sarg) for sarg in args]
        for name, mname in zip(args, sargs):
            self.symbol_table.insert(new_scope, name, mname)

        sargs = ", ".join(f'"{arg}"' for arg in sargs)
        params = [f"params [{sargs}]"] if args else []

        buffer = []
        buffer += ["{"]
        buffer += [self._compile_implicit_do(new_scope, params + body)]
        buffer += ["}"]

        return self._seperator.join(buffer)

    @special("do", [many(FORM)])
    def compile_do_expression(self, scope, expr, root, body):
        return f"; {self._seperator}".join(
            self.compile_if_not_str(scope, expression) for expression in body
        )

    @special("if", [FORM, FORM, maybe(FORM)])
    def compile_if_expression(self, scope, expr, root, cond, body, else_expr):
        cond = self.compile_if_not_str(scope, cond)

        if_scope = self.symbol_table.scope_from(scope)
        else_scope = self.symbol_table.scope_from(scope)
        body = self.compile_if_not_str(if_scope, body)
        else_expr = (
            self.compile_if_not_str(else_scope, else_expr) if else_expr else None
        )

        buff = [f"if ({cond}) then", "{", f"{body}", f"}}{'' if else_expr else ';'}"]
        if else_expr:
            buff += ["else", "{", f"{else_expr}", "}"]
        return self._seperator.join(buff)

    @special("for", [FORM, many(FORM)])
    def compile_for_expression(self, scope, expr, root, cond, body):
        if not isinstance(cond, SQFList):
            raise SyntaxError("condition must be a list")

        if len(cond) not in range(3, 4 + 1):
            raise SyntaxError(f"for takes 3 to 4 arguments. {len(cond)} given")

        new_scope = self.symbol_table.scope_from(scope)

        cond = [self.compile_if_not_str(scope, val) for val in cond]

        iterator = self._mangle_private(new_scope, cond[0])
        self.symbol_table.insert(new_scope, cond[0], iterator)

        start = cond[1]
        end = cond[2]
        step = cond[3] if len(cond) == 4 else None

        body = self._compile_implicit_do(new_scope, body)

        buffer = []
        buffer += [
            f"for \"{iterator}\" from {start} to {end} {f'step {step} ' if step else ''}do"
        ]
        buffer += []
        buffer += ["{", body, "}"]

        return self._seperator.join(buffer)

    @special("while", [FORM, many(FORM)])
    def compile_while_expression(self, scope, expr, root, cond, body):
        if not isinstance(cond, SQFExpression):
            raise SyntaxError("while condition must be an expression")

        cond = self.compile_if_not_str(scope, cond)

        new_scope = self.symbol_table.scope_from(scope)
        body = self._compile_implicit_do(new_scope, body)

        buffer = [f"while {{{cond}}} do"]
        buffer += ["{", body, "}"]

        return self._seperator.join(buffer)

    @special("doseq", [FORM, many(FORM)])
    def compile_doseq_expression(self, scope, expr, root, initializer, body):

        if not isinstance(initializer, SQFList):
            raise SyntaxError("initializer must be a list")

        if len(initializer) != 2:
            raise SyntaxError(
                "initializer must contain only the binding name and the sequence"
            )

        new_scope = self.symbol_table.scope_from(scope)

        binding, seq = initializer
        binding = self.compile_if_not_str(scope, binding)
        self.symbol_table.insert(new_scope, initializer[0], binding)

        binding_expr = SQFExpression(
            [SQFSymbol("def"), SQFSymbol(binding), SQFSymbol("_x")]
        )
        seq = self.compile_if_not_str(new_scope, seq)
        body = self._compile_implicit_do(new_scope, [binding_expr] + body)

        buffer = ["{", body, "}"]
        buffer += [f"forEach {seq}"]

        return self._seperator.join(buffer)

    @builds_model(SQFString)
    def compile_string(self, scope, string):
        return f'"{string}"'

    @builds_model(SQFSymbol)
    def compile_symbol(self, scope, symbol):
        lookup = self.symbol_table.lookup(scope, symbol)
        if lookup:
            return lookup
        else:
            return mangle(symbol)

    @builds_model(SQFList)
    def compile_list(self, scope, lst):
        # return f"[{', '.join(map(self.compile, lst))}]"
        return f"[{', '.join(self.compile(x, scope) for x in lst)}]"

    @builds_model(SQFInteger)
    @builds_model(SQFFloat)
    def compile_integer(self, scope, integer):
        return str(integer)

    @builds_model(SQFExpression)
    def compile_expression(self, scope, expr):
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
                return build_method(self, scope, expr, sroot, *parse_tree)
            else:
                return self.compile_function_call(scope, sroot, args)
