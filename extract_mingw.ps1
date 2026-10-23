[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
# Check if 7z is available
if (Get-Command 7z -ErrorAction SilentlyContinue) {
    7z x mingw.7z -oC:\mingw64
} else {
    # Use built-in expand-archive (PowerShell 5+)
    Expand-Archive -Path mingw.7z -DestinationPath C:\mingw64 -Force
}