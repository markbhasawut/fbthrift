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

# Do not call directly, use cmake
#
# Cython requires source files in a specific structure, the structure is
# created as tree of links to the real source files.

import os
import shutil
import sys
from pathlib import Path

import Cython
from Cython.Build import cythonize
from Cython.Compiler import Options
from setuptools import Extension, setup

Options.fast_fail = True

# Configure Cython include path from environment to find dependency .pxd files
# CMake sets CYTHON_INCLUDE_PATH with paths to folly, boost, and build directories
# This is needed for both --api-only and build_ext phases
cython_include_path = os.environ.get("CYTHON_INCLUDE_PATH", "")
include_dirs = ["."]
if cython_include_path:
    include_dirs.extend([p for p in cython_include_path.split(":") if p])

API_MODULES = (
    ("thrift/python/_types.pyx", "thrift.python.types"),
    ("thrift/python/exceptions.pyx", "thrift.python.exceptions"),
    (
        "thrift/python/server/python_async_processor.pyx",
        "thrift.python.server.python_async_processor",
    ),
    (
        "thrift/python/server/request_context.pyx",
        "thrift.python.server.request_context",
    ),
    (
        "thrift/python/server/interceptor/service_interceptor.pyx",
        "thrift.python.server.interceptor.service_interceptor",
    ),
    (
        "thrift/python/server_impl/python_async_processor.pyx",
        "thrift.python.server_impl.python_async_processor",
    ),
    (
        "thrift/python/server_impl/request_context.pyx",
        "thrift.python.server_impl.request_context",
    ),
    (
        "thrift/python/server_impl/interceptor/service_interceptor.pyx",
        "thrift.python.server_impl.interceptor.service_interceptor",
    ),
    ("thrift/py3/_stream.pyx", "thrift.py3.stream"),
    ("thrift/python/streaming/sink.pyx", "thrift.python.streaming.sink"),
    (
        "thrift/python/streaming/bidistream.pyx",
        "thrift.python.streaming.bidistream",
    ),
    (
        "thrift/python/streaming/py_promise.pyx",
        "thrift.python.streaming.py_promise",
    ),
    (
        "thrift/python/client/py_bridge/py_bridge_channel.pyx",
        "thrift.python.client.py_bridge.py_bridge_channel",
    ),
)

if "--api-only" in sys.argv:
    if include_dirs:
        # Create CompilationOptions with include_path
        # This allows Cython to find folly .pxd files during compilation
        compilation_options = Options.CompilationOptions(
            Options.default_options,
            include_path=include_dirs,
        )
    else:
        compilation_options = None

    api_output_dir = Path(".cython_api")

    def compile_api(source, full_module_name):
        source_path = Path(source)
        output_file = api_output_dir / source_path.with_suffix(".cpp")
        output_file.parent.mkdir(parents=True, exist_ok=True)
        # Cython refuses to overwrite some generated headers when a C++ type
        # declaration preamble precedes its generated-file marker. These are
        # private, deterministic outputs, so remove them before regenerating.
        for generated_path in (
            output_file,
            output_file.with_suffix(".h"),
            output_file.with_name(f"{output_file.stem}_api.h"),
        ):
            generated_path.unlink(missing_ok=True)
        result = Cython.Compiler.Main.compile(
            source,
            options=compilation_options,
            full_module_name=full_module_name,
            output_file=str(output_file),
            cplus=True,
            language_level=3,
        )
        if result.num_errors:
            raise SystemExit(
                f"Cython API generation failed for {full_module_name}"
            )
        if not result.api_file:
            raise SystemExit(
                f"Cython did not generate an API header for {full_module_name}"
            )
        api_destination = source_path.with_name(
            f"{source_path.stem}_api.h"
        )
        shutil.copyfile(result.api_file, api_destination)
        if result.h_file:
            public_header_destination = source_path.with_suffix(".h")
            shutil.copyfile(result.h_file, public_header_destination)

    # Invoke cython compiler directly instead of calling cythonize().
    # Generating *_api.h files only requires first stage of compilation
    # from cython source -> cpp source.
    for api_source, api_module in API_MODULES:
        compile_api(api_source, api_module)

