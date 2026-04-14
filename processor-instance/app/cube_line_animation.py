import os
import sys
import glob
from tqdm import tqdm
import time

import numpy as np
import matplotlib.pyplot as plt

from skimage.io import imsave
from astropy.visualization import make_lupton_rgb
import subprocess
from grizli import utils
import astropy.io.fits as pyfits
from astropy.utils.data import download_file

import grizli.jwst_utils
grizli.jwst_utils.set_quiet_logging()

lw, lr = utils.get_line_wavelengths()

def make_cube_line_animation(outroot="cube-05645164001_g395h-f290lp_p173+48", rest_wave=5008.24, label="oiii", dv_max=1000, s=0.5, clean=True, sync=True, **kwargs):
    """
    """
    from grizli.pipeline import auto_script
    from grizli.aws import db
    # os.chdir("/Users/gbrammer/Research/JWST/Projects/NIRSpec/IFU-Recalib")
    # os.chdir("/GrizliImaging")

    for BASE_PATH in ['/GrizliImaging','/Users/gbrammer/Research/GrizliImaging/']:
        if os.path.exists(BASE_PATH):
            break
        
    PATH = os.path.join(BASE_PATH, 'IFU-Redshifts')

    print(PATH)

    if not os.path.exists(PATH):
        os.makedirs(PATH)

    os.chdir(PATH)
    lockfile = outroot + ".lock"
    if os.path.exists(lockfile):
        print(f"lockfile {lockfile} found")
        return None

    with open(lockfile, "w") as fp:
        fp.write(time.ctime() + "\n")

    local_file = cube_file = outroot + ".fits"

    row = db.SQL(f"select * from nirspec_ifu_products where outroot = '{outroot}'")[0]
    row["redshift"]

    s3_file = "s3://msaexp-nirspec/ifu_exposures/jw{obsid}/{outroot}.fits".format(**row).replace("%2B","+")
    s3_path = "s3://msaexp-nirspec/ifu_exposures/jw{obsid}/".format(**row).replace("%2B","+")

    print(s3_file)
    print(f"\n{outroot}     z={row['redshift']:.3f}    file exists: {os.path.exists(local_file)}")
    
    if os.path.exists(local_file):
        cube_hdu = pyfits.open(local_file)
    else:
        cube_hdu = pyfits.open(download_file(FITS_URL, cache=True))

    cube_wave = utils.GTable(cube_hdu['WCS-TAB'].data)['WAVELENGTH'] / 1.e4

    # cube_hdu[0].header['GRATING']
    
    dv = (cube_wave / (1 + row["redshift"]) * 1.e4 - rest_wave) / rest_wave * 3.e5
    irange = np.where(np.abs(dv) < dv_max)[0]
    ii = int(np.mean(irange))
    
    di = 2
    # s = 0.5
    
    cube_hdu = pyfits.open(cube_file)
    cube_wave = utils.GTable(cube_hdu['WCS-TAB'].data)['WAVELENGTH'] / 1.e4

    st = np.nanmedian(cube_hdu['SCI'].data[irange[0]-10:irange[-1]+10,:,:], axis=(0))

    stw = np.nansum(cube_hdu['WHT'].data[irange[0]-10:irange[-1]+10,:,:], axis=(0))
    st = np.nansum((cube_hdu['SCI'].data * cube_hdu['WHT'].data)[irange[0]-10:irange[-1]+10,:,:], axis=(0)) / stw

    st_percentiles = np.nanpercentile(st, [1, 99])

    # ! rm /tmp/test_*png
    png_files = sorted(glob.glob(f"{outroot}_frame_*.png"))
    for file in png_files:
        os.remove(file)

    imed = np.nanmedian(cube_hdu['SCI'].data[irange,:,:])
    iperc = np.nanpercentile(cube_hdu['SCI'].data[irange,:,:], [1, 50, 99])

    for j, i in tqdm(enumerate(irange)):
        # print(i)
        if 1:
            try:
                image = make_lupton_rgb(
                    cube_hdu['SCI'].data[i+di,:,:]*1.0,
                    cube_hdu['SCI'].data[i,:,:]*1.1,
                    cube_hdu['SCI'].data[i-di,:,:]*1.2,
                    stretch=0.1*s, minimum=-0.02
                )
                cmap = None
            except ValueError:
                continue
        else:
            imax = (iperc[2] - iperc[1]) * 1.5 * 8
            image = (cube_hdu['SCI'].data[i,:,:] + 0.05 * imax) / imax  / 1.05 * 255
            cmap = 'magma_r'
    
        # imsave(f"/tmp/test_{j:04d}.png", image[::-1,:,:])

        nw, ny, nx = cube_hdu['SCI'].shape
    
        # fig, axes = plt.subplots(1,2,figsize=(8,4), sharex=True, sharey=True)
        fig, axes = plt.subplots(1,2,figsize=(8,4*ny/nx), sharex=True, sharey=True)
        ax = axes[0]
        ifill = image / 255.
        ifill[ifill == 0] = np.nan
        ax.imshow(ifill, cmap=cmap, vmin=0, vmax=1)
        sh = ifill.shape
        j0 = j/len(irange)*sh[1]
        ysh = sh[0]*0.005
        ax.plot([0, j0], [ysh, ysh], marker='None', color='0.5', zorder=110)
        ax.scatter(j0, ysh, marker='>', color='0.5', zorder=100, s=18)

        ax.text(0.01, 0.02, f"{cube_wave[irange[0]]:6.4f}", ha='left', va='bottom', transform=ax.transAxes, fontsize=8, color='k', zorder=100,
                bbox=dict(fc='w', ec='None', alpha=0.8)
                )
        ax.text(0.99, 0.02, f"{cube_wave[irange[-1]]:6.4f}", ha='right', va='bottom', transform=ax.transAxes, fontsize=8, color='k', zorder=100,
                bbox=dict(fc='w', ec='None', alpha=0.8)
                )
        ax.text(0.5, 0.02, f"{cube_wave[i]:6.4f}", ha='center', va='bottom', transform=ax.transAxes, fontsize=10, color='k', zorder=100,
                bbox=dict(fc='w', ec='None', alpha=0.8)
                )
        ax = axes[1]
        if 0:
            ax.imshow(st, cmap='bone_r', vmin=st_percentiles[0], vmax=st_percentiles[1])
        else:
            ax.imshow(np.log(st + 0.05*st_percentiles[1]), cmap='bone_r', vmin=np.log(st_percentiles[1]*0.03), vmax=np.log(st_percentiles[1]))

        fig.text(0.99, 0.06 * nx / ny, cube_file, ha='right', va='bottom', transform=fig.transFigure, fontsize=8, color='k', zorder=100,
                 bbox=dict(fc='w', ec='None', alpha=0.8)
                )
        fig.text(0.99, 0.01 * nx / ny, time.ctime(), ha='right', va='bottom', transform=fig.transFigure, fontsize=8, color='k', zorder=100,
                              bbox=dict(fc='w', ec='None', alpha=0.8)
    )

        for ax in axes:
            ax.axis('off')

        fig.tight_layout(pad=0)

        fig.savefig(f"{outroot}_frame_{j:04d}.png", dpi=72)
        plt.close(fig)


    png_files = sorted(glob.glob(f"{outroot}_frame_*.png"))
    png_files.sort()

    output_gif = cube_file.replace(".fits", f".{label}.anim.gif")

    # Create the animated GIF using ImageMagick's convert command
    # -delay 10 sets the delay between frames (in 1/100ths of a second)
    # -loop 0 makes the animation loop forever
    subprocess.run([
        "magick", "-delay", "8", "-loop", "0", *png_files, output_gif
    ])

    if sync:
        os.system(f"aws s3 cp {output_gif} {s3_path} --acl public-read")
        print(f"https://s3.amazonaws.com/{s3_path[5:]}{output_gif}".replace(
            "+", "%2B"
        ))
        
        print(f"set status=22 for {outroot}")
        db.execute(f"update nirspec_ifu_products set status = 22 where outroot = '{outroot}'")

    if clean:
        for file in png_files:
            os.remove(file)
        
        if os.path.exists("/GrizliImaging"):
            os.remove(cube_file)
            os.remove(output_gif)

    os.remove(lockfile)

    print(f"open -a \"Google Chrome\" {os.getcwd()}/{output_gif}")
    return output_gif

def run_one(**kwargs):
    row = db.SQL("""
    select outroot, redshift from nirspec_ifu_products
    where status = 2 and redshift > 4.6 AND grating = 'G395H'
    ORDER BY RANDOM() LIMIT 1
    """)
    if len(row) == 0:
        return None
    else:
        kwargs["outroot"] = row["outroot"]
        result = make_cube_line_animation(**kwargs)
        return result

def run_from_args(argv):
    
    kws = dict(
        outroot="cube-05645164001_g395h-f290lp_p173+48",
        rest_wave=5008.24,
        label="oiii",
        dv_max=1000,
        s=0.5,
        clean=True,
        sync=True,
    )

    for k in kws:
        ki = "--" + k
        if ki in argv:
            j = argv.index(ki) + 1
            if isinstance(kws[k], str):
                kws[k] = argv[j]
            elif isinstance(kws[k], bool):
                kws[k] = argv[j].upper() in ["1", "TRUE"]
            else:
                kws[k] = float(argv[j])
    
    print(kws)
    if "--fixed" in argv:
        result = make_cube_line_animation(**kws)
    else:
        result = run_one(**kws)

    return result

if __name__ == "__main__":
    run_from_args(sys.argv)