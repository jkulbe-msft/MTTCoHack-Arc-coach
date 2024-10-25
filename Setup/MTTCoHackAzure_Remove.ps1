param (
    $resourceGroup = 'rg-cohackArc'
)
# connect to MS graph
try {
    Connect-MgGraph -Scopes "Directory.ReadWrite.All" -ErrorAction Stop
    Write-Host "connected to MS graph"
} catch {
    Write-Error "Error connecting to MS graph"
    exit 1
}

#get subscription id
$subscriptionId = (Get-AzContext).Subscription.Id
Write-Host $subscriptionId

#get primary domain name
$domain = (Get-MgDomain | Where-Object { $_.IsVerified -eq $true -and $_.IsDefault -eq $true }).Id

# unsign RBAC roles to cohacker on the subscription
$cohackerId = (Get-MgUser -Filter "userPrincipalName eq 'cohacker@$domain'").Id
Remove-AzRoleAssignment -ObjectId $cohackerId -RoleDefinitionName "Resource Policy Contributor - Custom" -Scope "/subscriptions/$subscriptionId"

# remove a custom role
Remove-AzRoleDefinition -Name "Resource Policy Contributor - Custom" -Force
Remove-AzRoleDefinition -Name "Azure Connected Machine Resource Administrator - Custom" -Force

# delete a resource group
Remove-AzResourceGroup -Name $resourceGroup -Force

# delete cohacker user
Remove-AzADUser -UserPrincipalName "cohacker@$domain" 

Write-Host "Please delete any service prncipals created during the lab"
