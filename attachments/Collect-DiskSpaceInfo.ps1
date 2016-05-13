[CmdletBinding()]
param(
    [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
    [string[]]$ComputerName
)
PROCESS {
    foreach ($computer in $computername) {
        try {
            $params = @{'ComputerName'=$computer;
                        'Filter'="DriveType=3";
                        'Class'='Win32_LogicalDisk';
                        'ErrorAction'='Stop'}
            $ok = $True
            $disks = Get-WmiObject @params
        } catch {
            Write-Warning "Error connecting to $computer"
            $ok = $False
        }

        if ($ok) {
            foreach ($disk in $disks) {
                $properties = @{'ComputerName'=$computer;
                                'DeviceID'=$disk.deviceid;
                                'FreeSpace'=$disk.freespace;
                                'Size'=$disk.size;
                                'Collected'=(Get-Date)}
                $obj = New-Object -TypeName PSObject -Property $properties
                $obj.PSObject.TypeNames.Insert(0,'Report.DiskSpaceInfo')
                Write-Output $obj
            }
        }                       
    }
}
