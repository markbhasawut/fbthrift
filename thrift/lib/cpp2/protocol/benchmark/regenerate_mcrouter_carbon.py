#!/usr/bin/env python3
# Copyright (c) Meta Platforms, Inc. and affiliates.
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

"""Check or update mcrouter's committed Carbon outputs through a provider.

The public mcrouter repository contains Carbon IDLs and generated files, but
not Meta's full ``carbon/facebook/compiler`` implementation. This driver owns
the reproducible repository operation while leaving the compiler replaceable.

A provider must accept these arguments:

  --input <absolute .idl path>
  --output-dir <empty directory>
  --include-prefix <repository-relative gen directory>
  --source-root <absolute mcrouter repository root>

Every file emitted for a program must have a basename beginning with the IDL
stem. That ownership rule lets update mode remove stale outputs without
touching another program sharing the same ``gen`` directory.
"""

from __future__ import annotations

import argparse
import dataclasses
import os
import pathlib
import re
import shutil
import subprocess
import sys
import tempfile


IMPORT_PATTERN = re.compile(r'^\s*import\s+"([^"]+)"', re.MULTILINE)


@dataclasses.dataclass(frozen=True)
class GeneratedProgram:
    source: pathlib.Path
    generated: pathlib.Path
    changed: tuple[pathlib.Path, ...]
    missing: tuple[pathlib.Path, ...]
    stale: tuple[pathlib.Path, ...]


def _resolve_programs(
    root: pathlib.Path, requested: list[pathlib.Path]
) -> list[pathlib.Path]:
    if requested:
        programs = []
        for value in requested:
            path = value if value.is_absolute() else root / value
            path = path.resolve()
            try:
                path.relative_to(root)
            except ValueError as error:
                raise ValueError(f"IDL is outside the mcrouter checkout: {path}") from error
            programs.append(path)
    else:
        programs = sorted((root / "mcrouter").rglob("*.idl"))

    if not programs:
        raise ValueError(f"no Carbon IDLs found under {root / 'mcrouter'}")
    for path in programs:
        if not path.is_file():
            raise ValueError(f"Carbon IDL does not exist: {path}")
    return _topological_order(root, programs)


def _topological_order(
    root: pathlib.Path, programs: list[pathlib.Path]
) -> list[pathlib.Path]:
    program_set = {path.resolve() for path in programs}
    dependencies: dict[pathlib.Path, set[pathlib.Path]] = {}
    for path in program_set:
        imports = IMPORT_PATTERN.findall(path.read_text(encoding="utf-8"))
        dependencies[path] = {
            (root / imported).resolve()
            for imported in imports
            if (root / imported).resolve() in program_set
        }

    ordered: list[pathlib.Path] = []
    temporary: set[pathlib.Path] = set()
    permanent: set[pathlib.Path] = set()

    def visit(path: pathlib.Path) -> None:
        if path in permanent:
            return
        if path in temporary:
            raise ValueError(f"Carbon import cycle contains {path}")
        temporary.add(path)
        for dependency in sorted(dependencies[path]):
            visit(dependency)
        temporary.remove(path)
        permanent.add(path)
        ordered.append(path)

    for path in sorted(program_set):
        visit(path)
    return ordered


def _provider_command(
    generator: pathlib.Path,
    generator_args: list[str],
    source: pathlib.Path,
    output_dir: pathlib.Path,
    include_prefix: pathlib.Path,
    root: pathlib.Path,
) -> list[str]:
    if generator.suffix == ".py":
        command = [sys.executable, os.fspath(generator)]
    else:
        command = [os.fspath(generator)]
    command.extend(generator_args)
    command.extend(
        [
            "--input",
            os.fspath(source),
            "--output-dir",
            os.fspath(output_dir),
            "--include-prefix",
            include_prefix.as_posix(),
            "--source-root",
            os.fspath(root),
        ]
    )
    return command


