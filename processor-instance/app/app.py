import os
import json
import logging
import time
import traceback
import sys
import importlib
import socket
import secrets

try:
    import boto3

    from grizli.aws import db
    from grizli import utils

    from msaexp.cloud import ifu, msa

except ImportError:
    # ignore for now
    ifu = msa = None
    pass

try:
    from grizli.aws import visit_processor
except ImportError:
    visit_processor = None

import logging_loki
from flask import Flask, request


def get_hashroot():
    hash_key = secrets.token_urlsafe(16)[:6]
    return hash_key.lower().replace("-", "x")


THIS_HOST = socket.gethostname()
if "deployment" in THIS_HOST:
    THIS_HOST = "deployment-" + THIS_HOST.split("-")[-1]

THIS_HASH = f"[{get_hashroot()} {THIS_HOST}]".replace(
    "Gabriels-MacBook-Pro.local", "macbook-pro.local"
)

DEFAULT_PORT = "8080"

app = Flask(__name__)

try:
    handler_kwargs = dict(
        url=f"{os.getenv('COCKPIT_LOG_URL')}/loki/api/v1/push",
        tags={"job": "logs_from_python"},
        auth=(os.getenv('COCKPIT_API_KEY'), os.getenv('COCKPIT_LOG_TOKEN')),
        # auth=(os.getenv("COCKPIT_LOG_TOKEN")),
        version="1",
    )

    has_key = {}

    keyfail = False
    for key in [
        "COCKPIT_LOG_URL",
        "COCKPIT_LOG_TOKEN",
        # 'COCKPIT_API_KEY',
    ]:
        if os.getenv(key) is None:
            has_key[key] = False
            print(f"env: {key} not set")
            keyfail = True
        else:
            has_key[key] = True

    if keyfail:
        raise ValueError

    log_formatter = logging.Formatter(
        THIS_HASH + " - %(name)s - %(levelname)s -  %(message)s"
    )

    handler = logging_loki.LokiHandler(**handler_kwargs)
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(log_formatter)
    # logger.addHandler(handler)

    # ch = logging.StreamHandler()
    # ch.setLevel(logging.DEBUG)
    # ch.setFormatter(log_formatter)
    #
    # logger.addHandler(ch)
    #
    # logger.info(f"initialize logger")

    has_loki_logger = True

except:

    has_loki_logger = False

app.logger.setLevel(logging.DEBUG)
app.logger.debug(f"has_loki_logger: {has_loki_logger}")
app.logger.debug(f"log hash: {THIS_HASH}")

if has_loki_logger:
    app.logger.addHandler(handler)
    app.logger.setLevel(logging.DEBUG)

    if ifu is not None:
        ifu.LOGGER.addHandler(handler)
        ifu.LOGGER.setLevel(logging.DEBUG)

    if msa is not None:
        msa.LOGGER.addHandler(handler)
        msa.LOGGER.setLevel(logging.DEBUG)

modules = ["grizli", "msaexp", "jwst", "numpy"]
module_versions = {}
for mod in modules:
    try:
        module_versions[mod] = importlib.import_module(mod).__version__
    except ImportError:
        module_versions[mod] = None

app.logger.info(f"modules: {json.dumps(module_versions)}")

# logger.root.level = logging.DEBUG


@app.route("/", methods=["GET", "POST"])
def app_root():

    app.logger.info(f"request args: {json.dumps(request.args)}")

    os.chdir("/GrizliImaging/")

    if request.method == "POST":
        json_data = json.loads(request.data.replace(b",\n}", b"}"))

        if 0:
            raise ValueError(f"xxx raw request.data: {request.data}")

        POST = f"POST: {json_data}"

        app.logger.info(f"post data: {json.dumps(json_data)}")

        if "runmode" in json_data:
            runmode = json_data.pop("runmode")

            initialize_with_sleep()

            if runmode == "initialize":
                initialize_with_sleep(**json_data)
            elif runmode == "ifu":
                run_one_ifu(**json_data)
            elif runmode == "ifu-product":
                run_one_ifu_product(**json_data)
            elif runmode == "msa":
                run_one_msa(**json_data)
            elif runmode == "assoc":
                run_one_assoc(**json_data)
            elif runmode == "another":
                another_function(**json_data)
            else:
                app.logger.error(f"runmode={runmode} not recognized")

    else:
        POST = "GET"

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


def initialize_with_sleep(tmax=10, **json_data):
    """ """
    import time
    import numpy as np

    sleep_time = np.random.rand() * tmax
    app.logger.info(
        f"initialize: {json.dumps(json_data)} + sleep for {sleep_time:.2f} s"
    )

    time.sleep(sleep_time)


def another_function(**json_data):
    """
    Test for logging
    """
    app.logger.info(f"another_function: {json.dumps(json_data)}")


