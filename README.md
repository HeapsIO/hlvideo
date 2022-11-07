# hlvideo

Hashlink video support

#### Windows Setup

- Download and build AOM from hlvideo root directory

for x64

```
git clone https://aomedia.googlesource.com/aom
mkdir aom_x64
cd aom_x64
cmake ../aom -DCMAKE_BUILD_TYPE=Release -G "Visual Studio 15 2017" -T host=x64 -A x64
cmake --build . --config Release
```

or for win32

```
git clone https://aomedia.googlesource.com/aom
mkdir aom_x32
cd aom_x32
cmake ../aom -DCMAKE_BUILD_TYPE=Release -G "Visual Studio 15 2017" -T host=x64
cmake --build . --config Release
```

- Define HASHLINK_SRC env var to point to your `hashlink` directory

#### Dependencies / Requirements:

- Haxe
- Hashlink 
- AOM