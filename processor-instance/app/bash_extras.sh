##
## BASH helper functions that will be available in the command-line $PATH
##

## Print shift alignment logs
check_shift_alignment() {
    files=`ls -ltr */Prep/*shifts.log  | awk '{print $9}'`
    for file in $files; do 
        ls -lt ${file}
        grep " 1.000" ${file} | sed -e "s/^/     /"
        echo ""
    done
}

## Print WCS alignment logs
check_astrometry_alignment() {
    # echo """grep -e " 0 " -e "radec" \`ls -ltr */Prep/*wcs.log | awk '{print $9}'\`"""
    grep -e " 0 " -e "radec" `ls -ltr */Prep/*wcs.log  | awk '{print $9}'`| sed $'s/:/:\t/'
    echo ""
    ls -ltr */Prep/*fail*
}

alias grs=check_shift_alignment

alias gr=check_astrometry_alignment

## Count rate.fits exposures in assoc directories
count_rate() {
    roots=`ls *footprint.fits | sed "s/_footprint.fits//"`
    for root in $roots; do 
        for ext in RAW Prep; do 
            echo ${root}/${ext} `ls ${root}/${ext}/*rate.fits | wc -l`
        done
         echo ""
    done
}

## Count FLT/FLC exposures in assoc directories
count_flt() {
    roots=`ls *footprint.fits | sed "s/_footprint.fits//"`

    for root in $roots; do 
        for ext in RAW Prep; do 
            echo ${root}/${ext} `ls ${root}/${ext}/*flc.fits | wc`
        done
         echo ""
    done

    for root in $roots; do 
        for ext in RAW Prep; do 
            echo ${root}/${ext} `ls ${root}/${ext}/*flt.fits | wc`
        done
         echo ""
    done

}

## list large files
dubig() {

    files=`ls`

    du -sc $files | sort -nr | awk '
         BEGIN {
            split("KB,MB,GB,TB", Units, ",");
         }
         {
            u = 1;
            while ($1 >= 1024) {
               $1 = $1 / 1024;
               u += 1
            }
            $1 = sprintf("%5.1f %s", $1/2, Units[u]);
            print $0;
         }' | grep -v KB

}