import os
from grizli import jwst_utils
import mastquery.utils

rate_file = "jw06579001001_02101_00001_nrs1_rate.fits"

_ = mastquery.utils.download_from_mast([rate_file])

for context in ["jwst_1225.pmap", "jwst_1303.pmap"]:
    os.environ["CRDS_CONTEXT"] = os.environ["CRDS_CTX"] = context
    jwst_utils.set_crds_context()

    from jwst.assign_wcs import AssignWcsStep
    import jwst.datamodels

    with jwst.datamodels.open(rate_file) as dm:
        input_wcs = AssignWcsStep().run(dm)

os.remove(rate_file)
