# Making a Report

I want to start by saying that SQL Server Reporting Services (SSRS) is a pretty powerful set of tools. While it'd be cool if this short little ebook gave you complete SSRS coverage, it ain't gonna happen. Hop on to Amazon (or wherever you buy your books) and you'll find a number of books, each hundreds of pages thick, covering SSRS in detail. What I'm going to attempt to give you is the crash course.

But before I do, let me reiterate something from the beginning of this book: _SQL Server Reporting Services is worth your time to learn_. Yes, you already know Excel, or Access, or whatever you're using these days. SSRS is better. SSRS can tap into any SQL Server-based data, along with data living in other database platforms. It's powerful. It offers scheduled report generation and delivery, a Web-based reporting console for end-user self-service, and a lot more. This is totally a tool you want to become proficient with, because the investment in time _will be paid back a hundredfold_, I promise.

OK. Let's go.

I've populated my PowerShell table with a year's worth of disk information from three computers, queried monthly from each. I'd like to produce a trend-line report, so that I can start to predict when I'll get low on space.

## Verifying Reporting Services

I'm going to start by launching the Reporting Services Configuration Manager. I'll log in, and then just verify that all of the services and whatnot are running properly.
![image023.png](images/image023.png)



Note that this is also where you can set up the Web Service URL, the Report Manager URL, modify e-mail settings, change the account report-generation runs under, and so forth. I'm just verifying that everything is started and running.

## Accessing Report Manager

Also note that Reporting Services has its own embedded Web server; it doesn't depend on IIS. If you go to the "Report Manager URL" tab, you'll find a link you can click to get to the Report Manager Web site. Report Manager can be used to do most of what I need; note that the version of SQL Server Management Studio included with SQL Server Express cannot provide this functionality. If you happen to have a full version of SQL Server Management Studio, you can use it to connect to Reporting Services. Since I don't, I'll work with the Web-based Report Manager.

