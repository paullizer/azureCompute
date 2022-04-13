<#  
.SYNOPSIS  
    Vertically scale an Azure Virtual Machine
.DESCRIPTION  
    Vertically scale an Azure Virtual Machine

        v1.0 - Update
.NOTES  
    File Name       :   Start-AzVMScaleUp.ps1  
    Author          :   Paul Lizer, paullizer@microsoft.com
    Prerequisite    :   PowerShell V5, Azure PowerShell 5.6.0 or greater
    Version         :   1.0 (2022 04 13)     
.LINK  
    https://github.com/paullizer/azureCompute 
.EXAMPLE  
    Manual exection as a PowerShell script with custom VM Size list
        Start-AzVMScale.ps1 -VmName {Azure_VM-Name} -ResourceGroupName {Azure_Resource_Group_Name} -VmSizes {Comma,Seperated,Sizes}
        Start-AzVMScale.ps1 -VmName "VM-Host1" -ResourceGroupName "RG-East" -VmSizes "Standard_D2s_v3,Standard_D3s_v3,Standard_D4s_v3,Standard_D6s_v3"

.EXAMPLE  
    Manual exection as a PowerShell script
        Start-AzVMScaleUp.ps1 -VmName {Azure_VM-Name} -ResourceGroupName {Azure_Resource_Group_Name}
        Start-AzVMScaleUp.ps1 -VmName "VM-Host1" -ResourceGroupName "RG-East"

.EXAMPLE  
    Manual exection as a PowerShell script without VMName, all VMs in the defined Resource Group will scale
        Start-AzVMScaleUp.ps1 -ResourceGroupName {Azure_Resource_Group_Name}
        Start-AzVMScaleUp.ps1 -ResourceGroupName "RG-East"

.EXAMPLE  
    Triggered by Scheduled Runbook. Populate the VmName and ResourceGroupName values when initiating the Runbook.

        Start-AzVMScaleUp.ps1        

.EXAMPLE  
    Triggered by Azure Alert. The WebhookData is automatically sent.

        Start-AzVMScaleUp.ps1
#>

<#***************************************************
                       Process
-----------------------------------------------------
    
https://github.com/paullizer/azureCompute/tree/main/automatedScaling

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
    [Parameter(Mandatory=$false, HelpMessage="Enter a singular VM.")]
    [string]$VmName,
    [Parameter(Mandatory=$false, HelpMessage="Enter a singular Resource Group.")]
    [string]$ResourceGroupName,
    [Parameter(Mandatory=$false, HelpMessage="Enter at least two VM size names in order from small to large, seperated by comma (no spaces).")]
    [string]$VmSizes,
    [Parameter(Mandatory=$false, HelpMessage="Webhook JSON data is delivered via another Azure service, not used for scheduled or manual runbooks.")]
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
                "Standard_B2ms"
                )

<#***************************************************
                       Functions
-----------------------------------------------------
***************************************************#>

function Set-VMSize () {
    <#----------------------
        Determine if a Azure PowerShell is installed. If not, attempt to install
    -----------------------#>

    [CmdletBinding()]
    param (
        $RgName,
        $VmName,
        $VmSize
    )

    Write-Output ("Scaling " +  $VmName + " to " + $VmSize)
    $VmScale = Get-AzVM -ResourceGroupName $RgName -Name $VmName
    $VmScale.HardwareProfile.VmSize = $VmSize
    Update-AzVM -ResourceGroupName $RgName -VM $VmScale | Out-Null
}

<#***************************************************
                       Execution
-----------------------------------------------------
***************************************************#>

Write-Output "Starting VM Scaling."

do
{    
    Write-Output "Logging into Azure subscription using Az cmdlets..."
    
    $connectionName = "AzureRunAsConnection"
    try
    {
        # Get the connection "AzureRunAsConnection "
        $servicePrincipalConnection = Get-AutomationConnection -Name $connectionName         

        Add-AzAccount `
            -ServicePrincipal `
            -TenantId $servicePrincipalConnection.TenantId `
            -ApplicationId $servicePrincipalConnection.ApplicationId `
            -CertificateThumbprint $servicePrincipalConnection.CertificateThumbprint | Out-Null
        
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

    if (!$VmName) {
        Write-Output ("Getting list of VMs from " + $ResourceGroupName)

        $VmList = Get-AzVM -ResourceGroupName $ResourceGroupName

        Write-Output ("Number of VMs discovered for scaling: " + $VmList.count)

        foreach ($VmName in $VmList.name){
            if ($VmSizes){
                $scaleLevel = @()
                foreach ($size in $VmSizes.Split(",")) {
                    $scaleLevel += $size
                }
            }
        
            try {
                $Vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
                $CurrentSize = $Vm.HardwareProfile.VmSize
            }
            catch {
                Write-Output "[Error Message] $($_.exception.message) `n"
                Exit 0
            }
        
            for ($x = 0; $x -lt $scaleLevel.count; $x++) {
        
                if ($CurrentSize -eq $scaleLevel[$x]){
        
                    if ($x -eq $scaleLevel.count-1){
                        Write-Output ("VM named " + $VmName + " is at size - " + $scaleLevel[$x] + ". No change will be made.")
                        $foundMatch = $true
                    }
                    else {
                        try {
                            Set-VMSize $ResourceGroupName $VmName $scaleLevel[$x+1]
                            $foundMatch = $true
                        }
                        catch {
                            Write-Output "[Error Message] $($_.exception.message) `n"
                            Exit 0
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
                    Write-Output ("Setting VM named " + $VmName + " to size - " + $scaleLevel[[int]($scaleLevel.GetUpperBound(0)/2)] + ".")
                    Set-VMSize $ResourceGroupName $VmName $scaleLevel[[int]($scaleLevel.GetUpperBound(0)/2)]
                }
                catch {
                    Write-Output "[Error Message] $($_.exception.message) `n"
                    Exit 0
                }
            }
        }
    }
    else {
        if ($VmSizes){
            $scaleLevel = @()
            foreach ($size in $VmSizes.Split(",")) {
                $scaleLevel += $size
            }
        }
    
        try {
            $Vm = Get-AzVM -ResourceGroupName $ResourceGroupName -Name $VmName
            $CurrentSize = $Vm.HardwareProfile.VmSize
        }
        catch {
            Write-Output "[Error Message] $($_.exception.message) `n"
            Exit 0
        }
    
        for ($x = 0; $x -lt $scaleLevel.count; $x++) {
    
            if ($CurrentSize -eq $scaleLevel[$x]){
    
                if ($x -eq $scaleLevel.count-1){
                    Write-Output ("VM named " + $VmName + " is at Level " + ($x+1) + " - " + $scaleLevel[$x] + ". No change will be made.")
                    $foundMatch = $true
                }
                else {
                    try {
                        Set-VMSize $ResourceGroupName $VmName $scaleLevel[$x+1]
                        $foundMatch = $true
                    }
                    catch {
                        Write-Output "[Error Message] $($_.exception.message) `n"
                        Exit 0
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
                Exit 0
            }
        }

    }

    Write-Output "Completed VM Scaling."
}