[CmdletBinding()] 
param()  

try { 
    Trace-VstsEnteringInvocation $MyInvocation

    # Get user inputs.
    [string]$publishPath = Get-VstsInput -Name 'publishPath' -Require
    [string]$rdlFolderPath = Get-VstsInput -Name 'rdlFolderPath' -Require
    [string]$reportServer = Get-VstsInput -Name 'reportServer' -Require

    [bool]$useSSRSCredential = Get-VstsInput -Name 'useSSRSCredential' -Require -AsBool
    [string]$ssrsUserName = Get-VstsInput -Name 'ssrsUserName' 
    [string]$ssrsPassword = Get-VstsInput -Name 'ssrsPassword' 

    function CreateReportFolder {
        param (
            [string]$folderName,
            [string]$parentFolderName,
            $ssrsConnection
        )

        try {
            Write-Host "Creating Folder : $folderName..."
            $ssrsConnection.CreateFolder($folderName, $parentFolderName, $null)
            Write-Host "Created Folder : $folderName!!!"   
        }
        catch [System.Web.Services.Protocols.SoapException]{
            if ($_.Exception.Detail.InnerText -match "[^rsItemAlreadyExists400]") {
                Write-Warning "Folder $parentFolderName/$folderName already exists"
            }
            else {
                Write-Error "$_"
            }
        }
    }

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

    if ($publishPath.Contains("\")) {
        throw 'Publish Path should contain "/" not "\" '
    }

    $splitPublishPath = $publishPath.Split("/")
    $parentFolder = "/"
    foreach ($item in $splitPublishPath) {
        if ($item) {
            CreateReportFolder -folderName $item -parentFolderName $parentFolder -ssrsConnection $ssrsConn
            $parentFolder = "$parentFolder/$item".Replace("//", "/")
        }
    }

    $rdlFiles = Get-ChildItem -Path $rdlFolderPath -Filter *.rdl | ForEach-Object { $_.FullName }

    if ($rdlFiles.Length -ne 0) {
        foreach ($file in $rdlFiles) {
            $reportName = [IO.Path]::GetFileNameWithoutExtension($file)
            
            Write-Host ""
            Write-Host "Uploading file : $reportName"
            $bytes = Get-Content $file -ReadCount 0 -Encoding Byte
            $warnings = @{}
            $response = $ssrsConn.CreateCatalogItem("Report", $reportName, "/$publishPath", $false, $bytes, $null, [ref]$warnings)
            if ($warnings.Length -eq 0) {
                Write-Host "Upload Complete"
            }
            else {
                Write-Host $warnings
            }
        }    
    }
    else {
        Write-Warning "No rdl file found in $rdlFolderPath"
    }
}
finally { 
    Trace-VstsLeavingInvocation $MyInvocation 
}