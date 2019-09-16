import argparse
import os
import io
import sys

def sqisp_main():
    sys.path.insert(0, "")
    sys.exit(cmdline_handler("sqisp", sys.argv))

def cmdline_handler():
    return "hello world"
