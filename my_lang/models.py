class SQFObject(object):
    def __repr__(self):
        return "%s(%s)" % (self.__class__.__name__, super(SQFObject, self).__repr__())


class SQFString(SQFObject, str):
    def __new__(cls, s=None):
        value = super(SQFString, cls).__new__(cls, s)
        return value


class SQFSequence(SQFObject, tuple):
    """
    An abstract type for sequence-like models to inherit from.
    """

    # def replace(self, other, recursive=True):;
    #     if recursive:
    #         for x in self:
    #             replace_hy_obj(x, other)
    #     SQFObject.replace(self, other)
    #     return self

    def __add__(self, other):
        return self.__class__(
            super(SQFSequence, self).__add__(
                tuple(other) if isinstance(other, list) else other
            )
        )

    def __getslice__(self, start, end):
        return self.__class__(super(SQFSequence, self).__getslice__(start, end))

    def __getitem__(self, item):
        ret = super(SQFSequence, self).__getitem__(item)

        if isinstance(item, slice):
            return self.__class__(ret)

        return ret

    def __repr__(self):
        # return str(self) if PRETTY else super(SQFSequence, self).__repr__()
        return str(self)

    # def __str__(self):
    #     return "" +
    # global _hy_colored_ast_objects
    # with pretty():
    #     c = self.color if _hy_colored_ast_objects else str
    #     if self:
    #         return ("{}{}\n  {}{}").format(
    #             c(self.__class__.__name__),
    #             c("(["),
    #             (c(",") + "\n  ").join([repr_indent(e) for e in self]),
    #             c("])"),
    #         )
    #     else:
    #         return "" + c(self.__class__.__name__ + "()")


class SQFExpression(SQFObject, tuple):
    pass


class SQFList(SQFObject, tuple):
    pass


class SQFSymbol(SQFObject, str):
    def __new__(cls, s=None):
        return super(SQFSymbol, cls).__new__(cls, s)


class SQFInteger(SQFObject, int):
    pass


class SQFFloat(SQFObject, float):
    pass
