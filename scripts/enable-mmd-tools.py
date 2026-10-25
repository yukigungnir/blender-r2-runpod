import addon_utils
import glob
import os
import sys


addon_root = "/opt/blender/5.2/scripts/addons/mmd_tools"
for wheel in glob.glob(os.path.join(addon_root, "wheels", "*.whl")):
    if wheel not in sys.path:
        sys.path.insert(0, wheel)

module = addon_utils.enable("mmd_tools", default_set=False, persistent=False)
if module is None:
    raise RuntimeError("MMD Tools could not be enabled")

print("MMD Tools enabled:", getattr(module, "MMD_TOOLS_VERSION", "unknown"))

