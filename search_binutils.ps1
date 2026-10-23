[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$content = (Invoke-WebRequest -Uri 'https://repo.msys2.org/mingw/x86_64/' -UseBasicParsing).Content
$content | Select-String 'binutils' | ForEach-Object { $_.Line }