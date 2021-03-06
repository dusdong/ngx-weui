#!/usr/bin/env bash

readonly currentDir=$(cd $(dirname $0); pwd)
cd ${currentDir}
rm -rf publish
rm -rf __gen_components
rm -rf publish-es2015
cp -r components __gen_components
node ./scripts/build/inline-template.js

VERSION=$(node -p "require('./package.json').version")

buildSchematics() {
  echo '  Compiling schematics'
  schematics_source_dir=${PWD}/__gen_components/schematics/
  schematics_dist_dir=${PWD}/publish/schematics/
  $(npm bin)/tsc -p ${schematics_source_dir}tsconfig.json
  echo '  Coping all json files'
  rsync -am --include="*.json" --include="*/" --exclude=* ${schematics_source_dir}/ ${schematics_dist_dir}/
}

#######################################
# update version references
# Arguments:
#   param1 - Source directory
# Returns:
#   None
#######################################
updateVersionReferences() {
  NPM_DIR="$1"
  (
    echo "======    VERSION: Updating version references in ${NPM_DIR}"
    cd ${NPM_DIR}
    perl -p -i -e "s/0\.0\.0\-PLACEHOLDER/${VERSION}/g" $(grep -ril 0\.0\.0\-PLACEHOLDER .) < /dev/null 2> /dev/null
  )
}

echo 'Compiling to es2015 via Angular compiler'
$(npm bin)/ngc -p tsconfig-build.json -t es2015 --outDir publish-es2015/src

echo 'Bundling to es module of es2015'
export ROLLUP_TARGET=esm
$(npm bin)/rollup -c rollup.config.js -f es -i publish-es2015/src/index.js -o publish-es2015/esm2015/weui.js

echo 'Compiling to es5 via Angular compiler'
$(npm bin)/ngc -p tsconfig-build.json -t es5 --outDir publish-es5/src

echo 'Bundling to es module of es5'
export ROLLUP_TARGET=esm
$(npm bin)/rollup -c rollup.config.js -f es -i publish-es5/src/index.js -o publish-es5/esm5/weui.js

echo 'Bundling to umd module of es5'
export ROLLUP_TARGET=umd
$(npm bin)/rollup -c rollup.config.js -f umd -i publish-es5/esm5/weui.js -o publish-es5/bundles/weui.umd.js

echo 'Bundling to minified umd module of es5'
export ROLLUP_TARGET=mumd
$(npm bin)/rollup -c rollup.config.js -f umd -i publish-es5/esm5/weui.js -o publish-es5/bundles/weui.umd.min.js

echo 'Unifying publish folder'
mv publish-es5 publish
mv publish-es2015/esm2015 publish/esm2015
rm -rf publish-es2015

echo 'Build schematics'
buildSchematics

echo 'Cleaning up temporary files'
rm -rf __gen_components
rm -rf publish/src/*.js
rm -rf publish/src/**/*.js

echo 'Normalizing entry files'
sed -e "s/from '.\//from '.\/src\//g" publish/src/index.d.ts > publish/weui.d.ts
sed -e "s/\":\".\//\":\".\/src\//g" publish/src/index.metadata.json > publish/weui.metadata.json
rm publish/src/index.d.ts publish/src/index.metadata.json

echo 'update version'
cp components/package.json publish/package.json
updateVersionReferences publish

echo 'Copying README.md'
cp README.md publish/README.md

echo 'Copying wx.d.ts'
cp components/jweixin/jweixin.d.ts publish/jweixin.d.ts

echo 'Copying less'
node ./scripts/build/generate-style.js
