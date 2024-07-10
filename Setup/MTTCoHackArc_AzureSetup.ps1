#choose the region where to deploy the resources
param (
    $region,
    $team
)

if ([string]::IsNullOrEmpty($region)) {
    Write-Error "The region parameter is required. Example: ./deploy -region 'northeurope' -team '01'"
    exit 1
}

#get subscription id
$subscriptionId = (Get-AzContext).Subscription.Id
Write-Host $subscriptionId

# register providers
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridCompute
Register-AzResourceProvider -ProviderNamespace Microsoft.GuestConfiguration
Register-AzResourceProvider -ProviderNamespace Microsoft.HybridConnectivity
Register-AzResourceProvider -ProviderNamespace Microsoft.AzureArcData
Register-AzResourceProvider -ProviderNamespace Microsoft.Compute
Register-AzResourceProvider -ProviderNamespace Microsoft.Insights
Register-AzResourceProvider -ProviderNamespace Microsoft.ManagedIdentity
Register-AzResourceProvider -ProviderNamespace Microsoft.OperationsManagement
Register-AzResourceProvider -ProviderNamespace Microsoft.OperationalInsights
Register-AzResourceProvider -ProviderNamespace Microsoft.Security

# install graph module
Install-Module -Name "Microsoft.Graph" -force

# connect to MS graph
try {
Connect-MgGraph -Scopes "Directory.ReadWrite.All" -ErrorAction Stop
Write-Host "connected to MS graph"
}
catch {
    Write-Error "Error connecting to MS graph"
    exit 1
}
#generate a random password 12 characters long with special characters, numbers, and letters
#get primary domain name
$domain = (Get-MgDomain | Where-Object { $_.IsVerified -eq $true -and $_.IsDefault -eq $true }).Id

#create user cohacker x
$password1 = -join ((33..47) + (58..64) + (91..96) + (123..126) + (48..57) + (65..90) + (97..122) | Get-Random -Count 12 | % {[char]$_})
$userParams = @{
    DisplayName = "cohacker$team"
    UserPrincipalName = "cohacker$team@$domain"
    AccountEnabled = $true
    MailNickname = "cohacker$team"
    PasswordProfile = @{
        ForceChangePasswordNextSignIn = $false
        Password = $password1
    }
}
$cohacker = New-MgUser @userParams
$cohackerId = $cohacker.Id

#create azure resource group
$ResourceGroup = "rg-cohackArc$team"
New-AzResourceGroup -Name $ResourceGroup -Location $region


# Define the custom role
$role = Get-AzRoleDefinition -Name "Resource Policy Contributor"
$role.Id = $null
$role.Name = "Resource Policy Contributor - Custom"
$role.IsCustom = $True
$role.Actions.RemoveRange(0,$role.Actions.Count)
$role.Actions.Add("Microsoft.Authorization/policyassignments/*")
$role.Actions.Add("Microsoft.Authorization/policydefinitions/*")
$role.Actions.Add("Microsoft.Authorization/policyexemptions/*")
$role.Actions.Add("Microsoft.Authorization/policysetdefinitions/*")
$role.Actions.Add("Microsoft.PolicyInsights/remediations/*")
$role.AssignableScopes.Clear()
$role.AssignableScopes.Add("/subscriptions/$subscriptionId")

New-AzRoleDefinition -Role $role

#assign RBAC roles to cohacker user on the resource Group
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Security Admin" -ResourceGroupName $ResourceGroup
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Log Analytics Contributor" -ResourceGroupName $ResourceGroup
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Monitoring Contributor" -ResourceGroupName $ResourceGroup
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Azure Connected Machine Resource Administrator" -ResourceGroupName $ResourceGroup
#New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Resource Policy Contributor" -ResourceGroupName $ResourceGroup
#New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "User Access Administrator" -ResourceGroupName $ResourceGroup
#New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Virtual Machine Contributor" -ResourceGroupName $ResourceGroup

#assign RBAC roles to cohacker user on the subscription
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Monitoring Contributor" -ResourceGroupName $ResourceGroup
New-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Resource Policy Contributor - Custom" -Scope /subscriptions/$subscriptionId

$WorkspaceName = "log-analytics-" + (Get-Random -Maximum 99999) # workspace names need to be unique in resource group - Get-Random helps with this for the example code
$Location = $region

# Create the workspace
New-AzOperationalInsightsWorkspace -Location $Location -Name $WorkspaceName -Sku PerGB2018 -ResourceGroupName $ResourceGroup
