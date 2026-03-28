
import sys
import os
import logging

logger = logging.getLogger()

path = os.getenv('PATH')
if 'package/bin' not in path:
    os.environ['PATH'] += ':' + os.path.join(os.getcwd(), "package/bin")

for subdir in ['package','handlers']:
    package_dir = os.path.join(os.getcwd(), subdir)
    if package_dir not in sys.path:
        sys.path.append(package_dir)

from importlib import import_module
module_versions = {}
for module in ['numpy','msaexp','grizli','astropy']:
    try:
        mod = import_module(module)
        module_versions[module] = mod.__version__
    except ImportError:
        module_versions[module] = None

print(module_versions)

os.system('aws s3 ls | tail -3')

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

