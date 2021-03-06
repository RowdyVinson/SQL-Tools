<#
Name: Compare Instance Objects
Author: Rowdy Vinson
Date: 8/9/16
Description: Uses running account privs to execute SQL data gathering scripts and compare the output. Output is the object type, name, and side indicator where the object is present. 
    Account requires read rights to msdb and master databases along with all user databases.
#>
#Gets target server names
$Server1 = Read-host -Prompt "Enter Server1 name"
$Server2 = Read-host -Prompt "Enter Server2 name"


#Change as needed. Running user account must have rights to this file. 
$Outpath = 'C:\it\'
$Outfile = $Outpath+'CompareInstance-'+$Server1+'_'+$Server2+'.txt'

#Loads SQL Cmdlets
if (! (Get-PSSnapin -Name sqlservercmdletsnapin100 -ErrorAction SilentlyContinue))
{
    "Loading SQL server commandlets"
    Add-PSSnapin sqlservercmdletsnapin100 -ErrorAction SilentlyContinue
}
        
if (! (Get-PSSnapin -Name sqlserverprovidersnapin100 -ErrorAction SilentlyContinue))
{
    "Loading SQL provider commandlets"
    Add-PSSnapin sqlserverprovidersnapin100 -ErrorAction SilentlyContinue
}
#Clean up old output file
del $Outfile -ErrorAction SilentlyContinue


#Queries for comparison
$SQLUsers = "SELECT * FROM [master].[sys].[server_principals]"
$SQLJobs = "SELECT * FROM [msdb].[dbo].[sysjobs]"
$SQLConfig = "SELECT * FROM [master].[sys].[configurations]"
$SQLLinkedServers = "SELECT [name],[is_linked] FROM [master].[sys].[servers] WHERE is_linked = 1"
$SQLCLRAssemblies = "DECLARE @Assemblies TABLE(database_name VARCHAR(50), name VARCHAR(100),is_user_defined bit)
INSERT INTO @Assemblies EXEC sp_MSforeachdb 'USE ? SELECT ''?'',[name],[is_user_defined] FROM [sys].[assemblies] WHERE is_user_defined = 1'
select * from @Assemblies"
$SQLOperators = "SELECT [name] FROM [msdb].[dbo].[sysoperators]"

#Query execution
$Users1 = Invoke-Sqlcmd -Query $SQLUsers -ServerInstance $Server1
$Users2 = Invoke-Sqlcmd -Query $SQLUsers -ServerInstance $Server2
$Jobs1 = Invoke-Sqlcmd -Query $SQLJobs -ServerInstance $Server1
$Jobs2 = Invoke-Sqlcmd -Query $SQLJobs -ServerInstance $Server2
$Config1 = Invoke-Sqlcmd -Query $SQLConfig -ServerInstance $Server1
$Config2 = Invoke-Sqlcmd -Query $SQLConfig -ServerInstance $Server2
$LinkedServers1 = Invoke-Sqlcmd -Query $SQLLinkedServers -ServerInstance $Server1
$LinkedServers2 = Invoke-Sqlcmd -Query $SQLLinkedServers -ServerInstance $Server2
$Assemblies1 = Invoke-Sqlcmd -Query $SQLCLRAssemblies -ServerInstance $Server1
$Assemblies2 = Invoke-Sqlcmd -Query $SQLCLRAssemblies -ServerInstance $Server2
$Operators1 = Invoke-Sqlcmd -Query $SQLOperators -ServerInstance $Server1
$Operators2 = Invoke-Sqlcmd -Query $SQLOperators -ServerInstance $Server2


#Adds header info for outfile
$header1 = "Server 1 (Left) = "+$Server1+"    <-|_|_|->    Server 2 (Right) = "+$Server2
Add-Content -Value $header1 -Path $Outfile
$header2 = "Type,Name,SideIndicator/Result"
Add-Content -Value $header2 -Path $Outfile

#Adds values to output file
##############################
##########   Users  ##########
##############################
$Values = @()
$Array1 = $Users1
$Array2 = $Users2
$Type = 'USER'

#Try-catch code for Name property
Try 
    {
    $ObjectsNotOnBoth = Compare-Object $Array1 $Array2 -Property name
    }
Catch
    {
    If ($Array1 -eq $NULL)
        {
        Foreach ($Object in $Array2)
            {
            $Values += $Type+','+$Object.name+',=>'
            Add-Content -Value $Values -Path $Outfile
            }
        }
    If ($Array2 -eq $NULL)
        {
        Foreach ($Object in $Array1)
            {
            $Values += $Type+','+$Object.name+',<='
            Add-Content -Value $Values -Path $Outfile
            }
        }
    }
If ($ObjectsNotOnBoth -ne $NULL) 
    {
    $ObjectsNotOnBoth| ForEach-Object -Process {$Values += $Type+','+$_.name+','+$_.SideIndicator}
    Add-Content -Value $Values -Path $Outfile
    }
    
##############################
##########   Jobs   ##########
##############################
$Values = @()
$Array1 = $Jobs1
$Array2 = $Jobs2
$Type = 'JOB'

