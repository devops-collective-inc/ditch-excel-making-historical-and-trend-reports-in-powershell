# Capturing the data

## Collecting Data

Data collection is where you'll be using PowerShell. Keep in mind that one of the goals of this book is to provide you with tools that make storing the data in SQL Server as transparent and easy as possible. With that in mind, the data must be collected and formatted in a way that supports transparent and easy. So I'm going to establish some standards, which you'll need to follow.

As an example, I'm going to write a script that retrieves local drive size free space information (on my systems, SAN storage looks like a local drive to Windows, so it'll capture that space for SAN-connected volumes). I'm writing the data-collection piece as a PowerShell advanced script; if you're not familiar with those, check out _Learn PowerShell Toolmaking in a Month of Lunches_ (http://manning.com/).

There are a few important things to notice about this:

- The data-collection function outputs a single custom object. This is the only thing my data-storage tools will accept.
- The custom object has a custom type name, "Report.DiskSpaceInfo." The first part of that, "Report." is mandatory. In other words, every function you write must output a custom object whose type name starts with the word "Report" and a period. The second part of the type name is defined by you, should represent the kind of data you're collecting, and must be unique within the database. 
- Be sure to include a ComputerName property if appropriate, so that you can identify which computer each piece of data came from.
- You should always include a "Collected" property, which is the current date. Don't convert this to any kind of display format - you'll worry about that when building the report. Right now, you just want a raw date/time object.
- Property names should consist of letters, maybe numbers, and nothing else. No spaces, no symbols. It's "FreeSpace," not "Free Space (bytes)." 
- You need to be a bit careful about what data you collect. My tools are capable of dealing with properties that contain dates (like "collected"), strings of up to 250 characters, and 64-bit integers (capable of storing numbers up to around 9,000,000,000,000,000,000). Anything else will result in un-handled errors and possibly lost or truncated data. Strings using double-byte character sets (DBCS) like Unicode are fine.
- You don't have to explicitly include ComputerName or Collected properties. However, if you do, I'll automatically tell SQL Server to index those (I'll also index any Name property you pass in) for faster reporting, since you'll most often be sorting and filtering on those fields.

Planning is crucial here. Once your first data is added to the SQL Server database, you lock in the properties that will be stored. Here, its going to be computer name, drive letter (DeviceID), size, free space, and the collected date. I can never add more information to my DiskSpaceInfo repository without deleting the existing data and starting over. So the moral of the story is, think hard about what you want to collect and report on.

When run, my function outputs something like this:
```
FreeSpace  : 43672129536
Size     : 64055406592
ComputerName : MOC
Collected  : 11/17/2012
DeviceID   : C:
```
Don't be tempted to make this look fancy - remember, it's go to go into SQL Server. When you build your reports, you can pretty this up as much as you want.

I'm naming my script `C:\Collect-DiskSpaceInfo.ps1`. You'll see that script name later.

## Storing Your Data

Included with this book should be a script module named SQLReporting. This needs to go in a very specific location on your computer:

    My Documents (make sure it's _My_ Documents, not _Public_ Documents)
        WindowsPowerShell
            Modules
                SQLReporting
                    SQLReporting.psm1

If you don't have the folder and filename structure exactly correct, this won't work. After putting the module there, open a new PowerShell console and run `Import-Module SQLReporting` to make sure it imports correctly. If you get an error, then you didn't put it in the right spot.

I'm assuming that, by this point, you have a command or script that can produce the objects you want to store, and that those have an appropriate type name as outlined in the previous chapter. For the sake of example, my script name is `C:\Collect-DiskSpaceInfo.ps1`.

I'm also assuming that you've installed the SQLReporting module as outlined above.

## Saving to Your Local SQL Server Express Instance

If you're taking the easy way out, and saving to a local SQL Server Express instance named SQLEXPRESS, do this:
````
C:\Collect-DiskSpaceInfo.ps1 |
Save-ReportData -LocalExpressDatabaseName PowerShell
````
That's it. Of course, this presumes you've already created the "PowerShell" database (which could be named anything you want; I outlined that earlier in this book). In my example, the objects output by Collect-DiskSpaceInfo.ps1 have a type name of "Report.DiskSpaceInfo," so they'll be stored in a table named DiskSpaceInfo within the PowerShell database. That table gets created automatically if it doesn't exist.

## Saving to a Remote SQL Server

This is a bit trickier, but not too much. You'll need to start by constructing a connection string. They look something like this:

`Server=myServerAddress;Database=myDataBase;Trusted\_Connection=True;`

You fill in your server name or IP address. For example, to access the default instance on SERVER1, the server address would just be SERVER1. To access an instance named MYSQL on a server named SERVER2, the server address would be SERVER2\MYSQL. That's a backslash. You also fill in your database name. Using the connection string looks like this:

````
C:\Collect-DiskSpaceInfo.ps1 |
Save-ReportData -ConnectionString "Server=myServerAddress;Database=myDataBase;Trusted\_Connection=True;"
````
In other words, just pass the connection string instead of a local express database name. The necessary table will be created if it doesn't already exist.

## Reading Your Data

PowerShell isn't really meant to read the data from your SQL Server database; SSRS will do that. But, if you want to quickly test your data, you can do so. You'll need a `-LocalExpressDatabaseName` or `-ConnectionString` parameter, exactly as described under "Storing Your Data." You also need to know the original object type name that went into the database, such as "Report.DiskSpaceInfo" in my example.

`Get-ReportData -LocalExpressDatabaseName PowerShell -TypeName Report.DiskSpaceInfo`

That's it. The appropriate objects should come out of the database. From there, you can sort them, filter them, or whatever using normal PowerShell commands. But the real action is when you use SSRS to read that data and construct reports!

## Collecting Performance Data

I'm adding this chapter to the book somewhat under protest. I know performance data is something folks want to collect; PowerShell just isn't an awesome way to do it.

PowerShell can only pull performance data _as it's happening_. So, let's say you grab your computer's CPU utilization _right now_. It's 3%. What's that tell you about your CPU utilization? Nothing. Your computer could average 80%, and you just happened to catch it on its slowest millisecond of the day. So performance data has to be captured in a series of samples, often over a long period of time, and that's where I'd argue PowerShell isn't well-suited.

Imagine you're capturing data from a remote computer: You've got to make a WMI connection, or a Remoting connection to use CIM, because those are the only real ways PowerShell can easily access performance counters. Both your computer and the remote one are running a copy of PowerShell to do that (in the case of Remoting, at least), which means they've spun up the .NET Framework, blah blah blah. It's layers of software; performance-capturing software is usually designed to be small and lightweight, and PowerShell is neither of those. That isn't a dig on PowerShell; it's just not what the shell was designed for.

But I know a lot of admins are going to want to do this anyway. "The Boss won't buy SCOM, and we have to do something." I'd argue that you _don't_ have to do "something" other than tell the The Boss, "no, you can't do that, it's not how the software works and you're creating more performance load than you're measuring, fool," but I suppose being employed can sometimes overrule technical accuracy.

To minimize impact, I'm going to offer an approach that runs scripts right on the machines you're measuring, rather than capturing data remotely. Yes, you're building a "performance monitoring agent," and that should bother you, because you probably didn't get into this industry to be a professional software developer. But that's what this task entails.

(By the way, if all this ranting sounds a little grumpy, I really only get to write these free ebooks on Sunday mornings and I haven't had much coffee yet.)

## Methodology

I'm going to write a script that captures performance data every 5 seconds, for a full minute, right on a local computer. The intent is that you'd schedule this under Task Scheduler to run whenever needed. I'd suggest running it during known peak utilization times, maybe 2-3 times a day. Don't get carried away and schedule it to run every 5 minutes - you're going to generate more data than can possibly be useful.

I'm going to write the actual performance-measuring bit as a function, and then call the function at the bottom of the script. That means you just schedule the script (actually, you'd schedule `PowerShell.exe -filename script.ps1`) to run. If you need to collect multiple bits of performance, you'd add a function for each bit, and call each one in the script.

The data is going to be stored in a remote SQL Server database, and if you plan to have multiple servers doing so, you're going to want a real SQL Server edition, not the Express one (which is limited in how many connections it can accept, amongst other restrictions).

Every server on which you install these is going to need my SQLReporting module. I'd honestly suggest putting the module in `\Windows\System32\WindowsPowerShell\v1.0\Modules\SQLReporting\SQLReporting.psm1`, just to ensure the module is available for all user accounts - including whatever account Task Scheduler is using to run the script. This isn't a "best practice;" the best practice would be to put the module somewhere not in System32, and then add that path to the PSModulePath environment variable. That, however, leads us down a path of instruction and explanation that's out of scope for this book. So I'm taking the cheater's way out and using System32.

## Finding a Counter

I'm going to rely on the PowerShell v3 Get-Counter command to access performance data. I'm starting by listing all available counter sets:
````
Get-Counter -ListSet \*
````
Using this, I discover the System set, which looks interesting. So I take a deeper look:
````
PS C:\> Get-Counter -ListSet System
CounterSetName   : System
MachineName    : .
CounterSetType   : SingleInstance
Description    : The System performance object consists of counters that apply to more than one instance of a
          component processors on the computer.
Paths       : {\System\File Read Operations/sec, \System\File Write Operations/sec, \System\File Control
          Operations/sec, \System\File Read Bytes/sec...}
PathsWithInstances : {}
Counter      : {\System\File Read Operations/sec, \System\File Write Operations/sec, \System\File Control
          Operations/sec, \System\File Read Bytes/sec...}

PS C:\> Get-Counter -ListSet System | Select-Object -ExpandProperty Counter
\System\File Read Operations/sec
\System\File Write Operations/sec
\System\File Control Operations/sec
\System\File Read Bytes/sec
\System\File Write Bytes/sec
\System\File Control Bytes/sec
\System\Context Switches/sec
\System\System Calls/sec
\System\File Data Operations/sec
\System\System Up Time
\System\Processor Queue Length
\System\Processes
\System\Threads
\System\Alignment Fixups/sec
\System\Exception Dispatches/sec
\System\Floating Emulations/sec
\System\% Registry Quota In Use
````
All interesting stuff. Note that this is a SingleInstance set, meaning there's only one of these on the system. A MultiInstance set comes in bunches - for example, the Process set is MultiInstance, with one instance of the counters for each running process. If you want to accurately grab data, you've got to decide which process you want to grab it for. System, in fact, is the only SingleInstance set I found on my machine. So I'm not going to use it. Might as well show you the hard stuff, right?

How about IPv4 instead?
````
PS C:\> Get-Counter -ListSet IPv4 | Select-Object -ExpandProperty Counter
\IPv4\Datagrams/sec
\IPv4\Datagrams Received/sec
\IPv4\Datagrams Received Header Errors
\IPv4\Datagrams Received Address Errors
\IPv4\Datagrams Forwarded/sec
\IPv4\Datagrams Received Unknown Protocol
\IPv4\Datagrams Received Discarded
\IPv4\Datagrams Received Delivered/sec
\IPv4\Datagrams Sent/sec
\IPv4\Datagrams Outbound Discarded
\IPv4\Datagrams Outbound No Route
\IPv4\Fragments Received/sec
\IPv4\Fragments Re-assembled/sec
\IPv4\Fragment Re-assembly Failures
\IPv4\Fragmented Datagrams/sec
\IPv4\Fragmentation Failures
\IPv4\Fragments Created/sec
````
Fun stuff there. Let's play. Here's my script, C:\PerformanceCheck.ps1:
````
$Datagrams = Get-Counter -Counter "\IPv4\Datagrams/sec" -SampleInterval 5 -MaxSamples 12
$DataGrams | Select-Object -Property @{n='Collected';e={$\_.CounterSamples.Timestamp}},
                  @{n='ComputerName';e={Get-Content Env:\COMPUTERNAME}},
                  @{n='IPv4DatagramsSec';e={$\_.CounterSamples.CookedValue}}
````
The basic methodology here is to get the counters into a variable, and you can see that I've specified 12 samples every 5 seconds, for a total of 1 minute. You then need to pull out the "CookedValue" property from each counter sample. I've also grabbed the sample timestamp and named it "Collected," and the current computer name, to correspond with what my SQLReporting module needs. The results of this:
````
Collected       ComputerName        IPv4DatagramsSec
---------       ------------        ----------------
11/18/2012 7:58:42 AM MOC             0.19922178698138
11/18/2012 7:58:47 AM MOC             825.908768304232
11/18/2012 7:58:52 AM MOC             711.73267889951
````
That's almost ready to be piped right to my Save-ReportData command, which will need to be given a complete connection string to a SQL Server database. The problem right now is that Select-Object doesn't give me a way to apply the proper custom TypeName to the objects, so I'll have to modify my script a bit:
````
$Datagrams = Get-Counter -Counter "\IPv4\Datagrams/sec" -SampleInterval 5 -MaxSamples 3
$DataGrams |
ForEach-Object {
  $props = @{'ComputerName'=(Get-Content Env:\COMPUTERNAME);
       'IPv4Datagrams'=($\_.CounterSamples.CookedValue);
       'Collected'=($\_.CounterSamples.TimeStamp)}
  $obj = New-Object -TypeName PSObject -Property $props
$obj.PSObject.TypeNames.Insert(0,'Report.IPv4DatagramsPerSec')
  Write-Output $obj
} |
Save-ReportData -Conn "Server=myServerAddress;Database=myDataBase;Trusted\_Connection=True;"
````
It was still worth doing the first version of the script as a quick-and-dirty test, but this second version will save the data into a SQL database.

So there you have it. Run that script every so often - not too often, mind you - and you'll have performance data in a SQL Server database. From there, you can start building reports on it.

