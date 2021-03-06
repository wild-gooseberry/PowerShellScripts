
function Get-ACEConnection ($ConnectionString){
    $conn = new-object System.Data.OleDb.OleDbConnection($ConnectionString) 
    $conn.open() 
    $conn 
 
} 

function Get-ACETable ($Connection){
    $Connection.GetOleDbSchemaTable([System.Data.OleDb.OleDbSchemaGuid]::tables,$null) 
} 

function Get-ACEConnectionString ($FilePath){
 
    switch -regex ($FilePath) 
    { 
        '\.xlsm$|\.xls$|\.xlsx$|\.xlsb$' {"Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$filepath`";Extended Properties=`"Excel 12.0 Xml;HDR=YES;IMEX=1`";"} 
         '\.csv$' {"Provider=Microsoft.Jet.OLEDB.4.0;Data Source=`"$(Split-Path $filepath)`";Extended Properties=`"TEXT;HDR=YES;FMT=DELIMITED`";"} 
        '\.mdb$|\.accdb$'        {"Provider=Microsoft.ACE.OLEDB.12.0;Data Source=`"$filepath`";Persist Security Info=False;"} 
    } 
 
} #Get-ACEConnectionString 
 
####################### 
<# 
.SYNOPSIS 
Queries Excel and Access files. 
.DESCRIPTION 
Get-ACEData gets data from Microsoft Office Access (*.mdb and *.accdb) files and Microsoft Office Excel (*.xls, *.xlsx, and *.xlsb) files 
.INPUTS 
None 
    You cannot pipe objects to Get-ACEData 
.OUTPUTS 
   System.Data.DataSet 
.EXAMPLE 
Get-ACEData -FilePath ./budget.xlsx -WorkSheet 'FY2010$','FY2011$' 
This example gets data for the worksheets FY2010 and FY2011 from the Excel file 
.EXAMPLE 
Get-ACEData - -FilePath ./budget.xlsx -WorksheetListOnly 
This example list the Worksheets for the Excel file 
.EXAMPLE 
Get-ACEData -FilePath ./projects.xls -Query 'Select * FROM [Sheet1$]' 
This example gets data using a query from the Excel file 
.NOTES 
Imporant!!!  
Install ACE 12/26/2010 or higher version from LINK below 
If using an x64 host install x64 version and use x64 PowerShell 
Version History 
v1.0   - Chad Miller - 4/21/2011 - Initial release 
.LINK 
http://www.microsoft.com/downloads/en/details.aspx?FamilyID=c06b8369-60dd-4b64-a44b-84b371ede16d&displaylang=en 
#> 
function Get-ACEData 
{ 
     
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)]  
    [ValidateScript({$_ -match  '\.xlsm$|\.xls$|\.xlsx$|\.xlsb$|\.mdb$|\.accdb$|\.csv$'})] [string]$FilePath, 
    [Parameter(Position=1, Mandatory=$false)]  
    [alias("Worksheet")] [string[]]$Table, 
    [Parameter(Position=2, Mandatory=$false)] [string]$Query, 
    [Parameter(Mandatory=$false)] 
    [alias("WorksheetListOnly")] [switch]$TableListOnly 
    ) 
 
    $FilePath = $(resolve-path $FilePath).path 
    $conn = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $FilePath) 
 
    #If TableListOnly switch specified list tables/worksheets then exit 
    if ($TableListOnly) 
    {  
        Get-ACETable -Connection $conn 
        $conn.Close() 
 
    } 
    #Else tablelistonly switch not specified 
    else 
    { 
        $ds = New-Object system.Data.DataSet 
        $cmd = new-object System.Data.OleDb.OleDbCommand 
        $cmd.Connection = $conn 
        $da = new-object System.Data.OleDb.OleDbDataAdapter 
 
        if ($Query) 
        { 
            $qry = $Query 
            $cmd.CommandText = $qry 
            $da.SelectCommand = $cmd 
            $dt = new-object System.Data.dataTable 
            $null = $da.fill($dt) 
            $ds.Tables.Add($dt) 
        } 
        #Return one or more specified tables/worksheets 
        elseif ($Table) 
        { 
            $Table |  
            foreach{ $qry = "select * from [{0}]" -f $_; 
            $cmd.CommandText = $qry; 
            $da.SelectCommand = $cmd; 
            $dt = new-object System.Data.dataTable("$_"); 
            $null = $da.fill($dt); 
            $ds.Tables.Add($dt)} 
        } 
        #Return all tables/worksheets 
        else 
        { 
            Get-ACETable $conn |  
            where {$_.TABLE_TYPE -eq  'TABLE' } | 
            foreach{ $qry = "select * from [{0}]" -f $_.TABLE_NAME; 
            $cmd.CommandText = $qry; 
            $da.SelectCommand = $cmd; 
            $dt = new-object System.Data.dataTable("$($_.TABLE_NAME)"); 
            $null = $da.fill($dt); 
            $ds.Tables.Add($dt)} 
        } 
 
        $conn.Close() 
        Write-Output ($ds) 
    } 
 
} #Get-ACEData 


function Set-ACEData 
{ 
     
    [CmdletBinding()] 
    param( 
    [Parameter(Position=0, Mandatory=$true)]  
    [ValidateScript({$_ -match  '\.xls$|\.xlsx$|\.xlsb$|\.mdb$|\.accdb$|\.csv$'})] [string]$FilePath, 
    [Parameter(Position=1, Mandatory=$false)] [string]$query,
	 [switch]$append
    ) 
 
   $FilePath = $(resolve-path $FilePath).path 
	#use jet.oledb to carry out INSERT INTO command since the new driver doesn't work for that
   if ($append){
		$cnnStr ="Provider=Microsoft.Jet.OLEDB.4.0;Data Source=`"$filepath`";Extended Properties=`"Excel 8.0;HDR=YES`";"
		$conn = Get-ACEConnection -ConnectionString $cnnStr 
	}
   else{ 
   $conn = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $FilePath).replace(";IMEX=1","") }
   $cmd = new-object System.Data.OleDb.OleDbCommand 
   $cmd.Connection = $conn 
   $cmd.CommandText = $query
   $null=$cmd.ExecuteNonQuery()
	$conn.Close() 
	
} #Set-AceData


#modified function from richardsiddaway's access functions

#date format #01-Sep-79#" to work across cultures

function Invoke-ACEAccessStoredProcedure {
[CmdletBinding()]
param (
    $path,
    [string]$name,
	 $parameter
)
    $sql = "EXECUTE $name "
	 $connection = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $path) 
    $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection)
    if ($parameter){$cmd.Parameters.AddWithValue("",$parameter)}
    $reader = $cmd.ExecuteReader()
   
    $dt = New-Object System.Data.DataTable
    $dt.Load($reader)
	 $connection.Close()  
    $dt
} 