#Try-catch code for Name property
Try 
    {
    $ObjectsNotOnBoth = Compare-Object $Array1 $Array2 -Property name
    }
Catch
    {
    If ($Array1 -eq $NULL)
        {
        Foreach ($Object in $Array2)
            {
            $Values += $Type+','+$Object.name+',=>'
            Add-Content -Value $Values -Path $Outfile
            }
        }
    If ($Array2 -eq $NULL)
        {
        Foreach ($Object in $Array1)
            {
            $Values += $Type+','+$Object.name+',<='
            Add-Content -Value $Values -Path $Outfile
            }
        }
    }
If ($ObjectsNotOnBoth -ne $NULL) 
    {
    $ObjectsNotOnBoth| ForEach-Object -Process {$Values += $Type+','+$_.name+','+$_.SideIndicator}
    Add-Content -Value $Values -Path $Outfile
    }
    
##############################
##########Assemblies##########
##############################
$Values = @()
$Array1 = $Assemblies1
$Array2 = $Assemblies2
$Type = 'ASSEMBLIES'

#Try-catch code for database name and name properties
Try 
    {
    $ObjectsNotOnBoth = Compare-Object $Array1 $Array2 -Property database_name,name
    }
Catch
    {
    If ($Array1 -eq $NULL)
        {
        Foreach ($Object in $Array2)
            {
            $Values += $Type+','+$Object.database_name+'_'+$Object.name+',=>'
            Add-Content -Value $Values -Path $Outfile
            }
        }
    If ($Array2 -eq $NULL)
        {
        Foreach ($Object in $Array1)
            {
            $Values += $Type+','+$Object.database_name+'_'+$Object.name+',<='
            Add-Content -Value $Values -Path $Outfile
            }
        }
    }
If ($ObjectsNotOnBoth -ne $NULL) 
    {
    $ObjectsNotOnBoth| ForEach-Object -Process {$Values += $Type+','+$_.database_name+'_'+$_.name+','+$_.SideIndicator}
    Add-Content -Value $Values -Path $Outfile
    }
    
##############################
########## Operators##########
##############################
$Values = @()
$Array1 = $Operators1
$Array2 = $Operators2
$Type = 'OPERATOR'

#Try-catch code for Name property
Try 
    {
    $ObjectsNotOnBoth = Compare-Object $Array1 $Array2 -Property name
    }
Catch
    {
    If ($Array1 -eq $NULL)
        {
        Foreach ($Object in $Array2)
            {
            $Values += $Type+','+$Object.name+',=>'
            Add-Content -Value $Values -Path $Outfile
            }
        }
    If ($Array2 -eq $NULL)
        {
        Foreach ($Object in $Array1)
            {
            $Values += $Type+','+$Object.name+',<='
            Add-Content -Value $Values -Path $Outfile
            }
        }
    }
If ($ObjectsNotOnBoth -ne $NULL) 
    {
    $ObjectsNotOnBoth| ForEach-Object -Process {$Values += $Type+','+$_.name+','+$_.SideIndicator}
    Add-Content -Value $Values -Path $Outfile
    }
    
##############################
##########  Config  ##########
##############################
$Values = @()
foreach ($ConfigItem1 in $Config1) #This loops through each config item and copares it, dumping into $Values if it does not match.
    {
    $ConfigItem2 = $Config2 | Where-Object {$_.configuration_id -like $ConfigItem1.configuration_id}
    $ConfigMatch = ($ConfigItem1.value_in_use -eq $ConfigItem2.value_in_use)
    if ($ConfigMatch -eq $FALSE)
        {
        $Values += 'CONFIGURATION,'+$ConfigItem1.name+',DOES NOT MATCH'
        }
    }
If ($Values -ne $NULL) #If $Values is not $Null, writes to $Outfile. This avoids blank lines in the middle of the output file.
    {
    Add-Content -Value $Values -Path $Outfile
    }

##################################
##########Linked Servers##########
##################################
$Values = @()
Try 
    {
    $LinkedServersNotOnBoth = Compare-Object $LinkedServers1 $LinkedServers2 -Property name
    }
Catch
    {
    If ($LinkedServers1 -eq $NULL)
        {
        Foreach ($LinkedServer in $LinkedServers2)
            {
            $Values += 'LINKED SERVER,'+$LinkedServer.name+',=>'
            Add-Content -Value $Values -Path $Outfile
            }
        }
    If ($LinkedServers2 -eq $NULL)
        {
        Foreach ($LinkedServer in $LinkedServers1)
            {
            $Values += 'LINKED SERVER,'+$LinkedServer.name+',<='
            Add-Content -Value $Values -Path $Outfile
            }
        }
    }
If ($LinkedServersNotOnBoth -ne $NULL) 
    {
    $LinkedServersNotOnBoth| ForEach-Object -Process {$Values += 'LINKED SERVER,'+$_.name+','+$_.SideIndicator}
    Add-Content -Value $Values -Path $Outfile
    }