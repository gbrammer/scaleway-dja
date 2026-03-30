
import sys
import os
import logging
import glob

logger = logging.getLogger()

package_path = None
for p in ['function/package', 'package']:
    if os.path.exists(p):
        package_path = p

# os.system('pip install awscli')

print(f'package_path: {package_path}')

package_bin = os.path.join(os.getcwd(), package_path, "bin")

path = os.getenv('PATH')
if package_bin not in path:
    os.environ['PATH'] += ':' + package_bin

print(f"$PATH: {os.environ['PATH']}")

for subdir in ['package','handlers']:
    package_dir = os.path.join(
        os.getcwd(), os.path.dirname(package_path), subdir
    )
    if package_dir not in sys.path:
        sys.path.append(package_dir)

print(f"sys.path: {sys.path}")

for p in sys.path:
    file_ = glob.glob(os.path.join(package_path, "eazy"))
    if len(file_) > 0:
        print("eazy: ", file_)
        break

os.system('which python')

os.system('aws s3 ls | tail -3')

if '--pathonly' in sys.argv:
    sys.exit()

print(f"PWD: {os.getcwd()}")

from importlib import import_module
module_versions = {}
for module in ['numpy','msaexp','grizli','astropy','numba']:
    # mod = import_module(module)
    try:
        mod = import_module(module)
        module_versions[module] = mod.__version__
    except ImportError:
        module_versions[module] = None

print(module_versions)

import eazy

eazy.fetch_eazy_photoz()

if '--imports' in sys.argv:
    sys.exit()
    
#######

event = {
    "msacombine": True,
    "root": "gds-barrufet-s156-v4",
    "key": "2198_2735"
}

from grizli.aws import db
from msaexp.cloud import combine

obj = db.SQL(f"""
SELECT * FROM nirspec_extractions_helper
WHERE root = '{event["root"]}' AND key = '{event["key"]}'
""")

args = dict(obj[0])
for k in ['rowid','status','count']:
    args[k] = int(args[k])
for k in ['ctime']:
    args[k] = float(args[k])

combine.handle_spectrum_extraction(**args)

##### Redshift
from grizli.aws import db
from msaexp.cloud import redshift
import msaexp.cloud.utils

import eazy

eazy.fetch_eazy_photoz()

event = {
    'zfile': 'gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits',
    # 'log_level': logging.INFO,
}

obj = db.SQL(f"""
SELECT * FROM nirspec_redshift_handler
WHERE file = '{event["zfile"]}'
""")

args = dict(obj[0])

logger.info(f"{args}")

res = redshift.handle_nirspec_redshift(
    args, ACL='public-read', clean=False
)

logger.info("handle_nirspec_redshift finished")

