# -*- coding: utf-8 -*-

"""Console script for sqisp."""
import sys
import click
import time
import logging
import importlib.resources
import hy

from os import makedirs
from pathlib import Path
from sqisp import compile
from .formatter import format
from .compiler import SQFASTCompiler
from .bootstrap import stdlib
from .utils import mangle_cfgfunc

from watchdog.observers import Observer
from watchdog.events import PatternMatchingEventHandler

IGNORE_PATTERNS = [r".#"]


def compile_file(pinput, poutput, file, pretty=False, compiler=None):
    if any(ignore in str(file) for ignore in IGNORE_PATTERNS):
        return None
    makedirs(Path(poutput, file).parent, exist_ok=True)
    with open(Path(pinput, file), "r") as fin, open(
        Path(poutput, file.stem + ".sqf"), "w"
    ) as fout:
        text = fin.read()
        text = compile(text, compiler=compiler)
        text = format(text) if pretty else text
        fout.write(text)


def start_watch(input_dir, output_dir, pretty=False):
    logging.basicConfig(format="%(asctime)s - %(message)s", level=logging.INFO)
    logging.info(f"Beginning watch in {input_dir}")
    logging.info(f"Writing files to: {output_dir}")

    def handle_compile_event(event):
        logging.info(f"Building file: {event.src_path}")
        compile_file(input_dir, output_dir, Path(event.src_path), pretty=pretty)

    patterns = ["*.sqp"]
    IGNORE_PATTERNS = [".#*"]
    sqp_event_handler = PatternMatchingEventHandler(
        patterns, IGNORE_PATTERNS, ignore_directories=True
    )
    sqp_event_handler.on_modified = handle_compile_event
    sqp_event_handler.on_created = handle_compile_event

    observer = Observer()
    observer.schedule(sqp_event_handler, str(input_dir), recursive=True)
    observer.start()
    try:
        while True:
            time.sleep(1)
    except KeyboardInterrupt:
        observer.stop()
    observer.join()

DESCRIPTION_TEMPLATE = '''
class CfgFunctions
{{
	class sqisp
	{{
		class stdlib
		{{
			{}
		}};
	}};
}};
'''

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
@click.option(
    "-w", "--watch", is_flag=True, help="Automatically recompile modified files."
)
@click.option(
    "-n", "--no-stdlib", is_flag=True, help="If set, won't compile the stdlib.")
def main(input, output, pretty=False, watch=False, no_stdlib=False):
    """Console script for sqisp."""

    pinput = Path(input)
    poutput = Path(output if output else ".")

    if not no_stdlib:
        paths = [Path(path)
                 for path in importlib.resources.contents(stdlib)
                 if ".sqp" in path]
        compiler = SQFASTCompiler()
        cfgfuncs = []
        for path in paths:
            text = compile(importlib.resources.read_text(stdlib, path),
                           compiler=compiler)
            mangled_name = mangle_cfgfunc(path.stem, qualified=False)
            out_path = Path(poutput, "stdlib", mangled_name + ".sqf")
            out_path.parent.mkdir(parents=True, exist_ok=True)
            out_path.write_text(text)

            cfgfuncs.append(f'class {mangled_name} {{file = "stdlib\{out_path.name}"}}')
        description_ext = DESCRIPTION_TEMPLATE.format(
            ("\n" + " " * 24).join(cfgfuncs))
        Path(poutput, "description.ext").write_text(description_ext)

    if pinput.is_dir():
        if poutput.suffix:
            raise ValueError("input and output paths must both be directories.")

        sqp_files = pinput.rglob("*.sqp")
        compiler = SQFASTCompiler(pretty=pretty)
        for file in sqp_files:
            compile_file(pinput, poutput, file, pretty=pretty, compiler=compiler)
        if watch:
            return start_watch(pinput, poutput, pretty=pretty)
    else:
        with open(pinput, 'r') as fin:
            text = fin.read()
            text = compile(text)
            text = format(text) if pretty else text

        if poutput:
            if poutput.suffix:
                with open(poutput, 'w') as f:
                    f.write(text)
            else:
                out_path = Path(poutput, pinput.stem + ".sqf")
                makedirs(out_path.parent, exist_ok=True)
                with open(out_path, 'w') as f:
                    f.write(text)
        else:
            click.echo(text)



    # with open(path, "r") as f:
    #     sqisp_text = f.read()

    # compiled_sqf = compile(sqisp_text)

    # if pretty:
    #     compiled_sqf = format(compiled_sqf)

    # if output:
    #     with open(output, "w") as f:
    #         f.write(compiled_sqf)
    # else:
    #     click.echo(compiled_sqf)
    return 0


if __name__ == "__main__":
    sys.exit(main())  # pragma: no cover
