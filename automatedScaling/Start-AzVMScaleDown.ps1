<#  
.SYNOPSIS  
    Deploy hub and spoke architecture with transitive routing.
.DESCRIPTION  
    Deploy hub and spoke architecture with transitive routing using a JSON template to define the hub and spoke configurations.
    
    This means Virtual Network Gateways are deployed (which have a cost), VNET peering is performed between hub and spoke(s), VNET to VNET connection is performed between hubs,
    and route tables are deployed to facility transitive routing.

        v1.0 - Update
.NOTES  
    File Name       :   Deploy-VirtualNetwork.ps1  
    Author          :   Paul Lizer, paullizer@microsoft.com
    Prerequisite    :   PowerShell V5, Azure PowerShell 5.6.0 or greater
    Version         :   1.0 (2021 07 15)     
.LINK  
    https://github.com/paullizer/transitiveRouting
.EXAMPLE  
    If no parameter is defined then JSON template (https://github.com/paullizer/transitiveRouting/blob/main/multiHub/template-multiHub-SingleSub-nameSchema.json) will be used

        Deploy-VirtualNetwork.ps1

.EXAMPLE  
    You can use your own configured JSON template. UNC and HTTP/HTTPS paths can be used. You should really not be using HTTP at this point, please do better.

        Deploy-VirtualNetwork.ps1 -template "path:\to\tempalte.json"

.EXAMPLE  
    You can use your own configured JSON template. UNC and HTTP/HTTPS paths can be used. You should really not be using HTTP at this point, please do better.

        Deploy-VirtualNetwork.ps1 -template "https://github.com/paullizer/transitiveRouting/blob/main/multiHub/template-multiHub-SingleSub-nameExplicit.json"
#>

<#***************************************************
                       Process
-----------------------------------------------------
    
https://github.com/paullizer/transitiveRouting#multi-hub-architecture

***************************************************#>
    

<#***************************************************
                       Terminology
-----------------------------------------------------
N\A
***************************************************#>


<#***************************************************
                       Variables
-----------------------------------------------------
***************************************************#>

param (
    [Parameter(Mandatory=$false)]
    [string]$VmName,
    [Parameter(Mandatory=$false)]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$false)]
    [object]$Webhookdata
)

[string] $FailureMessage = "Failed to execute the command"
[int] $RetryCount = 3 
[int] $TimeoutInSecs = 20
$RetryFlag = $true
$Attempt = 1
$foundMatch = $false
$attemptScale = $false

# The standard number of VM levels for scaling is three (3) but you can add as many as you like
$scaleLevel = @(
                "Standard_B2ms",    # Level 1
                "Standard_D2s_v3",  # Level 2
                "Standard_D4s_v3"   # Level 3
                )

<#***************************************************
                       Functions
-----------------------------------------------------
***************************************************#>

function Set-VMSize () {
    <#----------------------
        Determine if a Azure PowerShell is installed. If not, attempt to install.
    -----------------------#>

    [CmdletBinding()]
    param (
        $RgName,
        $VmName,
        $VmSize
    )

    Write-Output ("Scaling down " +  $VmName + " to " + $VmSize)
    $VmScale = Get-AzVM -ResourceGroupName $RgName -Name $VmName
    $VmScale.HardwareProfile.VmSize = $VmSize
    Update-AzVM -ResourceGroupName $RgName -VM $VmScale
}

<#***************************************************
                       Execution
-----------------------------------------------------
***************************************************#>

Write-Output "Starting VM Scale Down."

do
{    
    Write-Output "Logging into Azure subscription using Az cmdlets..."
    
    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection=Get-AutomationConnection -Name $connectionName         

        Add-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint 
        
        Write-Output "Successfully logged into Azure subscription using Az cmdlets..."
        $attemptScale = $true
        $RetryFlag = $false
    }
    catch 
    {
        if (!$servicePrincipalConnection)
        {
            $ErrorMessage = "Connection $connectionName not found."

            $RetryFlag = $false

            throw $ErrorMessage
        }

        if ($Attempt -gt $RetryCount) 
        {
            Write-Output "$FailureMessage! Total retry attempts: $RetryCount"

            Write-Output "[Error Message] $($_.exception.message) `n"

            $RetryFlag = $false
        }
        else 
        {
            Write-Output "[$Attempt/$RetryCount] $FailureMessage. Retrying in $TimeoutInSecs seconds..."

            Start-Sleep -Seconds $TimeoutInSecs

            $Attempt = $Attempt + 1
        }   
    }
}
while($RetryFlag)

if ($attemptScale){
    
    if ($Webhookdata){
        $WebhookdataObject =  $Webhookdata.RequestBody | ConvertFrom-Json
        $VmName = $WebhookdataObject.data.essentials.configurationItems
        $ResourceGroupName = $WebhookdataObject.data.essentials.alertTargetIDs.split("/")[4]
    }

    try {
        $Vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
    }
    catch {
        Write-Output "[Error Message] $($_.exception.message) `n"
    }

    $CurrentSize = $Vm.HardwareProfile.VmSize

    for ($x = 0; $x -lt $scaleLevel.count; $x++) {

        if ($CurrentSize -eq $scaleLevel[$x]){

            if ($x -eq 0){
                Write-Output ("VM named " + $VmName + " is at Level " + ($x+1) + " - " + $scaleLevel[$x] + ". No change will be made.")
                $foundMatch = $true
            }
            else {
                try {
                    Write-Output ("Setting VM named " + $VmName + " to Level " + ($x) + " - " + $scaleLevel[$x-1] + ".")
                    Set-VMSize $ResourceGroupName $VmName $scaleLevel[$x-1]
                    $foundMatch = $true
                }
                catch {
                    Write-Output "[Error Message] $($_.exception.message) `n"
                }
            }

            if ($foundMatch){
                $x = $scaleLevel.count
            }
        }
    }

    if (!$foundMatch){
        # This is used to correct VM sizing so that it follows the scale level model.
        #   A VM could fall out of the scale level model if a user manually changes the VM size
        #   via the Portal or PowerShell.
        # Set VM to middle Level in scale Level array (close to middle anyway)
        try {
            Write-Output ("Setting VM named " + $VmName + " to Default, Level " + ([int]($scaleLevel.GetUpperBound(0)/2)+1) + " - " + $scaleLevel[[int]($scaleLevel.GetUpperBound(0)/2)] + ".")
            Set-VMSize $ResourceGroupName $VmName $scaleLevel[[int]($scaleLevel.GetUpperBound(0)/2)]
        }
        catch {
            Write-Output "[Error Message] $($_.exception.message) `n"
        }
    }

    Write-Output "Completed VM Scale Down."
}