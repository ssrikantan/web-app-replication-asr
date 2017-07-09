#$SQLServerName = '10.0.2.4'
param ( 
        [string]$SQLServerName 
      )
#notepad (Get-WebConfigFile 'IIS:\Sites\Default Web Site\simple2tierweb_deploy')
Write-output "Executing powershell through VM custom script extension ....... "
Write-output "The SQL Server Name to set is " + $SQLServerName
$site = Get-WebApplication -Site "Default Web Site"

#Login-AzureRmAccount
#$SQLServerName = 'drasrsqlSrv14-test'
#$site=Get-Website -Name "Default Web Site"
#$site.Application
#$rootpath = $site.physicalpath
#$rootpath

  
       
        $FolderPath=Get-WebConfigFile 'IIS:\Sites\Default Web Site\simple2tierweb_deploy'
        $FolderPath
        $confipath=$FolderPath.DirectoryName+"\web.config"
        $confipath
        #$confipath= "C:\Inetpub\wwwroot\simple2tierweb_deploy\web.config"
        $xml = [xml](get-content $confipath -ErrorAction Stop)
        $cname = "miniappdbConnectionString1"
        $dbInfo = $xml.SelectNodes("/configuration/connectionStrings/add [@name='$cname']")
        $xml
        $ConnectionString=$dbInfo.connectionString
        $ConnectionString
        $connectionName=$dbInfo.name
        $arr=$ConnectionString.split(";")
        $ConnectionStringNew=""

        foreach($str in $arr)
        {
            if($str -like "Data Source*")
            {
                $str="Data Source="+$SQLServerName
            }
            if(!$str.Equals(""))
            {
                $ConnectionStringNew+=$str+";"
            }
        }
        $ConnectionStringNew
        Stop-Service w3svc;

        $pathVariable=$env:windir+"\system32\inetsrv"

        cd $pathVariable
        $site.name
        try
        {
            .\appcmd set config 'Default Web Site/simple2tierweb_deploy' -section:connectionStrings /"[name='$connectionName'].connectionString:$connectionstringnew"
            #.\appcmd set config $site.name -section:connectionStrings /"[name='$connectionName'].connectionString:$connectionstringnew"

        }
        catch
        {
            throw("Unable to update Server farm")
        }

        Start-Service w3svc
    