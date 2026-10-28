#!/usr/bin/env python3

import datetime
import fcntl
import hashlib
import json
import os
import re
import signal
import socket
import subprocess
import sys
import time
from pathlib import Path
from urllib.parse import quote

import yaml
from rich import box
from rich.console import Console, Group
from rich.panel import Panel
from rich.table import Table
from rich.text import Text


COMPONENTS = {
    "server": "app.kubernetes.io/name=camberfs,app.kubernetes.io/component=server",
    "csi": "app.kubernetes.io/name=camberfs-csi,app.kubernetes.io/component in (controller,node)",
    "mount": "app.kubernetes.io/name=camberfs-csi,app.kubernetes.io/component=mount",
    "db": "app.kubernetes.io/name=camberfs,app.kubernetes.io/component=postgresql",
    "valkey": "app.kubernetes.io/name=camberfs,app.kubernetes.io/component=valkey",
}

TARGET_KINDS = {
    "camberfs": "server",
    "server": "server",
    "s": "server",
    "csi": "csi",
    "c": "csi",
    "mount": "mount",
    "mnt": "mount",
    "m": "mount",
    "db": "db",
    "valkey": "valkey",
    "vk": "valkey",
    "v": "valkey",
}

TARGET_COMMAND_ALIASES = {
    "log": "logs",
    "lg": "logs",
    "l": "logs",
    "ex": "exec",
    "e": "exec",
    "shell": "exec",
    "sh": "exec",
    "g": "gdb",
    "del": "delete",
    "d": "delete",
    "rm": "delete",
    "ls": "pods",
    "list": "pods",
    "ps": "pods",
    "p": "pods",
}

COLOR_BG = "#262626"
COLOR_DARK = "#1e1e1e"
COLOR_PANEL = "#2b2b2b"
COLOR_FG = "#ffcb83"
COLOR_ACCENT = "#fc5e00"
COLOR_TEXT_ACCENT = "#fc874f"
COLOR_LIGHT_ORANGE = "#ffc88a"
COLOR_AMBER = "#f79500"
COLOR_GOLD = "#ffbe55"
COLOR_GREEN = "#a4a900"
COLOR_CORAL = "#ff8c68"
COLOR_SAND = "#c69752"
COLOR_MUTED = "#8c7458"
COLOR_WHITE = "#fafaff"

CONSOLE = Console(highlight=False, style=COLOR_FG)
ERROR_CONSOLE = Console(stderr=True, highlight=False, style=COLOR_CORAL)
LOG_PREFIX = re.compile(r"^\[pod/([^/]+)/([^\]]+)\]\s?(.*)$")
MOUNT_TARGET_UID = re.compile(r"/pods/([^/]+)/")
LOG_BADGES = (
    "38;2;30;30;30;48;2;252;94;0",
    "38;2;30;30;30;48;2;247;149;0",
    "38;2;30;30;30;48;2;255;190;85",
    "38;2;30;30;30;48;2;252;135;79",
    "38;2;30;30;30;48;2;198;151;82",
    "38;2;250;250;255;48;2;193;57;0",
    "38;2;30;30;30;48;2;164;169;0",
)
HTTP_METHODS = ("get", "post", "put", "patch", "delete", "head", "options", "trace")


HELP_SECTIONS = (
    (
        "Inspect",
        (
            ("ui", "Live dashboard"),
            ("status", "Dashboard snapshot"),
            ("pods", "Servers and nodes"),
            ("csi", "CSI pods and nodes"),
            ("mount", "Mount workloads and passthrough mode"),
            ("lb", "Service and ready endpoints"),
            ("storage", "PVCs and storage class"),
            ("top", "Server and CSI usage"),
            ("events", "Recent namespace events"),
            ("context", "Context and namespace"),
            ("aliases", "Shell and command shortcuts"),
            ("oai [ROUTE] [METHOD]", "Inspect the Git OpenAPI spec"),
        ),
    ),
    (
        "Logs",
        (
            ("logs [TARGET] [OPTS]", "Server logs"),
            ("csi logs [TARGET] [OPTS]", "CSI controller and node logs"),
            ("mount logs [TARGET] [OPTS]", "FUSE mount logs"),
            ("db logs [OPTS]", "PostgreSQL logs"),
            ("valkey logs [OPTS]", "Valkey logs"),
        ),
    ),
    (
        "Shells and debugging",
        (
            ("exec [TARGET] [CMD]", "Server shell or command"),
            ("csi exec [TARGET] [CMD]", "CSI shell or command"),
            ("mount exec [TARGET] [CMD]", "Mount shell or command"),
            ("gdb [TARGET] [PROCESS]", "Attach to a server"),
            ("csi gdb [TARGET] [PROCESS]", "Attach to CSI"),
            ("mount gdb [TARGET] [PROCESS]", "Attach to a FUSE mount"),
            ("delete POD [OPTS]", "Delete a server pod"),
            ("csi delete POD [OPTS]", "Delete a CSI pod"),
            ("mount delete POD [OPTS]", "Delete a mount pod"),
            ("db shell [COMMAND]", "PostgreSQL shell"),
            ("valkey shell [COMMAND]", "Valkey shell"),
        ),
    ),
    (
        "Clients",
        (
            ("curl [PATH] [OPTS]", "Cached Service proxy"),
            ("curl-status", "Show proxy connection"),
            ("curl-stop", "Stop proxy connection"),
            ("db [PSQL_ARGS]", "psql client"),
            ("valkey [CLI_ARGS]", "valkey-cli client"),
        ),
    ),
)

HELP_SHORTCUTS = (
    ("cfsrepo", 'cd "$CFS_REPO"'),
    ("cfsp", "cfs pods"),
    ("cfscsi", "cfs csi"),
    ("cfslg", "cfs logs"),
    ("cfslgf", "cfs logs -f"),
    ("cfsmntlg", "cfs mount logs"),
    ("cfsex", "cfs exec"),
    ("cfsgdb", "cfs gdb"),
    ("cfscsigdb", "cfs csi gdb"),
    ("cfscurl", "cfs curl"),
    ("cfsdb", "cfs db"),
    ("cfsvk", "cfs valkey"),
)

COMMAND_ALIASES = {
    "alias": "aliases",
    "dashboard": "ui",
    "openapi": "oai",
    "ls": "pods",
    "servers": "pods",
    "lg": "logs",
    "log": "logs",
    "l": "logs",
    "ex": "exec",
    "e": "exec",
    "shell": "exec",
    "g": "gdb",
    "del": "delete",
    "d": "delete",
    "rm": "delete",
    "p": "pods",
    "psql": "db",
    "vk": "valkey",
}

HELP_EXAMPLES = (
    ("cfs logs -f", "Follow every server"),
    ("cfs logs 2 --since=10m", "Recent logs from server 2"),
    ("cfs mount logs 1 -f", "Follow a specific FUSE mount"),
    ("cfs exec 1", "Shell into server 1"),
    ("cfs csi gdb 2", "Debug CSI pod 2"),
    ("cfs mount gdb 1", "Debug FUSE mount 1"),
    ("cfs m d 1", "Delete mount pod 1"),
    ("cfs curl /v1/health -i", "Request through the LB"),
    ("cfs oai /v1/health", "Inspect an API route"),
    ("cfs db -c 'select now()'", "Run a query"),
)

HELP_ENVIRONMENT = (
    ("GROUP_PREFIX", "Deployment group prefix"),
    ("CFS_REPO", "CamberFS Git checkout"),
    ("CFS_NAMESPACE", "Namespace override"),
    ("CFS_KUBECTL", "kubectl executable"),
    ("CFS_CURL_PORT", "Fixed proxy port"),
    ("CFS_RUNTIME_DIR", "Runtime state directory"),
    ("CFS_GDB_IMAGE", "Debugger image"),
)

