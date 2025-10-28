primeiro=1
for file in *.shp ; do
        if [ $primeiro -eq 1 ] ; then
                shp2pgsql $file direccion | psql -U postgres -d mexico
                primeiro=0
        else
                shp2pgsql -a $file direccion | psql -U postgres -d mexico
        fi
done 2>&1 | tee /mnt/dados/download/mexico/log.txt
