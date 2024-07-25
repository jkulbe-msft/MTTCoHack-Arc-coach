[cmdletbinding()]
param (
    [string]$NIC1IPAddress,
    [string]$NIC2IPAddress,
    [string]$GhostedSubnetPrefix,
    [string]$VirtualNetworkPrefix
)

Start-Transcript -Path C:\transcripts\hvhostsetup.txt

Write-Output "NIC1IPAddress: $NIC1IPAddress"
Write-Output "NIC2IPAddress: $NIC2IPAddress"
Write-Output "GhostedSubnetPrefix: $GhostedSubnetPrefix"
Write-Output "VirtualNetworkPrefix: $VirtualNetworkPrefix"

[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force
Install-Module Subnet -Force

Set-VMHost -EnableEnhancedSessionMode $True
New-VMSwitch -Name "NestedSwitch" -SwitchType Internal

$NIC1IP = Get-NetIPAddress | Where-Object -Property AddressFamily -EQ IPv4 | Where-Object -Property IPAddress -EQ $NIC1IPAddress
$NIC2IP = Get-NetIPAddress | Where-Object -Property AddressFamily -EQ IPv4 | Where-Object -Property IPAddress -EQ $NIC2IPAddress

$NATSubnet = Get-Subnet -IP $NIC1IP.IPAddress -MaskBits $NIC1IP.PrefixLength
$HyperVSubnet = Get-Subnet -IP $NIC2IP.IPAddress -MaskBits $NIC2IP.PrefixLength
$NestedSubnet = Get-Subnet $GhostedSubnetPrefix
$VirtualNetwork = Get-Subnet $VirtualNetworkPrefix

New-NetIPAddress -IPAddress $NestedSubnet.HostAddresses[0] -PrefixLength $NestedSubnet.MaskBits -InterfaceAlias "vEthernet (NestedSwitch)"
New-NetNat -Name "NestedSwitch" -InternalIPInterfaceAddressPrefix "$GhostedSubnetPrefix"

Add-DhcpServerv4Scope -Name "Nested VMs" -StartRange $NestedSubnet.HostAddresses[1] -EndRange $NestedSubnet.HostAddresses[-1] -SubnetMask $NestedSubnet.SubnetMask
Set-DhcpServerv4OptionValue -DnsServer 168.63.129.16 -Router $NestedSubnet.HostAddresses[0]

Install-RemoteAccess -VpnType RoutingOnly
cmd.exe /c "netsh routing ip nat install"
cmd.exe /c "netsh routing ip nat add interface ""$($NIC1IP.InterfaceAlias)"""
cmd.exe /c "netsh routing ip add persistentroute dest=$($NatSubnet.NetworkAddress) mask=$($NATSubnet.SubnetMask) name=""$($NIC1IP.InterfaceAlias)"" nhop=$($NATSubnet.HostAddresses[0])"
cmd.exe /c "netsh routing ip add persistentroute dest=$($VirtualNetwork.NetworkAddress) mask=$($VirtualNetwork.SubnetMask) name=""$($NIC2IP.InterfaceAlias)"" nhop=$($HyperVSubnet.HostAddresses[0])"

Get-Disk | Where-Object -Property PartitionStyle -EQ "RAW" | Initialize-Disk -PartitionStyle GPT -PassThru | New-Volume -FileSystem NTFS -AllocationUnitSize 65536 -DriveLetter F -FriendlyName "Hyper-V"

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -SkipPublisherCheck -Force
Install-Module -Name AutomatedLab -AllowClobber -Force
[Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTIN', 'true', 'Machine')
$env:AUTOMATEDLAB_TELEMETRY_OPTIN = 'true'
# Import-Module AutomatedLab -Force
New-LabSourcesFolder -DriveLetter C -Force
Enable-LabHostRemoting -Force
Update-LabSysinternalsTools
Set-PSFConfig -Module AutomatedLab -Name DoNotWaitForLinux -Value $true
# download Windows Server 2022 Evaluation
Start-BitsTransfer -Destination C:\LabSources\ISOs\WindowsServer2022Eval.iso -Source 'https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US'
Start-BitsTransfer -Destination C:\LabSources\OSUpdates\windows10.0-kb5031364-x64_03606fb9b116659d52e2b5f5a8914bbbaaab6810.msu -Source 'https://catalog.s.download.windowsupdate.com/c/msdownload/update/software/secu/2023/10/windows10.0-kb5031364-x64_03606fb9b116659d52e2b5f5a8914bbbaaab6810.msu'

# download SQL Server 2022
Start-BitsTransfer -Destination C:\LabSources\sql2022-ssei-dev.exe -Source 'https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us'
Start-Process -FilePath C:\LabSources\sql2022-ssei-dev.exe -ArgumentList "/action=download /mediatype=iso /mediapath=C:\LabSources\ISOs /quiet" -Wait

# download Ubuntu Desktop
Start-BitsTransfer -Destination C:\LabSources\ISOs\ubuntu-24.04-desktop-amd64.iso -Source 'https://mirror.pilotfiber.com/ubuntu-iso/24.04/ubuntu-24.04-live-server-amd64.iso'

Unblock-LabSources

Stop-Transcript

# install lab machines
Start-Transcript -Path C:\transcripts\Arc.txt

$labName = 'MTTCoHackArc'
$vmpath = "F:\$labname"

# $domainName = 'contoso.com'

$osName = 'Windows Server 2022 Datacenter Evaluation'
$osNameWithDesktop = 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
$osLinux = 'Ubuntu-Server 24.04 LTS "Noble Numbat"'

Enable-LabHostRemoting -Force

New-LabDefinition -Name $labname -DefaultVirtualizationEngine HyperV -VmPath $vmpath
Add-LabIsoImageDefinition -Path C:\LabSources\ISOs\SQLServer2022-x64-ENU.iso -Name 'SQLServer2022'

Add-LabVirtualNetworkDefinition -Name $labname -AddressSpace '192.168.50.0/24'
Add-LabVirtualNetworkDefinition -Name 'NestedSwitch'

$netAdapter = @()
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch $labname
$netAdapter += New-LabNetworkAdapterDefinition -VirtualSwitch 'NestedSwitch' -UseDhcp

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:DomainName' = 'corp.contoso.com'
    'Add-LabMachineDefinition:Memory' = 2GB
    #'Add-LabMachineDefinition:MinMemory' = 1GB
    #'Add-LabMachineDefinition:MaxMemory' = 8GB
    #'Add-LabMachineDefinition:EnableWindowsFirewall' = $true
    'Add-LabMachineDefinition:Processors' = 2
    'Add-LabMachineDefinition:OperatingSystem' = $osName
}

# Domain Controller
Add-LabMachineDefinition -Name 'DC1' -Roles RootDC,Routing -NetworkAdapter $netAdapter -MinMemory 512MB -MaxMemory 4GB

# file and SQL server
Add-LabDiskDefinition -Name 'SRV1-Data' -DiskSizeInGb 10 -Label 'Data' -DriveLetter S
Add-LabDiskDefinition -Name 'SRV1-Logs' -DiskSizeInGb 10 -Label 'Logs' -DriveLetter L
Add-LabMachineDefinition -Name 'SRV1' -Roles FileServer,SQLServer2022 -IsDomainJoined -DiskName 'SRV1-Data','SRV1-Logs' -OperatingSystem $osNameWithDesktop -MinMemory 1GB -MaxMemory 8GB -Processors 4 -Network $labname -Gateway 192.168.50.3 

# Linux
Add-LabMachineDefinition -Name 'LIN1' -OperatingSystem $osLinux -MinMemory 512MB -MaxMemory 4GB -Network 'NestedSwitch'

Install-Lab -DelayBetweenComputers 60 -ErrorAction Continue

# patch SRV1
Copy-LabFileItem -Path "C:\LabSources\OSUpdates\windows10.0-kb5031364-x64_03606fb9b116659d52e2b5f5a8914bbbaaab6810.msu" -ComputerName SRV1 -DestinationFolderPath C:\
Invoke-LabCommand -ActivityName "update SRV1" -ComputerName SRV1 -scriptblock { 
    expand -f:* C:\windows10.0-kb5031364-x64_03606fb9b116659d52e2b5f5a8914bbbaaab6810.msu C:\ ;
    dism /online /add-package /packagepath:C:\Windows10.0-KB5031364-x64.cab /quiet /norestart }
Restart-LabVM -ComputerName 'SRV1'

# switch Linux machine to nested switch, will not pick up IP otherwise
$vm = Get-VM -Name 'LIN1'
$adapter = Get-VMNetworkAdapter -VM $vm
Disconnect-VMNetworkAdapter -VMNetworkAdapter $adapter
Connect-VMNetworkAdapter -VMNetworkAdapter $adapter -SwitchName 'NestedSwitch'


# Features
$dcjob = Install-LabWindowsFeature -FeatureName RSAT -ComputerName 'DC1' -IncludeAllSubFeature -IncludeManagementTools

Wait-LWLabJob -Job $dcjob -ProgressIndicator 10 -NoDisplay -PassThru

Show-LabDeploymentSummary -Detailed
Stop-Transcript