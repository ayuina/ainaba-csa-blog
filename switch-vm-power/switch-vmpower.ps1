<#
    .SYNOPSIS
    This script switch Azure Virtual Machine power status.
    .DESCRIPTION
    If the target virtual machine is in "deallocated" status, then this script boots the vm.
    If the target virtual machine is in "running" status, then this script shutdown and deallocate the vm.
    If the target virtual machins is in other status like "starting" or "deallocating", just show the current status and do nothing.
#>

param(
    [string]$tenantid = 'guid-of-azure-ad-tenant',
    [string]$appid = 'application-id-registered-on-azure-ad',
    [string]$secret = 'your service principal key',
    [string]$subscription = 'subscription-guid-of-target-vm',
    [string]$resourceGroup = 'resourceGroupName',
    [string]$vmname = 'targetVmName'
)

function Main()
{
    #Azure AD にログイン
    #https://docs.microsoft.com/ja-jp/powershell/scripting/learn/deep-dives/add-credentials-to-powershell-functions?view=powershell-7.1#creating-credential-object
    $secpass = ConvertTo-SecureString -String $secret -AsPlainText -Force
    $credential = New-Object System.Management.Automation.PSCredential ($appid, $secpass)
    Disable-AzContextAutosave > $null
    Connect-AzAccount -ServicePrincipal -Credential $credential -Tenantid $tenantid -Subscription $subscription  > $null

    #VM情報を取得
    $targetVm = Get-AzVM -ResourceGroupName $resourceGroup -Name $vmname -Status
    #電源の情報を取得   
    $powerState = $targetVm.Statuses |  where { $_.Code.StartsWith('PowerState/') } | foreach { $_.Code.Split('/')[1] }

    #上げ下げ
    Write-Host "Target vm ($vmname) is now $powerState . "
    if($powerState -eq 'deallocated')
    {
        Write-Host "Starting virtual machine... "
        Start-AzVM -ResourceGroupName $resourceGroup -Name $vmname -NoWait  > $null
    }
    elseif ($powerState -eq 'running') 
    {
        Write-Host "Stopping virtual machine... "
        Stop-AzVM -ResourceGroupName $resourceGroup -Name $vmname -Force -NoWait  > $null
    }
    else 
    {
        Write-Host "Do nothing "
    }
}

Main