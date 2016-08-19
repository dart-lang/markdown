if [ -z "${DDC_PATH}" ]; then
  echo "Please set DDC_PATH so that the Dev Compiler may be found."
  exit 1
fi

if [ -z "${MARKDOWN_SERVICE_BUCKET}" ]; then
  echo "Please set MARKDOWN_SERVICE_BUCKET to a Google Cloud bucket."
  exit 1
fi

# Fail fast.
set -e

# Verbose commands.
set -x

dart $DDC_PATH/tool/build_sdk.dart \
    --dart-sdk $DDC_PATH/gen/patched_sdk/ \
    --no-summarize \
    --modules node \
    --out service/dart_sdk.js

dart $DDC_PATH/bin/dartdevc.dart compile \
    --no-summarize \
    --no-source-map \
    --modules node \
    --out service/markdown_service.js \
    service/markdown_service.dart

# The output of `build_sdk.dart` was dropped into `service/`, so we need to
# rewrite the import so that `gcloud alpha functions deploy` picks it up.
sed -e "s/require('dart_sdk')/require('.\/dart_sdk')/" \
    -i '' \
    service/markdown_service.js

pushd service
gcloud alpha functions deploy markdownToHtml \
    --bucket "${MARKDOWN_SERVICE_BUCKET}" \
    --trigger-http
popd
