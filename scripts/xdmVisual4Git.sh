#!/bin/bash
#used to generate xdm visualization from a single branch of xdm public repo

if [ "$#" -ne 2 ]; then
  echo "Wrong number of argument!"
  echo "Usage: ./scripts/xdmVisual4Git.sh repoBranchName repoHttpsURL"
  exit 1
fi

#set repo branch name
repoBranch=$2"_"$1
xdmgit="/xdm.git"
github="https://github.com/"
repoBranch=${repoBranch//$xdmgit}
repoBranch=${repoBranch//$github}
if [[ $repoBranch == adobe_* ]]
then
  repoBranch=${repoBranch//"adobe_"}
fi

#Pre-processing xdm json schemas
(rm -rf publicXdm; git clone -b $1 $2 publicXdm)
(cd publicXdm; npm install; npm run xed-validation)
(rm -rf bower_components/mdjson-schemas/*; cp -r ./publicXdm/bin/xed-validation/xed/* ./bower_components/mdjson-schemas/; rm -rf publicXdm)
node ./scripts/convert.js
(node ./scripts/fixref.js; rm schemaLoc.json)
retVal=$?
if [ "${retVal}" -ne 0 ]; then
  exit "${retVal}"
fi

xdms=$(find bower_components/mdjson-schemas -name "*.schema.json" -print)
for xdm in $xdms; do
  echo "processing---> $xdm"
  oldid=${xdm:32}
  newid=$(echo $oldid|rev|cut -d'/' -f 1|rev)
  #echo $oldid
  #echo $newid
  sed -i '' "s~${oldid}~${newid}~g" $xdm
  sed -i '' "s~\"\$id\":~\"id\":~g" $xdm
done

#grunt prod
echo "Running grunt prod"
rm -rf prod/$repoBranch/
rm -rf Gruntfile.js
sed "s/xdmVersion/$repoBranch/g" Gruntfile_template.js > Gruntfile.js
grunt prod

#generate xdm schema visualization pages
cd prod/$repoBranch/
rm index.html
echo "# XDM Visualization" >> index.md
echo "## Git Repo Branch: $repoBranch" >> index.md

uberSchemas=()
standardComponents=()
extensionComponents=()
standardCompGrp=()

folders=(adobe behaviors common airship classes datatypes mixins uberschemas)

rm ../../listOfXdms.txt
for folder in ${folders[@]}; do
  objs=$(find "schemas/$folder" -name "*.schema.json" -print -maxdepth 5)
  for obj in $objs; do
    origin="${obj/schemas\//}"
    schema="${origin/.schema.json/}"
    filename="${schema//\//.}"
    #echo "filename-->" $filename
    if [[ $filename != *.obj[0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9][0-9]* ]] # not showing generated objs
    then
        echo "$filename," >> ../../listOfXdms.txt
        if [[ $filename == adobe.* || $filename == airship.* ]]
        then
          extensionComponents+=( ${filename} )
        elif [[ $filename == uberschemas.* ]];
        then
          uberSchemas+=( $filename )
        else
          standardComponents+=( ${filename} )
        fi
        #echo "<a href = "http://localhost:9001/prod/$repoBranch/$filename.html">${filename}</a>" >> index.html
        #echo "<br>" >> index.html
    fi
    cp basic.html $filename.html #use basic as template
    sed  -i '' "s#experience/Profile.schema.json#$origin#g" $filename.html
  done
done

#standard component group
for i in ${standardComponents[@]}; do
  value=$(echo ${i%%.*})
  if ! (printf '%s\n' "${standardCompGrp[@]}" | grep -xq $value); then
    standardCompGrp+=( $value )
  fi
done

echo "### Standard XDM Schemas" >> index.md
for i in ${uberSchemas[@]}; do
  echo "Generating HTML:" $i
  echo "[$i](http://opensource.adobe.com/xdmVisualization/prod/$repoBranch/$i.html)<br/>" >> index.md
done

echo "### Standard Core Components" >> index.md

for h in ${standardCompGrp[@]}; do
  echo "#### "$h >> index.md
  for i in ${standardComponents[@]}; do
    if [[ $i == $h.* ]]
    then
      echo "Generating HTML:" $i
      echo "[$i](http://opensource.adobe.com/xdmVisualization/prod/$repoBranch/$i.html)<br/>" >> index.md
    fi
  done
done

echo "### Extension Components" >> index.md
for i in ${extensionComponents[@]}; do
  echo "Generating HTML:" $i
  echo "[$i](http://opensource.adobe.com/xdmVisualization/prod/$repoBranch/$i.html)<br/>" >> index.md
done

cd ../../
node ./scripts/dropdown.js $repoBranch
(rm prod/index.html; rm index.html)
git add .
git commit -m "merge xdm visualization for $repoBranch branch"
git push origin
#grunt connect:server:keepalive
