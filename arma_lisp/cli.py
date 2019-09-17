# -*- coding: utf-8 -*-

"""Console script for arma_lisp."""
import sys
import click
import os
import pathlib

from arma_lisp import compile


@click.command()
@click.argument("input", type=click.Path(exists=True))
@click.option(
    "-o",
    "--output",
    type=click.Path(),
    help="Path to output file. Prints to std out otherwise.",
)
@click.option(
    "-p", "--pretty", is_flag=True, help="Pretty prints the the compiled sqf."
)
def main(input, output, pretty):
    """Console script for arma_lisp."""

    path = pathlib.PurePath(input)
    # parent = path.parent
    # name = path.stem

    with open(path, "r") as f:
        sqisp_text = f.read()

    try:
        compiled_sqf = compile(sqisp_text, pretty=pretty)
    except Exception as e:
        click.echo(e.message, err=True)

    if output:
        with open(output, "w") as f:
            f.write(compiled_sqf)
    else:
        click.echo(compiled_sqf)
    return 0


if __name__ == "__main__":
    sys.exit(main())  # pragma: no cover
