# hlvideo

Hashlink video support

#### Windows Setup

- Download and build AOM from hlvideo root directory

```
git clone https://aomedia.googlesource.com/aom
mkdir aom_build
cd aom_build
cmake ../aom -G "Visual Studio 15 2017" -T host=x64
cmake --build .
```

- Define HASHLINK_SRC env var to point to your `hashlink` directory

#### Dependencies / Requirements:

- Haxe
- Hashlink 
- AOM