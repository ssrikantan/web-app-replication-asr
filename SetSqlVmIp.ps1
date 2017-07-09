
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
 

    Write-OutPut ("Name of resource group: " + $RGName)
    Try
    {
        "Logging in to Azure..."
        $Conn = Get-AutomationConnection -Name AzureRunAsConnection 
        Add-AzureRMAccount -ServicePrincipal -Tenant $Conn.TenantID -ApplicationId $Conn.ApplicationID -CertificateThumbprint $Conn.CertificateThumbprint

        "Selecting Azure subscription..."
        Select-AzureRmSubscription -SubscriptionId $Conn.SubscriptionID -TenantId $Conn.tenantid 

       
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
            $VMi = $vmMap.$VMID   
            $VM = Get-AzureRmVm -ResourceGroupName $RGName -Name $VMi.RoleName
            $nics = Get-AzureRmNetworkInterface -ResourceGroupName $VM.ResourceGroupName

            foreach ($nic in $nics)
            {
                if($nic.VirtualMachine.Id.Equals($VM.Id))
                {
                    Write-Output ("Found a matching nic for this VM:")
                    Break
                }
                else
                {
                    # ignore,not a match
                }
            }
            $PRIVIP = $nic.IpConfigurations | select-object -ExpandProperty PrivateIpAddress
            Set-AzureRmAutomationVariable -AutomationAccountName $AutomationAccountName -Name $AutomationVariableName -ResourceGroupName $VM.ResourceGroupName -Value $PRIVIP -Encrypted $False
            Write-Output ("Set the Runbook variable with the Private IP of the SQL Server VM : " + $PRIVIP)
        }
        Catch
        {
            $ErrorMessage = 'Failed to set the Runbook variable with the Private IP of the SQL Server VM.'
            $ErrorMessage += " `n"
            $ErrorMessage += 'Error: '
            $ErrorMessage += $_
            Write-Error -Message $ErrorMessage `
            -ErrorAction Stop
        }

    }
}
