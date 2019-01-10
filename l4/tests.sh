for filename in officialtests/*; do
    [ -e "$filename" ] || continue
    filename=`echo $filename | sed 's/officialtests\///g'`;
    make gt arg=$filename;
    [ $filename == "7-loopiii.imp" ] && make gt arg=$filename;
    [ $filename == "program2.imp" ] && make gt arg=$filename;
    read -n1 ans
done