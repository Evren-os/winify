$debug = $false

$timeFilePath = "$env:USERPROFILE\Documents\PowerShell\LastExecutionTime.txt"
$updateInterval = 7

if ($debug) {
    Write-Host "#######################################" -ForegroundColor Red
    Write-Host "#           Debug mode enabled        #" -ForegroundColor Red
    Write-Host "#          ONLY FOR DEVELOPMENT       #" -ForegroundColor Red
    Write-Host "#       IF YOU ARE NOT DEVELOPING       #" -ForegroundColor Red
    Write-Host "#       JUST RUN `Update-Profile`       #" -ForegroundColor Red
    Write-Host "#        to discard all changes        #" -ForegroundColor Red
    Write-Host "#   and update to the latest profile   #" -ForegroundColor Red
    Write-Host "#               version                #" -ForegroundColor Red
    Write-Host "#######################################" -ForegroundColor Red
}

function Get-GitHubConnectivity {
    try {
        return Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1
    } catch {
        return $false
    }
}
$global:canConnectToGitHub = $false
Start-Job -ScriptBlock { Test-Connection github.com -Count 1 -Quiet -TimeoutSeconds 1 } |
    ForEach-Object { $global:canConnectToGitHub = $_ } | Out-Null

function Import-TerminalIcons {
    if (-not (Get-Module -Name Terminal-Icons -ErrorAction SilentlyContinue)) {
        try {
            Import-Module Terminal-Icons -ErrorAction Stop
        } catch {
            Write-Warning "Failed to import Terminal-Icons module."
        }
    }
}

$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path $ChocolateyProfile) {
    Import-Module "$ChocolateyProfile" -ErrorAction SilentlyContinue
}

function Clear-Cache {
    Write-Host "Clearing cache..." -ForegroundColor Cyan
    Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue
    Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Clearing User Temp..." -ForegroundColor Yellow
    Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
    Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue
    Write-Host "Cache clearing completed." -ForegroundColor Green
}

$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    Remove-Item function:prompt -Force
    try {
        $starshipInit = & starship init powershell
        Invoke-Expression $starshipInit
    } catch {
        Write-Warning "Failed to initialize starship prompt."
    }
    prompt
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell $($PSVersionTable.PSVersion)$adminSuffix"

function Test-CommandExists {
    param($command)
    return $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
}
$EDITOR = if (Test-CommandExists nvim) { 'nvim' }
          elseif (Test-CommandExists pvim) { 'pvim' }
          elseif (Test-CommandExists vim) { 'vim' }
          elseif (Test-CommandExists vi) { 'vi' }
          elseif (Test-CommandExists code) { 'code' }
          elseif (Test-CommandExists notepad++) { 'notepad++' }
          elseif (Test-CommandExists sublime_text) { 'sublime_text' }
          else { 'notepad' }
Set-Alias -Name vim -Value $EDITOR

function Edit-Profile { vim $PROFILE.CurrentUserAllHosts }
Set-Alias -Name ep -Value Edit-Profile

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -Recurse -Filter "*${name}*" -ErrorAction SilentlyContinue |
        ForEach-Object { "$($_.FullName)" }
}

Set-Alias -Name code -Value codium
Set-Alias -Name c -Value clear