Note: I'm going to breeze through this report-creating stuff - you'll find a more complete tutorial at [http://msdn.microsoft.com/en-us/library/ms167559%28v=sql.110%29.aspx](http://msdn.microsoft.com/en-us/library/ms167559%28v=sql.110%29.aspx).

Also note: I had to explicitly run Internet Explorer "as Administrator" to get Reporting Services to recognize me. Because I didn't feel like playing with permissions for this ebook, I just went with that.
![image025.png](images/image025.png)


I'm going to start by creating a new folder called "Disk Space." SSRS lets you apply permissions to folders, so you can grant other folks access to this. You can use the "Site Settings" link to assign site-wide permissions, and that'll let non-administrators get in, if you like. Obviously, that makes sense mainly if you're running this on a central SQL Server, and not on your own desktop or laptop.

Next, we have to create a data source within this folder. This is the database where we'll be pulling our data from. Because my SQLReporting module stores all of your data in a single database (named "PowerShell" in my examples), you could create an SSRS folder for all of your reports, since they'll all share that same data source.


As you can see, I just needed to specify the server and database portion of the connection string. I've selected Windows Integrated Security, meaning my login account will be used to access the data. Always use the Test Connection button to make sure this is working.

Note that we aren't actually going to use this data source, but I wanted to show you how to create one because once you start really getting into SSRS, having predefined sources can be very handy.
![image027.png](images/image027.png)


Back in the folder, we can see the new data source.
![image029.png](images/image029.png)

## Building a Report

But now we've got to take a bit of a departure. You can't actually design reports in Report Manager; you just manage them. So we need to create a report definition, and to do that we're going to need a tool. Go to [http://www.microsoft.com/en-us/download/details.aspx?id=29072](http://www.microsoft.com/en-us/download/details.aspx?id=29072) and get Report Builder. When installing, don't sweat the URL prompt - we can save our reports as .RDL files instead of deploying via HTTP.



I'm going to pick the Chart Wizard for my new report.
![image033.png](images/image033.png)



I need to create a new dataset (because this isn't linked to the Reporting Services installation, there's no access to any shared datasets created there).
![image035.png](images/image035.png)


This is a lot like the data source setup we did in Report Manager, which is one reason I wanted to show it to you there first. Always test the connection before proceeding!
![image037.png](images/image037.png)


Choose the table that contains the data you need. You can rearrange the fields using the little blue arrows, and then change grouping and aggregating of specific fields (like generating averages, min, max, and so on). Because I have only one table, there are no relationships to mess with, and I don't want to filter out any of the data.

If you're good with SQL Server, you can click "Edit as Text" to manually edit the SQL query instead of using the GUI. I'm actually going to do that, so that I can combine the ComputerName and DeviceID fields into a single field.
![image039.png](images/image039.png)


I've named this combined field "Computer-Drive," and I clicked the "!" button to run the query and test the results. That's just what I want.
![image041.png](images/image041.png)


I'm going to choose the Line chart type next, so that I can get a trend line.
![image043.png](images/image043.png)


Next, I decide which bits of data go where. The "Computer\_Drive" column will be series, meaning each Computer/Drive combination will have its own line on the chart. "Collected" will form the horizontal axis, showing time, and the sum of the FreeSpace for each value of Collected will form the vertical axis of the chart. Because I'll only have one free space value per computer per day, there won't actually be any summing happening.

The next screen lets you pick a visual style for the chart.


![image045.png](images/image045.png)


Er, yeah. After running the report (using the "Run" button in the ribbon), I'm not impressed. Back to Design.
![image047.png](images/image047.png)
A little resizing, and double-clicking to edit the chart title, might help.
![image049.png](images/image049.png)


W00t! We're definitely getting there. Now's when I could think of some potential changes to make.



![image051.png](images/image051.png)


I want to edit my query a bit, so I'll right-click my data set and edit the Query.
![image053.png](images/image053.png)
I've removed Size, because I'm not really using it. I've added an ORDER BY clause to make sure the data appears in date order, and I've added a calculation to display free space in megabytes instead of bytes, rounded to two decimal places. Note that I've been careful to name the resulting field the same name - "FreeSpace" - by using the AS option. Because my report is already looking for FreeSpace, it's important that the field continue to exist by that name.

![image055.png](images/image055.png)

I've edited the axis titles of the chart and made it a bit bigger.
![image057.png](images/image057.png)


Not bad. I could continue tweaking this - maybe using the T-SQL date/time functions to generate nicer-looking dates along the "X" axis - but let's call it "good" for now. I'll switch back into design mode and save this as DiskFreeSpace.rdl on the file system.
![image059.png](images/image059.png)

Back in the Web-based Report Manager, in my folder, I'll click Upload File to upload that .RDL file.

![image061.png](images/image061.png)

I can click the now-uploaded report to run it, and gain access to export options, like PDF.

## The Case for "Real" Reporting Services

This Express edition of Reporting Services is missing a few key features. I'll argue that most organizations probably already have a full edition of SQL Server someplace, and if you can get SSRS installed (it doesn't cost anything extra, it's just a feature), then you gain access to a lot of awesome abilities - like being able to schedule reports, let people subscribe to them, basically taking everything off your hands once the report is designed.

SSRS also supports "Report Parts," which are kind of like mini-report chunks that can be re-used in other reports. By building a library of such parts, you can then construct meta-reports that contain lots of information. That's why I think SSRS is such a good investment of your time - there's so much you can do to reduce your own future workload. The full SSRS also has a Web-based report designer, meaning you can define data sources (such as those you populate with PowerShell), and then let other folks build their own reports right in a Web browser.

SSRS also integrates with SharePoint, meaning reports and whatnot can be published to a SharePoint installation. Again, this is all about letting you define the reports, setting up a routine to put data into tables (which I've hopefully made pretty easy), and then never touching it again. Get reporting off your plate entirely by building dashboards and reports that happen automatically, and which report consumers can access on their own.