HELP_TARGETING = (
    ("cfs [TARGET] COMMAND", "CamberFS is the default target"),
    ("TARGET", "camberfs, csi, mount, db, or valkey"),
    ("m l 1", "Short for mount logs 1"),
    ("c g 2", "Short for csi gdb 2"),
    ("m d 1", "Short for mount delete 1"),
    ("POD", "Pod number or unique name fragment"),
    ("[OPTS]", "Passed through to kubectl"),
    ("--", "Separates command arguments"),
)


class CfsError(Exception):
    pass


def namespace():
    override = os.environ.get("CFS_NAMESPACE")
    if override:
        return override
    prefix = os.environ.get("GROUP_PREFIX")
    if not prefix:
        raise CfsError("GROUP_PREFIX is not set (or set CFS_NAMESPACE explicitly)")
    return f"patapsco-{prefix}-platform"


def panel_title(title):
    return Text(title, style=f"bold {COLOR_TEXT_ACCENT}")


def help_panel(title, rows, border_style):
    table = Table.grid(expand=True, padding=(0, 1))
    table.style = COLOR_FG
    table.add_column(style=f"bold {COLOR_TEXT_ACCENT}", no_wrap=True)
    table.add_column(style=COLOR_FG)
    for command, description in rows:
        table.add_row(command, description)
    return Panel(
        table,
        title=panel_title(title),
        title_align="left",
        border_style=border_style,
        box=box.ROUNDED,
        padding=(0, 1),
    )


def print_help():
    try:
        target_namespace = namespace()
        namespace_style = COLOR_GREEN
    except CfsError:
        target_namespace = "set GROUP_PREFIX or CFS_NAMESPACE"
        namespace_style = COLOR_GOLD

    usage = Text()
    usage.append("cfs", style=f"bold {COLOR_TEXT_ACCENT}")
    usage.append(" [TARGET] COMMAND [ARGS]", style=f"bold {COLOR_WHITE}")
    target = Text()
    target.append("namespace  ", style=COLOR_LIGHT_ORANGE)
    target.append(target_namespace, style=f"bold {namespace_style}")
    CONSOLE.print(
        Panel(
            Group(
                Text("Fast cluster operations for CamberFS", style=COLOR_FG),
                Text(),
                usage,
                target,
            ),
            title=Text(" CamberFS CLI ", style=f"bold {COLOR_TEXT_ACCENT}"),
            subtitle=Text(" Kubernetes toolkit ", style=COLOR_LIGHT_ORANGE),
            border_style=COLOR_ACCENT,
            box=box.ROUNDED,
            padding=(1, 2),
        )
    )

    panels = [
        help_panel(HELP_SECTIONS[0][0], HELP_SECTIONS[0][1], COLOR_ACCENT),
        help_panel("Shell shortcuts", HELP_SHORTCUTS, COLOR_AMBER),
        help_panel(HELP_SECTIONS[2][0], HELP_SECTIONS[2][1], COLOR_AMBER),
        help_panel("Examples", HELP_EXAMPLES, COLOR_CORAL),
        help_panel(HELP_SECTIONS[1][0], HELP_SECTIONS[1][1], COLOR_GOLD),
        help_panel(HELP_SECTIONS[3][0], HELP_SECTIONS[3][1], COLOR_SAND),
        help_panel("Configuration", HELP_ENVIRONMENT, COLOR_MUTED),
        help_panel("Targeting", HELP_TARGETING, COLOR_GOLD),
    ]
    if CONSOLE.width >= 110:
        for index in range(0, len(panels), 2):
            row = Table.grid(expand=True, padding=(0, 1))
            row.add_column(ratio=1, vertical="top")
            row.add_column(ratio=1, vertical="top")
            row.add_row(panels[index], panels[index + 1])
            CONSOLE.print(row)
    else:
        for panel in panels:
            CONSOLE.print(panel)


def print_aliases(args):
    if args:
        raise CfsError("usage: cfs aliases")

    command_aliases = tuple(
        (f"cfs {alias}", f"cfs {command}")
        for alias, command in COMMAND_ALIASES.items()
    )
    shell_panel = help_panel("Shell aliases", HELP_SHORTCUTS, COLOR_ACCENT)
    command_panel = help_panel("Command aliases", command_aliases, COLOR_AMBER)

    title = Text()
    title.append("cfs aliases", style=f"bold {COLOR_TEXT_ACCENT}")
    title.append("  shortcuts available in your shell", style=COLOR_FG)
    CONSOLE.print(Panel(title, border_style=COLOR_ACCENT, padding=(0, 1)))

    if CONSOLE.width >= 100:
        row = Table.grid(expand=True, padding=(0, 1))
        row.add_column(ratio=1, vertical="top")
        row.add_column(ratio=1, vertical="top")
        row.add_row(shell_panel, command_panel)
        CONSOLE.print(row)
    else:
        CONSOLE.print(shell_panel)
        CONSOLE.print(command_panel)

    note = Text()
    note.append("cfs", style=f"bold {COLOR_TEXT_ACCENT}")
    note.append(f" with no arguments opens {os.environ.get('CFS_REPO', '<CFS_REPO>')}.")
    CONSOLE.print(Panel(note, border_style=COLOR_MUTED, padding=(0, 1)))


def openapi_spec_path():
    repo = os.environ.get("CFS_REPO")
    if not repo:
        raise CfsError("CFS_REPO is not set")
    path = Path(repo).expanduser() / "docs" / "generated" / "openapi_server.yaml"
    if not path.is_file():
        raise CfsError(f"OpenAPI spec not found: {path}")
    return path


def load_openapi_spec():
    path = openapi_spec_path()
    try:
        spec = yaml.safe_load(path.read_text())
    except (OSError, yaml.YAMLError) as error:
        raise CfsError(f"cannot read OpenAPI spec: {error}") from error
    if not isinstance(spec, dict) or not isinstance(spec.get("paths"), dict):
        raise CfsError(f"invalid OpenAPI spec: {path}")
    return spec


def openapi_cache_path():
    base = os.environ.get("XDG_CACHE_HOME")
    directory = Path(base).expanduser() if base else Path.home() / ".cache"
    directory = directory / "cfs"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory / "openapi-index.json"


def openapi_index():
    spec_path = openapi_spec_path()
    stat = spec_path.stat()
    cache_path = openapi_cache_path()
    try:
        cached = json.loads(cache_path.read_text())
        if (
            cached.get("spec") == str(spec_path)
            and cached.get("mtime_ns") == stat.st_mtime_ns
            and cached.get("size") == stat.st_size
            and isinstance(cached.get("routes"), dict)
        ):
            return cached["routes"]
    except (FileNotFoundError, json.JSONDecodeError, OSError):
        pass

    spec = load_openapi_spec()
    routes = {
        route: [method.upper() for method in HTTP_METHODS if method in item]
        for route, item in spec["paths"].items()
        if isinstance(item, dict)
    }
    cache = {
        "spec": str(spec_path),
        "mtime_ns": stat.st_mtime_ns,
        "size": stat.st_size,
        "routes": routes,
    }
    temporary = cache_path.with_name(f".{cache_path.name}.{os.getpid()}")
    try:
        temporary.write_text(json.dumps(cache, separators=(",", ":")))
        temporary.chmod(0o600)
        temporary.replace(cache_path)
    except OSError:
        temporary.unlink(missing_ok=True)
    return routes


def resolve_openapi_node(spec, node, seen=None):
    if not isinstance(node, dict) or "$ref" not in node:
        return node
    reference = node["$ref"]
    if not isinstance(reference, str) or not reference.startswith("#/"):
        return node
    seen = set() if seen is None else seen
    if reference in seen:
        return node
    seen.add(reference)
    target = spec
    try:
        for part in reference[2:].split("/"):
            part = part.replace("~1", "/").replace("~0", "~")
            target = target[part]
    except (KeyError, TypeError):
        return node
    if not isinstance(target, dict):
        return target
    merged = dict(target)
    merged.update({key: value for key, value in node.items() if key != "$ref"})
    return resolve_openapi_node(spec, merged, seen)