function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip -UseBasicParsing).Content }
function winutil { irm https://christitus.com/win | iex }
function winutildev { irm https://christitus.com/windev | iex }
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "pwsh.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}
Set-Alias -Name su -Value admin

function uptime {
    try {
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)
        } else {
            $lastBootStr = net statistics workstation |
                Select-String "since" |
                ForEach-Object { $_.ToString().Replace('Statistics since ', '') }
            if    ($lastBootStr -match '^\d{2}/\d{2}/\d{4}') { $dateFormat = 'dd/MM/yyyy' }
            elseif($lastBootStr -match '^\d{2}-\d{2}-\d{4}') { $dateFormat = 'dd-MM-yyyy' }
            elseif($lastBootStr -match '^\d{4}/\d{2}/\d{2}') { $dateFormat = 'yyyy/MM/dd' }
            elseif($lastBootStr -match '^\d{4}-\d{2}-\d{2}') { $dateFormat = 'yyyy-MM-dd' }
            elseif($lastBootStr -match '^\d{2}\.\d{2}\.\d{4}') { $dateFormat = 'dd.MM.yyyy' }

            if ($lastBootStr -match '\bAM\b' -or $lastBootStr -match '\bPM\b') {
                $timeFormat = 'h:mm:ss tt'
            } else {
                $timeFormat = 'HH:mm:ss'
            }
            $bootTime = [System.DateTime]::ParseExact($lastBootStr, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }
        Write-Host ("System started on: {0}" -f $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss")) -ForegroundColor DarkGray
        $uptime = (Get-Date) - $bootTime
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $uptime.Days, $uptime.Hours, $uptime.Minutes, $uptime.Seconds) -ForegroundColor Blue
    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

function reload-profile { . $profile }
function unzip ($file) {
    Write-Output("Extracting $file to $pwd")
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | Select-Object -First 1 |
                ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) { Write-Error "No file path specified."; return }
    $FilePath = $args[0]
    if (Test-Path $FilePath) { $Content = Get-Content $FilePath -Raw }
    else { Write-Error "File path does not exist."; return }
    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Set-Clipboard $url
        Write-Output $url
    } catch { Write-Error "Failed to upload the document. Error: $_" }
}
function grep($regex, $dir) {
    if ($dir) { Get-ChildItem $dir | Select-String $regex }
    else { $input | Select-String $regex }
}
function df { Get-Volume }
function sed($file, $find, $replace) {
    (Get-Content $file).replace($find, $replace) | Set-Content $file
}
function which($name) { Get-Command $name | Select-Object -ExpandProperty Definition }
function export($name, $value) { Set-Item -Force -Path "env:$name" -Value $value }
function pkill($name) { Get-Process $name -ErrorAction SilentlyContinue | Stop-Process }
function pgrep($name) { Get-Process $name }
function head { param($Path, $n = 10); Get-Content $Path -Head $n }
function tail { param($Path, $n = 10, [switch]$f); Get-Content $Path -Tail $n -Wait:$f }
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }
function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path
    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath
        $parentPath = if ($item.PSIsContainer) { $item.Parent.FullName } else { $item.DirectoryName }
        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)
        if ($item) { $shellItem.InvokeVerb('delete'); Write-Host "Item '$fullPath' has been moved to the Recycle Bin." }
        else { Write-Host "Error: Could not find the item '$fullPath' to trash." }
    } else { Write-Host "Error: Item '$fullPath' does not exist." }
}

function docs {
    $docs = if ([Environment]::GetFolderPath("MyDocuments")) { [Environment]::GetFolderPath("MyDocuments") } else { "$HOME\Documents" }
    Set-Location -Path $docs
}
function dtop {
    $dtop = if ([Environment]::GetFolderPath("Desktop")) { [Environment]::GetFolderPath("Desktop") } else { "$HOME\Documents" }
    Set-Location -Path $dtop
}
function k9 { Stop-Process -Name $args[0] }
function la { Import-TerminalIcons; Get-ChildItem -Path . -Force | Format-Table -AutoSize }
function ll { Import-TerminalIcons; Get-ChildItem -Path . -Force -Hidden | Format-Table -AutoSize }
function gs { git status }
function ga { git add . }
function gc { param($m) git commit -m "$m" }
function gp { git push }
function g { __zoxide_z github }
function gcl { git clone "$args" }
function gcom { git add .; git commit -m "$args" }
function lazyg { git add .; git commit -m "$args"; git push }
function sysinfo { Get-ComputerInfo }
function flushdns { Clear-DnsClientCache; Write-Host "DNS has been flushed" }
function cpy { Set-Clipboard $args[0] }
function pst { Get-Clipboard }

$PSReadLineOptions = @{
    EditMode = 'Windows'
    HistoryNoDuplicates = $true
    HistorySearchCursorMovesToEnd = $true
    Colors = @{
        Command   = '#87CEEB'
        Parameter = '#98FB98'
        Operator  = '#FFB6C1'
        Variable  = '#DDA0DD'
        String    = '#FFDAB9'
        Number    = '#B0E0E6'
        Type      = '#F0E68C'
        Comment   = '#D3D3D3'
        Keyword   = '#8367c7'
        Error     = '#FF6347'
    }
    PredictionSource = 'History'
    PredictionViewStyle = 'ListView'
    BellStyle = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}
Set-PSReadLineOption -PredictionSource HistoryAndPlugin
Set-PSReadLineOption -MaximumHistoryCount 10000

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git' = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout')
        'npm' = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }
    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] |
            Where-Object { $_ -like "$wordToComplete*" } |
            ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
        ForEach-Object { [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_) }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

function Initialize-Zoxide {
    if (Get-Command zoxide -ErrorAction SilentlyContinue) {
        Invoke-Expression (& { (zoxide init --cmd cd powershell | Out-String) })
    } else {
        Write-Host "zoxide command not found. Scheduling installation in background..." -ForegroundColor Yellow
        Start-Job -ScriptBlock {
            try {
                winget install -e --id ajeetdsouza.zoxide
            } catch {
                Write-Error "Failed to install zoxide. Error: $_"
            }
        } | Out-Null
    }
}
Start-Job -ScriptBlock { Initialize-Zoxide } | Out-Null

if (Test-Path "$PSScriptRoot\CTTcustom.ps1") {
    . "$PSScriptRoot\CTTcustom.ps1"
}