else:
    python_lib_idx = sys.argv.index("--libpython")
    python_lib = Path(sys.argv[python_lib_idx + 1]).name.removeprefix("lib")
    for library_suffix in (".dylib", ".so", ".a", ".lib"):
        python_lib = python_lib.removesuffix(library_suffix)
    del sys.argv[python_lib_idx : python_lib_idx + 2]

    # Library search paths from CMakeLists (passed via LIBRARY_DIRS env var)
    lib_search_paths = os.environ.get("LIBRARY_DIRS", "").split(":")
    lib_search_paths = [p for p in lib_search_paths if p]  # Filter empty strings

    # All C++ dependencies are consolidated into libthrift_python_cpp. On
    # macOS its LC_LOAD_DYLIB entries load those dependencies, and extension
    # modules use dynamic lookup for their unresolved Python/C++ symbols.
    if sys.platform == "darwin":
        dynamic_libs = ["thrift_python_cpp"]
    else:
        dynamic_libs = [
            "thrift_python_cpp",
            "ssl",
            "crypto",
            "pthread",
            "aio",
            "glog",
            "gflags",
            "event",
            "lzma",
            "snappy",
            "sodium",
            "unwind",
        ]

    extra_link_args = []

    # Read LDFLAGS from environment
    ldflags_str = os.environ.get("LDFLAGS", "")
    if ldflags_str:
        import shlex

        extra_link_args.extend(shlex.split(ldflags_str))

    # RPATH for runtime library resolution
    # Use @loader_path (macOS) or $ORIGIN (Linux) so delocate/auditwheel can properly bundle libraries into the wheel.
    if sys.platform == "darwin":
        extra_link_args.append("-Wl,-rpath,@loader_path/.libs")
        extra_link_args.append("-Wl,-rpath,@loader_path")
    else:
        extra_link_args.append("-Wl,-rpath,$ORIGIN/.libs")
        extra_link_args.append("-Wl,-rpath,$ORIGIN")

    common_options = {
        "language": "c++",
        "include_dirs": include_dirs,
        "library_dirs": lib_search_paths,  # Tell linker where to find dynamic libraries
        "libraries": dynamic_libs + [python_lib],
        "define_macros": [
            ("THRIFT_HAS_JSON5_PROTOCOL", "1"),
            ("GLOG_USE_GFLAGS", "1"),
            ("GLOG_USE_GLOG_EXPORT", "1"),
        ],
        "extra_compile_args": ["-std=c++20", "-fcoroutines"],
        "extra_link_args": extra_link_args,
    }
    server_options = {
        **common_options,
        "define_macros": [
            *common_options["define_macros"],
            ("__PYX_ENUM_CLASS_DECL", ""),
        ],
    }

    exts = [
        # thrift.python extension modules
        Extension(
            "thrift.python.adapter",
            sources=["thrift/python/adapter.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.async_client_factory",
            sources=["thrift/python/client/async_client_factory.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.async_client",
            sources=["thrift/python/client/async_client.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.omni_client",
            sources=["thrift/python/client/omni_client.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.py_bridge.py_bridge_channel",
            sources=[
                "thrift/python/client/py_bridge/py_bridge_channel.pyx",
                "thrift/python/client/py_bridge/PyBridgeRequestChannel.cpp",
                "thrift/python/client/py_bridge/PySender.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.python.client.request_channel",
            sources=["thrift/python/client/request_channel.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.ssl",
            sources=["thrift/python/client/ssl.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.sync_channel_factory",
            sources=["thrift/python/client/sync_channel_factory.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.sync_client_factory",
            sources=["thrift/python/client/sync_client_factory.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.client.sync_client",
            sources=["thrift/python/client/sync_client.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.common",
            sources=["thrift/python/common.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.converter",
            sources=["thrift/python/converter.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.exceptions",
            sources=["thrift/python/exceptions.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_containers",
            sources=["thrift/python/mutable_containers.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_exceptions",
            sources=["thrift/python/mutable_exceptions.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_serializer",
            sources=["thrift/python/mutable_serializer.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_typeinfos",
            sources=["thrift/python/mutable_typeinfos.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_types",
            sources=["thrift/python/mutable_types.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.protocol",
            sources=["thrift/python/protocol.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.reflection_enums",
            sources=["thrift/python/reflection_enums.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.serializer",
            sources=["thrift/python/serializer.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.server",
            sources=[
                "thrift/python/server.pyx",
                "thrift/python/server/PythonAsyncProcessor.cpp",
                "thrift/python/server/PythonAsyncProcessorFactory.cpp",
                "thrift/python/server/event_handler.cpp",
                "thrift/python/server/interceptor/PythonServiceInterceptor.cpp",
                "thrift/python/std_libcpp.cpp",
            ],
            **server_options,
        ),
        # thrift.python.streaming extension modules
        # Each .pyx file generates to generated/*.cpp (via build_dir="generated")
        # Handwritten .cpp files (e.g., SinkBridge.cpp, bidi_stream.cpp) are also
        # compiled.
        Extension(
            "thrift.python.streaming.stream",
            sources=["thrift/python/streaming/stream.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.streaming.py_promise",
            sources=["thrift/python/streaming/py_promise.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.streaming.python_user_exception",
            sources=[
                "thrift/python/streaming/python_user_exception.pyx",
                "thrift/python/streaming/PythonUserException.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.python.streaming.sink",
            sources=[
                "thrift/python/streaming/sink.pyx",
                "thrift/python/streaming/SinkBridge.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.python.streaming.bidistream",
            sources=[
                "thrift/python/streaming/bidistream.pyx",
                "thrift/python/streaming/bidi_stream.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.python.streaming.closeable",
            sources=["thrift/python/streaming/closeable.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.types",
            sources=["thrift/python/_types.pyx"],
            **common_options,
        ),
        # Additional thrift.python extension modules
        Extension(
            "thrift.python.any.serializer",
            sources=["thrift/python/any/serializer.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.conformance.universal_name",
            sources=["thrift/python/conformance/universal_name.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.mutable_converter",
            sources=["thrift/python/mutable_converter.pyx"],
            **common_options,
        ),
        # NOTE: thrift.python.server.* submodule extensions are NOT built here.
        # They would conflict with the thrift.python.server extension module (.so).
        # All imports use thrift.python.server_impl.* instead (see server.pyx, py3/server.pyx).
        # thrift.python.server_impl extension modules
        Extension(
            "thrift.python.server_impl.async_processor",
            sources=["thrift/python/server_impl/async_processor.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.server_impl.python_async_processor",
            sources=["thrift/python/server_impl/python_async_processor.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.server_impl.request_context",
            sources=[
                "thrift/python/server_impl/request_context.pyx",
                "thrift/python/server/request_context_holder.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.python.server_impl.interceptor.server_module",
            sources=["thrift/python/server_impl/interceptor/server_module.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.python.server_impl.interceptor.service_interceptor",
            sources=["thrift/python/server_impl/interceptor/service_interceptor.pyx"],
            **common_options,
        ),
        # thrift.py3 extension modules
        Extension(
            "thrift.py3.exceptions",
            sources=["thrift/py3/exceptions.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.serializer",
            sources=["thrift/py3/serializer.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.server",
            sources=[
                "thrift/py3/server.pyx",
                "thrift/python/server/event_handler.cpp",
            ],
            **common_options,
        ),
        Extension(
            "thrift.py3.stream",
            sources=["thrift/py3/_stream.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.types",
            sources=["thrift/py3/types.pyx"],
            **common_options,
        ),
        # Additional thrift.py3 extension modules
        Extension(
            "thrift.py3.builder",
            sources=["thrift/py3/builder.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.client",
            sources=["thrift/py3/client.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.converter",
            sources=["thrift/py3/converter.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.metadata",
            sources=["thrift/py3/metadata.pyx"],
            **common_options,
        ),
        Extension(
            "thrift.py3.reflection",
            sources=["thrift/py3/reflection.pyx"],
            **common_options,
        ),
    ]

    # Test extension modules - only built if THRIFT_BUILD_TESTS=1
    # (set by add_subdirectory(test) in CMakeLists.txt)
    if os.environ.get("THRIFT_BUILD_TESTS", "0") == "1":
        test_extensions = [
            Extension(
                "thrift.python.test.request_context_extractor.request_context_extractor",
                sources=[
                    "thrift/python/test/request_context_extractor/request_context_extractor.pyx"
                ],
                **common_options,
            ),
            Extension(
                "thrift.python.test.python_async_processor_factory_test",
                sources=["thrift/python/test/python_async_processor_factory_test.pyx"],
                **common_options,
            ),
            Extension(
                "thrift.python.test.typeinfo_test",
                sources=["thrift/python/test/typeinfo_test.pyx"],
                **common_options,
            ),
            # client/test Cython helpers (thrift.python.* namespace for internal use)
            Extension(
                "thrift.python.client.test.event_handler_helper",
                sources=["thrift/python/client/test/event_handler_helper.pyx"],
                **common_options,
            ),
            Extension(
                "thrift.python.client.test.exceptions_helper",
                sources=["thrift/python/client/test/exceptions_helper.pyx"],
                **common_options,
            ),
            # client/test Cython helpers (thrift.lib.python.* namespace for test imports)
            Extension(
                "thrift.lib.python.client.test.event_handler_helper",
                sources=["thrift/lib/python/client/test/event_handler_helper.pyx"],
                **common_options,
            ),
            Extension(
                "thrift.lib.python.client.test.exceptions_helper",
                sources=["thrift/lib/python/client/test/exceptions_helper.pyx"],
                **common_options,
            ),
            Extension(
                "thrift.lib.python.client.test.client_event_handler.helper",
                sources=[
                    "thrift/lib/python/client/test/client_event_handler/helper.pyx"
                ],
                **common_options,
            ),
            # event_handlers/helper extension for client_server tests
            Extension(
                "thrift.lib.python.test.event_handlers.helper",
                sources=["thrift/lib/python/test/event_handlers/helper.pyx"],
                **common_options,
            ),
            # metadata_response extension for metadata response tests
            # Uses header-only C++ implementation in metadata_response.h
            Extension(
                "thrift.lib.python.test.metadata_response.metadata_response",
                sources=[
                    "thrift/lib/python/test/metadata_response/metadata_response.pyx"
                ],
                **common_options,
            ),
        ]

        # Filter to extensions whose source files exist
        available = {ext for ext in test_extensions if os.path.exists(ext.sources[0])}
        missing_names = {ext.name for ext in test_extensions if ext not in available}

        if missing_names:
            print(
                f"WARNING: THRIFT_BUILD_TESTS=1 but {len(missing_names)} test extension(s) missing source files:"
            )
            for name in sorted(missing_names):
                print(f"  - {name}")

        print(f"Building {len(available)} test extension(s)")
        exts.extend(available)
    else:
        print("Skipping test extensions (THRIFT_BUILD_TESTS not set)")

    # Base packages always included
    packages = [
        "thrift",
        "thrift.python",
        "thrift.python.any",
        "thrift.python.reflection",
        "thrift.python.client",
        "thrift.python.client.py_bridge",
        "thrift.python.conformance",
        "thrift.python.schema",
        "thrift.python.server_impl",
        "thrift.python.server_impl.interceptor",
        "thrift.python.streaming",
        "thrift.py3",
        "thrift.lib",
        "thrift.lib.python",
        "apache.thrift.metadata",
        # Folly Python bindings bundled into thrift wheel
        # (folly doesn't build a wheel yet)
        "folly",
    ]

    # Test-only package (directory created by test symlinks)
    if os.environ.get("THRIFT_BUILD_TESTS", "0") == "1":
        packages.append("thrift.lib.python.client")

    # API headers can contain a C++ declaration preamble before Cython's
    # generated-file marker. Remove these private build-dir outputs and their
    # translation units so cythonize regenerates them instead of rejecting its
    # own previous output.
    for api_source, _ in API_MODULES:
        generated_cpp = Path("generated") / Path(api_source).with_suffix(".cpp")
        for generated_path in (
            generated_cpp,
            generated_cpp.with_suffix(".h"),
            generated_cpp.with_name(f"{generated_cpp.stem}_api.h"),
        ):
            generated_path.unlink(missing_ok=True)

    setup(
        name="thrift",
        version="0.0.1",
        packages=packages,
        package_data={"": ["*.pyi", "*.pxd", "*.pyx", "*.h", "*.so", "*.dylib", "py.typed"]},
        setup_requires=["cython"],
        zip_safe=False,
        ext_modules=cythonize(
            exts,
            compiler_directives={"language_level": 3},
            build_dir="generated",
            include_path=include_dirs,  # Allow Cython to find folly .pxd files
        ),
    )
