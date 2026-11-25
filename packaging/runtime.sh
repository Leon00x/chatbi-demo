# Source this after setting project_root.
python_framework="$project_root/runtime/python"
python_version_dir="$python_framework/Python.framework/Versions/3.14"
export DYLD_FRAMEWORK_PATH="$python_framework"
export DYLD_LIBRARY_PATH="$python_version_dir/lib"
export PYTHONDONTWRITEBYTECODE=1
export PATH="$project_root/runtime/node/bin:$PATH"
