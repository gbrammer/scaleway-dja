"""
Tiles for the cutout server
"""

import time
import os
import glob
import json
import numpy as np
import matplotlib.pyplot as plt
import yaml
import tqdm

import mastquery

from grizli.aws.tile_mosaic import (
    drizzle_tile_subregion,
    reset_locked,
    get_lambda_client,
    send_event_lambda,
    count_locked,
    tile_subregion_wcs,
)

from grizli.aws import db
from grizli import utils

if os.path.exists("/GrizliImaging/"):
    PATH = "/GrizliImaging/Tiles"
else:
    PATH = "/tmp/Tiles"

if not os.path.exists(PATH):
    os.makedirs(PATH)

EVENTS_FILE = os.path.join(PATH, "events.yaml")
print(f"Events: {EVENTS_FILE}")

TILE_LOGFILE = "/tmp/tiles_history.txt"


def log_finished():
    with open(os.path.join(PATH, "finished.txt"), "w") as fp:
        fp.write(time.ctime())

    if os.path.exists(EVENTS_FILE):
        os.remove(EVENTS_FILE)


def query_tile_events(max_count=200):
    nlock, tlock = count_locked()
    if nlock > 0:
        utils.log_comment(
            TILE_LOGFILE, f"Unlock {nlock} locked subtiles.", verbose=True
        )
        reset_locked()
        # utils.log_comment(TILE_LOGFILE, tlock[:10])

    else:
        utils.log_comment(TILE_LOGFILE, "No locked tiles.")

    extra = ""
    # extra = "AND filter like 'F115W%%'"

    progs = ""

    tiles = db.SQL(
        f"""SELECT tile, subx, suby, filter, count(filter) as count, max(instrume) as instrume,
                min(substr(e.file,1,7)) as file0, max(substr(e.file,1,7)) as file1
                FROM mosaic_tiles_exposures t, exposure_files e
                WHERE t.expid = e.eid AND in_mosaic = 0
                {progs}
                AND filter < 'G0' AND e.instrume in ('MIRI','NIRCAM','ACS')
                AND filter not like '%%GRISM%%'
                {extra}
                GROUP BY tile, subx, suby, filter
                ORDER BY filter ASC
                """
    )

    if len(tiles) == 0:
        tiles = db.SQL(
            f"""SELECT tile, subx, suby, filter, count(filter) as count,
                min(substr(e.file,1,7)) as file0, max(substr(e.file,1,7)) as file1
                FROM mosaic_tiles_exposures t, exposure_files e
                WHERE t.expid = e.eid AND in_mosaic = 0
                {progs}
                AND filter < 'G0'
                AND ((filter not like '%%GR150%%' AND filter not like '%%-GRISM%%') OR (filter like 'F356W-GRISMR') OR (filter like 'F444W-GRISMR'))
                AND (e.instrume in ('MIRI'))
                GROUP BY tile, subx, suby, filter
                ORDER BY filter ASC
                """
        )

    utils.log_comment(TILE_LOGFILE, f"Tiles to run: {len(tiles)}", verbose=True)
    utils.Unique(tiles["filter"])

    if len(tiles) == 0:
        log_finished()

    ############
    # Write tile "events" to a local file

    NMAX = len(tiles)

    istart = i = -1

    max_locked = 800

    events = []

    with open(EVENTS_FILE, "w") as fp:
        for i in tqdm.tqdm(range(len(tiles))):
            # i+=1

            if tiles["filter"][i] in ["xF2100W"]:
                continue

            event = dict(
                tile=int(tiles["tile"][i]),
                subx=int(tiles["subx"][i]),
                suby=int(tiles["suby"][i]),
                filter=str(tiles["filter"][i]),
                exposure_count=int(tiles["count"][i]),
                counter=i + 2,
                # clean_flt=clean_flt,
                time=time.ctime(),
            )

            events.append(event)

        yaml.dump(events, fp)

    return events


