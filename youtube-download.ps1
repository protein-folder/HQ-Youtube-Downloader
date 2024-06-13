#im not sure why you would use this for downloading videos less than 1080p
#this was made to "fix" a quirk with yt-dlp where it seperates the audio and video stream if the video is 1080p or greater
#this utilizes yt-dlp and ffmpeg 
#dependencies: https://github.com/FFmpeg/FFmpeg https://github.com/yt-dlp/yt-dlp

# Function to check for internet connection
function Test-InternetConnection {
    try {
        $null = Test-Connection -ComputerName "www.google.com" -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

# Check for internet connection
if (-not (Test-InternetConnection)) {
    Write-Host "Error: No active internet connection. Please check your internet connection and run the script again."
    
    # Add a delay to keep the window open for 10 seconds (adjust as needed)
    Start-Sleep -Seconds 10

    exit
}

# Logging functions
# this used to be called "Log-Message" but you literally cant type anything in powershell without it throwing a shitfit so i named it "etch"
function Etch-Message {
    param (
        [string]$message
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "$timestamp - $message"
    Write-Output $logMessage
}

function Etch-Error {
    param (
        [string]$LoggingError
    )

    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logError = "$timestamp - ERROR: $Loggingerror"
    Write-Error $logError
}

# Specify the log folder path:
$logFolderName = "youtube-download-logs"

# Ensure $outputDirectory is defined before using it
if ($null -eq $outputDirectory -or $outputDirectory -eq "") {
    $outputDirectory = $PSScriptRoot
}

$logFolderPath = Join-Path $outputDirectory $logFolderName
$logFilePath = Join-Path $logFolderPath "script_log_$(Get-Date -Format 'yyyyMMdd_HHmmss').txt"

# Create the log folder if it doesn't exist
if (-not (Test-Path $logFolderPath -PathType Container)) {
    New-Item -ItemType Directory -Path $logFolderPath | Out-Null
}

# Start transcript logging
Start-Transcript -Path $logFilePath -Append

# Function to validate YouTube video URL
# This used to be called "Validate-YouTubeURL" but powershell gets pissy when you use any synonym of confirm
function Check-YouTubeURL {
    param (
        [string]$url
    )

    if ($url -match '^https://www\.youtube\.com/watch\?v=[a-zA-Z0-9_-]+$') {
        return $true
    } else {
        Etch-Error "Invalid YouTube video URL entered: $url"
        Write-Host "Error: Invalid YouTube video URL. Please enter a valid URL."
        return $false
    }
}

# Function to validate and sanitize the output directory
function Check-Directory {
    param (
        [string]$directory
    )

    if (Test-Path $directory -PathType Container) {
        return $true
    } else {
        Etch-Error "Invalid directory entered: $directory"
        Write-Host "Error: Invalid directory. Please enter a valid directory path."
        return $false
    }
}

function Get-VideoFormatCode {
    param (
        [string]$quality
    )

    switch ($quality) {
        "2160p" { return 401 }
        "1440p" { return 400 }
        "1080p" { return 137 }
        "720p"  { return 136 }
        "480p"  { return 135 }
        "360p"  { return 134 }
        "240p"  { return 133 }
        "144p"  { return 160 }
        default { return $null }
    }
}

$video = ""

# Validate and sanitize the YouTube video URL
do {
    $video = Read-Host "Please enter the YouTube video URL"
} until (Check-YouTubeURL -url $video)

# Ask for the output directory
$outputDirectory = $PSScriptRoot

# Inform the user about the default directory
Etch-Message "Default output directory: $outputDirectory"
Write-Host "Default output directory: $outputDirectory"

# Ask for confirmation to use the default directory
$validResponse = $false
do {
    $useDefaultDirectory = Read-Host "Do you want to use the default output directory ($outputDirectory)? (Y/N)"
    
    if ($useDefaultDirectory -eq 'Y' -or $useDefaultDirectory -eq 'y') {
        $validResponse = $true
    } elseif ($useDefaultDirectory -eq 'N' -or $useDefaultDirectory -eq 'n') {
        $validResponse = $true
        do {
            $outputDirectory = Read-Host "Please enter the directory where you want to save the video"
        } until (Check-Directory -directory $outputDirectory)
    } else {
        Etch-Error "Invalid response entered: $useDefaultDirectory"
        Write-Host "Error: Invalid response. Please enter 'Y' or 'N'."
    }
} until ($validResponse)

# Prompt the user for video quality
do {
    $videoQuality = Read-Host "Please enter the desired video quality (e.g., 2160p, 1440p, 1080p, 720p, etc.)"
    $formatCode = Get-VideoFormatCode -quality $videoQuality

    if ($null -eq $formatCode) {
        Etch-Error "Invalid video quality entered: $videoQuality"
        Write-Host "Error: Invalid video quality. Please enter a valid quality (e.g., 1440p, 1080p, 720p, etc.)"
    }
} until ($null -ne $formatCode)

# Navigate to the output directory
Set-Location $outputDirectory

# Download video using yt-dlp
$videoCommand = "yt-dlp.exe -f $formatCode --output ""video_temp.mp4"" $video"

# Execute the yt-dlp.exe command for video download
try {
    Invoke-Expression $videoCommand
} catch {
    Etch-Error "Failed to download video: $_"
    Write-Host "Error: $_"
    exit
}

# Check if the video file exists
if (-not (Test-Path "video_temp.mp4")) {
    Etch-Error "Video file not found. This is most likely because the selected quality is not available. Check the YouTube video and ensure the selected quality is available"

    # Show a warning message to the user before exiting
    Write-Host "Video file not found. This is most likely because the selected quality is not available. Check the YouTube video and ensure the selected quality is available"
    
    # Add a delay to keep the window open for 10 seconds (adjust as needed)
    Start-Sleep -Seconds 10

    exit
}

# Download audio using yt-dlp
$audioCommand = "yt-dlp.exe -f 140 --output ""audio_temp.m4a"" $video"

# Execute the yt-dlp.exe command for audio download
try {
    Invoke-Expression $audioCommand
} catch {
    Etch-Error "Failed to download audio: $_"
    Write-Host "Error: $_"

    # Show a warning message to the user before exiting
    Write-Host "Warning: An unknown error occurred during audio download. The script will now close."
    Start-Sleep -Seconds 10  # Give the user some time to read the warning
    exit
}

# Get the title of the YouTube video
$title = (yt-dlp.exe --get-title $video).Trim()

# Append the quality to the title
$titleWithQuality = "$title $videoQuality"

# Rename the downloaded files with consideration for existing files
$videoDestination = Join-Path $outputDirectory "video.mp4"
$audioDestination = Join-Path $outputDirectory "audio.m4a"

if (Test-Path $videoDestination -or Test-Path $audioDestination) {
    $overwriteConfirmation = Read-Host "Warning: Files with the same names already exist in the output directory. Do you want to overwrite them? (Y/N)"
    
    if ($overwriteConfirmation -ne 'Y' -and $overwriteConfirmation -ne 'y') {
        Etch-Message "Operation aborted. Exiting script."
        Write-Host "Operation aborted. Exiting script."
        exit
    }
}

#Renames the temp files into readable files (im not sure why this is here but im afraid to remove it)
Rename-Item -Path "video_temp.mp4" -NewName "video.mp4" -Force
Rename-Item -Path "audio_temp.m4a" -NewName "audio.m4a" -Force

# Merge video and audio into a single file using ffmpeg
ffmpeg -i "video.mp4" -i "audio.m4a" -c:v copy -c:a copy -strict experimental "$titleWithQuality.mp4"

# Inform the user where the output file is located
Etch-Message "The merged file is located at: $outputDirectory\$titleWithQuality.mp4"
Write-Host "The merged file is located at: $outputDirectory\$titleWithQuality.mp4"

# Open the merged file using the default associated application
Start-Process "$outputDirectory\$titleWithQuality.mp4"

# Cleanup: Delete the intermediate audio and video files
if (Test-Path "audio.m4a") {
    Remove-Item "audio.m4a" -Force
}

if (Test-Path "video.mp4") {
    Remove-Item "video.mp4" -Force
}

# Stop transcript logging
Stop-Transcript