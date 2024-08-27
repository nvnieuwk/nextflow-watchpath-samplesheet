OUTDIR=$(pwd)/results
rm -rf $OUTDIR
mkdir $OUTDIR

for i in $(seq 1 4)
do
    sleep $(shuf -i 1-3 -n 1)
    mkdir $OUTDIR/sample$i
    touch $OUTDIR/sample$i/sample$i.cram
    touch $OUTDIR/sample$i/sample$i.cram.crai
done
