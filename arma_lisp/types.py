from pkg_resources import resource_stream, resource_string, resource_listdir

__types = {}


def is_builtin(fn_name: str) -> bool:
    return fn_name.lower() in __types


def load_types(path: str):
    global __types
    resource = resource_string(__name__, '')
    print(resource)
    # with open(path, "r") as f:
    #     for line in f:
    #         fn_type = line[0]
    #         if fn_type == "b":
    #             key, value = parse_binary(line)
    #             __types[key] = value
    #         elif fn_type == "u":
    #             key, value = parse_unary(line)
    #             __types[key] = value
    #         elif fn_type == "n":
    #             key, value = parse_nullary(line)
    #             __types[key] = value


def parse_nullary(line: str):
    fn_name = line[2:].strip()
    return fn_name, dict(type="nullary")


def parse_unary(line: str):
    parts = line[2:].split()

    fn_name = parts[0]
    arg_type = parts[1]
    return fn_name, dict(type="unary", argtype=arg_type)


def parse_binary(line: str):
    parts = line[2:].split()
    left_arg_type, fn_name, right_arg_type = parts

    return (
        fn_name,
        dict(type="binary", left_arg_type=left_arg_type, right_arg_type=right_arg_type),
    )