def _generate_program(
    root: pathlib.Path,
    generator: pathlib.Path,
    generator_args: list[str],
    source: pathlib.Path,
    scratch: pathlib.Path,
) -> GeneratedProgram:
    relative_source = source.relative_to(root)
    include_prefix = relative_source.parent / "gen"
    output_dir = scratch / relative_source.with_suffix("")
    output_dir.mkdir(parents=True)
    subprocess.run(
        _provider_command(
            generator,
            generator_args,
            source,
            output_dir,
            include_prefix,
            root,
        ),
        check=True,
        cwd=root,
    )

    emitted = sorted(path for path in output_dir.rglob("*") if path.is_file())
    if not emitted:
        raise ValueError(f"Carbon provider emitted no files for {relative_source}")
    invalid = [path for path in emitted if not path.name.startswith(source.stem)]
    if invalid:
        names = ", ".join(path.name for path in invalid)
        raise ValueError(
            f"Carbon provider violated the {source.stem!r} ownership prefix: {names}"
        )

    generated_dir = root / include_prefix
    generated_relative = {path.relative_to(output_dir) for path in emitted}
    existing_relative = {
        path.relative_to(generated_dir)
        for path in generated_dir.rglob(f"{source.stem}*")
        if path.is_file()
    }
    missing = tuple(sorted(generated_relative - existing_relative))
    stale = tuple(sorted(existing_relative - generated_relative))
    changed = tuple(
        relative
        for relative in sorted(generated_relative & existing_relative)
        if (output_dir / relative).read_bytes()
        != (generated_dir / relative).read_bytes()
    )
    return GeneratedProgram(source, output_dir, changed, missing, stale)


def _atomic_copy(source: pathlib.Path, destination: pathlib.Path) -> None:
    destination.parent.mkdir(parents=True, exist_ok=True)
    descriptor, temporary_name = tempfile.mkstemp(
        prefix=f".{destination.name}.", dir=destination.parent
    )
    os.close(descriptor)
    temporary = pathlib.Path(temporary_name)
    try:
        shutil.copyfile(source, temporary)
        os.replace(temporary, destination)
    finally:
        temporary.unlink(missing_ok=True)


def _update_program(root: pathlib.Path, program: GeneratedProgram) -> None:
    generated_dir = root / program.source.relative_to(root).parent / "gen"
    for relative in (*program.changed, *program.missing):
        _atomic_copy(program.generated / relative, generated_dir / relative)
    for relative in program.stale:
        (generated_dir / relative).unlink()


def _print_delta(root: pathlib.Path, program: GeneratedProgram) -> None:
    relative_source = program.source.relative_to(root)
    for label, paths in (
        ("changed", program.changed),
        ("missing", program.missing),
        ("stale", program.stale),
    ):
        for path in paths:
            print(f"{relative_source}: {label}: {path}")


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--mcrouter-root", required=True, type=pathlib.Path)
    parser.add_argument("--generator", required=True, type=pathlib.Path)
    parser.add_argument(
        "--generator-arg", action="append", default=[], metavar="ARG"
    )
    parser.add_argument("--mode", choices=("check", "update"), default="check")
    parser.add_argument("--idl", action="append", default=[], type=pathlib.Path)
    arguments = parser.parse_args()

    try:
        root = arguments.mcrouter_root.resolve()
        generator = arguments.generator.resolve()
        if not (root / "mcrouter" / "lib" / "carbon").is_dir():
            raise ValueError(f"not an mcrouter source checkout: {root}")
        if not generator.is_file():
            raise ValueError(f"Carbon generator does not exist: {generator}")
        programs = _resolve_programs(root, arguments.idl)

        deltas: list[GeneratedProgram] = []
        with tempfile.TemporaryDirectory(prefix="mcrouter-carbon-codegen-") as value:
            scratch = pathlib.Path(value)
            for source in programs:
                program = _generate_program(
                    root,
                    generator,
                    arguments.generator_arg,
                    source,
                    scratch,
                )
                if program.changed or program.missing or program.stale:
                    deltas.append(program)
                    _print_delta(root, program)
                    if arguments.mode == "update":
                        _update_program(root, program)

        if arguments.mode == "check" and deltas:
            print(
                f"mcrouter Carbon outputs are stale for {len(deltas)} program(s)",
                file=sys.stderr,
            )
            return 1
        action = "updated" if arguments.mode == "update" else "checked"
        print(f"{action} {len(programs)} mcrouter Carbon program(s)")
        return 0
    except (OSError, subprocess.CalledProcessError, ValueError) as error:
        print(f"mcrouter Carbon codegen: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
