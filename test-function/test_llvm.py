
import sys
import os

sys.path.append(os.path.join(os.getcwd(), 'package_llvm'))

os.system('cp package_llvm/llvmlite/binding/libLLVM-16.so /usr/lib/')

import numba
print(f'numba: {numba.__version__} {numba.__file__}')