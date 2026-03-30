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

import numpy as np

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

    loki_handler = logging_loki.LokiHandler(**handler_kwargs)
    loki_handler.setLevel(logging.DEBUG)
    loki_handler.setFormatter(log_formatter)

except:

    loki_handler = None

app.logger.setLevel(logging.DEBUG)
app.logger.debug(f'has_loki_logger: {loki_handler is not None}')
app.logger.debug(f'log hash: {THIS_HASH}')

if loki_handler is not None:
    app.logger.addHandler(loki_handler)
    app.logger.setLevel(logging.DEBUG)

modules = ['grizli','msaexp','jwst','numpy']
module_versions = {}
for mod in modules:
    try:
        module_versions[mod] = importlib.import_module(mod).__version__
    except ImportError:
        module_versions[mod] = None

# app.logger.info(f"modules: {json.dumps(module_versions)}")

# logger.root.level = logging.DEBUG

def handle(raw_event, context):
    """
    Function handler
    """
    import glob
    import json
    from importlib import import_module
    from grizli.aws import db
    from msaexp.cloud import redshift, combine
    
    if loki_handler is not None:
        
        redshift.LOGGER.addHandler(loki_handler)
        redshift.LOGGER.setLevel(logging.DEBUG)

        combine.LOGGER.addHandler(loki_handler)
        combine.LOGGER.setLevel(logging.DEBUG)

    if "queryStringParameters" in raw_event:
        event = raw_event["queryStringParameters"]
    else:
        event = raw_event.copy()

    result = {"event": event}

    if "log_level" in event:
        # logger.setLevel(int(event["log_level"]))
        app.logger.setLevel(int(event["log_level"]))
        redshift.LOGGER.setLevel(int(event["log_level"]))
        combine.LOGGER.setLevel(int(event["log_level"]))
        
    app.logger.info(f"event: {json.dumps(event)}")

    if event["runmode"] == "msa-redshift":
        
        obj = db.SQL(f"""
        SELECT * FROM nirspec_redshift_handler
        WHERE file = '{event["zfile"]}'
        """)
        
        args = dict(obj[0])
        for k in event:
            args[k] = event[k]

        kwargs = {
            "ACL": "public-read",
            "clean": True,
        }

        for k in kwargs:
            if k in event:
                kwargs[k] = event[k]

        app.logger.info(f"handle_nirspec_redshift({args}, **{kwargs})")

        res = redshift.handle_nirspec_redshift(args, **kwargs)

        if res is not None:
            res = dict(res)

            result["result"] = {k:res[k] for k in ["file", "z"]}

            app.logger.info(
                "handle_nirspec_redshift: {file} z={z:.3f}".format(**res)
            )
        else:
            app.logger.info(
                "handle_nirspec_redshift: null"
            )
            

    elif event["runmode"] == "msa-combine":

        from grizli.aws import db

        obj = db.SQL(f"""
        SELECT * FROM nirspec_extractions_helper
        WHERE root = '{event["root"]}' AND key = '{event["key"]}'
        """)

        args = dict(obj[0])
        for k in ['rowid','status','count']:
            args[k] = int(args[k])
        for k in ['ctime']:
            args[k] = float(args[k])

        app.logger.info(f"handle_spectrum_extraction(**{args})")
        
        try:
            xobj, info, status = combine.handle_spectrum_extraction(**args)
            result["result"] = dict(info[0])
            app.logger.info(
                "handle_spectrum_extraction: {file}".format(**result["result"])
            )
            
        except Exception as exc:
            exc_info = sys.exc_info()
            exc_report = "".join(traceback.format_exception(*exc_info))
            
            app.logger.error(exc_report)
            result["result"] = exc_report

    else:
        result["status"] = None

    return result

def test_handler_combine():
    
    event = {
        "runmode": "msa-combine",
        "root": "gds-barrufet-s156-v4",
        "key": "2198_2735"
    }

    result = handle(event, {})
    print(result)
    return result


def test_handler_redshift():

    event = {
        "runmode": "msa-redshift",
        "zfile": 'gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits',
        "log_level": logging.INFO,
    }

    result = handle(event, {})
    print(result)
    return result


def test_handler():
    
    test_handler_combine()
    
    test_handler_redshift()


@app.route('/', methods=["GET", "POST"])
def process_request():
        
    #app.logger.info(f"request args: {json.dumps(request.args)}")
    #app.logger.info(f"request data: {request.data}")
    # app.logger.info(f"request form: {request.json}")
    #app.logger.info(f"request values: {request.values}")

    os.chdir('/GrizliImaging/')

    if request.method == 'POST':
        try:
            json_data = request.json
        except:
            try:
                json_data = json.loads(request.data.replace(b",\n}",b"}"))
            except:
                json_data = json.dumps(request.args)

        if 0:
            raise ValueError(f'xxx raw request.data: {request.form}')

        POST = f'POST: {json_data}'

        app.logger.info(f"post data: {json.dumps(json_data)}")
        
        if "runmode" in json_data:
            runmode = json_data.pop("runmode")
            if runmode in ["msa-redshift", "msa-combine"]:
                handle(json_data, {})
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

has_loki_logger: {loki_handler is not None}

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
    
    if "--another" in sys.argv:

        another_function(**json_data)

    else:
        port_env =  os.getenv("PORT", DEFAULT_PORT)
        port = int(port_env)
        app.run(debug=True, host="0.0.0.0", port=port)
