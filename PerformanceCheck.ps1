$Datagrams = Get-Counter -Counter "\IPv4\Datagrams/sec" -SampleInterval 5 -MaxSamples 3
$DataGrams | 
ForEach-Object { 
    $props = @{'ComputerName'=(Get-Content Env:\COMPUTERNAME);
               'IPv4Datagrams'=($_.CounterSamples.CookedValue);
               'Collected'=($_.CounterSamples.TimeStamp)}
    $obj = New-Object -TypeName PSObject -Property $props
    $obj.PSObject.TypeNames.Insert(0,'Report.IPv4DatagramsPerSec')
    Write-Output $obj
} |
Save-ReportData -ConnectionString "Server=myServerAddress;Database=myDataBase;Trusted_Connection=True;"