def run_one_ifu(**json_data):
    """
    Run a file with status = 0
    """

    if "sync" not in json_data:
        json_data["sync"] = True

    if "clean" not in json_data:
        json_data["clean"] = 3

    # instance_hash = get_hashroot()
    app.logger.info(f"run_one_preprocess_ifu: {json.dumps(json_data)}")

    if "rowid" not in json_data:
        app.logger.error(f"run_one_preprocess_ifu: 'rowid' not specified")
        return False

    lockfile = os.path.join("/GrizliImaging", "ifu_{rowid}.lock".format(**json_data))

    if os.path.exists(lockfile) & ("force" not in json_data):
        app.logger.critical(f"run_one_preprocess_ifu: {lockfile} found")
        return False

    with open(lockfile, "w") as fp:
        fp.write(time.ctime() + "\n")

    try:
        row = ifu.run_one_preprocess_ifu(**json_data)
    except Exception as exc:
        exc_info = sys.exc_info()
        exc_report = "".join(traceback.format_exception(*exc_info))
        app.logger.error(f"run_one_preprocess_ifu: {exc_report}")

    app.logger.info(f"run_one_preprocess_ifu: complete")
    os.remove(lockfile)


def run_one_ifu_product(**json_data):
    """
    Run a file with status = 0
    """

    if "sync" not in json_data:
        json_data["sync"] = True

    if "clean" not in json_data:
        json_data["clean"] = 3

    # instance_hash = get_hashroot()
    app.logger.info(f"run_one_ifu_product: {json.dumps(json_data)}")

    if "rowid" not in json_data:
        app.logger.error(f"run_one_ifu_product: 'rowid' not specified")
        return False

    lockfile = os.path.join(
        "/GrizliImaging", "ifu_product_{rowid}.lock".format(**json_data)
    )

    if os.path.exists(lockfile) & ("force" not in json_data):
        app.logger.critical(f"run_one_preprocess_ifu: {lockfile} found")
        return False

    with open(lockfile, "w") as fp:
        fp.write(time.ctime() + "\n")

    try:
        row = ifu.run_one_products_ifu(**json_data)
    except Exception as exc:
        exc_info = sys.exc_info()
        exc_report = "".join(traceback.format_exception(*exc_info))
        app.logger.error(f"run_one_ifu_product: {exc_report}")

    app.logger.info(f"run_one_ifu_product: complete")
    os.remove(lockfile)


# @app.route('/msa', methods=["GET", "POST"])
def run_one_msa(**json_data):
    """
    Run a file with status = 0
    """

    if "sync" not in json_data:
        json_data["sync"] = True

    app.logger.info(f"run_one_msa_preprocess: {json.dumps(json_data)}")

    if "file" not in json_data:
        app.logger.error(f"run_one_msa_preprocess: 'file' not specified")
        return False

    lockfile = os.path.join(
        "/GrizliImaging", "msa_" + json_data["file"].replace("rate.fits", "rate.lock")
    )

    if os.path.exists(lockfile) & ("force" not in json_data):
        app.logger.critical(f"run_one_msa_preprocess: {lockfile} found")
        return False

    with open(lockfile, "w") as fp:
        fp.write(time.ctime() + "\n")

    try:
        row = msa.run_one_msa_preprocess(**json_data)
    except Exception as exc:
        exc_info = sys.exc_info()
        exc_report = "".join(traceback.format_exception(*exc_info))
        app.logger.error(f"run_one_msa_preprocess: {exc_report}")

    app.logger.info(f"run_one_msa_preprocess: complete")
    os.remove(lockfile)


def run_one_assoc(**json_data):
    """
    Run a file with status = 0
    """

    if "sync" not in json_data:
        json_data["sync"] = True

    if "clean" not in json_data:
        json_data["clean"] = 3

    # instance_hash = get_hashroot()
    app.logger.info(f"run_one_assoc: {json.dumps(json_data)}")

    if visit_processor is None:
        app.logger.critical(
            f"run_one_assoc: failed to import grizli.aws.visit_processor"
        )
        return False

    if "assoc_name" not in json_data:
        app.logger.critical(f"run_one_assoc: 'assoc_name' not specified")
        return False

    assoc = json_data.pop("assoc_name")

    lockfile = os.path.join("/GrizliImaging", f"assoc_{assoc}.lock")

    if os.path.exists(lockfile) & ("force" not in json_data):
        app.logger.critical(f"run_one_assoc: {lockfile} found")
        return False

    with open(lockfile, "w") as fp:
        fp.write(time.ctime() + "\n")

    try:
        visit_processor.process_visit(assoc, **json_data)
        # pass

    except Exception as exc:
        exc_info = sys.exc_info()
        exc_report = "".join(traceback.format_exception(*exc_info))
        app.logger.error(f"run_one_assoc: {exc_report}")

    app.logger.info(f"run_one_assoc: {json.dumps(json_data)}")
    app.logger.info(f"run_one_assoc: complete")
    os.remove(lockfile)


