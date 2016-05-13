function Save-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True,ValueFromPipeline=$True)]
        [object[]]$InputObject,

        [Parameter(Mandatory=$True,ParameterSetName='local')]
        [string]$LocalExpressDatabaseName,

        [Parameter(Mandatory=$True,ParameterSetName='remote')]
        [string]$ConnectionString
    )
    BEGIN {
        if ($PSBoundParameters.ContainsKey('LocalExpressDatabaseName')) {
            $ConnectionString = "Server=$(Get-Content Env:\COMPUTERNAME)\SQLEXPRESS;Database=$LocalExpressDatabaseName;Trusted_Connection=$True;"
        }
        Write-Verbose "Connection string is $ConnectionString"

        $conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
        $conn.ConnectionString = $ConnectionString
        try {
            $conn.Open()
        } catch {
            throw "Failed to connect to $ConnectionString"
        }

        $SetUp = $false
    }
    PROCESS {
        foreach ($object in $InputObject) {
            if (-not $SetUp) {
                $table = Test-Database -ConnectionString $ConnectionString -Object $object -Debug -verbose
                $SetUp = $True
            }

            $properties = $object | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name
            $sql = "INSERT INTO $table ("
            $values = ""
            $needs_comma = $false

            foreach ($property in $properties) {
                if ($needs_comma) {
                    $sql += ","
                    $values += ","
                } else {
                    $needs_comma = $true
                }

                $sql += "[$property]"
                if ($object.($property) -is [int]) {
                    $values += $object.($property)
                } else {
                    $values += "'$($object.($property) -replace "'","''")'"
                }
            }

            $sql += ") VALUES($values)"
            Write-Verbose $sql
            Write-Debug "Done building SQL for this object"

            $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
            $cmd.Connection = $conn
            $cmd.CommandText = $sql
            $cmd.ExecuteNonQuery() | out-null
        }
    }
    END {
        $conn.close()
    }
}

function Test-Database {
    [CmdletBinding()]
    param(
        [string]$ConnectionString,
        [object]$object
    )

    # Connect
    $conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
    $conn.ConnectionString = $ConnectionString
    $conn.Open() | Out-null

    $TypeName = $object | Get-Member | select-object -ExpandProperty TypeName
    $Properties = $object | Get-Member -MemberType Properties | Select-Object -ExpandProperty Name

    $Table = $typename.split('.')[1]
    Write-Verbose "Table name is $Table"

    if ($TypeName.split('.')[0] -ne 'Report') {
        throw "Illegal type name on input object - aborting - please read the book!"
    }

    # Test to see if table exists
    $sql = "SELECT COUNT(*) AS num FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND LOWER(TABLE_NAME) = '$($Table.tolower())'"
    write-verbose $sql
    $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
    $cmd.CommandText = $sql
    $cmd.Connection = $conn
    $result = $cmd.ExecuteReader()
    $result.read() | out-null
    $num_rows = $result.GetValue(0)
    Write-Debug "Tested for table"
    $result.close() | Out-Null

    $table = "[$table]"

    if ($num_rows -gt 0) {
        # Table exists
        $conn.close() | Out-Null
        return $table
    } else {
        # Table doesn't exist
        $sql = "CREATE TABLE dbo.$table ("
        $needs_comma = $false
        $indexes = @()

        foreach ($property in $Properties) {
            if ($needs_comma) {
                $sql += ','
            } else {
                $needs_comma = $True
            }

            if ($object.($property) -is [int] -or
                $object.($property) -is [int32] -or
                $object.($property) -is [uint32] -or
                $object.($property) -is [int64] -or
                $object.($property) -is [uint64]) {
                $sql += "[$property] BIGINT"
            } elseif ($object.($property) -is [datetime]) {
                $sql += "[$property] DATETIME2"
            } else {
                $sql += "[$property] NVARCHAR(255)"
            }

            if ($property -in @('name','computername','collected')) {
                $indexes += $property
            }

        }
        $sql += ")"
        Write-Debug "$sql"

        $cmd.CommandText = $sql
        $cmd.ExecuteNonQuery() | out-null

        foreach ($index in $indexes) {
            $sql = "CREATE NONCLUSTERED INDEX [idx_$index] ON $table([$index])"
            Write-Debug "$sql"
            $cmd.CommandText = $sql
            $cmd.ExecuteNonQuery() | out-null
        }

        $conn.close()
        return $table
    }

}

