for filename in gebalotests/*; do
    [ -e "$filename" ] || continue
    filename=`echo $filename | sed 's/gebalotests\///g'`;
    make gt arg=$filename;
    read -n1 ans
done