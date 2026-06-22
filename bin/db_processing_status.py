#!/usr/bin/env python

# Query status summary for various types of remote DJA processing
# (assoc, msa, ifu, ifu-product)

import time
import sys

if "--help" in sys.argv:
    print("db_processing_status.py [--skip assoc msa ifu ifu-product] [--only ifu]")
    sys.exit()

from grizli.aws import db
from grizli import utils

queries = ["assoc", "msa", "ifu", "ifu-product"]

if "--skip" in sys.argv:
    i = sys.argv.index('--skip')
    while i < len(sys.argv):
        # print(i, sys.argv[i])
        if sys.argv[i] in queries:
            queries.pop(queries.index(sys.argv[i]))
            # print(queries)
        
        i += 1

if "--only" in sys.argv:
    i = sys.argv.index('--only')
    queries = sys.argv[i+1:]

now = utils.nowtime()
dt = 4

for i, arg in enumerate(sys.argv):
    if arg.startswith("--dt="):
        dt = float(arg.split("=")[-1])

dtu = dt * 86400

def print_header(txt, newline="\n"):
    print(newline + f"{'='*24}{txt:^26}{'='*24}\n")

print('')
print_header(time.ctime())

COLOR_LIST = {
    1: 'yellow',
    0: 'magenta',
    2: 'green',
    22: 'green',
    9: 'red',
    10: 'red',
    5: 'red',
    3: 'red'
}

BG_COLOR_LIST = {
    10: 'white',
    22: 'white',
    5: 'white'
}

def status_color(status, text=None, align='>', strlen=None):
    from colors import color

    if text is None:
        if strlen is None:
            text = status
        else:
            text = f'{{0:{align}{strlen}}}'.format(status)
            
    colortext = color(
        text,
        fg=(COLOR_LIST[int(status)] if int(status) in COLOR_LIST else 'cyan'),
        bg=(BG_COLOR_LIST[int(status)] if int(status) in BG_COLOR_LIST else None)
    )

    return colortext

def status_column(table):

    status = [status_color(str(s)) for s in table['status']]
    table['status'] = status

def pprint(table):
    import numpy as np
    
    clen = [len(c)+2 for c in table.colnames]
    for i, c in enumerate(table.colnames):
        dt = table[c].dtype
        if dt.name.startswith('str'):
            nst = int(dt.name[3:]) // 32
            clen[i] = int(np.maximum(clen[i], nst+2))

    fmt = ' '.join([
        f'{{{i}:{">" if c == "count" else "^"}{clen[i]}}}'
        for i, c in enumerate(table.colnames)
    ])

    rows = []
    rows += [
        fmt.format(*table.colnames),
        fmt.format(*['-' * n for n in clen]),
    ]

    if 'status' in table.colnames:
        si = table.colnames.index('status')
    else:
        si = None
    
    for row in table:
        vals = [row[c] for c in table.colnames]
        if si is not None:
            vals[si] = status_color(row['status'], strlen=8)#text=vals[si])

        rows.append(fmt.format(*vals))

    if si is None:
        print("\n".join(rows))
        return rows
    
    pad_left = np.sum(clen[:si]) + 2 * (si - 1)
    empty = ['=' * n for n in clen]
    rows.append(fmt.format(*([""] * si + empty[si:])))
    uns = utils.Unique(table["status"], verbose=False)
    counts = [""] * len(clen)
    for i, s in enumerate(uns.values):
        counts[si] = status_color(s, strlen=8)
        if "count" in table.colnames:
            counts[si+1] = table["count"][uns[s]].sum()
        elif (si + 1) < len(counts):
            counts[si+1] = uns.counts[i]
        else:
            counts.append(uns.counts[i])
            if i == 0:
                fmt += '   {x}'.replace("x", f"{len(counts)-1}")
                # print("xxx", fmt)

        rows.append(fmt.format(*counts))

    print("\n".join(rows))

    return rows

# assoc
if "assoc" in queries:
    print_header("Imaging associations")

    if "--jwst" in sys.argv:
        extra = " AND instrument_name in ('NIRCAM','MIRI','NIRISS') "

    elif "--xjwst" in sys.argv:
        extra = " AND instrument_name NOT IN ('NIRCAM','MIRI','NIRISS') "
    else:
        extra = ""

    status = db.SQL(f"""
    SELECT proposal_id, filters, status, count(distinct(assoc_name)) from
    (
      SELECT proposal_id,
             assoc_name,
             string_agg(distinct(filter), ' ') as filters,
             status
      FROM assoc_table
      WHERE (status in (0,1) OR modtime > {now.mjd - dt})
      AND (modtime < {now.mjd + dt} OR modtime is null) {extra}
      GROUP BY proposal_id, assoc_name, status
    ) filt
    GROUP BY proposal_id, filters, status
    ORDER BY proposal_id, filters, status
    """)

    if len(status) > 0:
        pprint(status)

if "msa" in queries:
    # MSA
    print_header("Nirspec MSA prep")
    print_header(" - preprocess_nirspec - ", "")

    status = db.SQL(f"""
    SELECT root, substr(rate_file, 3, 5) as proposal_id, grating || '-' || filter as grating, split_part(rate_file, '_', 4) as det, status, count(*) --, max(ctime - {now.unix}) as ctime
    from preprocess_nirspec
    where (status in (0,1) OR ctime > {now.unix - dtu}) """
    f"AND (ctime < {now.unix + dt} OR ctime is NULL)"
    """group by root, status, grating, filter, substr(rate_file, 3, 5), split_part(rate_file, '_', 4) order by substr(rate_file, 3, 5), root, grating, filter, split_part(rate_file, '_', 4), status limit 10
    """)
    status['proposal_id'] = status['proposal_id'].astype(int)

    if len(status) > 0:
        pprint(status)
        # status_column(status)
        # status.pprint(align=['^','>','>','>'])

if "ifu" in queries:
    # IFU
    print_header("Nirspec IFU prep")
    print_header(" - nirspec_ifu_exposures - ")

    status = db.SQL(f"""
    SELECT substr(\"fileSetName\", 3, 5) as proposal_id, grating || '-' || filter as grating, status, count(*)
    from nirspec_ifu_exposures
    where (status in (0,1) OR ctime > {now.unix - dtu}) AND (ctime < {now.unix + dt}) AND ("publicReleaseDate_mjd" < {now.mjd}) AND status not in (71)
    group by status, grating, filter, substr(\"fileSetName\", 3, 5) order by substr(\"fileSetName\", 3, 5), grating, filter, status
    """)

    status['proposal_id'] = status['proposal_id'].astype(int)

    if len(status) > 0:
        pprint(status)

if "ifu-product" in queries:
    # IFU
    print_header("IFU products")

    status = db.SQL(f"""
    SELECT obsid, gfilt as grating, status
    from nirspec_ifu_products
    where (status in (0,1) OR ctime > {now.unix - dtu}) AND (ctime < {now.unix + dt})
    GROUP BY obsid, gfilt, status order by obsid, gfilt, status
    """)

    if len(status) > 0:
        pprint(status)

if "msa-combine" in queries:
    # IFU
    print_header("MSA combine  (nirspec_extractions_helper)")

    status = db.SQL(f"""
    SELECT root, status, count(status)
    from nirspec_extractions_helper
    where status in (110,111) OR (ctime > {now.unix - dtu} AND ctime < {now.unix + dt})
    GROUP BY root, status order by root, status
    """)

    if len(status) > 0:
        pprint(status)

print("\n")