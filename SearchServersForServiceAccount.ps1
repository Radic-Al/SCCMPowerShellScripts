param
(
    [string]$ADGroup,
    [string]$Hostname,
    [string]$ADOSFilter,
    [string]$ServiceAccount,
    [switch]$ServerListOnly
)

$__hosts = @();

if ($Hostname.Length -gt 0)
{
    $__hosts += $Hostname;
}

if ($ADOSFilter.Length -gt 0)
{
    $_hosts = @(Get-ADComputer -Filter { OperatingSystem -Like '*Windows Server*'} | Where-Object {$_.DistinguishedName -notlike "*OU=Hosted*"} | Select Name);
    foreach ($_host in $_hosts)
    {
        $__hosts += $_host.Name;
    }
}


if ($ADGroup.Length -gt 0)
{
    foreach ($_host in get-adGroupMember "$ADGroup")
    {
        $__hosts += $_host.Name;
    }
}

"" | Out-File "./test.txt"

foreach ($hostname in $__hosts)
{
    $services = @();
    if (-not $ServerListOnly)
    {
        try
        {
            if (Test-Connection $hostname -Count 1 -Quiet)
            {
                $services = Get-WmiObject -Class Win32_Service -ComputerName $hostname -Filter "StartName Like '$ServiceAccount@%' OR StartName Like '%\\$ServiceAccount'";
            }
        } catch {}

        Write-Host ;
        Write-Host $_host;
        Write-Host "-----------------";
        foreach ($service in $services)
        {
            Write-Host $service.Name $service.Status;
        }
    } else {
        try
        {
            if (Test-Connection $hostname -Count 1 -Quiet)
            {
                $services = @(Get-WmiObject -Class Win32_service -ComputerName $hostname -Filter "StartName Like '$ServiceAccount@%' OR StartName Like '%\\$ServiceAccount'");
            }
        } catch {}
        if ($services.count -gt 0)
        {
            Write-Host $hostname;
            $hostname | Out-File "./test.txt" -Append
        }
    }
}