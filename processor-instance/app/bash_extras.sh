check_shift_alignment() {
    files=`ls -ltr */Prep/*shifts.log  | awk '{print $9}'`
    for file in $files; do 
        ls -lt ${file}
        grep " 1.000" ${file} | sed -e "s/^/     /"
        echo ""
    done
}

check_astrometry_alignment() {
    # echo """grep -e " 0 " -e "radec" \`ls -ltr */Prep/*wcs.log | awk '{print $9}'\`"""
    grep -e " 0 " -e "radec" `ls -ltr */Prep/*wcs.log  | awk '{print $9}'`| sed $'s/:/:\t/'
    echo ""
    ls -ltr */Prep/*fail*
}

alias grs=check_shift_alignment
alias gr=check_astrometry_alignment

count_rate() {
    roots=`ls *footprint.fits | sed "s/_footprint.fits//"`
    for root in $roots; do 
        for ext in RAW Prep; do 
            echo ${root}/${ext} `ls ${root}/${ext}/*rate.fits | wc -l`
        done
         echo ""
    done
}

count_flt() {
    roots=`ls *footprint.fits | sed "s/_footprint.fits//"`
    for root in $roots; do 
        for ext in RAW Prep; do 
            echo ${root}/${ext} `ls ${root}/${ext}/*flc.fits | wc`
        done
         echo ""
    done
}
