#### ESTABLISHING VARIABLES ####

## CURRENT DATE
$Data = Get-Date -Format "yyyy-MM-dd HH:mm:ss"

## ARRAY THAT HOLDS ALL OBJECTS - JOB ENTRIES
$report = @()

## SPECIFYING DATA FOR SENDMAIL FUNCTION
$fromemail = 'Job_Alert@domain_name.com'
$mailserver = 'mail_server.domain_name.com'
$toemail = 'recipient@domain_name.com'

## SPECIFYING BODY CSS STYLE
$style = "<style>BODY{font-family: Arial; font-size: 10pt;}"
$style = $style + "TABLE{border: 1px solid black; border-collapse: collapse;}"
$style = $style + "TH{border: 1px solid black; background: #dddddd; padding: 5px; }"
$style = $style + "TD{border: 1px solid black; padding: 5px; }"
$style = $style + "</style>"

## SPECIFYING DATABASE CONNECTION STRING
$dataSource = “DATABASE_SERVER_NAME”
$database = “msdb”
$connectionString = “Server=$dataSource;Database=$database;Integrated Security=True;”

## OPENING CONNECTION TO THE DATABASE
$connection = New-Object System.Data.SqlClient.SqlConnection
$connection.ConnectionString = $connectionString
$connection.Open()



## QUERY THAT FINDS ALL JOBS THAT ARE CURRENTLY RUNNING

$query =  @"
SELECT sj.name, sja.*
FROM msdb.dbo.sysjobactivity AS sja
INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id
WHERE sja.start_execution_date IS NOT NULL
AND sja.stop_execution_date IS NULL
"@

## QUERY THAT FINDS ALL JOBS THAT WERE RUNNING IN THE PAST AND THAT RUNS CURRENTLY - USEFUL FOR TESTING PURPOSES

<#
$query =  @"
SELECT sj.name, sja.*
FROM msdb.dbo.sysjobactivity AS sja
INNER JOIN msdb.dbo.sysjobs AS sj ON sja.job_id = sj.job_id
WHERE sja.start_execution_date IS NOT NULL
"@
#>


## GETTING RESULTS FROM DATABASE
$command = $connection.CreateCommand()
$command.CommandText = $query
$result = $command.ExecuteReader()
$table = new-object “System.Data.DataTable”
$table.Load($result)

## CLOSING CONNECTION WITH SQL DB
$connection.Close()

## FOREACH LISTED ROW/JOB CALCULATE HOW LONG IT RUNS, AND IF RUNS OVER 5 MINUTES - ADD TO REPORT ARRAY
ForEach ($T in $table) {
$JStart = $T.start_execution_date -f "yyyy-MM-dd HH:mm:ss"
$Date_Diff = NEW-TIMESPAN –Start $JStart –End $Data

    ## BELOW SPECIFY HOW MANY MINUTES IS THE TRIGGER - 5 IN THIS EXAMPLE
    if ($Date_Diff.TotalMinutes -gt 5){
    $ts = New-TimeSpan -minutes $Date_Diff.TotalMinutes
    $JobDuration = '{0:00}:{1:00}:{2:00}' -f $ts.Hours,$ts.Minutes,$ts.Seconds

    $CustomObject = [pscustomobject]@{
    Name=$T.name;
    JobStart=$T.start_execution_date;
    HowLongIsRunning=$JobDuration;
    }

    }
## ADDING EACH ROW/JOB OBJECT THAT HAS BEEN REPORTED, TO THE REPORT ARRAY
$report += $CustomObject
}

## CREATING MESSAGE BODY / CONVERTING TO HTML
$body = $report | select Name, JobStart, HowLongIsRunning | ConvertTo-Html -Head $style

## INFORMATION ABOUT SCRIPT LOCATION
$body += "Script location: \\Server_Name\C$\Tools\Scripts\SQL\SQL Jobs Monitor"

## THAT PART HAS BEEN LEFT FOR TESTING PORPOSES
#$format = @{Expression={$_.name};Label=”Job Name”;width=10},@{Expression={$_.start_execution_date};Label=”Job Start Time”; width=30}
#$table | format-table $format -AutoSize

## IR THERE IS AN ENTRY IN REPORT ARRAY - SEND MESSAGE
if ($report) {
send-mailmessage -Priority High -from $fromemail -to $toemail -SMTPServer $mailserver -Subject "Some SQL Jobs ran more than 5 minutes." -Body "$body" -BodyAsHtml
} else {
Write-Output "No SQL jobs are currently running."
}