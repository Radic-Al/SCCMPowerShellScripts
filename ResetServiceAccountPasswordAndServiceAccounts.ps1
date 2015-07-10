param
(
    [string]$ServiceAccount="",  #ServiceAccount In Local AD to change password for (username only no domain)
    [string]$Password="",  #New password to assign
    [string[]]$Hosts,  #List of hosts to search for services running under $ServiceAccount
    [switch]$ResetPassword
)

IF ($ServiceAccount.Length -lt 1)
{
    $ServiceAccount = (Read-Host -Prompt "Provide Service Account to Search for");
}
$ServiceAccount = $ServiceAccount -replace "\\", "\\";

IF ($Hosts.Count -eq 0)
{
    $Hosts = (Read-Host -Prompt "Provide Host(s) Name");
}

#Reset AD Password
IF ($Password.Length -lt 1)
{
    $SecurePassword = (Read-Host -Prompt "Provide New Password" -AsSecureString);

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
            
            if ($Service.StopService().ReturnValue -eq 0)
            {
                write-host "Service stopped" -ForegroundColor "Green";
            } else {
                write-host "Service failed to stop" -ForegroundColor "Yellow";
            }

            if ($Service.StartService().ReturnValue -eq 0)
            {
                write-host "Service Started Successfully" -ForegroundColor "Green";
            } else {
                write-host "Service did not restart" -ForegroundColor "Green";
            }
            Get-WmiObject -Class Win32_Service -ComputerName $hostname -Filter "Name = '$serviceName'" | Select Name, StartName, State;
        }
    }
}
Catch
{
    [system.exception];
    "system exception caught";
}
Finally
{
    
    [Runtime.InteropServices.Marshal]::ZeroFreeBSTR($BSTR);
    Remove-Variable Password,SecurePassword, BSTR;
}