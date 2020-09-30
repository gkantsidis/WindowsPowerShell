[CmdletBinding()]
param(

)

# Install the dotnet-core-uninstall tool from https://github.com/dotnet/cli-lab/releases
# Instructions in https://docs.microsoft.com/en-us/dotnet/core/install/remove-runtime-sdk-versions?pivots=os-windows

dotnet-core-uninstall remove --all-previews --sdk -y
dotnet-core-uninstall remove --all-but-latest --sdk -y
dotnet-core-uninstall remove --all-but-latest --runtime -y

# dotnet --list-sdks
# dotnet --list-runtimes
# dotnet-core-uninstall list