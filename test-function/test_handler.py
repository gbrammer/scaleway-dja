import logging
import sys
sys.path.append("/home/app/function/package")

from handlers.handle import handle

event = {
    "msacombine": True,
    "root": "gds-barrufet-s156-v4",
    "key": "2198_2735"
}
        
handle(event, {})

event = {
    'zfile': 'gds-barrufet-s156-v4_prism-clear_2198_2735.spec.fits',
    'log_level': logging.DEBUG,
}

handle(event, {})