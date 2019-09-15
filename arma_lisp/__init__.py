import re
import unicodedata

keyword_regex = r"[0-9a-zA-Z_]+"

mangle_delim = "X"


def is_sqf_keyword(s: str):
    return bool(re.fullmatch(keyword_regex, s))


def mangle(s: str):
    def unicode_char_to_hex(uchr):
        if len(uchr) == 1 and ord(uchr) < 128:
            return format(ord(uchr), "x")
        return (
            uchr.encode("unicode-escape")
            .decode("utf-8")
            .lstrip("\\U")
            .lstrip("\\u")
            .lstrip("\\x")
            .lstrip("0")
        )

    assert s

    s = str(s)
    s = s.replace("-", "_")
    s2 = s.lstrip("_")
    leading_underscores = "_" * (len(s) - len(s2))
    s = s2

    if s.endswith("?"):
        s = "is_" + s[:-1]

    # s = 'al_' + ''.join(c if c )

    if not is_sqf_keyword(leading_underscores + s):
        s = "al_" + "".join(
            c
            if is_sqf_keyword(c)
            else "{0}{1}{0}".format(
                mangle_delim,
                unicodedata.name(c, "").lower().replace("-", "L").replace(" ", "_")
                or f"U{unicode_char_to_hex(c)}",
            )
            for c in s
        )

    assert is_sqf_keyword(s)

    return leading_underscores + s


# print(mangle("___λ-hello"))
# print(mangle("even?"))
# print(mangle(":hello"))
