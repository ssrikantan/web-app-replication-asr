
param ( 
        [Object]$RecoveryPlanContext 
      ) 

Write-Output $RecoveryPlanContext

$AutomationVariableName = 'PrivateIpSqlDb'
$AutomationAccountName = 'asrdraccount'

if($RecoveryPlanContext.FailoverDirection -ne 'PrimaryToSecondary')
{
    Write-Output 'Script is ignored since Azure is not the target'
}
else
{
    $VMinfo = $RecoveryPlanContext.VmMap | Get-Member | Where-Object MemberType -EQ NoteProperty | select -ExpandProperty Name
    $vmMap = $RecoveryPlanContext.VmMap
   
    Write-Output ("Found the following VMGuid(s): `n" + $VMInfo)

    if ($VMInfo -is [system.array])
    {
        $VMinfo = $VMinfo[0]

        Write-Output "Found multiple VMs in the Recovery Plan"
    }
    else
    {
        Write-Output "Found only a single VM in the Recovery Plan"
    }

    $RGName = $RecoveryPlanContext.VmMap.$VMInfo.ResourceGroupName

    #Write-OutPut ("Name of resource group: " + $RGName)
    Try
    {
        "Logging in to Azure..."
        $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
        Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

        "Selecting Azure subscription..."
        Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 

         $SqlVmPrivateIpVar = Get-AzureRMAutomationVariable -AutomationAccountName $AutomationAccountName -Name $AutomationVariableName -ResourceGroupName $RGName  
        "Retrieved the SQL VM Private IP Variable from the Runbook Automation Account..."
        $SqlVmPrivateIpVal  = $SqlVmPrivateIpVar.value
       
        Write-Output ("SQL VM Private IP retrieved from Automation variable" + $SqlVmPrivateIpVal)
        $scriptarguments = "-SQLServerName $SqlVmPrivateIpVal"
    }
    Catch
    {
        $ErrorMessage = 'Login to Azure subscription failed.'
        $ErrorMessage += " `n"
        $ErrorMessage += 'Error: '
        $ErrorMessage += $_
        Write-Error -Message $ErrorMessage `
                        -ErrorAction Stop
    }
 foreach($VMID in $VMinfo)
     {
         Try
         {
            $VM = $vmMap.$VMID   
                        
            if( !(($VM -eq $Null) -Or ($VM.ResourceGroupName -eq $Null) -Or ($VM.RoleName -eq $Null))) 
            {
                #this check is to ensure that we skip when some data is not available else it will fail
                Write-output ("VM Resource Group Name " + $VM.ResourceGroupName)
                Write-output ("VM Name " + $VM.RoleName)
                $VMData = Get-AzureRmVM -ResourceGroupName $VM.ResourceGroupName -Name $VM.RoleName
                Write-Output ("retrieved VM Detailed info .... "+$VMData) 
                $PRENIC = $VMData.NetworkProfile.NetworkInterfaces[0]
                Write-OutPut ('NIC Unique Identifier to update' + $PRENIC.Id)
                $ALLNICS = Get-AzureRmNetworkInterface  -ResourceGroupName $VM.ResourceGroupName 
                Write-OutPut ('Count of all NICs in this Resource Group ...' + $ALLNICS.Count)
                $NIC = ""
                foreach($allnic IN $ALLNICS)
                {
                    If ($PRENIC.Id.Equals($allnic.Id))
                    {
                        $NIC = $allnic
                        Write-OutPut ('Located the NIC assigned to this VM...' +  $allnic.Id)
                        break
                    }
                 }
                $PIP = New-AzureRmPublicIpAddress -Name ('pip'+$VM.RoleName) -ResourceGroupName $RGName -Location $VMData.Location -AllocationMethod Dynamic
                Write-Output ("Public IP Created ....... ")  
                $NIC.IpConfigurations[0].PublicIpAddress = $PIP
                Set-AzureRmNetworkInterface -NetworkInterface $NIC     
                Write-Output ("Added public IP address to the NIC in VM: " + $VM.RoleName) 

                Set-AzureRmVMCustomScriptExtension -ResourceGroupName $VM.ResourceGroupName `
                     -VMName $VM.RoleName `
                     -Name "myCustomScript" `
                     -FileUri "https://asrdrscriptstore.blob.core.windows.net/scripts/UpdateWebConfigRemote.ps1" `
                     -Run "UpdateWebConfigRemote.ps1" -Argument $scriptarguments -Location $VMData.Location
                     #-Run "UpdateWebConfigRemote.ps1" -Argument "-SQLServerName 10.0.2.4" -Location $VMData.Location  
                Update-AzureRmVm -ResourceGroupName $VM.ResourceGroupName -VM $VMData
                Write-Output ("Updated the SQL Database connection string in web.config inside VM: " + $VM.RoleName)
            }
            else
            {
                    Write-Output ("Empty block received, no VMs in it ...")  
            }
        }
        Catch
        {
            $ErrorMessage = 'Failed to udpate VM Public IP.'
            $ErrorMessage += " `n"
            $ErrorMessage += 'Error: '
            $ErrorMessage += $_
            Write-Error -Message $ErrorMessage `
            -ErrorAction Stop
        }
    }
}
