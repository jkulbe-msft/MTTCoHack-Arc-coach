#Requires -RunAsAdministrator

if (!((Get-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V).state))
{
    Write-Output "Hyper-V is not installed. Installing Hyper-V..."
    Enable-WindowsOptionalFeature -Online -FeatureName Microsoft-Hyper-V -All -NoRestart
    throw "Please restart the computer and run the script again."
}

Start-Transcript -Path C:\MTTCohackArc.txt

Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
Install-Module -Name Pester -SkipPublisherCheck -AllowClobber -Force
Install-Module -Name AutomatedLab -AllowClobber -Force
[Environment]::SetEnvironmentVariable('AUTOMATEDLAB_TELEMETRY_OPTIN', 'true', 'Machine')
$env:AUTOMATEDLAB_TELEMETRY_OPTIN = 'true'
Import-Module AutomatedLab -Force
New-LabSourcesFolder -DriveLetter C -Force
Enable-LabHostRemoting -Force
Update-LabSysinternalsTools
# download Windows Server 2022 Evaluation
Start-BitsTransfer -Destination C:\LabSources\ISOs\WindowsServer2022Eval.iso -Source 'https://go.microsoft.com/fwlink/p/?LinkID=2195280&clcid=0x409&culture=en-us&country=US'
Start-BitsTransfer -Destination C:\LabSources\sql2022-ssei-dev.exe -Source 'https://go.microsoft.com/fwlink/?linkid=2215202&clcid=0x409&culture=en-us&country=us'
Start-Process -FilePath C:\LabSources\sql2022-ssei-dev.exe -ArgumentList "/action=download /mediatype=iso /mediapath=C:\LabSources\ISOs /quiet" -Wait
Add-LabIsoImageDefinition -Path C:\LabSources\ISOs\SQLServer2022-x64-ENU.iso -Name 'SQLServer2022'
# Start-BitsTransfer -Destination C:\LabSources\ISOs\ubuntu-24.04-live-server-amd64.iso -Source 'https://mirror.pilotfiber.com/ubuntu-iso/24.04/ubuntu-24.04-live-server-amd64.iso'
# Start-BitsTransfer -Destination C:\LabSources\ISOs\ubuntu-24.04-desktop-amd64.iso -Source 'https://mirror.pilotfiber.com/ubuntu-iso/24.04/ubuntu-24.04-desktop-amd64.iso'
Unblock-LabSources

$labName = 'MTTCoHackArc'
$vmpath = "C:\$labname"

$osName = 'Windows Server 2022 Datacenter Evaluation'
$osNameWithDesktop = 'Windows Server 2022 Datacenter Evaluation (Desktop Experience)'
#$osLinux = 'Ubuntu 24.04 LTS "Noble Numbat"'

Enable-LabHostRemoting -Force

New-LabDefinition -Name $labname -DefaultVirtualizationEngine HyperV -VmPath $vmpath

#defining default parameter values, as these ones are the same for all the machines
$PSDefaultParameterValues = @{
    'Add-LabMachineDefinition:DomainName' = 'corp.contoso.com'
    'Add-LabMachineDefinition:Memory' = 2GB
    'Add-LabMachineDefinition:Processors' = 2
    'Add-LabMachineDefinition:OperatingSystem' = $osName
}

# Domain Controller
Add-LabMachineDefinition -Name 'DC1' -Roles RootDC -MinMemory 512MB -MaxMemory 4GB

# Admin server
# Add-LabDiskDefinition -Name 'ADM1-Data' -DiskSizeInGb 10 -Label 'Data' -DriveLetter S
# Add-LabDiskDefinition -Name 'ADM1-Logs' -DiskSizeInGb 10 -Label 'Logs' -DriveLetter L
# Add-LabMachineDefinition -Name 'ADM1' -Roles CARoot,WindowsAdminCenter,FileServer -IsDomainJoined -OperatingSystem $osNameWithDesktop -DiskName 'ADM1-Data','ADM1-Logs' -MinMemory 1GB -MaxMemory 8GB

# file and SQL server
Add-LabDiskDefinition -Name 'SRV1-Data' -DiskSizeInGb 10 -Label 'Data' -DriveLetter S
Add-LabDiskDefinition -Name 'SRV1-Logs' -DiskSizeInGb 10 -Label 'Logs' -DriveLetter L
Add-LabMachineDefinition -Name 'SRV1' -Roles FileServer,SQLServer2022 -IsDomainJoined -DiskName 'SRV1-Data','SRV1-Logs' -MinMemory 512MB -MaxMemory 4GB

# Linux
# Add-LabMachineDefinition -Name 'LIN1' -OperatingSystem $osLinux -MinMemory 512MB -MaxMemory 4GB

Install-Lab -DelayBetweenComputers 120

# Features
$dcjob = Install-LabWindowsFeature -FeatureName RSAT -ComputerName 'DC1' -IncludeAllSubFeature -IncludeManagementTools
# $admjob = Install-LabWindowsFeature -FeatureName RSAT,DHCP,File-Services -ComputerName 'ADM1' -IncludeAllSubFeature -AsJob -PassThru

# Install and update WAC extensions
#$wacjob = Invoke-LabCommand -ActivityName "WAC Update" -ComputerName ADM1 -AsJob -PassThru -ScriptBlock { 
#    Import-Module "$env:ProgramFiles\windows admin center\PowerShell\Modules\ExtensionTools"
#    Get-Extension "https://adm1" | ? status -eq Available | foreach {Install-Extension "https://adm1" $_.id}
#    Get-Extension "https://adm1" | ? islatestVersion -ne $true | foreach {Update-Extension "https://adm1" $_.id}
# }

Wait-LWLabJob -Job $dcjob -ProgressIndicator 10 -NoDisplay -PassThru
#Wait-LWLabJob -Job $admjob -ProgressIndicator 10 -NoDisplay -PassThru
#Wait-LWLabJob -Job $wacjob -ProgressIndicator 10 -NoDisplay -PassThru

Get-LabVM | ? Name -ne 'dc1' | Restart-LabVM -Wait

# SMB share
# create SMB share on data disk on SRV1
#Invoke-LabCommand -ActivityName "create SMB shares" -ComputerName 'SRV1' -ScriptBlock {
#    New-Item -Path S:\Share -ItemType Directory -Force
#    icacls S:\Share /grant 'Domain Computers:(OI)(CI)F' 
#    New-SmbShare -Path S:\Share -FullAccess 'Everyone' -Name Share
#}
Show-LabDeploymentSummary -Detailed
Write-Output "Please add a Linux machine using Hyper-V QuickCreate."
Stop-Transcript
