# Backup Tool by Thomas Gassmann and Simon Baumeler

Clear-Host
# Set initial variables to be used in the backup script.
$scriptPath = Split-Path -Parent $MyInvocation.MyCommand.Definition
# Set file path to a combined value of the $scriptPath and "config.xml". This variable will contain the file name for the configuration xml file.
$filePath = Join-Path $scriptPath "config.xml"
# Create the web client to download necessary files.
$webClient = new-object Net.WebClient

# Check whether the 7zip files are inside the script folder.

# The path of the 7zip executable file.
$exePath = Join-Path $scriptPath "7z.exe"
# The path of the 7zip application extension file.
$dllPath = Join-Path $scriptPath "7z.dll"
# Check whether the executable file for 7zip exists.
if (-not (Test-Path $exePath)) {
    # The file 7z.exe was not found. Download the file.
    $webClient.DownloadFile("http://thomasgassmann.bplaced.net/7z.exe", $exePath)
}
# Check whether the application extension for 7zip exists
if (-not (Test-Path $dllPath)) {
    # The file 7z.dll was not found. Download the file.
    $webClient.DownloadFile("http://thomasgassmann.bplaced.net/7z.dll", $dllPath)
}
# Get the content of the configuration file and parse it to xml.
# Read the xml configuration from the file path and parse it into a valid xml value.
[xml]$xmlConfigurationContent = Get-Content -Path $filePath
Write-Host "Reading configuration file from $scriptPath..."
Write-Host "===================================================="
Write-Host ""
# If the configuration file is not empty continue.
if ($xmlConfigurationContent.HasChildNodes) {
    # Get the default backup path with its XPath.
    $defaultBackupPath = (Select-Xml "//BackupConfiguration//DefaultBackupPath" $xmlConfigurationContent).Node.InnerText
    # Get the default password with its XPath.
    $defaultPassword = (Select-Xml "//BackupConfiguration//DefaultPassword" $xmlConfigurationContent).Node.InnerText
    # Loop through BackupItemList
    $xmlConfigurationContent.SelectNodes("//BackupConfiguration//BackupItemList//BackupItem") | ForEach-Object {
        # Read current backup item configuration
        
        # Creates the name of the current backup with the given Backup name and the current date formatted in the following way: "yyyy-MM-dd-hh-mm-ss"
        $currentBackupName = $_.GetElementsByTagName("Name").innerXml + "-" + (Get-Date -Format "yyyy-MM-dd-hh-mm-ss")
        # Gets the value that determines whether the zip file should be protected with a password.
        $isPasswordProtected = $_.GetElementsByTagName("IsZipPasswordProtected").innerXml
        # Gets the Destination Backup Path from the current BackupItem.
        $destBackupPath = $_.GetElementsByTagName("DestBackupPath").innerXml
        # Gets the Compression level of the zip file from the current BackupItem.
        $compressionLevel = $_.GetElementsByTagName("CompressionLevel").innerXml
        # If the XML node in the BackupItem with the Name "UseDefaultPassword" is set to true, use the default password, else not.
        if ($_.GetElementsByTagName("UseDefaultPassword").innerXml -eq $true) {
            # Set the password to the default password.
            $password = $defaultPassword
        } else {
            # Set the password to the password found in the current BackupItem configuration.
            $password = $_.GetElementsByTagName("Password").innerXml
        }
        # Set the source path for the backup to the value found in the BackupItem configuration.
        $sourceBackupPath = $_.GetElementsByTagName("SourceBackupPath").innerXml
        # If the XML node in the BackupItem with the name "UseDefaultPath" is set to true, use the default backup path, else not.
        if ($_.GetElementsByTagName("UseDefaultPath").innerXml -eq $true) {
            $destBackupPath = $defaultBackupPath
        }
        # Gets a value from the BackupItem configuration determinating whether the backup should be zipped
        $shouldBeZipped = $_.GetElementsByTagName("Zip").innerXml
        # Create destination folder, if it doesn't exist
        if (-Not(Test-Path $destBackupPath)) {
            # Create Directory.
            New-Item -Path $destBackupPath -Type Directory
        }

        # Do backup

        # Set destination path to the current destination path combined with the current backup name.
        $destBackupPath = Join-Path $destBackupPath $currentBackupName
        # If the backup should be zipped, zip it, else copy the files.
        if ($shouldBeZipped -eq $true) {
            # Start zipped backup

            # Set the compression type to "zip".
            $compressionType = "zip"   
            # Set the path of the zip file equal to the destination backup path combined with the current backup name with the .zip file extension. 
            $zipPath = Join-Path $destBackupPath ($currentBackupName + ".zip")
            # Set the arguments to be used in the 7zip operation.
            # - The compression type ("zip")
            # - The path of the output zip file.
            # - The source backup path to zip.
            # - The compression level
            $arguments = "a -t$compressionType ""$zipPath"" ""$sourceBackupPath"" $compressionLevel"
            # If the zip should be protected with a password, add the password parameter to the arguments.
            if ($isPasswordProtected) {
                # Add the password parameter with the given password form the configuration to the arguments.
                $arguments += " -p$password"
            }
            # Start 7zip zipping process with the given arguments. Hide the window and wait until the process finished.
            $p = Start-Process $exePath -ArgumentList $arguments -Wait -PassThru -WindowStyle "Hidden"
            # If the 7zip process has not finished and has an Exit Code not equal to 0, print an error.
            if (-Not(($p.HasExited -eq $true) -and ($p.ExitCode -eq 0))) {
                # Print error message saying that there was a problem. Print the error code for further investigation in the internet.
                Write-Error ("There was a problem creating the zip file '$zipPath'. ExitCode: " + $p.ExitCode)
            }
            # Set the out variable to the output text to be used. This output text contains all the information used to create the zip file (except password itself).
            $out = "Created backup of $sourceBackupPath at $zipPath with compression type $compressionType and compression level $compressionLevel"
            # If the zip is password protected, add the information to the output.
            if ($isPasswordProtected) {
                # Add the information that the zip was protected with a password.
                $out += " and with password protection"
            }
            # Write out the output text.
            Write-Host "$out."
        } else {
            # Start non-zipped backup
            # XCopy the source backup path to the given destination backup path.
            # -E : all sub-directories, even if they are empty
            # -C : ignore all errors
            # -I : show a list of the copied files
            # -F : show the source- and destination- file names while copying
            # -R : copy read-only files
            # -Y : suppress confirmation of replacing files
            XCopy $sourceBackupPath $destBackupPath /E /C /I /F /R /Y 
            # Print out that the source backup path was successfully backed up at the destination backup path.
            Write-Host "Created backup of $sourceBackupPath at $destBackupPath without creating a zip file."
        }
    }
} else {
    # XML configuration file is empty
    Write-Error "Your XML Configuration file at the path $filepath does not seem to be valid."
}