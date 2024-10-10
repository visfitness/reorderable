# Documentation

To generate the `DocC` folder, use the following command (assuming XCode is installed):

```bash
 xcodebuild clean docbuild -scheme Reorderable -destination generic/platform=IOS DOCC_HOSTINGS_BASE_PATH=reorderable OTHER_DOCC_FLAGS="--output-path Documentation/DocC"
```