if __name__ == "__main__":
    # app.run(host='0.0.0.0', port=8080)

    json_data = {"message": "local_test"}

    _ = initialize_with_sleep(tmax=16)

    #####
    # IFU exposure preprocessing
    #####
    if "--ifu" in sys.argv:
        if "--fixed" in sys.argv:
            # 15601 jw05766001001_02101_00005_nrs1
            # 14390 jw06579001001_02101_00001
            json_data["rowid"] = 14390

        if "rowid" not in json_data:
            rows = db.SQL(
                "select rowid from nirspec_ifu_exposures where status = 0 ORDER BY RANDOM()"
            )

            finished_file = os.path.join(
                "/GrizliImaging", "ifu_finished.txt"
            )
            if len(rows) == 0:
                with open(finished_file, "a") as fp:
                    fp.write(time.ctime() + "\n")

                print("Nothing to do for nirspec_ifu_exposures")
                sys.exit()
            else:
                if os.path.exists(finished_file):
                    os.remove(finished_file)

            json_data["rowid"] = int(rows["rowid"][0])

        run_one_ifu(**json_data)

    #####
    # IFU combined product
    #####
    elif "--ifu-product" in sys.argv:
        # prism test cube-03181001001_prism-clear_twa-28
        if "--fixed" in sys.argv:
            json_data["rowid"] = 594

        if "rowid" not in json_data:
            rows = db.SQL(
                "select rowid from nirspec_ifu_products where status = 0 ORDER BY RANDOM()"
            )

            finished_file = os.path.join(
                "/GrizliImaging", "ifu-products_finished.txt"
            )
            if len(rows) == 0:
                with open(finished_file, "a") as fp:
                    fp.write(time.ctime() + "\n")

                print("Nothing to do for nirspec_ifu_products")
                sys.exit()
            else:
                if os.path.exists(finished_file):
                    os.remove(finished_file)

            json_data["rowid"] = int(rows["rowid"][0])
        
        run_one_ifu_product(**json_data)

    elif "--ifu-anim" in sys.argv:
        import cube_line_animation
        if "--all" in sys.argv:
            result = "start"
            while result is not None:
                result = cube_line_animation.run_from_args(sys.argv)
                print("xxx result", result)
        else:
            result = cube_line_animation.run_from_args(sys.argv)

    elif "--ifu-anim-all" in sys.argv:
        import cube_line_animation
        result = "start"
        while result is not None:
            result = cube_line_animation.run_from_args(sys.argv)

    elif "--msa-combine" in sys.argv:
        import container
        result = container.run_one_combine()

    elif "--msa-combine-all" in sys.argv:
        import container
        result = "start"
        while result is not None:
            result = container.run_one_combine()

    #####
    # MSA exposure preprocessing
    #####
    elif "--msa" in sys.argv:
        if "--fixed" in sys.argv:
            json_data["file"] = "jw04866002001_03101_00002_nrs2_rate.fits"

        if "file" not in json_data:
            rows = db.SQL(
                "select rate_file, root from preprocess_nirspec where status = 0 ORDER BY RANDOM()"
            )

            finished_file = os.path.join(
                "/GrizliImaging", "msa_finished.txt"
            )
            if len(rows) == 0:
                with open(finished_file, "a") as fp:
                    fp.write(time.ctime() + "\n")

                print("Nothing to do for preprocess_nirspec msa")
                sys.exit()
            else:
                if os.path.exists(finished_file):
                    os.remove(finished_file)

            json_data["file"] = rows["rate_file"][0]

        run_one_msa(**json_data)

    #####
    # Imaging association
    #####
    elif "--assoc" in sys.argv:
        if "--fixed" in sys.argv:
            json_data["assoc_name"] = "j175356p6510_nexus-center-9263-f115w_00634"

        if "assoc_name" not in json_data:
            rows = db.SQL(
                "select assoc_name from assoc_table where status = 0 ORDER BY RANDOM()"
            )

            finished_file = os.path.join(
                "/GrizliImaging", "assoc_finished.txt"
            )
            if len(rows) == 0:
                with open(finished_file, "a") as fp:
                    fp.write(time.ctime() + "\n")

                print("Nothing to do for assoc status=0")
                sys.exit()
            else:
                if os.path.exists(finished_file):
                    os.remove(finished_file)

            json_data["assoc_name"] = rows["assoc_name"][0]

        run_one_assoc(**json_data)

    elif "--another" in sys.argv:

        another_function(**json_data)

    elif "--flask-server" in sys.argv:
        port_env = os.getenv("PORT", DEFAULT_PORT)
        port = int(port_env)
        app.run(debug=True, host="0.0.0.0", port=port)
    
    else:
        print("Couldn't find anything to do for {sys.argv}")
