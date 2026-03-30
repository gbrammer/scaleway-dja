"""
./build.sh
python handlers/handle.py

curl localhost:8080

"""
import sys
import os
import secrets
import socket
import logging

# sys.path.append(os.path.join(os.getcwd(), "package"))

def get_logging_handler():

    import logging_loki

    # raise ValueError
    
    def get_hashroot():
        hash_key = secrets.token_urlsafe(16)[:6]
        return hash_key.lower().replace("-", "x")

    THIS_HOST = socket.gethostname()
    if "deployment" in THIS_HOST:
        THIS_HOST = "deployment-" + THIS_HOST.split("-")[-1]
    elif len(THIS_HOST) > 32:
        THIS_HOST = "sfunc-" + THIS_HOST.split('-')[-1]

    THIS_HASH = f"[{get_hashroot()} {THIS_HOST}]".replace(
        "Gabriels-MacBook-Pro.local", "macbook-pro.local"
    )

    handler_kwargs = dict(
        url=f"{os.getenv('COCKPIT_LOG_URL')}/loki/api/v1/push",
        tags={"job": "logs_from_function"},
        auth=(os.getenv('COCKPIT_API_KEY'), os.getenv('COCKPIT_LOG_TOKEN')),
        version="1",
    )

    log_formatter = logging.Formatter(
        THIS_HASH + " - %(name)s - %(levelname)s -  %(message)s"
    )

    handler = logging_loki.LokiHandler(**handler_kwargs)
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(log_formatter)
    
    return handler


logger = logging.getLogger("func")
logger.setLevel(logging.INFO)

ch = logging.StreamHandler()
ch.setFormatter(logging.Formatter(" - %(name)s - %(levelname)s -  %(message)s"))
logger.addHandler(ch)
logger.root.setLevel(logger.level)

try:
    loki_handler = get_logging_handler()
    logger.addHandler(loki_handler)
except:
    loki_handler = None

logger.info("start")


def install_dependencies(unzip=True, clean=True):
    """
    Download additional package zipfile
    """
    import msaexp.cloud.utils
    if loki_handler is not None:
        msaexp.cloud.utils.LOGGER.addHandler(loki_handler)
        msaexp.cloud.utils.LOGGER.setLevel(logger.level)

    url = "s3://dja-cloud/function/package_msaexp.zip"

    local_file = msaexp.cloud.utils.download_file(
        url,
        env_prefix="SCA_",
    )
    
    file_size = os.stat(local_file).st_size / 1024**2
    logger.info(f"{local_file}: {file_size:.1f}M")
    
    if local_file.endswith('.zip') and unzip:
        logger.info(f"unzip -o -q {local_file} -d /home/app/function")
        os.system(f"unzip -o -q {local_file} -d /home/app/function")
        if clean:
            logger.info(f"remove {local_file}")
            os.remove(local_file)

    os.system("cp /home/app/function/package/llvmlite/binding/libLLVM-16.so /usr/lib/libLLVM-16.so")

    logger.info(
        f"/usr/lib/libLLVM-16.so exists: {os.path.exists('/usr/lib/libLLVM-16.so')}"
    )
    
    logger.info("pip install awscli")
    os.system("pip install awscli")


def check_package():
    """
    Check if `numba` found in package environment and download
    package extension if not
    """
    #scipy_test = os.path.exists("package/scipy/__init__.py")
    # scipy_test |= os.path.exists("function/package/scipy/__init__.py")
    try:
        import numba
        import_test = numba.__version__
    except ImportError:
        import_test = False

    if not import_test:
        install_dependencies()
    
    try:
        import numba
        import_test = numba.__version__
    except ImportError:
        import_test = False

    return import_test


def handle(raw_event, context):
    """
    Function handler
    """
    import glob
    import json
    from importlib import import_module

    if "queryStringParameters" in raw_event:
        event = raw_event["queryStringParameters"]
    else:
        event = raw_event.copy()

    if "log_level" in event:
        logger.setLevel(int(event["log_level"]))

    logger.info(f"event: {json.dumps(event)}")

    # logger.info(f"cwd: {os.getcwd()}")
    # logger.info(f"sys.path: {json.dumps(sys.path)}")
    # logger.info(f"files: {json.dumps(glob.glob('*'))}")
    
    check_package()
    
    module_versions = {}
    for module in ['numpy','msaexp','grizli','astropy']:
        try:
            mod = import_module(module)
            module_versions[module] = mod.__version__
        except ImportError:
            module_versions[module] = None

    logger.info(json.dumps(module_versions))

    import numpy as np
    import msaexp
        
    if "zfile" in event:
        from grizli.aws import db
        from msaexp.cloud import redshift
        import msaexp.cloud.utils

        import eazy

        eazy.fetch_eazy_photoz()

        if loki_handler is not None:
            for child in [msaexp.cloud.utils, redshift]:
                child.LOGGER.addHandler(loki_handler)
                child.LOGGER.setLevel(logger.level)

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

    if "msacombine" in event:

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

        logger.info(f"{args}")
        
        combine.handle_spectrum_extraction(**args)
        
    return {
        "statusCode": 200,
        "body": {
            "message": "\n".join([
                f"numpy version: {np.__version__}",
                f"msaexp version: {msaexp.__version__ } {msaexp.__file__}",
                f"event: {json.dumps(event)}"
            ])
        }
    }
    
if __name__ == "__main__":
    import sys
    import os

    path = os.getenv('PATH')
    if 'package/bin' not in path:
        os.environ['PATH'] += ':' + os.path.join(os.getcwd(), "package/bin")

    for subdir in ['package','handlers']:
        package_dir = os.path.join(os.getcwd(), subdir)
        if package_dir not in sys.path:
            sys.path.append(package_dir)

    from importlib import import_module
    module_versions = {}
    for module in ['numpy','msaexp','grizli','astropy','numba']:
        try:
            mod = import_module(module)
            module_versions[module] = mod.__version__
        except ImportError:
            module_versions[module] = None

    print(module_versions)
     
    try:
        from scaleway_functions_python import local
        local.serve_handler(handle)

    except ImportError:
        # import handle
        # from handle import handle
        import logging
        
        handle(
            {
                'zfile': 'gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits',
                'log_level': logging.INFO,
            },
            {}
        )
        
        event = {
            "msacombine": True,
            "root": "gds-barrufet-s156-v4",
            "key": "2198_2735"
        }