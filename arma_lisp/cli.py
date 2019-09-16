# -*- coding: utf-8 -*-

"""Console script for arma_lisp."""
import sys
import click
import os
import pathlib

from arma_lisp import compile


@click.command()
@click.argument('input', type=click.Path(exists=True))
def main(input, args=None):
    """Console script for arma_lisp."""

    path = pathlib.PurePath(input)
    parent = path.parent
    name = path.stem

    out_path = pathlib.PurePath(parent, name + '.sqf')

    with open(path, 'r') as f:
        sqisp_text = f.read()

    try:
        compiled_sqf = compile(sqisp_text)
    except Exception as e:
        click.echo(e.message, err=True)

    with open(out_path, 'w') as f:
        f.write(compiled_sqf)
    return 0


if __name__ == "__main__":
    sys.exit(main())  # pragma: no cover