function Get-ReportData {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$True)]
        [string]$TypeName,

        [Parameter(Mandatory=$True,ParameterSetName='local')]
        [string]$LocalExpressDatabaseName,

        [Parameter(Mandatory=$True,ParameterSetName='remote')]
        [string]$ConnectionString
    )
    
    if ($PSBoundParameters.ContainsKey('LocalExpressDatabaseName')) {
        $ConnectionString = "Server=$(Get-Content Env:\COMPUTERNAME)\SQLEXPRESS;Database=$LocalExpressDatabaseName;Trusted_Connection=$True;"
    }
    Write-Verbose "Connection string is $ConnectionString"

    $conn = New-Object -TypeName System.Data.SqlClient.SqlConnection
    $conn.ConnectionString = $ConnectionString
    try {
        $conn.Open()
    } catch {
        throw "Failed to connect to $ConnectionString"
    }

    $table = "$($TypeName.split('.')[1].ToLower())"
    Write-Verbose "Table name is $Table"

    if ($TypeName.split('.')[0] -ne 'Report') {
        throw "Illegal type name on input object - aborting - please read the book!"
    }

    # Test to see if table exists
    $sql = "SELECT COUNT(*) AS num FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = 'dbo' AND LOWER(TABLE_NAME) = '$Table'"
    write-verbose $sql
    $cmd = New-Object -TypeName System.Data.SqlClient.SqlCommand
    $cmd.CommandText = $sql
    $cmd.Connection = $conn
    $result = $cmd.ExecuteReader()
    $result.read() | out-null
    $num_rows = $result.GetValue(0)
    $result.close() | Out-Null

    if ($num_rows -eq 0) {
        throw "Table for $TypeName not found in database"
    }

    # Need to get the schema for this table
    $sql = "select c.name, t.name from sys.columns c inner join sys.types t on c.system_type_id = t.system_type_id left outer join sys.index_columns ic on ic.object_id = c.object_id and ic.column_id = c.column_id left outer join sys.indexes i on ic.object_id = i.object_id and ic.index_id = i.index_id where t.name <> 'sysname' AND c.object_id = OBJECT_ID('$table')"
    Write-Verbose $sql

    $cmd.CommandText = $sql
    $result = $cmd.ExecuteReader()
    $properties = @{}
    while ($result.read()) {
        $properties.add($result.GetString(0),$result.getstring(1))
    }
    $result.close() | out-null

    Write-Debug "Constructed property bag"

    # construct query to get columns in known order
    $sql = "SELECT "
    $needs_comma = $false
    foreach ($property in $properties.keys) {
        if ($needs_comma) {
            $sql += ","
        } else {
            $needs_comma = $True
        }
        $sql += "[$property]"
    }
    $sql += " FROM $table"

    # query rows
    Write-Verbose $sql
    $cmd.commandtext = $sql
    $result = $cmd.executereader()
    while ($result.read()) {
        Write-Verbose "Reading row and constructing object"
        $obj = New-Object -TypeName PSObject
        $obj.PSObject.TypeNames.Insert(0,$TypeName)
        foreach ($property in $properties.keys) {
            Write-Verbose "  $property"
            if ($properties[$property] -eq 'datetime2') { [datetime]$prop = $result.GetDateTime($result.GetOrdinal($property)) }
            if ($properties[$property] -eq 'bigint') { [uint64]$prop = $result.GetInt64($result.GetOrdinal($property)) }
            if ($properties[$property] -eq 'nvarchar') { [string]$prop = $result.GetString($result.GetOrdinal($property)) }
            $obj | Add-Member -MemberType NoteProperty -Name $property -Value $prop
        }
        Write-Debug "Object constructed"
        Write-Output $obj
    }

    $result.close() | out-null
    $conn.close() | out-null
 }

New-Alias -Name ssql -Value Save-ReportData
New-Alias -Name gsql -Value Get-ReportData

Export-ModuleMember -Function Save-ReportData,Get-ReportData -Alias ssql,gsql