import os
import json
import logging
import time
import traceback
import sys
import importlib
import socket
import secrets

import boto3

from grizli.aws import db
from grizli import utils

from msaexp.cloud import redshift, combine

import logging_loki
from flask import Flask, request

def get_hashroot():
    hash_key = secrets.token_urlsafe(16)[:6]
    return hash_key.lower().replace("-", "x")

THIS_HOST = socket.gethostname()
if "deployment" in THIS_HOST:
    THIS_HOST = "deployment-" + THIS_HOST.split("-")[-1]

THIS_HASH = f"[{get_hashroot()} {THIS_HOST}]".replace(
    "Gabriels-MacBook-Pro.local",
    "macbook-pro.local"
)

DEFAULT_PORT = "8080"

app = Flask(__name__)

try:
    handler_kwargs = dict(
        url=f"{os.getenv('COCKPIT_LOG_URL')}/loki/api/v1/push",
        tags={"job": "logs_from_container"},
        auth=(os.getenv('COCKPIT_API_KEY'), os.getenv('COCKPIT_LOG_TOKEN')),
        version="1",
    )

    has_key = {}
    
    keyfail = False
    for key in [
        'COCKPIT_LOG_URL',
        'COCKPIT_LOG_TOKEN',
        'COCKPIT_API_KEY',
    ]:
        if os.getenv(key) is None:
            has_key[key] = False
            print(f'env: {key} not set')
            keyfail = True
        else:
            has_key[key] = True
    
    if keyfail:
        raise ValueError

    log_formatter = logging.Formatter(
        THIS_HASH + ' - %(name)s - %(levelname)s -  %(message)s'
    )

    handler = logging_loki.LokiHandler(**handler_kwargs)
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(log_formatter)
    
    has_loki_logger = True

except:

    has_loki_logger = False

app.logger.setLevel(logging.DEBUG)
app.logger.debug(f'has_loki_logger: {has_loki_logger}')
app.logger.debug(f'log hash: {THIS_HASH}')

if has_loki_logger:
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.DEBUG)

    redshift.LOGGER.addHandler(handler)
    redshift.LOGGER.setLevel(logging.DEBUG)

    combine.LOGGER.addHandler(handler)
    combine.LOGGER.setLevel(logging.DEBUG)

modules = ['grizli','msaexp','jwst','numpy']
module_versions = {}
for mod in modules:
    try:
        module_versions[mod] = importlib.import_module(mod).__version__
    except ImportError:
        module_versions[mod] = None

app.logger.info(f"modules: {json.dumps(module_versions)}")

# logger.root.level = logging.DEBUG

def handle(raw_event, context):
    """
    Function handler
    """
    import glob
    import json
    from importlib import import_module
    from grizli.aws import db

    if "queryStringParameters" in raw_event:
        event = raw_event["queryStringParameters"]
    else:
        event = raw_event.copy()

    if "log_level" in event:
        # logger.setLevel(int(event["log_level"]))
        app.logger.setLevel(int(event["log_level"]))
        redshift.LOGGER.setLevel(int(event["log_level"]))
        combine.LOGGER.setLevel(int(event["log_level"]))
        
    logger.info(f"event: {json.dumps(event)}")

    if event["runmode"] == "msa-redshift":
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

    elif event["runmode"] == "msa-combine":

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
        
        res = combine.handle_spectrum_extraction(**args)

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


def test_handler():
    
    event = {
        "runmode": "msa-combine",
        "root": "gds-barrufet-s156-v4",
        "key": "2198_2735"
    }

    handle(event, {})

    event = {
        "runmode": "msa-redshift",
        "zfile": 'gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits',
        "log_level": logging.INFO,
    }

    handle(event, {})


@app.route('/', methods=["GET", "POST"])
def process_request():
        
    app.logger.info(f"request args: {json.dumps(request.args)}")

    os.chdir('/GrizliImaging/')

    if request.method == 'POST':
        json_data = json.loads(request.data.replace(b",\n}",b"}"))

        if 0:
            raise ValueError(f'xxx raw request.data: {request.data}')

        POST = f'POST: {json_data}'

        app.logger.info(f"post data: {json.dumps(json_data)}")
        
        if "runmode" in json_data:
            runmode = json_data.pop("runmode")
            if runmode in ["msa-redshift", "msa-combine"]:
                handle(json_data)
            elif runmode == "another":
                another_function(**json_data)
            else:
                app.logger.error(
                    f"runmode={runmode} not recognized"
                )

    else:
        POST = 'GET'
        
    doc = f"""<!DOCTYPE html>
<html>
<body>
<h1>Hello from Flask on Scaleway Serverless!</h1>

has_loki_logger: {has_loki_logger}

module_versions:

{json.dumps(module_versions)}

has_keys: {json.dumps(has_key)}

request args: {json.dumps(request.args)}

{POST}

</body>
</html>"""
    return doc

def initialize_with_sleep(**json_data):
    """
    """
    import time
    import numpy as np
    
    sleep_time = 5 + np.random.rand() * 5
    app.logger.info(
        f"initialize: {json.dumps(json_data)} + sleep for {sleep_time:.2f} s"
    )
    
    time.sleep(sleep_time)

def another_function(**json_data):
    """
    Test for logging
    """
    app.logger.info(f"another_function: {json.dumps(json_data)}")


if __name__ == '__main__':
    # app.run(host='0.0.0.0', port=8080)

    json_data = {"message": "local_test"}
    
    if "--ifu" in sys.argv:
        if "--fixed" in sys.argv:
            # 15601 jw05766001001_02101_00005_nrs1
            # 14390 jw06579001001_02101_00001

            json_data["rowid"] = 14390

        run_one_ifu(**json_data)

    elif "--ifu-product" in sys.argv:
        # prism test cube-03181001001_prism-clear_twa-28
        json_data["rowid"] = 594
        run_one_ifu_product(**json_data)

    elif "--msa" in sys.argv:
        if "--fixed" in sys.argv:
            json_data["file"] = "jw04866002001_03101_00002_nrs2_rate.fits"

        if "file" not in json_data:
            rows = db.SQL("select rate_file, root from preprocess_nirspec where status = 0 ORDER BY RANDOM()")
            if len(rows) == 0:
                exit
            
            
        run_one_msa(**json_data)

    elif "--assoc" in sys.argv:
        if "--fixed" in sys.argv:
            json_data["assoc_name"] = "j175356p6510_nexus-center-9263-f115w_00634"

        run_one_assoc(**json_data)

    elif "--another" in sys.argv:

        another_function(**json_data)

    else:
        port_env =  os.getenv("PORT", DEFAULT_PORT)
        port = int(port_env)
        app.run(debug=True, host="0.0.0.0", port=port)
