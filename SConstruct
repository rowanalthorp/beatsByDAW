# Thank the AI lords for this one

import os

# Initialize the environment from godot-cpp's SConstruct
env = SConscript("godot-cpp/SConstruct")

# Miniaudio is vendored as a single header.
env.Append(CPPPATH=["third_party/miniaudio"])

# If you are on Windows, you might need specific compiler flags
# if env["platform"] == "windows":
#     env.Append(CCFLAGS=["/EHsc"])

# List all your C++ source files here for Rowan's backend
sources = [
    "src/register_types.cpp",
    "src/test_cpp.cpp",
    "src/audio_engine/miniaudio.cpp",
    "src/audio_engine/audio_device.cpp",
    "src/audio_engine/audio_engine.cpp",
]

# Build the shared library depending on the target platform
library = None
if env["platform"] == "windows":
    library = env.SharedLibrary(
        "bin/daw_backend.windows.template_debug.x86_64.dll",
        source=sources,
    )
elif env["platform"] == "linux":
    library = env.SharedLibrary(
        "bin/daw_backend.linux.template_debug.x86_64.so",
        source=sources,
    )
elif env["platform"] == "macos":
    library = env.SharedLibrary(
        "bin/daw_backend.macos.template_debug.framework/beats_backend.macos.template_debug",
        source=sources,
    )

Default(library)