def schema_name(spec, schema):
    if not isinstance(schema, dict):
        return "-"
    reference = schema.get("$ref")
    if isinstance(reference, str):
        return reference.rsplit("/", 1)[-1]
    schema = resolve_openapi_node(spec, schema)
    if not isinstance(schema, dict):
        return str(schema)
    if "oneOf" in schema:
        return " | ".join(schema_name(spec, item) for item in schema["oneOf"])
    if "anyOf" in schema:
        return " | ".join(schema_name(spec, item) for item in schema["anyOf"])
    schema_type = schema.get("type", "object")
    if isinstance(schema_type, list):
        schema_type = " | ".join(str(item) for item in schema_type)
    if schema_type == "array":
        schema_type = f"array[{schema_name(spec, schema.get('items', {}))}]"
    if schema.get("format"):
        schema_type = f"{schema_type} ({schema['format']})"
    return str(schema_type)


def schema_values(spec, schema):
    schema = resolve_openapi_node(spec, schema)
    if not isinstance(schema, dict):
        return ""
    values = []
    if "enum" in schema:
        values.append(" | ".join(str(item) for item in schema["enum"]))
    if "default" in schema:
        values.append(f"default: {schema['default']}")
    if "example" in schema:
        values.append(f"example: {schema['example']}")
    return "; ".join(values)


def schema_properties(spec, schema, seen=None):
    if not isinstance(schema, dict):
        return {}, set()
    seen = set() if seen is None else seen
    reference = schema.get("$ref")
    if isinstance(reference, str):
        if reference in seen:
            return {}, set()
        seen.add(reference)
    schema = resolve_openapi_node(spec, schema)
    if not isinstance(schema, dict):
        return {}, set()
    properties = dict(schema.get("properties", {}))
    required = set(schema.get("required", []))
    for part in schema.get("allOf", []):
        part_properties, part_required = schema_properties(spec, part, seen)
        properties.update(part_properties)
        required.update(part_required)
    return properties, required


def openapi_methods(path_item):
    return [method for method in HTTP_METHODS if method in path_item]


def resolve_openapi_route(spec, query):
    paths = spec["paths"]
    if query in paths:
        return query
    normalized = f"/{query.lstrip('/')}"
    if normalized in paths:
        return normalized
    lowered = query.lower()
    matches = [route for route in paths if lowered in route.lower()]
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise CfsError(f"no OpenAPI route matches {query!r}")
    preview = ", ".join(matches[:8])
    suffix = " ..." if len(matches) > 8 else ""
    raise CfsError(f"ambiguous OpenAPI route {query!r}: {preview}{suffix}")


def openapi_parameters(spec, path_item, operation):
    parameters = []
    for parameter in [*path_item.get("parameters", []), *operation.get("parameters", [])]:
        parameter = resolve_openapi_node(spec, parameter)
        if isinstance(parameter, dict):
            parameters.append(parameter)
    return parameters


