[CmdletBinding()] 
param()  

try { 
    Trace-VstsEnteringInvocation $MyInvocation

    # Get user inputs.
    [string]$folderPath = Get-VstsInput -Name 'folderPath' -Require
    [string]$reportServer = Get-VstsInput -Name 'reportServer' -Require

    [bool]$useSSRSCredential = Get-VstsInput -Name 'useSSRSCredential' -Require -AsBool
    [string]$ssrsUserName = Get-VstsInput -Name 'ssrsUserName' 
    [string]$ssrsPassword = Get-VstsInput -Name 'ssrsPassword' 

    $ErrorActionPreference = "Stop"

    $ssrsServiceUri = "http://$reportServer/ReportServer/ReportService2010.asmx?wsdl"
    
    Write-Host "Connecting to $ssrsServiceUri ..."

    if ($useSSRSCredential) {
        $secPassword = ConvertTo-SecureString $ssrsPassword -AsPlainText -Force
        $cred = New-Object System.Management.Automation.PSCredential ($ssrsUserName, $secPassword)
        $ssrsConn = New-WebServiceProxy -Uri $ssrsServiceUri -Credential $cred
    }
    else {
        $ssrsConn = New-WebServiceProxy -Uri $ssrsServiceUri -UseDefaultCredential
    }

    Write-Host "Connected to $ssrsServiceUri!!!"

    try{
        Write-Host "Deleting $folderPath..."
        $ssrsConn.DeleteItem("/" + $folderPath)
        Write-Host "Deleted $folderPath..."
    }
    catch [System.Web.Services.Protocols.SoapException] {
        Write-Error "Error deleting $folderPath"
    }
}
finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}