def run_all_tiles(count=None):
    #############

    # This cell can be copied and run in an ipython terminal on EC2
    # i.e., to run faster with multiple parallel sessions

    def tile_handler(
        event, context, clean_flt=True, skip_existing=False, clean_result=True
    ):

        import os

        import glob
        import time

        import numpy as np
        import scipy
        import grizli

        from grizli.aws import tile_mosaic

        from grizli.aws import db

        db.get_db_engine()

        # tile, subx, suby, filter =  672, 133, 429, 'F160W'

        default_kwargs = {
            "tile": 672,
            "subx": 133,
            "suby": 429,
            "filter": "F160W",
            "kernel": "square",
            "pixfrac": 0.75,
            "clean_flt": clean_flt,
            "verbose": True,
        }

        for k in default_kwargs:
            if k in event:
                default_kwargs[k] = event[k]

        lock_file = "tile.{tile:04d}.{subx:03d}.{suby:03d}.{filter}.lock".format(
            **default_kwargs
        ).lower()

        if os.path.exists(lock_file) & (skip_existing):
            utils.log_comment(
                TILE_LOGFILE, f"{time.ctime()} {lock_file} - skip", verbose=True
            )
            return lock_file

        utils.log_comment(TILE_LOGFILE, f"{time.ctime()} {lock_file}", verbose=True)

        with open(lock_file, "w") as fp:
            fp.write(time.ctime() + "\n")

        print(f"WORKDIR: {os.getcwd()}")

        tile_mosaic.drizzle_tile_subregion(
            **default_kwargs,
            # tile=tile, subx=subx, suby=suby,
            # filter=filter,
            engine=db._ENGINE,
            s3output=None,
            ir_wcs=None,
            make_figure=False,
            skip_existing=skip_existing,
            gzip_output=False,
            query_persistence_pixels=False,
            saturated_lookback=-1,
        )

        output = {
            "numpy": np.__version__,
            "scipy": scipy.__version__,
            "grizli": grizli.__version__,
            #'tile':tile, 'subx':subx, 'suby':suby, 'filter':filter}
        }

        for k in default_kwargs:
            output[k] = default_kwargs[k]

        files = glob.glob(lock_file.split(".lock")[0] + "_*")
        files.sort()

        with open(lock_file, "a") as fp:
            for file in files:
                if clean_result:
                    os.remove(file)
                    utils.log_comment(
                        TILE_LOGFILE, f"    rm {file}", verbose=True
                    )

                fp.write(f"{file}\n")

        return output

    os.chdir(PATH)

    with open(EVENTS_FILE) as fp:
        events = yaml.load(fp, yaml.Loader)

    utils.log_comment(
        TILE_LOGFILE,
        f"\nTotal N={len(events)} events in {EVENTS_FILE}....\n",
        verbose=True,
    )

    lockfiles = glob.glob("*lock")
    utils.log_comment(
        TILE_LOGFILE, f"\nFound N={len(lockfiles)} lock files....\n", verbose=True
    )

    if len(lockfiles) == len(events):
        log_finished()
        return "done"

    # Randomize event list so multiple sessions will run in a different order
    so = np.argsort(np.random.normal(size=len(events)))

    if count is not None:
        so = so[:count]

    utils.log_comment(TILE_LOGFILE, f"\nRun N={len(so)} tiles....\n", verbose=True)

    # Handle pasting individual events into terminal session
    break_threshold = 2000
    # break at the first event with more than break_threshold if 1 else continue
    break_max = 0

    for j in so:
        # break
        if (events[j]["exposure_count"] > break_threshold) & (1):
            utils.log_comment(
                TILE_LOGFILE,
                events[j]["exposure_count"],
                events[j]["filter"],
                verbose=True,
            )
            if break_max:
                break
            else:
                continue

        else:
            if break_max:
                continue

            res = tile_handler(events[j], {}, skip_existing=True, clean_flt=False)

    return events


def wrapper(argv, suffix=""):

    global TILE_LOGFILE

    TILE_LOGFILE = os.path.join(PATH, f"tile_history{suffix}.txt")

    if not os.path.exists(EVENTS_FILE):
        events = query_tile_events()

    if "--count" in argv:
        count = int(argv[argv.index("--count") + 1])
    else:
        count = None

    utils.log_comment(TILE_LOGFILE, f"xxx count: {count}", verbose=True)

    if (PATH == "/tmp/Tiles") & (count is None):
        utils.log_comment(TILE_LOGFILE, "!!! local: count=1", verbose=True)
        count = 1

    run_all_tiles(count=count)


if __name__ == "__main__":
    import sys

    wrapper(sys.argv)
