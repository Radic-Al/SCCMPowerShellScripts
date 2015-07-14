param
(
    [string]$ServiceAccount="",  #ServiceAccount In Local AD to change password for (username only no domain)
    [string]$Password="",  #New password to assign
    [string[]]$Hosts,  #List of hosts to search for services running under $ServiceAccount
    [string]$ADGroupToSearch="",
    [switch]$ResetPassword,
    [switch]$Restart
)

IF ($ServiceAccount.Length -lt 1)
{
    $ServiceAccount = (Read-Host -Prompt "Provide Service Account to Search for");
}
$ServiceAccount = $ServiceAccount -replace "\\", "\\";

IF ($Hosts.Count -eq 0 -and $ADGroupToSearch.Length -eq 0)
{
    $Hosts = (Read-Host -Prompt "Provide Host(s) Name");
}

IF ($Password.Length -lt 1)
{
    $SecurePassword = (Read-Host -Prompt "Provide New Password" -AsSecureString);

    $BSTR = [system.runtime.interopservices.marshal]::SecureStringToBSTR($SecurePassword)
    $Password = [system.runtime.interopservices.marshal]::PtrToStringAuto($BSTR)
} else {
    $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force;
    $BSTR = [system.runtime.interopservices.marshal]::SecureStringToBSTR($SecurePassword)
    $Password = [system.runtime.interopservices.marshal]::PtrToStringAuto($BSTR)
}

IF ($ResetPassword)
{
    Set-ADAccountPassword -Identity $ServiceAccount -NewPassword $SecurePassword -Reset;
    "Password Reset on AD";
}


Try
{
    foreach ($hostname in $Hosts)
    {
        $services = Get-WmiObject -Class Win32_Service -ComputerName $hostname -Filter "StartName Like '$ServiceAccount@%' OR StartName Like '%\\$ServiceAccount'";
    
        foreach ($service in $services)
        {
            $service | Select Name, StartName, State;
            $serviceName = $service.Name;
            write-host "Stopping $serviceName";
            if ($service.Change($Null, $Null, $Null, $Null, $Null, $Null, $Null, $Password).ReturnValue -eq 0)
            {
                write-host "Service account password updated" -foregroundcolor "Green";
            } else {
                write-host "Service account update failed" -ForegroundColor "Red";
            }
            
            if (-not $Restart)
            {
                $PSService = get-service -ComputerName $hostname -Name $serviceName;
                if ($PSService.Status -eq "Started")
                {
                    $PSService.Stop();
                }
                try
                {
                    $PSService.WaitForStatus("Stopped", '00:01:00');
                }
                catch
                {}
                if ($PSService.Status -eq "Stopped")
                {
                    write-host "Service stopped" -ForegroundColor "Green";
                } else {
                    write-host "Service failed to stop" -ForegroundColor "Yellow";
                }

                if ($PSService.Status -eq "Stopped")
                {
                    $PSService.Start();
                }
                try
                {
                    $PSService.WaitForStatus("Started", '00:01:00');
                }
                catch
                {}
                if ($PSService.Status -eq "Started")
                {
                    write-host "Service Started Successfully" -ForegroundColor "Green";
                } else {
                    write-host "Service did not restart" -ForegroundColor "Green";
                }
                Get-WmiObject -Class Win32_Service -ComputerName $hostname -Filter "Name = '$serviceName'" | Select Name, StartName, State;
                Write-Host "";
            }
        }
        Write-Host "";
        Get-WmiObject -Class Win32_Service -ComputerName $hostname -Filter "StartName Like '$ServiceAccount@%' OR StartName Like '%\\$ServiceAccount'"  | Select Name, StartName, State;
        if ($Restart)
        {
            Write-Host "Restarting $hostname";
            Restart-Computer $hostname -Force;
			Write-Host "";
			Write-Host "";
        }
    }
}
Catch
{
    [system.exception];
    "system exception caught $_.InvocationInfo.ScriptLineNumber $_.Exception.ItemName $_.Exception.Message";
}
Finally
{
    
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR);
    Remove-Variable Password,SecurePassword, BSTR, Hosts, ServiceAccount;
}