#!/usr/bin/env python

# https://www.scaleway.com/en/docs/cockpit/how-to/send-metrics-logs-to-cockpit/

import subprocess
import json
import logging
import logging_loki
import time
import os
import socket

__all__ = ["get_cockpit_config"]

def get_cockpit_config(log_name="my-first-python-logger", verbose=False):

    proc = subprocess.run(
        "terraform output --json".split(),
        encoding='utf-8', 
        stdout=subprocess.PIPE
    )

    tf = json.loads(proc.stdout)

    if verbose:
        print(f"""
    import logging
    import logging_loki
    import time

    # export COCKPIT_LOG_URL={tf['cockpit_log_url']['value']}
    # export COCKPIT_API_KEY={tf['cockpit_api_key']['value']}
    # export COCKPIT_LOG_TOKEN={tf['cockpit_log_token']['value']}

    handler = logging_loki.LokiHandler(
        url="{tf['cockpit_log_url']['value']}/loki/api/v1/push",
        tags={{"job": "logs_from_python"}},
        auth=("{tf['cockpit_api_key']['value']}", "{tf['cockpit_log_token']['value']}"),
        version="1",
    )

    logger = logging.getLogger("my-first-python-logger")
    logger.addHandler(handler)
        """)

    handler = logging_loki.LokiHandler(
        url=f"{tf['cockpit_log_url']['value']}/loki/api/v1/push",
        tags={"job": "logs_from_python"},
        auth=(tf['cockpit_api_key']['value'], tf['cockpit_log_token']['value']),
        version="1",

    )

    THIS_HOST = socket.gethostname()
    if "deployment" in THIS_HOST:
        THIS_HOST = "deployment-" + THIS_HOST.split("-")[-1]

    THIS_HASH = f"[{THIS_HOST}]".replace(
        "Gabriels-MacBook-Pro.local", "macbook-pro.local"
    )

    log_formatter = logging.Formatter(
        THIS_HASH + " - %(name)s - %(levelname)s -  %(message)s"
    )

    logger = logging.getLogger(log_name)
    
    handler.setLevel(logging.DEBUG)
    handler.setFormatter(log_formatter)
    
    logger.addHandler(handler)
    return logger

if __name__ == "__main__":
    logger = get_cockpit_config(verbose=True)