#example:New-AccessStoredProcedure -path "test.accdb" -name "proc1" -proc "select * from test1" 
function New-ACEAccessStoredProcedure {
[CmdletBinding()]
param (
    $path,
    [string]$name,
    [string]$proc
)
    $sql = "CREATE PROCEDURE $name AS $proc"
    $connection = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $path) 
    $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection)
    $cmd.ExecuteNonQuery()   
	 $connection.Close()  
} 

function ImportFrom-ExcelToAccess {
[CmdletBinding()]
param (
    $ExcelPath,
	 $AccessPath,
	 $sheetName,
	 $table,
	 [switch]$overwrite
)
	if ($sheetName -is [int]){
		$sheetName= @(Get-ACEData $ExcelPath -TableListOnly | select -ExpandProperty Table_Name)[$sheetName-1]
	}
	if ($overwrite){
		$connection = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $AccessPath)
	   $sql = "DELETE FROM [MS Access;Database=" + $AccessPath + "].[$table]";
	   $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection)
	   $cmd.ExecuteNonQuery()   
		$connection.Close()  
		
		$connection = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $ExcelPath)
	   $sql = "INSERT INTO [MS Access;Database=" + $AccessPath + "].[$table] SELECT * FROM [$sheetname]";
	   $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection)
	   $cmd.ExecuteNonQuery()   
		$connection.Close()  
	}
	else{
		$connection = Get-ACEConnection -ConnectionString $(Get-ACEConnectionString $ExcelPath)
	   $sql = "SELECT * INTO [MS Access;Database=" + $AccessPath + "].[$table] FROM [$sheetname]";
	   $cmd = New-Object System.Data.OleDb.OleDbCommand($sql, $connection)
	   $cmd.ExecuteNonQuery()   
		$connection.Close()  
	}
} 

function New-ACEAccessDatabase {
param (
    [string]$path,
    [switch]$mdb
)    
    $cat = New-Object -ComObject 'ADOX.Catalog'
    
    if ($mdb) {$cat.Create("Provider=Microsoft.Jet.OLEDB.4.0; Data Source=$path")}
    else {$cat.Create("Provider=Microsoft.ACE.OLEDB.12.0; Data Source=$path")}

    $cat.ActiveConnection.Close()
}



Export-ModuleMember -function Get-ACEData,Set-ACEData,Invoke-ACEAccessStoredProcedure, New-ACEAccessStoredProcedure,ImportFrom-ExcelToAccess,New-ACEAccessDatabase,Get-ACEConnectionString,Get-ACEConnection