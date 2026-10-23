[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Get the package database to find the correct binutils URL
Invoke-WebRequest -Uri 'https://repo.msys2.org/mingw/x86_64/mingw-w64-x86_64-binutils-2.42-2-any.pkg.tar.zst' -OutFile 'binutils.zst'