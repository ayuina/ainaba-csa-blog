<#
    .SYNOPSIS
    Sample script of backup, resotre and clone Azure API Management configuration
    
    .DESCRIPTION
    This script can backup API Management to Azure blob, restore API Management from Azure blob, and Clone an API Management to anothre API Management.

    .PARAMETER backup
    Run baackup mode, need to specify source api management name.
    .PARAMETER restore
    Run restore mode, need to specify backuped blob file and target api management name.
    .PARAMETER clone
    Run clone mode, need to specify source and target api management name.
    
    .EXAMPLE
    Backup your API Management to blob specified. Backed up blob name is auto generated.
    > .\ops-apim.ps1 -backup -storageAccountName "YOUR_ACCOUNT_NAME" -containerName "CONTAINER_NAME" -sourceapim "YOUR_APIMANAGEMENT"

    .EXAMPLE
    Restore your API Management from blob specified.
    > .\ops-apim.ps1 -restore -storageAccountName "YOUR_ACCOUNT_NAME" -containerName "CONTAINER_NAME" -restoreblob "BLOB_NAME" -targetapim "YOUR_APIMANAGEMENT"

    .EXAMPLE
    Clone configuration from an API Management to another one.
    > .\ops-apim.ps1 -clone -storageAccountName "YOUR_ACCOUNT_NAME" -containerName "CONTAINER_NAME" -sourceapim "YOUR_APIMANAGEMENT_FROM" -targetapim "YOUR_APIMANAGEMENT_TO"

    .LINK
    Reference : https://docs.microsoft.com/en-us/azure/api-management/api-management-howto-disaster-recovery-backup-restore
    New-AzStorageContext : https://docs.microsoft.com/en-us/powershell/module/az.storage/new-azstoragecontext
    Backup-AzApiManagement : https://docs.microsoft.com/en-us/powershell/module/az.apimanagement/backup-azapimanagement
    Restore-AzApiManagement : https://docs.microsoft.com/en-us/powershell/module/az.apimanagement/restore-azapimanagement
#>

[CmdletBinding()]
param(
    [Parameter(ParameterSetName="backup", Mandatory = $true)]
    [Switch]$backup,
    [Parameter(ParameterSetName="restore", Mandatory = $true)]
    [Switch]$restore,
    [Parameter(ParameterSetName="clone", Mandatory = $true)]
    [Switch]$clone,

    [Parameter(Mandatory = $true)]
    [string]$storageAccountName,
    [Parameter(Mandatory = $true)]
    [string]$containerName,

    [Parameter(ParameterSetName="backup")]
    [Parameter(ParameterSetName="clone")]
    [string]$sourceapim,

    [Parameter(ParameterSetName="restore")]
    [string]$restoreblob,

    [Parameter(ParameterSetName="restore")]
    [Parameter(ParameterSetName="clone")]
    [string]$targetapim
)

function Main()
{
    if($backup)
    {
        Backup-ApiM -apim $sourceapim  -stracc $storageAccountName -container $containerName
    }
    elseif($restore)
    {
        Restore-ApiM -stracc $storageAccountName -container $containerName -blob $restoreblob -apim $targetapim 
    }
    elseif($clone)
    {
        $blob = Backup-ApiM -apim $sourceapim  -stracc $storageAccountName -container $containerName
        Restore-ApiM -stracc $storageAccountName -container $containerName -blob $blob -apim $targetapim 
    }
    else
    {
        Write-host "not implemented"   
    }
}

function Get-BackupStorageContext($stracc)
{
    Write-host ("finding $stracc")

    $bakstr = (Get-AzStorageAccount | where { $_.StorageAccountName -eq $stracc })[0]
    $strkey = (Get-AzStorageAccountKey -ResourceGroupName $bakstr.ResourceGroupName -AccountName $bakstr.StorageAccountName)[0].Value
    return New-AzStorageContext -StorageAccountName $stracc -StorageAccountKey $strkey
}

function Get-ApiManagementInstance($apim)
{
    Write-host ("finding $apim")
    return (Get-AzApiManagement | where {$_.Name -eq $apim})[0]
}

function Backup-ApiM($apim, $stracc, $container)
{
    $strctx = Get-BackupStorageContext -stracc $stracc
    $source = Get-ApiManagementInstance -apim $apim

    $blobfile = "{0}_{1:yyyy-MM-dd-HH-mm-ss}.apimbackup" -f $apim, [DateTime]::UtcNow
    Write-host ("Backup API Management {0} to https://{1}.blob.core.windows.net/{2}/{3}" -f $apim, $stracc, $container, $blobfile)
   Backup-AzApiManagement -ResourceGroupName $source.ResourceGroupName -Name $source.Name `
        -StorageContext  $strctx -TargetContainerName  $container -TargetBlobName $blobfile
    
    return $blobfile
}

function Restore-ApiM($stracc, $container, $blob, $apim)
{
    $strctx = Get-BackupStorageContext -stracc $stracc
    $target = Get-ApiManagementInstance -apim $apim

    Write-host ("Restore API Management : {0} from https://{1}.blob.core.windows.net/{2}/{3}" -f $apim, $stracc, $container, $blobfile)
    Restore-AzApiManagement -ResourceGroupName $target.ResourceGroupName -Name $target.Name `
        -StorageContext  $strctx -SourceContainerName  $container -SourceBlobName $blob
}


Main