def openapi_parameter_panel(spec, parameters):
    table = Table(
        box=box.SIMPLE_HEAD,
        expand=True,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("Name", style=f"bold {COLOR_LIGHT_ORANGE}", no_wrap=True)
    table.add_column("In", no_wrap=True)
    table.add_column("Required", justify="center", no_wrap=True)
    table.add_column("Type", no_wrap=True)
    table.add_column("Values")
    table.add_column("Description", ratio=2)
    for parameter in parameters:
        schema = parameter.get("schema", {})
        table.add_row(
            str(parameter.get("name", "?")),
            str(parameter.get("in", "?")),
            "yes" if parameter.get("required") else "no",
            schema_name(spec, schema),
            schema_values(spec, schema),
            str(parameter.get("description", "")),
        )
    content = table if parameters else Text("No parameters", style=COLOR_LIGHT_ORANGE)
    return Panel(content, title=panel_title("Parameters"), border_style=COLOR_GOLD)


def openapi_body_panel(spec, request_body):
    request_body = resolve_openapi_node(spec, request_body)
    if not isinstance(request_body, dict):
        return None
    content = request_body.get("content", {})
    sections = []
    for content_type, media in content.items():
        schema = media.get("schema", {}) if isinstance(media, dict) else {}
        heading = Text()
        heading.append(content_type, style=f"bold {COLOR_TEXT_ACCENT}")
        heading.append(f"  {schema_name(spec, schema)}", style=COLOR_LIGHT_ORANGE)
        sections.append(heading)
        properties, required = schema_properties(spec, schema)
        if properties:
            table = Table(
                box=box.SIMPLE_HEAD,
                expand=True,
                header_style=f"bold {COLOR_TEXT_ACCENT}",
                style=COLOR_FG,
            )
            table.add_column("Field", style=f"bold {COLOR_LIGHT_ORANGE}")
            table.add_column("Required", justify="center")
            table.add_column("Type")
            table.add_column("Values")
            table.add_column("Description", ratio=2)
            for name, field_schema in properties.items():
                resolved = resolve_openapi_node(spec, field_schema)
                description = resolved.get("description", "") if isinstance(resolved, dict) else ""
                table.add_row(
                    str(name),
                    "yes" if name in required else "no",
                    schema_name(spec, field_schema),
                    schema_values(spec, field_schema),
                    str(description),
                )
            sections.append(table)
    if not sections:
        sections.append(Text("No documented content", style=COLOR_LIGHT_ORANGE))
    required_label = "required" if request_body.get("required") else "optional"
    return Panel(
        Group(*sections),
        title=panel_title(f"Request body ({required_label})"),
        border_style=COLOR_AMBER,
    )


def openapi_responses_panel(spec, responses):
    table = Table(
        box=box.SIMPLE_HEAD,
        expand=True,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("Status", style=f"bold {COLOR_LIGHT_ORANGE}", no_wrap=True)
    table.add_column("Content")
    table.add_column("Schema")
    table.add_column("Description", ratio=2)
    for status, response in responses.items():
        response = resolve_openapi_node(spec, response)
        if not isinstance(response, dict):
            continue
        content = response.get("content", {})
        content_types = ", ".join(content)
        schemas = []
        for media in content.values():
            if isinstance(media, dict) and media.get("schema"):
                schemas.append(schema_name(spec, media["schema"]))
        table.add_row(
            str(status),
            content_types,
            ", ".join(dict.fromkeys(schemas)),
            str(response.get("description", "")),
        )
    return Panel(table, title=panel_title("Responses"), border_style=COLOR_SAND)


def print_openapi_operation(spec, route, path_item, method):
    operation = path_item[method]
    method_style = COLOR_GREEN if method == "get" else COLOR_CORAL if method == "delete" else COLOR_GOLD
    heading = Text()
    heading.append(method.upper(), style=f"bold {method_style}")
    heading.append(f"  {route}", style=f"bold {COLOR_LIGHT_ORANGE}")
    metadata = Text()
    if operation.get("summary"):
        metadata.append(str(operation["summary"]), style=COLOR_FG)
    details = []
    if operation.get("operationId"):
        details.append(f"operationId: {operation['operationId']}")
    if operation.get("tags"):
        details.append(f"tags: {', '.join(operation['tags'])}")
    if details:
        metadata.append("\n" + "  ".join(details), style=COLOR_LIGHT_ORANGE)
    CONSOLE.print(
        Panel(
            Group(heading, metadata),
            title=panel_title("OpenAPI operation"),
            border_style=COLOR_ACCENT,
        )
    )

    parameters = openapi_parameters(spec, path_item, operation)
    CONSOLE.print(openapi_parameter_panel(spec, parameters))
    body_panel = openapi_body_panel(spec, operation.get("requestBody"))
    if body_panel:
        CONSOLE.print(body_panel)
    CONSOLE.print(openapi_responses_panel(spec, operation.get("responses", {})))

    command = f"cfs curl '{route}' -X {method.upper()}"
    if body_panel:
        command += " -H 'content-type: application/json' -d '{}'"
    CONSOLE.print(
        Panel(
            Text(command, style=f"bold {COLOR_TEXT_ACCENT}"),
            title=panel_title("Request"),
            border_style=COLOR_MUTED,
        )
    )


def print_openapi_routes(spec):
    table = Table(
        box=box.SIMPLE_HEAD,
        expand=True,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("Route", style=f"bold {COLOR_LIGHT_ORANGE}", no_wrap=True)
    table.add_column("Methods", no_wrap=True)
    table.add_column("Summary", ratio=2)
    for route, path_item in spec["paths"].items():
        methods = openapi_methods(path_item)
        summaries = [
            str(path_item[method].get("summary", ""))
            for method in methods
            if path_item[method].get("summary")
        ]
        table.add_row(route, " ".join(method.upper() for method in methods), " / ".join(summaries))
    CONSOLE.print(
        Panel(
            table,
            title=panel_title(f"OpenAPI routes - {openapi_spec_path()}"),
            border_style=COLOR_ACCENT,
        )
    )


def openapi_command(args):
    if len(args) > 2:
        raise CfsError("usage: cfs oai [ROUTE] [METHOD]")
    spec = load_openapi_spec()
    if not args:
        print_openapi_routes(spec)
        return
    route = resolve_openapi_route(spec, args[0])
    path_item = spec["paths"][route]
    methods = openapi_methods(path_item)
    if not methods:
        raise CfsError(f"OpenAPI route has no operations: {route}")
    if len(args) == 2:
        method = args[1].lower()
        if method not in methods:
            choices = ", ".join(item.upper() for item in methods)
            raise CfsError(f"{route} does not support {method.upper()}; choose {choices}")
        methods = [method]
    for method in methods:
        print_openapi_operation(spec, route, path_item, method)


def complete_openapi(args):
    if not args:
        return 0
    kind = args[0]
    if kind == "routes":
        prefix = args[1] if len(args) > 1 else ""
        for route in openapi_index():
            if route.startswith(prefix):
                print(route)
        return 0
    if kind == "methods" and len(args) > 1:
        route = args[1]
        for method in openapi_index().get(route, []):
            print(method)
        return 0
    if kind == "pods" and len(args) > 1:
        pod_kind = TARGET_KINDS.get(args[1], args[1])
        if pod_kind not in COMPONENTS:
            return 0
        prefix = args[2] if len(args) > 2 else ""
        for index, item in enumerate(pod_items(pod_kind), 1):
            candidates = (str(index), item["metadata"]["name"], short_pod_name(item))
            for candidate in dict.fromkeys(candidates):
                if candidate.startswith(prefix):
                    print(candidate)
        return 0
    return 0


def kubectl_command(args):
    return [os.environ.get("CFS_KUBECTL", "kubectl"), "-n", namespace(), *args]


def kubectl(args, *, capture=False, check=True):
    command = kubectl_command(args)
    if capture:
        result = subprocess.run(command, text=True, stdout=subprocess.PIPE, check=check)
        return result.stdout
    return subprocess.run(command, check=check).returncode


def kubectl_json(args):
    output = kubectl([*args, "-o", "json"], capture=True)
    return json.loads(output)


def pod_items(kind):
    data = kubectl_json(["get", "pods", "-l", COMPONENTS[kind]])
    items = data.get("items", [])
    return sorted(items, key=lambda item: item["metadata"]["name"])


def pod_status(item):
    if item["metadata"].get("deletionTimestamp"):
        return "Terminating"
    statuses = item.get("status", {}).get("containerStatuses", [])
    for status in statuses:
        waiting = status.get("state", {}).get("waiting")
        if waiting and waiting.get("reason"):
            return waiting["reason"]
    return item.get("status", {}).get("phase", "Unknown")


def pod_ready(item):
    statuses = item.get("status", {}).get("containerStatuses", [])
    return f"{sum(bool(status.get('ready')) for status in statuses)}/{len(statuses)}"


def pod_restarts(item):
    statuses = item.get("status", {}).get("containerStatuses", [])
    return str(sum(status.get("restartCount", 0) for status in statuses))


def age(timestamp):
    if not timestamp:
        return "?"
    created = datetime.datetime.fromisoformat(timestamp.replace("Z", "+00:00"))
    delta = datetime.datetime.now(datetime.timezone.utc) - created
    seconds = max(0, int(delta.total_seconds()))
    units = ((86400, "d"), (3600, "h"), (60, "m"))
    for size, suffix in units:
        if seconds >= size:
            return f"{seconds // size}{suffix}"
    return f"{seconds}s"


def print_table(headers, rows):
    table = Table(
        box=box.SIMPLE_HEAD if CONSOLE.is_terminal else None,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    for header in headers:
        table.add_column(header)
    for row in rows:
        table.add_row(*(str(value) for value in row))
    CONSOLE.print(table)


def short_pod_name(item):
    name = item["metadata"]["name"]
    instance = item["metadata"].get("labels", {}).get("app.kubernetes.io/instance", "")
    prefix = f"{instance}-"
    return name[len(prefix) :] if instance and name.startswith(prefix) else name


def list_pods(kind):
    items = pod_items(kind)
    rows = []
    for index, item in enumerate(items, 1):
        rows.append(
            [
                index,
                short_pod_name(item),
                pod_ready(item),
                pod_status(item),
                pod_restarts(item),
                item.get("spec", {}).get("nodeName", "<pending>"),
                age(item["metadata"].get("creationTimestamp")),
            ]
        )
    if not rows:
        raise CfsError(f"no CamberFS {kind} pods found in {namespace()}")
    print_table(["#", "POD", "READY", "STATUS", "RESTARTS", "NODE", "AGE"], rows)


def resolve_pod(kind, target=None):
    items = pod_items(kind)
    if not items:
        raise CfsError(f"no CamberFS {kind} pods found in {namespace()}")
    if target is None:
        running = [item for item in items if item.get("status", {}).get("phase") == "Running"]
        return (running or items)[0]
    if target.isdigit():
        index = int(target)
        if index < 1 or index > len(items):
            raise CfsError(f"{kind} pod number must be between 1 and {len(items)}")
        return items[index - 1]
    exact = [item for item in items if item["metadata"]["name"] == target]
    if exact:
        return exact[0]
    matches = [item for item in items if target in item["metadata"]["name"]]
    if len(matches) == 1:
        return matches[0]
    if not matches:
        raise CfsError(f"no {kind} pod matches {target!r}")
    names = ", ".join(item["metadata"]["name"] for item in matches)
    raise CfsError(f"ambiguous {kind} target {target!r}: {names}")


def preferred_container(item, kind):
    names = [container["name"] for container in item.get("spec", {}).get("containers", [])]
    preferred = {
        "server": "camberfs",
        "csi": "camberfs-csi",
        "mount": "camberfs-fuse",
        "db": "postgresql",
        "valkey": "valkey",
    }.get(kind)
    if preferred in names:
        return preferred
    return names[0] if names else None


def split_target(kind, args):
    if not args:
        return None, []
    if args[0] == "--":
        return None, args[1:]
    candidate = args[0]
    if candidate.startswith("-"):
        return None, args
    try:
        resolve_pod(kind, candidate)
        remaining = args[1:]
        if remaining[:1] == ["--"]:
            remaining = remaining[1:]
        return candidate, remaining
    except CfsError:
        if candidate.isdigit():
            raise
        return None, args


def logs(kind, args):
    target, options = split_target(kind, args)
    command = ["logs"]
    target_item = None
    if target:
        target_item = resolve_pod(kind, target)
        command.append(target_item["metadata"]["name"])
    else:
        command.extend(["-l", COMPONENTS[kind]])
    container = preferred_container(target_item or resolve_pod(kind), kind)
    if kind == "csi" and not target:
        command.append("--all-containers=true")
    elif container:
        command.extend(["-c", container])
    if not any(option == "--tail" or option.startswith("--tail=") for option in options):
        command.append("--tail=200")
    command.append("--prefix=true")
    if not target and any(option in ("-f", "--follow") for option in options):
        command.append("--max-log-requests=20")
    target_pod = target_item["metadata"]["name"] if target_item else None
    return stream_logs(kind, [*command, *options], target_pod)


def csi_logs(args):
    if args[:1] in (["mount"], ["mounts"]):
        return logs("mount", args[1:])
    return logs("csi", args)


def stream_logs(kind, args, target_pod=None):
    items = pod_items(kind)
    labels = {}
    for index, item in enumerate(items, 1):
        pod = item["metadata"]["name"]
        if target_pod:
            if pod == target_pod:
                labels[pod] = str(index)
        elif kind == "mount":
            labels[pod] = str(index)
        else:
            labels[pod] = short_pod_name(item)
    width = max((len(label) for label in labels.values()), default=0)
    badges = {
        item["metadata"]["name"]: LOG_BADGES[index % len(LOG_BADGES)]
        for index, item in enumerate(items)
    }
    process = subprocess.Popen(
        kubectl_command(args),
        text=True,
        stdout=subprocess.PIPE,
        bufsize=1,
    )
    try:
        for line in process.stdout:
            match = LOG_PREFIX.match(line.rstrip("\n"))
            if not match:
                sys.stdout.write(line)
                sys.stdout.flush()
                continue
            pod, container, message = match.groups()
            label = labels.get(pod, pod)
            if kind == "csi" and not target_pod:
                label = f"{label}/{container}"
            padded = label.ljust(width if kind != "csi" or target_pod else len(label))
            if sys.stdout.isatty() and not os.environ.get("NO_COLOR"):
                style = badges.get(pod, "30;47")
                prefix = f"\033[1;{style}m {padded.upper()} \033[0m |"
            else:
                prefix = f"{padded.upper()} |"
            sys.stdout.write(f"{prefix} {message}\n")
            sys.stdout.flush()
    except KeyboardInterrupt:
        process.terminate()
        process.wait()
        return 130
    except BrokenPipeError:
        process.terminate()
        process.wait()
        return 0
    return process.wait()


def interactive_flags():
    if sys.stdin.isatty() and sys.stdout.isatty():
        return ["-it"]
    return ["-i"]


def exec_in(kind, args, default_command=None):
    target, command = split_target(kind, args)
    item = resolve_pod(kind, target)
    pod = item["metadata"]["name"]
    container = preferred_container(item, kind)
    command = command or default_command or ["sh"]
    kubectl_args = ["exec", *interactive_flags(), pod]
    if container:
        kubectl_args.extend(["-c", container])
    return kubectl([*kubectl_args, "--", *command])


def delete_pod(kind, args):
    if not args or args[0].startswith("-"):
        raise CfsError("usage: cfs [TARGET] delete POD [OPTS]")
    item = resolve_pod(kind, args[0])
    pod = item["metadata"]["name"]
    return kubectl(["delete", "pod", pod, *args[1:]])


def pod_is_ready(item):
    statuses = item.get("status", {}).get("containerStatuses", [])
    return bool(statuses) and all(status.get("ready") for status in statuses)


def collect_snapshot():
    selector = "app.kubernetes.io/name in (camberfs,camberfs-csi)"
    pods = kubectl_json(["get", "pods", "-l", selector]).get("items", [])
    services = kubectl_json(["get", "services", "-l", selector]).get("items", [])
    pvcs = kubectl_json(["get", "pvc", "-l", selector]).get("items", [])
    server_services = [
        service
        for service in services
        if service["metadata"].get("labels", {}).get("app.kubernetes.io/component") == "server"
    ]
    endpoints = []
    if server_services:
        name = server_services[0]["metadata"]["name"]
        slices = kubectl_json(
            ["get", "endpointslice", "-l", f"kubernetes.io/service-name={name}"]
        ).get("items", [])
        endpoints = [
            address
            for item in slices
            for endpoint in item.get("endpoints", [])
            if endpoint.get("conditions", {}).get("ready", True)
            for address in endpoint.get("addresses", [])
        ]
    return {
        "context": kubectl(["config", "current-context"], capture=True).strip(),
        "namespace": namespace(),
        "pods": sorted(pods, key=lambda item: item["metadata"]["name"]),
        "services": services,
        "pvcs": pvcs,
        "endpoints": endpoints,
    }


def pods_for(snapshot, name=None, component=None):
    matches = []
    for item in snapshot["pods"]:
        labels = item["metadata"].get("labels", {})
        if name is not None and labels.get("app.kubernetes.io/name") != name:
            continue
        if component is not None and labels.get("app.kubernetes.io/component") != component:
            continue
        matches.append(item)
    return matches


def summary_table(snapshot):
    groups = [
        ("Servers", pods_for(snapshot, "camberfs", "server")),
        ("CSI controller", pods_for(snapshot, "camberfs-csi", "controller")),
        ("CSI nodes", pods_for(snapshot, "camberfs-csi", "node")),
        ("Mounts", pods_for(snapshot, "camberfs-csi", "mount")),
        ("PostgreSQL", pods_for(snapshot, "camberfs", "postgresql")),
        ("Valkey", pods_for(snapshot, "camberfs", "valkey")),
    ]
    table = Table(
        box=box.SIMPLE,
        expand=True,
        show_header=False,
        pad_edge=False,
        style=COLOR_FG,
    )
    table.add_column(style=f"bold {COLOR_GOLD}")
    table.add_column(justify="right")
    table.add_column()
    table.add_column(justify="right")
    for label, items in groups:
        ready = sum(pod_is_ready(item) for item in items)
        total = len(items)
        if total == 0:
            state = Text("missing", style=COLOR_GOLD)
        elif ready == total:
            state = Text("healthy", style=COLOR_GREEN)
        else:
            state = Text("degraded", style=f"bold {COLOR_CORAL}")
        restarts = sum(int(pod_restarts(item)) for item in items)
        table.add_row(label, f"{ready}/{total}", state, f"{restarts} restarts")
    return table


def servers_table(snapshot):
    table = Table(
        box=box.SIMPLE_HEAD,
        expand=True,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("#", justify="right", width=3)
    table.add_column("Pod")
    table.add_column("Ready", justify="center")
    table.add_column("State")
    table.add_column("Restarts", justify="right")
    table.add_column("Node")
    table.add_column("Age", justify="right")
    for index, item in enumerate(pods_for(snapshot, "camberfs", "server"), 1):
        state = pod_status(item)
        style = COLOR_GREEN if pod_is_ready(item) else f"bold {COLOR_CORAL}"
        table.add_row(
            str(index),
            short_pod_name(item),
            pod_ready(item),
            Text(state, style=style),
            pod_restarts(item),
            item.get("spec", {}).get("nodeName", "<pending>"),
            age(item["metadata"].get("creationTimestamp")),
        )
    return table


def csi_table(snapshot):
    table = Table(
        box=box.SIMPLE_HEAD,
        expand=True,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("Role")
    table.add_column("Ready", justify="center")
    table.add_column("State")
    table.add_column("Restarts", justify="right")
    table.add_column("Node")
    for item in pods_for(snapshot, "camberfs-csi"):
        labels = item["metadata"].get("labels", {})
        role = labels.get("app.kubernetes.io/component", "?")
        state = pod_status(item)
        style = COLOR_GREEN if pod_is_ready(item) else f"bold {COLOR_CORAL}"
        table.add_row(
            role,
            pod_ready(item),
            Text(state, style=style),
            pod_restarts(item),
            item.get("spec", {}).get("nodeName", "<pending>"),
        )
    return table


def infrastructure_table(snapshot):
    table = Table(
        box=box.SIMPLE,
        expand=True,
        show_header=False,
        pad_edge=False,
        style=COLOR_FG,
    )
    table.add_column(style=f"bold {COLOR_GOLD}")
    table.add_column()
    server_services = [
        service
        for service in snapshot["services"]
        if service["metadata"].get("labels", {}).get("app.kubernetes.io/component") == "server"
    ]
    if server_services:
        service = server_services[0]
        ports = ", ".join(
            f"{port.get('name', '?')}:{port.get('port', '?')}"
            for port in service.get("spec", {}).get("ports", [])
        )
        table.add_row(
            "Service",
            f"{service.get('spec', {}).get('clusterIP', '?')}  {ports}  {len(snapshot['endpoints'])} endpoints",
        )
    else:
        table.add_row("Service", Text("missing", style=f"bold {COLOR_CORAL}"))
    bound = sum(pvc.get("status", {}).get("phase") == "Bound" for pvc in snapshot["pvcs"])
    total = len(snapshot["pvcs"])
    capacities = sorted(
        pvc.get("status", {}).get("capacity", {}).get("storage", "?")
        for pvc in snapshot["pvcs"]
    )
    table.add_row("Storage", f"{bound}/{total} PVCs bound  capacities: {', '.join(capacities) or 'none'}")
    return table


def snapshot_group(snapshot):
    identity = Text()
    identity.append(snapshot["context"], style=f"bold {COLOR_TEXT_ACCENT}")
    identity.append("  ")
    identity.append(snapshot["namespace"], style=COLOR_LIGHT_ORANGE)
    return Group(
        Panel(identity, title=panel_title("CamberFS"), border_style=COLOR_ACCENT),
        Panel(summary_table(snapshot), title=panel_title("Health"), border_style=COLOR_AMBER),
        Panel(servers_table(snapshot), title=panel_title("Servers"), border_style=COLOR_GOLD),
        Panel(
            infrastructure_table(snapshot),
            title=panel_title("Infrastructure"),
            border_style=COLOR_SAND,
        ),
    )


def status():
    CONSOLE.print(snapshot_group(collect_snapshot()))


def mount_spec(item):
    raw = item["metadata"].get("annotations", {}).get(
        "camberfs.patapsco.ai/mount-spec"
    )
    if not raw:
        return {}
    try:
        value = json.loads(raw)
    except json.JSONDecodeError:
        return {}
    return value if isinstance(value, dict) else {}


def mount_target_uids(item):
    raw = item["metadata"].get("annotations", {}).get(
        "camberfs.patapsco.ai/targets", "[]"
    )
    try:
        targets = json.loads(raw)
    except json.JSONDecodeError:
        targets = []
    if not isinstance(targets, list):
        return []
    return sorted(
        {
            match.group(1)
            for target in targets
            if isinstance(target, str)
            for match in [MOUNT_TARGET_UID.search(target)]
            if match
        }
    )


def controller_owner(item):
    owners = item.get("metadata", {}).get("ownerReferences", [])
    return next(
        (owner for owner in owners if owner.get("controller")),
        owners[0] if owners else None,
    )


def workload_for_pod(item, replicasets):
    owner = controller_owner(item)
    if not owner:
        return f"pod/{item['metadata']['name']}"
    kind = owner.get("kind", "workload")
    name = owner.get("name", "unknown")
    if kind == "ReplicaSet":
        replica_set = replicasets.get(name)
        parent = controller_owner(replica_set) if replica_set else None
        if parent:
            parent_kind = parent.get("kind", "workload").lower()
            return f"{parent_kind}/{parent.get('name', name)}"
        return f"rs/{name}"
    return f"{kind.lower()}/{name}"


def mounts():
    items = pod_items("mount")
    if not items:
        CONSOLE.print("No CamberFS mount pods found", style=COLOR_MUTED)
        return

    pods = kubectl_json(["get", "pods"]).get("items", [])
    pods_by_uid = {item["metadata"].get("uid"): item for item in pods}
    replica_set_items = kubectl_json(["get", "replicasets"]).get("items", [])
    replicasets = {item["metadata"]["name"]: item for item in replica_set_items}

    table = Table(
        box=box.SIMPLE_HEAD if CONSOLE.is_terminal else None,
        header_style=f"bold {COLOR_TEXT_ACCENT}",
        style=COLOR_FG,
    )
    table.add_column("#", justify="right", width=3)
    table.add_column("MOUNT")
    table.add_column("VOLUME")
    table.add_column("WORKLOAD")
    table.add_column("CONSUMER")
    table.add_column("MODE")
    table.add_column("ACCESS")
    table.add_column("STATUS")
    table.add_column("NODE")
    table.add_column("AGE", justify="right")
    cards = []

    for index, item in enumerate(items, 1):
        metadata = item["metadata"]
        labels = metadata.get("labels", {})
        spec = mount_spec(item)
        target_uids = mount_target_uids(item)
        consumers = [pods_by_uid[uid] for uid in target_uids if uid in pods_by_uid]
        missing = [uid for uid in target_uids if uid not in pods_by_uid]
        consumer_names = [pod["metadata"]["name"] for pod in consumers]
        consumer_names.extend(f"deleted:{uid[:8]}" for uid in missing)
        workloads = sorted({workload_for_pod(pod, replicasets) for pod in consumers})
        if missing and not workloads:
            workloads.append("deleted")

        has_store_volume = any(
            volume.get("name") == "store"
            for volume in item.get("spec", {}).get("volumes", [])
        )
        passthrough = bool(spec.get("backing_store_root")) or has_store_volume
        mode = Text(
            "passthrough" if passthrough else "streaming",
            style=f"bold {COLOR_GREEN}" if passthrough else COLOR_GOLD,
        )
        state = pod_status(item)
        state_style = COLOR_GREEN if state == "Running" else COLOR_CORAL
        mount_name = metadata["name"].removeprefix("camberfs-")
        volume = labels.get("camberfs.patapsco.ai/volume", "?")
        workload = "\n".join(workloads) or "unattached"
        consumer = "\n".join(consumer_names) or "none"
        access = "ro" if spec.get("read_only") else "rw"
        node = item.get("spec", {}).get("nodeName", "<pending>")
        mount_age = age(metadata.get("creationTimestamp"))
        if CONSOLE.width < 120:
            details = Table.grid(padding=(0, 1))
            details.add_column(style=f"bold {COLOR_LIGHT_ORANGE}", no_wrap=True)
            details.add_column(style=COLOR_FG)
            details.add_row("Mount", mount_name)
            details.add_row("Workload", workload)
            details.add_row("Consumer", consumer)
            details.add_row("Mode", mode)
            details.add_row("Access", access)
            details.add_row("Status", Text(state, style=state_style))
            details.add_row("Node", node)
            details.add_row("Age", mount_age)
            cards.append(
                Panel(
                    details,
                    title=Text(f" #{index}  {volume} ", style=f"bold {COLOR_TEXT_ACCENT}"),
                    title_align="left",
                    border_style=(COLOR_ACCENT, COLOR_AMBER, COLOR_GOLD)[(index - 1) % 3],
                    box=box.ROUNDED,
                    padding=(0, 1),
                )
            )
        else:
            table.add_row(
                str(index),
                mount_name,
                volume,
                workload,
                consumer,
                mode,
                access,
                Text(state, style=state_style),
                node,
                mount_age,
            )
    if cards:
        CONSOLE.print(Group(*cards))
        CONSOLE.print(
            Text("Logs: cfs mount logs TARGET -f", style=f"bold {COLOR_LIGHT_ORANGE}")
        )
    else:
        CONSOLE.print(table)


def server_service():
    data = kubectl_json(["get", "service", "-l", COMPONENTS["server"]])
    items = data.get("items", [])
    if len(items) != 1:
        names = ", ".join(item["metadata"]["name"] for item in items) or "none"
        raise CfsError(f"expected one CamberFS server service, found: {names}")
    return items[0]


def lb():
    service = server_service()
    name = service["metadata"]["name"]
    kubectl(["get", "service", name, "-o", "wide"])
    print("\nEndpoints:", flush=True)
    kubectl(
        [
            "get",
            "endpointslice",
            "-l",
            f"kubernetes.io/service-name={name}",
            "-o",
            "wide",
        ]
    )


def runtime_directory():
    base = os.environ.get("CFS_RUNTIME_DIR")
    if not base:
        base = os.environ.get("XDG_RUNTIME_DIR", f"/tmp/cfs-{os.getuid()}")
    directory = Path(base) / "cfs"
    directory.mkdir(mode=0o700, parents=True, exist_ok=True)
    return directory


def proxy_paths():
    kubectl_bin = os.environ.get("CFS_KUBECTL", "kubectl")
    context_name = subprocess.run(
        [kubectl_bin, "config", "current-context"],
        text=True,
        stdout=subprocess.PIPE,
        check=True,
    ).stdout.strip()
    key = hashlib.sha256(f"{context_name}\0{namespace()}".encode()).hexdigest()[:12]
    directory = runtime_directory()
    return (
        directory / f"proxy-{key}.json",
        directory / f"proxy-{key}.log",
        directory / f"proxy-{key}.lock",
    )


def port_is_open(port):
    try:
        with socket.create_connection(("127.0.0.1", int(port)), timeout=0.2):
            return True
    except OSError:
        return False


def read_proxy_state(path):
    try:
        state = json.loads(path.read_text())
        os.kill(int(state["pid"]), 0)
        if not port_is_open(state["port"]):
            return None
        return state
    except (FileNotFoundError, json.JSONDecodeError, KeyError, OSError, ValueError):
        return None


def allocate_proxy_port():
    configured = os.environ.get("CFS_CURL_PORT")
    if configured:
        port = int(configured)
        if port_is_open(port):
            raise CfsError(f"CFS_CURL_PORT {port} is already in use")
        return port
    with socket.socket() as listener:
        listener.bind(("127.0.0.1", 0))
        return listener.getsockname()[1]


def start_proxy():
    state_path, log_path, lock_path = proxy_paths()
    with lock_path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = read_proxy_state(state_path)
        if state:
            return state
        state_path.unlink(missing_ok=True)
        service = server_service()
        ports = service.get("spec", {}).get("ports", [])
        http_ports = [port for port in ports if port.get("name") == "http"]
        remote_port = int((http_ports or ports)[0]["port"] if ports else 8000)
        local_port = allocate_proxy_port()
        log = log_path.open("a")
        process = subprocess.Popen(
            kubectl_command(
                [
                    "proxy",
                    "--address=127.0.0.1",
                    f"--port={local_port}",
                    "--keepalive=30s",
                ]
            ),
            stdin=subprocess.DEVNULL,
            stdout=log,
            stderr=subprocess.STDOUT,
            start_new_session=True,
        )
        deadline = time.monotonic() + 10
        while time.monotonic() < deadline:
            if process.poll() is not None:
                log.close()
                detail = log_path.read_text(errors="replace")[-2000:]
                raise CfsError(f"curl proxy failed to start\n{detail}")
            if port_is_open(local_port):
                time.sleep(0.1)
                if process.poll() is None:
                    break
            time.sleep(0.1)
        else:
            process.terminate()
            process.wait()
            log.close()
            raise CfsError("timed out starting the curl proxy")
        state = {
            "pid": process.pid,
            "port": local_port,
            "namespace": namespace(),
            "service": service["metadata"]["name"],
            "service_port": remote_port,
        }
        temporary = state_path.with_suffix(".tmp")
        temporary.write_text(json.dumps(state))
        temporary.chmod(0o600)
        temporary.replace(state_path)
        log.close()
        return state


def stop_proxy():
    state_path, _, lock_path = proxy_paths()
    with lock_path.open("a+") as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = read_proxy_state(state_path)
        if not state:
            state_path.unlink(missing_ok=True)
            print("curl proxy is not running")
            return
        try:
            os.kill(int(state["pid"]), signal.SIGTERM)
        except ProcessLookupError:
            pass
        state_path.unlink(missing_ok=True)
        print("curl proxy stopped")


def proxy_status():
    state_path, log_path, _ = proxy_paths()
    state = read_proxy_state(state_path)
    if not state:
        print("curl proxy: stopped")
        return 1
    print(f"curl proxy: running (pid {state['pid']}, 127.0.0.1:{state['port']})")
    print(f"service:    {state['namespace']}/{state['service']}:{state['service_port']}")
    print(f"log:        {log_path}")


def curl_service(args):
    path = "/v1/health"
    options = list(args)
    if options and not options[0].startswith("-"):
        path = options.pop(0)
    if path.startswith("http://") or path.startswith("https://"):
        url = path
    else:
        state = start_proxy()
        proxy_path = (
            f"/api/v1/namespaces/{quote(state['namespace'], safe='')}"
            f"/services/http:{quote(state['service'], safe='')}:{state['service_port']}/proxy"
        )
        url = f"http://127.0.0.1:{state['port']}{proxy_path}/{path.lstrip('/')}"
    return subprocess.run(["curl", *options, url]).returncode


def gdb_rust_log():
    repo = os.environ.get("CFS_REPO")
    if not repo:
        raise CfsError("CFS_REPO is not set")
    values_path = Path(repo).expanduser() / "charts" / "camberfs" / "values.yaml"
    try:
        values = yaml.safe_load(values_path.read_text())
        rust_log = values["env"]["RUST_LOG"]
    except (OSError, KeyError, TypeError, yaml.YAMLError) as error:
        raise CfsError(f"cannot load env.RUST_LOG from {values_path}: {error}") from error
    if not isinstance(rust_log, str) or not rust_log:
        raise CfsError(f"env.RUST_LOG is empty or invalid in {values_path}")
    return rust_log


def gdb_attach(args, default_kind="server"):
    arguments = list(args)
    kind = default_kind
    if arguments and arguments[0] in TARGET_KINDS:
        kind = TARGET_KINDS[arguments.pop(0)]
    target = arguments[0] if arguments else "1"
    defaults = {
        "server": "camberfs-server",
        "csi": "camberfsplugin",
        "mount": "camberfs-fuse",
        "db": "postgres",
        "valkey": "valkey-server",
    }
    process_name = arguments[1] if len(arguments) > 1 else defaults[kind]
    if len(arguments) > 2:
        raise CfsError("usage: cfs [TARGET] gdb [POD] [PROCESS]")
    item = resolve_pod(kind, target)
    pod = item["metadata"]["name"]
    container = preferred_container(item, kind)
    image = os.environ.get("CFS_GDB_IMAGE", "ubuntu:24.04")
    rust_log = gdb_rust_log()
    profile = runtime_directory() / "gdb-profile.json"
    profile.write_text(
        json.dumps(
            {
                "securityContext": {
                    "privileged": True,
                    "runAsNonRoot": False,
                    "runAsUser": 0,
                    "runAsGroup": 0,
                    "capabilities": {"add": ["SYS_PTRACE"]},
                }
            }
        )
    )
    profile.chmod(0o600)
    script = r'''
set -e
if ! command -v gdb >/dev/null 2>&1 || ! command -v pgrep >/dev/null 2>&1; then
  if ! command -v apt-get >/dev/null 2>&1; then
    echo "debug image needs gdb and procps" >&2
    exit 1
  fi
  apt-get update -qq
  DEBIAN_FRONTEND=noninteractive apt-get install -y -qq gdb procps
fi
target=$1
case "$target" in
  *[!0-9]*) pid=$(pgrep -o -x "$target" || pgrep -o -f "$target" || true) ;;
  *) pid=$target ;;
esac
if [ -z "$pid" ] || [ ! -d "/proc/$pid" ]; then
  echo "process not found: $target" >&2
  exit 1
fi
echo "attaching gdb to $target (pid $pid) in $HOSTNAME"
exec gdb -p "$pid"
'''.strip()
    return kubectl(
        [
            "debug",
            "-it",
            f"pod/{pod}",
            f"--target={container}",
            f"--image={image}",
            f"--env=RUST_LOG={rust_log}",
            "--profile=sysadmin",
            f"--custom={profile}",
            "--",
            "bash",
            "-lc",
            script,
            "cfs-gdb",
            process_name,
        ]
    )


def db(args):
    script = 'PGPASSWORD="$POSTGRES_PASSWORD" exec psql -U "$POSTGRES_USER" -d "$POSTGRES_DB" "$@"'
    return exec_in("db", ["sh", "-c", script, "cfs-psql", *args])


def valkey(args):
    script = 'VALKEYCLI_AUTH="$VALKEY_PASSWORD" exec valkey-cli "$@"'
    return exec_in("valkey", ["sh", "-c", script, "cfs-valkey", *args])


def storage():
    selector = "app.kubernetes.io/name in (camberfs,camberfs-csi)"
    kubectl(["get", "pvc", "-l", selector, "-o", "wide"])
    print("\nStorage class:", flush=True)
    storage_class = f"camberfs-csi-{os.environ.get('GROUP_PREFIX', '')}"
    kubectl(["get", "storageclass", storage_class, "-o", "wide"], check=False)


def context():
    current = kubectl(["config", "current-context"], capture=True).strip()
    print(f"context:   {current}")
    print(f"namespace: {namespace()}")


def run_ui():
    from textual import work
    from textual.app import App, ComposeResult
    from textual.containers import VerticalScroll
    from textual.widgets import Footer, Header, Static

    class CamberFSApp(App):
        TITLE = "CamberFS"
        SUB_TITLE = "cluster dashboard"
        CSS = f"""
        Screen {{
            background: {COLOR_BG};
            color: {COLOR_FG};
        }}
        Header {{
            background: {COLOR_DARK};
            color: {COLOR_FG};
        }}
        HeaderIcon {{
            background: {COLOR_DARK};
            color: {COLOR_TEXT_ACCENT};
        }}
        HeaderTitle {{
            background: {COLOR_DARK};
            color: {COLOR_FG};
        }}
        HeaderClock {{
            background: {COLOR_PANEL};
            color: {COLOR_LIGHT_ORANGE};
        }}
        VerticalScroll {{
            background: {COLOR_BG};
            padding: 0 1;
        }}
        .panel {{
            background: {COLOR_PANEL};
            color: {COLOR_FG};
            height: auto;
            margin: 0 0 1 0;
        }}
        #message {{
            height: 1;
            color: {COLOR_LIGHT_ORANGE};
            margin: 0 1;
        }}
        Footer {{
            background: {COLOR_DARK};
            color: {COLOR_FG};
        }}
        FooterKey {{
            .footer-key--key {{
                background: {COLOR_ACCENT};
                color: {COLOR_DARK};
            }}
            .footer-key--description {{
                background: {COLOR_DARK};
                color: {COLOR_FG};
            }}
        }}
        """
        BINDINGS = [
            ("r", "refresh", "Refresh"),
            ("q", "quit", "Quit"),
        ]

        def compose(self) -> ComposeResult:
            yield Header(show_clock=True)
            with VerticalScroll():
                yield Static("Loading cluster state...", id="identity", classes="panel")
                yield Static(id="health", classes="panel")
                yield Static(id="servers", classes="panel")
                yield Static(id="csi", classes="panel")
                yield Static(id="infrastructure", classes="panel")
            yield Static("Starting...", id="message")
            yield Footer()

        def on_mount(self):
            self.refresh_snapshot()
            self.set_interval(5, self.refresh_snapshot)

        def action_refresh(self):
            self.refresh_snapshot()

        @work(thread=True, exclusive=True, exit_on_error=False)
        def refresh_snapshot(self):
            try:
                snapshot = collect_snapshot()
            except Exception as error:
                self.call_from_thread(self.show_error, str(error))
                return
            self.call_from_thread(self.apply_snapshot, snapshot)

        def apply_snapshot(self, snapshot):
            identity = Text()
            identity.append(snapshot["context"], style=f"bold {COLOR_TEXT_ACCENT}")
            identity.append("  ")
            identity.append(snapshot["namespace"], style=COLOR_LIGHT_ORANGE)
            self.query_one("#identity", Static).update(
                Panel(
                    identity,
                    title=panel_title("CamberFS"),
                    border_style=COLOR_ACCENT,
                )
            )
            self.query_one("#health", Static).update(
                Panel(
                    summary_table(snapshot),
                    title=panel_title("Health"),
                    border_style=COLOR_AMBER,
                )
            )
            self.query_one("#servers", Static).update(
                Panel(
                    servers_table(snapshot),
                    title=panel_title("Servers"),
                    border_style=COLOR_GOLD,
                )
            )
            self.query_one("#csi", Static).update(
                Panel(
                    csi_table(snapshot),
                    title=panel_title("CSI"),
                    border_style=COLOR_SAND,
                )
            )
            self.query_one("#infrastructure", Static).update(
                Panel(
                    infrastructure_table(snapshot),
                    title=panel_title("Infrastructure"),
                    border_style=COLOR_MUTED,
                )
            )
            timestamp = datetime.datetime.now().strftime("%H:%M:%S")
            self.query_one("#message", Static).update(f"Updated {timestamp}  |  refreshes every 5s")

        def show_error(self, message):
            self.query_one("#message", Static).update(
                Text(message, style=f"bold {COLOR_CORAL}")
            )

    CamberFSApp().run()


def run_target_command(kind, command, args):
    command = TARGET_COMMAND_ALIASES.get(command, command)
    if command == "pods":
        return mounts() if kind == "mount" else list_pods(kind)
    if command == "logs":
        return logs(kind, args)
    if command == "exec":
        return exec_in(kind, args)
    if command == "gdb":
        return gdb_attach(args, kind)
    if command == "delete":
        return delete_pod(kind, args)
    target = "camberfs" if kind == "server" else kind
    raise CfsError(f"unknown {target} command {command!r}; run `cfs help`")


def target_invocation(argv):
    target = argv[0]
    if target not in TARGET_KINDS:
        return None
    command = TARGET_COMMAND_ALIASES.get(argv[1], argv[1]) if len(argv) > 1 else "pods"
    kind = TARGET_KINDS[target]
    if kind in ("db", "valkey") and command not in (
        "pods",
        "logs",
        "exec",
        "gdb",
        "delete",
    ):
        return None
    if kind in ("db", "valkey") and len(argv) < 2:
        return None
    return kind, command, argv[2:]


def main(argv):
    if not argv or argv[0] in ("help", "-h", "--help"):
        print_help()
        return 0

    targeted = target_invocation(argv)
    if targeted:
        result = run_target_command(*targeted)
        return result if isinstance(result, int) else 0

    command, args = argv[0], argv[1:]
    command = COMMAND_ALIASES.get(command, command)

    actions = {
        "ui": run_ui,
        "aliases": lambda: print_aliases(args),
        "oai": lambda: openapi_command(args),
        "__complete": lambda: complete_openapi(args),
        "status": lambda: status(),
        "pods": lambda: list_pods("server"),
        "csi": lambda: list_pods("csi"),
        "mounts": mounts,
        "lb": lb,
        "logs": lambda: logs("server", args),
        "csi-logs": lambda: csi_logs(args),
        "mount-logs": lambda: logs("mount", args),
        "db-logs": lambda: logs("db", args),
        "valkey-logs": lambda: logs("valkey", args),
        "exec": lambda: exec_in("server", args),
        "gdb": lambda: gdb_attach(args),
        "delete": lambda: delete_pod("server", args),
        "csi-gdb": lambda: gdb_attach(args, "csi"),
        "csi-exec": lambda: exec_in("csi", args),
        "db-shell": lambda: exec_in("db", args),
        "valkey-shell": lambda: exec_in("valkey", args),
        "curl": lambda: curl_service(args),
        "curl-status": proxy_status,
        "curl-stop": stop_proxy,
        "db": lambda: db(args),
        "valkey": lambda: valkey(args),
        "storage": storage,
        "top": lambda: kubectl(
            ["top", "pods", "-l", "app.kubernetes.io/name in (camberfs,camberfs-csi)"]
        ),
        "events": lambda: kubectl(["get", "events", "--sort-by=.lastTimestamp"]),
        "context": context,
    }
    action = actions.get(command)
    if action is None:
        raise CfsError(f"unknown command {command!r}; run `cfs help`")
    result = action()
    return result if isinstance(result, int) else 0


if __name__ == "__main__":
    try:
        raise SystemExit(main(sys.argv[1:]))
    except CfsError as error:
        ERROR_CONSOLE.print(f"cfs: {error}", style=f"bold {COLOR_CORAL}")
        raise SystemExit(2)
    except (subprocess.CalledProcessError, json.JSONDecodeError) as error:
        code = error.returncode if isinstance(error, subprocess.CalledProcessError) else 1
        raise SystemExit(code)
