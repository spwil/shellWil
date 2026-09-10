function psSubMenu25 {
    # ==============================================================================
    #   FUNCIONES AUXILIARES DE CONEXION Y ANALISIS REMOTO (OPTIMIZACION Y LIMPIEZA)
    # ==============================================================================

    function Get-StandardIPPrompt {
        param(
            [string]$Mensaje = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
        )
        $inputRaw = Read-Host $Mensaje
        if ([string]::IsNullOrWhiteSpace($inputRaw)) {
            return ""
        }
        $inputRaw = $inputRaw.Trim()

        # Modalidad 1: IP Completa (formato X.X.X.X)
        if ($inputRaw -match '^(\d{1,3}\.){3}\d{1,3}$') {
            return $inputRaw
        }
        # Modalidad 2: 2 ultimos octetos (ej: 176.50 o 13.15) -> Asume prefijo 192.168.
        elseif ($inputRaw -match '^\d{1,3}\.\d{1,3}$') {
            return "192.168.$inputRaw"
        }
        # Tolerancia: 1 octeto (ej: 50) -> Asume prefijo 192.168.176.
        elseif ($inputRaw -match '^\d{1,3}$') {
            return "192.168.176.$inputRaw"
        }
        # Nombre de equipo (Hostname) o formato extendido
        return $inputRaw
    }

    function Parse-RemoteTarget {
        param([string]$Target)
        if ([string]::IsNullOrWhiteSpace($Target)) {
            return ""
        }
        $Target = $Target.Trim()
        if ($Target -match '^(\d{1,3}\.){3}\d{1,3}$') {
            return $Target
        }
        elseif ($Target -match '^\d{1,3}\.\d{1,3}$') {
            return "192.168.$Target"
        }
        elseif ($Target -match '^\d{1,3}$') {
            return "192.168.176.$Target"
        }
        return $Target
    }

    function Get-RemoteConnectionContext {
        $defTarget = ""
        if ($global:RemoteTargetIP) {
            $defTarget = $global:RemoteTargetIP
        }
        
        Write-Host "`n--- Conexion Remota ---" -ForegroundColor Yellow
        $prompt = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
        if ($defTarget) {
            $prompt += " [$defTarget]"
        }
        $inputTarget = Read-Host $prompt
        
        if ($inputTarget.Trim() -eq "") {
            if ($defTarget) {
                $target = $defTarget
            }
            else {
                Write-Host "[ERROR] Debe especificar un destino." -ForegroundColor Red
                return $null
            }
        }
        else {
            $target = Parse-RemoteTarget $inputTarget
        }

        # 1. Comprobación rápida de conectividad (.NET Ping con timeout 1000ms)
        Write-Host "Verificando conexion con $target (Ping rapido)..." -ForegroundColor Yellow
        $pingExitoso = $false
        try {
            $pingObj = New-Object System.Net.NetworkInformation.Ping
            $reply = $pingObj.Send($target, 1000)
            if ($reply.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                $pingExitoso = $true
            }
        }
        catch {
            $pingExitoso = Test-Connection -ComputerName $target -Count 1 -Quiet -ErrorAction SilentlyContinue
        }

        if (-not $pingExitoso) {
            Write-Host "[AVISO] El equipo $target no respondio al ping en 1s. Verifique si esta encendido o tiene firewall." -ForegroundColor Yellow
            $confirmar = Read-Host "¿Desea intentar la conexion de todas formas? (S/N) [N]"
            if ($confirmar.ToUpper() -ne "S") {
                return $null
            }
        }

        # 2. Resolución rápida de Hostname para soporte Kerberos / Dominio
        $targetHost = $target
        try {
            $dnsTask = [System.Net.Dns]::GetHostEntry($target)
            if ($dnsTask -and $dnsTask.HostName) {
                $targetHost = $dnsTask.HostName.Split('.')[0]
            }
        }
        catch {}

        # 3. Selección y configuración de credenciales (3 tipos solicitados)
        $cred = $null
        $tipoCred = "1"
        if ($global:RemoteTargetIP -eq $target -and $global:RemoteTargetCred -ne $null) {
            $usarExistente = Read-Host "¿Usar las credenciales guardadas para $target? (S/N) [S]"
            if ($usarExistente -eq "" -or $usarExistente.ToUpper() -eq "S") {
                $cred = $global:RemoteTargetCred
                $tipoCred = if ($global:RemoteAuthType) { $global:RemoteAuthType } else { "1" }
            }
        }
        
        if ($null -eq $cred) {
            Write-Host "`nSeleccione el tipo de autenticacion para ${target}:" -ForegroundColor Yellow
            Write-Host "1. Credenciales de la sesion actual (SSO/Dominio Local)"
            Write-Host "2. Credenciales de Usuario de Dominio (ej: DOMINIO\Usuario)"
            Write-Host "3. Credenciales de Usuario Local (ej: .\Administrador o $target\Administrador)"
            $tipoCred = Read-Host "Seleccione opcion [1]"
            if ([string]::IsNullOrWhiteSpace($tipoCred)) { $tipoCred = "1" }
            
            if ($tipoCred -eq "2" -or $tipoCred -eq "3") {
                $promptUser = if ($tipoCred -eq "2") { "Usuario de Dominio (ej: DOMINIO\Usuario)" } else { "Usuario Local (ej: .\Administrador)" }
                Write-Host "Ingrese las credenciales para ${promptUser}:" -ForegroundColor Yellow
                $rawCred = Get-Credential
                
                if ($rawCred) {
                    $uName = $rawCred.UserName
                    # Saneamiento para Tipo 3 (Usuario Local): Si no tiene '\' ni '@', anteponer '.\'
                    # para evitar que Windows intente resolver en el Controlador de Dominio causando demoras de 30s
                    if ($tipoCred -eq "3" -and $uName -notmatch '\\' -and $uName -notmatch '@') {
                        $fixedUser = ".\$uName"
                        $cred = New-Object System.Management.Automation.PSCredential($fixedUser, $rawCred.Password)
                    }
                    else {
                        $cred = $rawCred
                    }
                }
            }
        }
        
        $global:RemoteTargetIP = $target
        $global:RemoteTargetHostName = $targetHost
        $global:RemoteTargetCred = $cred
        $global:RemoteAuthType = $tipoCred
        
        return New-Object PSObject -Property @{
            ComputerName = $target
            HostName     = $targetHost
            Credential   = $cred
            AuthType     = $tipoCred
        }
    }

    function Mount-RemoteCShare {
        param(
            [string]$ComputerName,
            $Credential
        )
        $driveName = "RemoteC_Clean"
        if (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
        }
        
        $rootPath = "\\$ComputerName\C$"
        Write-Host "Conectando al recurso administrativo $rootPath..." -ForegroundColor Yellow
        
        try {
            if ($null -ne $Credential) {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Credential $Credential -Scope Global -ErrorAction Stop | Out-Null
            }
            else {
                New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Scope Global -ErrorAction Stop | Out-Null
            }
            Write-Host "Conectado exitosamente al recurso compartido C$." -ForegroundColor Green
            return $driveName
        }
        catch {
            # Si hay error 1219 (conexiones múltiples con credenciales distintas), intentar limpiar la sesión previa
            if ($_.Exception.Message -match "1219" -or $_.Exception.Message -match "multiple connections") {
                try {
                    cmd.exe /c "net use `"$rootPath`" /delete /y" 2>&1 | Out-Null
                    Start-Sleep -Milliseconds 300
                    if ($null -ne $Credential) {
                        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Credential $Credential -Scope Global -ErrorAction Stop | Out-Null
                    }
                    else {
                        New-PSDrive -Name $driveName -PSProvider FileSystem -Root $rootPath -Scope Global -ErrorAction Stop | Out-Null
                    }
                    Write-Host "Conectado exitosamente al recurso compartido C$ tras restablecer sesion." -ForegroundColor Green
                    return $driveName
                } catch {}
            }
            Write-Host "[ERROR] No se pudo mapear la unidad C$ remota." -ForegroundColor Red
            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Red
            return $null
        }
    }

    function Dismount-RemoteCShare {
        param([string]$driveName)
        if ($driveName -and (Get-PSDrive -Name $driveName -ErrorAction SilentlyContinue)) {
            Remove-PSDrive -Name $driveName -Force -ErrorAction SilentlyContinue
            Write-Host "Unidad remota C$ desmontada." -ForegroundColor Gray
        }
    }

    function Invoke-RemotePowerShellEncoded {
        param(
            [string]$ComputerName,
            $Credential,
            [string]$ScriptContent
        )
        $scriptBytes = [System.Text.Encoding]::Unicode.GetBytes($ScriptContent)
        $scriptBase64 = [Convert]::ToBase64String($scriptBytes)
        $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $scriptBase64"
        
        try {
            if ($null -ne $Credential) {
                $res = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ComputerName -Credential $Credential -ErrorAction Stop
            }
            else {
                $res = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ComputerName -ErrorAction Stop
            }
            return $res
        }
        catch {
            Write-Host "[ERROR] Fallo al invocar proceso WMI en $ComputerName : $_" -ForegroundColor Red
            return $null
        }
    }

    # ==============================================================================
    #   MODULOS INDEPENDIENTES DEL GRUPO 13: OPTIMIZACION Y LIMPIEZA REMOTA
    # ==============================================================================

    function Invoke-RemoteCleanTempFolders {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Iniciando limpieza ultrarrapida de temporales en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScript = @'
$delFiles = 0
$delDirs = 0
$delBytes = [int64]0

function Clean-TargetFolder {
    param([string]$targetDir)
    if (-not (Test-Path -LiteralPath $targetDir)) { return }
    $items = Get-ChildItem -LiteralPath $targetDir -Recurse -Force -ErrorAction SilentlyContinue
    if ($items) {
        foreach ($f in ($items | Where-Object { -not $_.PSIsContainer })) {
            try {
                $len = $f.Length
                Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                $script:delFiles++
                $script:delBytes += $len
            } catch {}
        }
        $dirs = $items | Where-Object { $_.PSIsContainer } | Sort-Object -Property @{Expression={$_.FullName.Length}} -Descending
        foreach ($d in $dirs) {
            try {
                Remove-Item -LiteralPath $d.FullName -Force -Confirm:$false -ErrorAction Stop
                $script:delDirs++
            } catch {}
        }
    }
}

# 1. Limpieza de Windows Temp y Prefetch
Clean-TargetFolder "C:\Windows\Temp"
Clean-TargetFolder "C:\Windows\Prefetch"

# 2. Limpieza de Temp de usuario activo
try {
    $cs = Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue
    if (-not $cs) { $cs = Get-WmiObject Win32_ComputerSystem -ErrorAction SilentlyContinue }
    if ($cs -and $cs.UserName) {
        $uName = $cs.UserName.Split('\')[-1]
        Clean-TargetFolder "C:\Users\$uName\AppData\Local\Temp"
    }
} catch {}

$mb = [Math]::Round($script:delBytes / 1MB, 2)
"Files:$script:delFiles|Dirs:$script:delDirs|MB:$mb" | Out-File -FilePath "C:\Windows\Temp\clean_temp_quick_res.txt" -Encoding UTF8 -Force
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScript
        $returnObj = [PSCustomObject]@{ Files = 0; Dirs = 0; MB = 0.0; Success = $false }

        if ($res -and $res.ReturnValue -eq 0 -and $res.ProcessId) {
            $remotePid = $res.ProcessId
            $timeout = 25
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                try {
                    if ($null -ne $cred) {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    } else {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }
                } catch { $proc = $null }
                if ($null -eq $proc) { break }
                $elapsed++
            }

            $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
            if ($null -ne $drive) {
                $resPath = "${drive}:\Windows\Temp\clean_temp_quick_res.txt"
                if (Test-Path -LiteralPath $resPath) {
                    $rawRes = Get-Content -LiteralPath $resPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if ($rawRes) {
                        $stats = @{}
                        $rawRes.Trim() -split '\|' | ForEach-Object {
                            $kv = $_ -split ':'
                            if ($kv.Length -eq 2) { $stats[$kv[0]] = $kv[1] }
                        }
                        $returnObj.Files = [int]$stats['Files']
                        $returnObj.Dirs = [int]$stats['Dirs']
                        $returnObj.MB = [double]$stats['MB']
                        $returnObj.Success = $true
                    }
                    Remove-Item -Path $resPath -Force -ErrorAction SilentlyContinue
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }

        if (-not $Silent) {
            if ($returnObj.Success) {
                Write-Host "`n[OK] Limpieza remota de temporales finalizada exitosamente:" -ForegroundColor Green
                Write-Host "  -> Archivos eliminados : $($returnObj.Files)" -ForegroundColor White
                Write-Host "  -> Carpetas eliminadas : $($returnObj.Dirs)" -ForegroundColor White
                Write-Host "  -> Espacio liberado    : $($returnObj.MB) MB" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] No se pudo completar la limpieza de temporales remota." -ForegroundColor Red
            }
        }
        return $returnObj
    }

    function Invoke-RemoteCleanProgramData {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Iniciando mantenimiento de ProgramData optimizado en $ipRemota..." -ForegroundColor Yellow
            Write-Host " > Modo acelerado: Poda selectiva de carpetas (evita traversing innecesario de Package Cache/Microsoft)..." -ForegroundColor Cyan
        }
        
        $remoteProgDataScript = @'
$excluirCarpetas = @("Microsoft", "Package Cache", "SoftwareLicensing", "Antivirus", "Windows Defender", "NVIDIA", "Docker", "Apple", "OEM", "Intel", "AMD")
$progData = "C:\ProgramData"
$dias = (Get-Date).AddDays(-7)
$exts = @(".tmp", ".log", ".bak", ".old", ".chk", ".temp")

$totalEliminados = 0
$totalBytes = [int64]0
$carpetasEscaneadas = 0

if (Test-Path -LiteralPath $progData) {
    # 1. Archivos en la raiz directa de ProgramData
    $rootFiles = Get-ChildItem -LiteralPath $progData -File -Force -ErrorAction SilentlyContinue
    foreach ($rf in $rootFiles) {
        if ($exts -contains $rf.Extension.ToLower() -and $rf.LastWriteTime -lt $dias) {
            try {
                $len = $rf.Length
                Remove-Item -LiteralPath $rf.FullName -Force -ErrorAction Stop
                $totalEliminados++
                $totalBytes += $len
            } catch {}
        }
    }

    # 2. Subdirectorios podando las exclusiones antes de entrar recursivamente
    $subDirs = Get-ChildItem -LiteralPath $progData -Directory -Force -ErrorAction SilentlyContinue
    foreach ($dir in $subDirs) {
        $omitir = $false
        foreach ($exc in $excluirCarpetas) {
            if ($dir.Name -like "*$exc*") { $omitir = $true; break }
        }
        if ($omitir) { continue }

        $carpetasEscaneadas++
        try {
            $files = Get-ChildItem -LiteralPath $dir.FullName -Recurse -File -Force -ErrorAction SilentlyContinue
            foreach ($f in $files) {
                if ($exts -contains $f.Extension.ToLower() -and $f.LastWriteTime -lt $dias) {
                    try {
                        $len = $f.Length
                        Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
                        $totalEliminados++
                        $totalBytes += $len
                    } catch {}
                }
            }
        } catch {}
    }
}
$mb = [Math]::Round($totalBytes / 1MB, 2)
"Scanned:$carpetasEscaneadas|Deleted:$totalEliminados|MB:$mb" | Out-File -FilePath "C:\Windows\Temp\clean_progdata_res.txt" -Encoding UTF8 -Force
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteProgDataScript
        $returnObj = [PSCustomObject]@{ Scanned = 0; Deleted = 0; MB = 0.0; Success = $false }

        if ($res -and $res.ReturnValue -eq 0 -and $res.ProcessId) {
            $remotePid = $res.ProcessId
            $timeout = 30
            $elapsed = 0
            while ($elapsed -lt $timeout) {
                Start-Sleep -Seconds 1
                try {
                    if ($null -ne $cred) {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    } else {
                        $proc = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }
                } catch { $proc = $null }
                if ($null -eq $proc) { break }
                $elapsed++
            }

            $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
            if ($null -ne $drive) {
                $resPath = "${drive}:\Windows\Temp\clean_progdata_res.txt"
                if (Test-Path -LiteralPath $resPath) {
                    $rawRes = Get-Content -LiteralPath $resPath -Raw -Encoding UTF8 -ErrorAction SilentlyContinue
                    if ($rawRes) {
                        $stats = @{}
                        $rawRes.Trim() -split '\|' | ForEach-Object {
                            $kv = $_ -split ':'
                            if ($kv.Length -eq 2) { $stats[$kv[0]] = $kv[1] }
                        }
                        $returnObj.Scanned = [int]$stats['Scanned']
                        $returnObj.Deleted = [int]$stats['Deleted']
                        $returnObj.MB = [double]$stats['MB']
                        $returnObj.Success = $true
                    }
                    Remove-Item -Path $resPath -Force -ErrorAction SilentlyContinue
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }

        if (-not $Silent) {
            if ($returnObj.Success) {
                Write-Host "`n[OK] Mantenimiento de ProgramData completado exitosamente:" -ForegroundColor Green
                Write-Host "  -> Carpetas analizadas : $($returnObj.Scanned)" -ForegroundColor White
                Write-Host "  -> Archivos obsoletos  : $($returnObj.Deleted)" -ForegroundColor White
                Write-Host "  -> Espacio liberado    : $($returnObj.MB) MB" -ForegroundColor Green
            } else {
                Write-Host "[ERROR] No se pudo completar el mantenimiento de ProgramData." -ForegroundColor Red
            }
        }
        return $returnObj
    }

    function Invoke-RemoteCleanRAM {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Optimizando memoria RAM en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$codigoC = "
    using System;
    using System.Runtime.InteropServices;
    public class RamUtil {
        [DllImport(\"psapi.dll\")]
        public static extern bool EmptyWorkingSet(IntPtr hProcess);
    }
"
if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
    Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
}
$procesos = [System.Diagnostics.Process]::GetProcesses()
$count = 0
foreach ($p in $procesos) {
    if ($p.Id -gt 4) {
        try {
            if ([RamUtil]::EmptyWorkingSet($p.Handle)) {
                $count++
            }
        } catch {}
    }
    if ($p) { $p.Dispose() }
}
Write-Output "Optimizado $count procesos."
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScriptContent
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Memoria RAM optimizada exitosamente en el equipo remoto $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo ejecutar la optimizacion de RAM remota." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanCPU {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Ajustando prioridad de procesos en el equipo remoto $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$procesosPesados = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10
$count = 0
foreach ($proc in $procesosPesados) {
    if ($proc.Name -ne "Idle" -and $proc.Name -ne "powershell") {
        try {
            $proc.PriorityClass = "BelowNormal"
            $count++
        } catch {}
    }
}
[System.GC]::Collect()
Write-Output "Ajustada prioridad para $count procesos pesados."
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteScriptContent
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Procesador y prioridades de tareas optimizadas en $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo ejecutar la optimizacion de CPU remota." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanRecycleBin {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        if (-not $Silent) {
            Write-Host "Vaciando Papelera de Reciclaje remota en $ipRemota..." -ForegroundColor Yellow
        }
        
        $remoteRecycleScript = @'
try {
    if (Get-Command Clear-RecycleBin -ErrorAction SilentlyContinue) {
        Clear-RecycleBin -Force -ErrorAction SilentlyContinue
    }
} catch {}
cmd.exe /c "rd /s /q C:\`$Recycle.Bin" 2>&1 | Out-Null
'@
        $res = Invoke-RemotePowerShellEncoded -ComputerName $ipRemota -Credential $cred -ScriptContent $remoteRecycleScript
        $success = ($res -and $res.ReturnValue -eq 0)
        if ($success) {
            Start-Sleep -Seconds 2
            if (-not $Silent) {
                Write-Host "[OK] Papelera de reciclaje remota vaciada correctamente en $ipRemota." -ForegroundColor White -BackgroundColor DarkGreen
            }
        } else {
            if (-not $Silent) {
                Write-Host "[ERROR] No se pudo vaciar la papelera en el equipo remoto." -ForegroundColor Red
            }
        }
        return [PSCustomObject]@{ Success = $success; ProcessId = if ($res) { $res.ProcessId } else { $null } }
    }

    function Invoke-RemoteCleanAdvancedProfiles {
        param(
            [Parameter(Mandatory=$true)]$ctx,
            [switch]$Silent
        )
        $ipRemota = $ctx.ComputerName
        $cred = $ctx.Credential
        
        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
        if ($null -eq $drive) {
            return [PSCustomObject]@{ TotalFiles = 0; TotalFolders = 0; TotalMB = 0.0; TotalErrors = 0; Success = $false }
        }

        if (-not $Silent) {
            Write-Host "Preparando ejecucion remota de limpieza profunda de temporales con desglose de usuarios..." -ForegroundColor Yellow
        }
        
        $remoteScriptContent = @'
$profilePaths = @()
try {
    # 1. Obtener perfiles de usuario locales y de dominio desde el Registro de Windows
    $profileKeys = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\ProfileList\*" -ErrorAction Stop
    foreach ($pk in $profileKeys) {
        $path = $pk.ProfileImagePath
        if ($path -and (Test-Path -LiteralPath $path)) {
            if ($path -notmatch "System32" -and $path -notmatch "ServiceProfiles") {
                if ($path -notin $profilePaths) {
                    $profilePaths += $path
                }
            }
        }
    }
}
catch {
    try {
        $profiles = Get-WmiObject -Class Win32_UserProfile -Filter "Special=False" -ErrorAction Stop
        foreach ($p in $profiles) {
            if ($p.LocalPath -and (Test-Path -LiteralPath $p.LocalPath)) {
                if ($p.LocalPath -notin $profilePaths) {
                    $profilePaths += $p.LocalPath
                }
            }
        }
    }
    catch {
        $fallbackPath = "C:\Users"
        if (Test-Path -LiteralPath $fallbackPath) {
            $folders = Get-ChildItem -LiteralPath $fallbackPath -Directory -ErrorAction SilentlyContinue
            foreach ($f in $folders) {
                if ($f.Name -notin "Default", "Default User", "All Users", "Public", "Publico") {
                    $profilePaths += $f.FullName
                }
            }
        }
    }
}

$report = @()
$global:progressData = @{}
$global:lastUpdate = [DateTime]::MinValue
$UserTimeoutSeconds = 30

function Write-ProgressFile {
    param([string]$currentUser, [string]$status)
    $now = Get-Date
    if (($now - $global:lastUpdate).TotalSeconds -lt 1 -and $status -ne "Done" -and $status -ne "Error" -and $status -notmatch "Timeout") {
        return
    }
    $global:lastUpdate = $now
    $lines = @()
    foreach ($u in $global:progressData.Keys) {
        $data = $global:progressData[$u]
        $lines += "User:$u|Path:$($data.Path)|Files:$($data.Files)|Folders:$($data.Folders)|Bytes:$($data.Bytes)|Status:$($data.Status)"
    }
    try {
        $lines | Out-File -FilePath "C:\Windows\Temp\clean_temp_progress.txt" -Encoding UTF8 -Force
    } catch {}
}

function Clear-FolderContents {
    param(
        [string]$FolderPath,
        [string]$userName,
        [ref]$errs,
        [DateTime]$userStartTime,
        [int]$timeoutSecs
    )
    if (-not (Test-Path -LiteralPath $FolderPath)) { return }
    $dirs = @()
    try {
        Get-ChildItem -LiteralPath $FolderPath -Recurse -Force -ErrorAction SilentlyContinue | ForEach-Object {
            if ($_.Name -like "clean_temp_*") { return }
            if (((Get-Date) - $userStartTime).TotalSeconds -gt $timeoutSecs) { throw "UserFolderTimeout" }
            $item = $_
            if ($item.PSIsContainer) {
                $dirs += $item
            } else {
                $len = $item.Length
                try {
                    Remove-Item -LiteralPath $item.FullName -Force -ErrorAction Stop
                    $global:progressData[$userName].Files++
                    $global:progressData[$userName].Bytes += $len
                    Write-ProgressFile -currentUser $userName -status "In Progress"
                } catch { $errs.Value++ }
            }
        }
    }
    catch {
        if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
            throw "UserFolderTimeout"
        }
        $errs.Value++
    }
    
    if ($dirs.Count -gt 0) {
        $sortedDirs = $dirs | Sort-Object -Property @{Expression={$_.FullName.Length}} -Descending
        foreach ($dir in $sortedDirs) {
            if (((Get-Date) - $userStartTime).TotalSeconds -gt $timeoutSecs) { throw "UserFolderTimeout" }
            try {
                Remove-Item -LiteralPath $dir.FullName -Force -Confirm:$false -ErrorAction Stop
                $global:progressData[$userName].Folders++
                Write-ProgressFile -currentUser $userName -status "In Progress"
            } catch { $errs.Value++ }
        }
    }
}

try {
    foreach ($path in $profilePaths) {
        $uName = Split-Path $path -Leaf
        $global:progressData[$uName] = @{
            Path    = $path
            Files   = 0
            Folders = 0
            Bytes   = [int64]0
            Status  = "Pending"
        }
    }
    $global:progressData["_SYSTEM_"] = @{
        Path    = "Sistema (Temp/Prefetch/Update/ServiceProfiles)"
        Files   = 0
        Folders = 0
        Bytes   = [int64]0
        Status  = "Pending"
    }
    Write-ProgressFile -currentUser "System" -status "Init"

    foreach ($path in $profilePaths) {
        $userName = Split-Path $path -Leaf
        $global:progressData[$userName].Status = "In Progress"
        Write-ProgressFile -currentUser $userName -status "In Progress"
        $uErrors = 0
        $userStartTime = Get-Date
        try {
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Temp") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\LocalLow\Temp") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\INetCache") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\Microsoft\Windows\Temporary Internet Files") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            Clear-FolderContents -FolderPath (Join-Path $path "AppData\Local\CrashDumps") -userName $userName -errs ([ref]$uErrors) -userStartTime $userStartTime -timeoutSecs $UserTimeoutSeconds
            $global:progressData[$userName].Status = "Done"
            Write-ProgressFile -currentUser $userName -status "Done"
        }
        catch {
            if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
                $global:progressData[$userName].Status = "Timeout"
                Write-ProgressFile -currentUser $userName -status "Timeout"
            } else {
                $global:progressData[$userName].Status = "Error"
                Write-ProgressFile -currentUser $userName -status "Error"
            }
        }
        $uData = $global:progressData[$userName]
        $report += "User:$userName|Path:$path|Files:$($uData.Files)|Folders:$($uData.Folders)|Bytes:$($uData.Bytes)|Errors:$uErrors|Status:$($uData.Status)"
    }
    
    $userName = "_SYSTEM_"
    $global:progressData[$userName].Status = "In Progress"
    Write-ProgressFile -currentUser $userName -status "In Progress"
    $sysErrors = 0
    $sysStartTime = Get-Date
    try {
        $systemPaths = @(
            "C:\Windows\Temp",
            "C:\Windows\Prefetch",
            "C:\Windows\SoftwareDistribution\Download",
            "C:\Windows\System32\config\systemprofile\AppData\Local\Temp",
            "C:\Windows\ServiceProfiles\LocalService\AppData\Local\Temp",
            "C:\Windows\ServiceProfiles\NetworkService\AppData\Local\Temp"
        )
        foreach ($sysPath in $systemPaths) {
            Clear-FolderContents -FolderPath $sysPath -userName $userName -errs ([ref]$sysErrors) -userStartTime $sysStartTime -timeoutSecs $UserTimeoutSeconds
        }
        $global:progressData[$userName].Status = "Done"
        Write-ProgressFile -currentUser $userName -status "Done"
    }
    catch {
        if ($_.ToString() -match "UserFolderTimeout" -or $_.Exception.Message -match "UserFolderTimeout") {
            $global:progressData[$userName].Status = "Timeout"
            Write-ProgressFile -currentUser $userName -status "Timeout"
        } else {
            $global:progressData[$userName].Status = "Error"
            Write-ProgressFile -currentUser $userName -status "Error"
        }
    }
    $sysData = $global:progressData[$userName]
    $report += "User:$userName|Path:$($sysData.Path)|Files:$($sysData.Files)|Folders:$($sysData.Folders)|Bytes:$($sysData.Bytes)|Errors:$sysErrors|Status:$($sysData.Status)"

    $outputPath = "C:\Windows\Temp\clean_temp_results.txt"
    $report | Out-File -FilePath $outputPath -Encoding UTF8 -Force
}
catch {
    $errPath = "C:\Windows\Temp\clean_temp_errors.txt"
    $_ | Out-File -FilePath $errPath -Encoding UTF8 -Force
}
'@
        $scriptBytes = [System.Text.Encoding]::Unicode.GetBytes($remoteScriptContent)
        $scriptBase64 = [Convert]::ToBase64String($scriptBytes)
        $cmd = "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -EncodedCommand $scriptBase64"
        
        if (-not $Silent) {
            Write-Host "Ejecutando script de limpieza profunda en segundo plano..." -ForegroundColor Yellow
        }
        
        $totalFiles = 0
        $totalFolders = 0
        $totalBytes = [int64]0
        $totalErrors = 0
        $hasResults = $false

        try {
            if ($null -ne $cred) {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
            } else {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
            }

            if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                $remotePid = $result.ProcessId
                if (-not $Silent) {
                    Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                    Write-Host "Realizando limpieza profunda en tiempo real (monitoreando progreso)...`n" -ForegroundColor Yellow
                }
                
                $timeout = 300
                $elapsed = 0
                $lastReport = @{}
                $progressFilePath = "${drive}:\Windows\Temp\clean_temp_progress.txt"
                
                while ($elapsed -lt $timeout) {
                    Start-Sleep -Seconds 2
                    $procCheck = $null
                    try {
                        if ($null -ne $cred) {
                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction Stop
                        } else {
                            $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction Stop
                        }
                    } catch {
                        $procCheck = "SimulatedActive"
                    }
                    
                    if (Test-Path -LiteralPath $progressFilePath) {
                        try {
                            $progressContent = Get-Content -LiteralPath $progressFilePath -Encoding UTF8 -ErrorAction Stop
                            if ($progressContent) {
                                foreach ($line in $progressContent) {
                                    $parts = $line -split '\|'
                                    $stats = @{}
                                    foreach ($part in $parts) {
                                        if ($part -match "^([^:]+):(.*)$") {
                                            $stats[$Matches[1]] = $Matches[2]
                                        }
                                    }
                                    $uName = $stats["User"]
                                    $uPath = $stats["Path"]
                                    if (-not $uName) { continue }
                                    
                                    $uFiles = [int]$stats["Files"]
                                    $uFolders = [int]$stats["Folders"]
                                    $uBytes = [int64]$stats["Bytes"]
                                    $uStatus = $stats["Status"]
                                    
                                    $prev = $lastReport[$uName]
                                    if ($null -eq $prev -or $prev.Files -ne $uFiles -or $prev.Folders -ne $uFolders -or $prev.Status -ne $uStatus) {
                                        $mbUser = [Math]::Round($uBytes / 1MB, 2)
                                        $displayContext = if ($uName -eq "_SYSTEM_") { "Sistema (Temp/Prefetch/Update/ServiceProfiles)" } else { "Carpeta: $uPath (Usuario: $uName)" }
                                        
                                        if (-not $Silent) {
                                            if ($uStatus -eq "Done") {
                                                Write-Host " -> [COMPLETADO] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Liberado: $mbUser MB" -ForegroundColor Green
                                            } elseif ($uStatus -eq "Timeout") {
                                                Write-Host " -> [OMITIDO (TIMEOUT)] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Excedio limite 30s" -ForegroundColor Yellow
                                            } elseif ($uStatus -eq "Error") {
                                                Write-Host " -> [ERROR] $displayContext | Limpieza interrumpida" -ForegroundColor Red
                                            } elseif ($uStatus -eq "In Progress") {
                                                Write-Host " -> [PROGRESO] $displayContext | Archivos: $uFiles | Carpetas: $uFolders | Liberado: $mbUser MB..." -ForegroundColor Yellow
                                            }
                                        }
                                        $lastReport[$uName] = @{ Files = $uFiles; Folders = $uFolders; Status = $uStatus }
                                    }
                                }
                            }
                        } catch {}
                    }
                    if ($null -eq $procCheck) { break }
                    $elapsed += 2
                }

                $resultsPath = "${drive}:\Windows\Temp\clean_temp_results.txt"
                $errorsPath = "${drive}:\Windows\Temp\clean_temp_errors.txt"
                
                for ($i = 0; $i -lt 6; $i++) {
                    if (Test-Path -LiteralPath $resultsPath) { $hasResults = $true; break }
                    if (Test-Path -LiteralPath $errorsPath) { break }
                    Start-Sleep -Milliseconds 500
                }

                if ($hasResults) {
                    if (-not $Silent) {
                        Write-Host "`n--- DETALLE FINAL DE LIMPIEZA POR USUARIO ---" -ForegroundColor Cyan
                    }
                    Get-Content -Path $resultsPath | ForEach-Object {
                        $parts = $_ -split '\|'
                        $userStats = @{}
                        foreach ($part in $parts) {
                            if ($part -match "^([^:]+):(.*)$") {
                                $userStats[$Matches[1]] = $Matches[2]
                            }
                        }
                        $uName = $userStats["User"]
                        $uPath = $userStats["Path"]
                        $uFiles = [int]$userStats["Files"]
                        $uFolders = [int]$userStats["Folders"]
                        $uBytes = [int64]$userStats["Bytes"]
                        $uErrors = [int]$userStats["Errors"]
                        $uStatus = $userStats["Status"]
                        
                        $totalFiles += $uFiles
                        $totalFolders += $uFolders
                        $totalBytes += $uBytes
                        $totalErrors += $uErrors
                        
                        $mbUser = [Math]::Round($uBytes / 1MB, 2)
                        $displayContext = if ($uName -eq "_SYSTEM_") { "Sistema (Temp/Prefetch/Update/ServiceProfiles)" } else { "Carpeta: $uPath (Usuario: $uName)" }
                        
                        if (-not $Silent) {
                            $statusLabel = if ($uStatus -eq "Timeout") { " [OMITIDO POR TIMEOUT]" } else { "" }
                            $color = if ($uStatus -eq "Timeout") { "Yellow" } else { "White" }
                            Write-Host "[$displayContext]$statusLabel" -ForegroundColor $color
                            Write-Host "  -> Archivos eliminados: $uFiles" -ForegroundColor Green
                            Write-Host "  -> Carpetas eliminadas: $uFolders" -ForegroundColor Green
                            Write-Host "  -> Espacio liberado   : $mbUser MB" -ForegroundColor Green
                            Write-Host "  -> Errores/Bloqueados : $uErrors" -ForegroundColor Yellow
                            Write-Host ""
                        }
                    }
                    
                    $totalMBLiberados = [Math]::Round($totalBytes / 1MB, 2)
                    if (-not $Silent) {
                        Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                        Write-Host "RESUMEN GLOBAL DE LIMPIEZA MULTI-USUARIO REMOTA (AVANZADA):" -ForegroundColor Cyan
                        Write-Host "Total archivos eliminados: $totalFiles" -ForegroundColor White
                        Write-Host "Total carpetas eliminadas: $totalFolders" -ForegroundColor White
                        Write-Host "Total espacio liberado:    $totalMBLiberados MB" -ForegroundColor Green
                        Write-Host "Total errores/bloqueados:  $totalErrors" -ForegroundColor Yellow
                        Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    }
                }
                
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_results.txt" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_progress.txt" -Force -ErrorAction SilentlyContinue
                Remove-Item -Path "${drive}:\Windows\Temp\clean_temp_errors.txt" -Force -ErrorAction SilentlyContinue
                Dismount-RemoteCShare -driveName $drive
            } else {
                if (-not $Silent) {
                    Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
                }
                Dismount-RemoteCShare -driveName $drive
            }
        }
        catch {
            if (-not $Silent) {
                Write-Host "[ERROR] Fallo la llamada WMI: $_" -ForegroundColor Red
            }
            Dismount-RemoteCShare -driveName $drive
        }

        return [PSCustomObject]@{
            TotalFiles   = $totalFiles
            TotalFolders = $totalFolders
            TotalMB      = [Math]::Round($totalBytes / 1MB, 2)
            TotalErrors  = $totalErrors
            Success      = $hasResults
        }
    }

    function Invoke-RemoteCleanGeneral {
        param(
            [Parameter(Mandatory=$true)]$ctx
        )
        $ipRemota = $ctx.ComputerName
        $swMaster = [System.Diagnostics.Stopwatch]::StartNew()
        
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "   INICIANDO LIMPIEZA GENERAL Y MANTENIMIENTO INTEGRAL EN $ipRemota" -ForegroundColor Yellow
        Write-Host "==========================================================================" -ForegroundColor Cyan
        
        # 1. Liberar RAM
        Write-Host "`n[FASE 1/6] Optimizando Memoria RAM..." -ForegroundColor Yellow
        $resRAM = Invoke-RemoteCleanRAM -ctx $ctx -Silent
        if ($resRAM.Success) {
            Write-Host "  -> Memoria RAM optimizada exitosamente (API EmptyWorkingSet)." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo optimizar la RAM." -ForegroundColor Yellow
        }

        # 2. Liberar CPU
        Write-Host "`n[FASE 2/6] Optimizando Procesador y Prioridades..." -ForegroundColor Yellow
        $resCPU = Invoke-RemoteCleanCPU -ctx $ctx -Silent
        if ($resCPU.Success) {
            Write-Host "  -> Prioridades de procesos pesados ajustadas a BelowNormal." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo ajustar la prioridad de CPU." -ForegroundColor Yellow
        }

        # 3. Limpiar Temporales de Carpetas (Windows Temp, Prefetch, Temp usuario activo)
        Write-Host "`n[FASE 3/6] Limpiando Archivos Temporales de Carpetas del Sistema..." -ForegroundColor Yellow
        $resTemp = Invoke-RemoteCleanTempFolders -ctx $ctx -Silent
        if ($resTemp.Success) {
            Write-Host "  -> Archivos eliminados : $($resTemp.Files)" -ForegroundColor White
            Write-Host "  -> Carpetas eliminadas : $($resTemp.Dirs)" -ForegroundColor White
            Write-Host "  -> Espacio liberado    : $($resTemp.MB) MB" -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo completar la limpieza de temporales de carpetas." -ForegroundColor Yellow
        }

        # 4. Limpieza de ProgramData (Poda selectiva)
        Write-Host "`n[FASE 4/6] Mantenimiento de Archivos Temporales en ProgramData..." -ForegroundColor Yellow
        $resProg = Invoke-RemoteCleanProgramData -ctx $ctx -Silent
        if ($resProg.Success) {
            Write-Host "  -> Carpetas analizadas : $($resProg.Scanned)" -ForegroundColor White
            Write-Host "  -> Archivos obsoletos  : $($resProg.Deleted)" -ForegroundColor White
            Write-Host "  -> Espacio liberado    : $($resProg.MB) MB" -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo completar la limpieza de ProgramData." -ForegroundColor Yellow
        }

        # 5. Vaciar Papelera de Reciclaje
        Write-Host "`n[FASE 5/6] Vaciando Papelera de Reciclaje Remota..." -ForegroundColor Yellow
        $resRecycle = Invoke-RemoteCleanRecycleBin -ctx $ctx -Silent
        if ($resRecycle.Success) {
            Write-Host "  -> Papelera de reciclaje vaciada para todos los usuarios." -ForegroundColor Green
        } else {
            Write-Host "  -> [AVISO] No se pudo vaciar la papelera." -ForegroundColor Yellow
        }

        # 6. Limpieza Avanzada Multi-Usuario (Perfiles)
        Write-Host "`n[FASE 6/6] Limpieza Avanzada de Temporales (Todos los Usuarios)..." -ForegroundColor Yellow
        $resAdv = Invoke-RemoteCleanAdvancedProfiles -ctx $ctx
        
        $swMaster.Stop()
        $totalDuracion = [Math]::Round($swMaster.Elapsed.TotalSeconds, 2)
        $advFiles = 0
        $advDirs = 0
        $advMB = 0.0
        if ($resAdv) {
            $advFiles = $resAdv.TotalFiles
            $advDirs = $resAdv.TotalFolders
            $advMB = $resAdv.TotalMB
        }
        $granTotalArchivos = $resTemp.Files + $resProg.Deleted + $advFiles
        $granTotalCarpetas = $resTemp.Dirs + $advDirs
        $granTotalMB = [Math]::Round($resTemp.MB + $resProg.MB + $advMB, 2)

        Write-Host "`n==========================================================================" -ForegroundColor Green
        Write-Host "   RESUMEN MAESTRO: LIMPIEZA GENERAL COMPLETADA EN $ipRemota" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "==========================================================================" -ForegroundColor Green
        Write-Host ("  Total Archivos Eliminados : {0}" -f $granTotalArchivos) -ForegroundColor White
        Write-Host ("  Total Carpetas Eliminadas : {0}" -f $granTotalCarpetas) -ForegroundColor White
        Write-Host ("  Total Espacio Liberado    : {0} MB" -f $granTotalMB) -ForegroundColor Green
        Write-Host ("  Tiempo Total Transcurrido : {0} segundos" -f $totalDuracion) -ForegroundColor Cyan
        Write-Host "==========================================================================" -ForegroundColor Green
    }

    function Ejecutar-DefragRemoto {
        param(
            [string]$ipRemota,
            $cred,
            [string]$driveLetter
        )

        $drive = Mount-RemoteCShare -ComputerName $ipRemota -Credential $cred
        if ($null -eq $drive) {
            return
        }

        # 1. Crear el script de desfragmentación remota
        $remoteScriptContent = @'
param(
    [string]$DriveLetter = "C"
)
$DriveLetter = $DriveLetter.Replace(":", "").Trim().ToUpper()

# Deteccion de tipo de disco (HDD vs SSD)
$mediaType = "HDD"
try {
    $partition = Get-WmiObject -Class Win32_LogicalDiskToPartition | Where-Object { $_.Dependent -match "${DriveLetter}:" }
    $partDeviceID = $partition.Antecedent.Split('=')[1].Trim('"')
    
    if ($partDeviceID -match "Disk #(\d+)") {
        $diskIndex = [int]$Matches[1]
        
        $diskDrive = Get-WmiObject -Class Win32_DiskDrive | Where-Object { $_.Index -eq $diskIndex }
        
        # Intentar MSFT_PhysicalDisk para MediaType preciso
        try {
            $physDisk = Get-CimInstance -Namespace Root\Microsoft\Windows\Storage -ClassName MSFT_PhysicalDisk -Filter "DeviceId = '$diskIndex'" -ErrorAction Stop
            if ($physDisk.MediaType -eq 4) {
                $mediaType = "SSD"
            } elseif ($physDisk.MediaType -eq 3) {
                $mediaType = "HDD"
            }
        }
        catch {
            # Fallback en base al modelo del disco
            if ($diskDrive.Model -match "SSD|NVME|Solid State|Flash") {
                $mediaType = "SSD"
            }
        }
    }
}
catch {}

Write-Output "Tipo de Soporte Detectado para unidad ${DriveLetter}:: $mediaType"

if ($mediaType -eq "SSD") {
    Write-Output "Iniciando optimizacion SSD (Trim/ReTrim) en unidad ${DriveLetter}:..."
    if (Get-Command Optimize-Volume -ErrorAction SilentlyContinue) {
        Optimize-Volume -DriveLetter $DriveLetter -ReTrim -Verbose
    } else {
        defrag.exe ${DriveLetter}: /O /U /V /H
    }
} else {
    Write-Output "Iniciando desfragmentacion HDD en unidad ${DriveLetter}:..."
    defrag.exe ${DriveLetter}: /U /V /H
}
Write-Output "Proceso de optimizacion completado con exito."
'@

        $remoteScriptPath = "${drive}:\Windows\Temp\defrag_remote.ps1"
        $logPath = "${drive}:\Windows\Temp\defrag_remote.log"
        
        # Eliminar log anterior si existe
        if (Test-Path $logPath) {
            Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
        }

        try {
            $remoteScriptContent | Out-File -FilePath $remoteScriptPath -Encoding ascii -Force -ErrorAction Stop
            Write-Host "Script de desfragmentacion copiado al equipo remoto." -ForegroundColor Green
        }
        catch {
            Write-Host "[ERROR] No se pudo copiar el script de desfragmentacion: $_" -ForegroundColor Red
            Dismount-RemoteCShare -driveName $drive
            return
        }

        # 2. Iniciar el proceso remoto en segundo plano usando cmd.exe para redirigir la salida
        $cmd = "cmd.exe /c `"powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\defrag_remote.ps1 -DriveLetter $driveLetter > C:\Windows\Temp\defrag_remote.log 2>&1`""
        Write-Host "Iniciando desfragmentacion/optimizacion en el equipo remoto..." -ForegroundColor Yellow

        try {
            if ($null -ne $cred) {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota -Credential $cred
            }
            else {
                $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ArgumentList $cmd -ComputerName $ipRemota
            }

            if ($result.ReturnValue -eq 0 -and $result.ProcessId) {
                $remotePid = $result.ProcessId
                Write-Host "Proceso remoto iniciado exitosamente (PID: $remotePid)." -ForegroundColor Green
                Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                Write-Host "Monitoreando progreso en tiempo real..." -ForegroundColor Cyan
                Write-Host "Presione la tecla 'Q' en cualquier momento para enviarlo a segundo plano." -ForegroundColor Yellow
                Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray

                $elapsed = 0
                $finished = $false
                $aborted = $false
                $lastLineCount = 0
                $maxTimeout = 3600  # 1 hora maximo de seguridad

                while ($elapsed -lt $maxTimeout) {
                    Start-Sleep -Milliseconds 1500
                    $elapsed += 1.5

                    # Verificar estado del proceso
                    if ($null -ne $cred) {
                        $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -Credential $cred -ErrorAction SilentlyContinue
                    }
                    else {
                        $procCheck = Get-WmiObject -Class Win32_Process -Filter "ProcessId = $remotePid" -ComputerName $ipRemota -ErrorAction SilentlyContinue
                    }

                    # Leer y emitir contenido nuevo del log
                    if (Test-Path $logPath) {
                        try {
                            $lines = Get-Content -Path $logPath -ErrorAction SilentlyContinue
                            if ($lines -and $lines.Count -gt $lastLineCount) {
                                for ($i = $lastLineCount; $i -lt $lines.Count; $i++) {
                                    Write-Host $lines[$i] -ForegroundColor Gray
                                }
                                $lastLineCount = $lines.Count
                            }
                        } catch {}
                    }

                    # Finalizar si el proceso ya no existe
                    if ($null -eq $procCheck) {
                        $finished = $true
                        break
                    }

                    # Detectar si el usuario pulso la tecla Q
                    if ($Host.UI.RawUI.KeyAvailable) {
                        $key = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyUp,IncludeKeyDown")
                        if ($key.Character -eq 'q' -or $key.Character -eq 'Q') {
                            $aborted = $true
                            break
                        }
                    }
                }

                if ($finished) {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[OK] Optimizacion remota finalizada exitosamente." -ForegroundColor Green
                    
                    # Limpiar archivos temporales
                    Remove-Item -Path $logPath -Force -ErrorAction SilentlyContinue
                    Remove-Item -Path $remoteScriptPath -Force -ErrorAction SilentlyContinue
                }
                elseif ($aborted) {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[!] Monitoreo cancelado por el usuario." -ForegroundColor Yellow
                    Write-Host "El proceso continuara ejecutandose de forma silenciosa en segundo plano (PID: $remotePid)." -ForegroundColor Green
                    Write-Host "Los archivos de registro se conservaran en C:\Windows\Temp\" -ForegroundColor Gray
                }
                else {
                    Write-Host "----------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "[!] Se alcanzo el tiempo limite de monitoreo local." -ForegroundColor Yellow
                    Write-Host "El proceso sigue ejecutandose en el equipo remoto (PID: $remotePid)." -ForegroundColor Green
                }
            }
            else {
                Write-Host "[ERROR] El proceso remoto retorno un error: $($result.ReturnValue)" -ForegroundColor Red
            }
        }
        catch {
            Write-Host "[ERROR] Fallo la llamada WMI para crear el proceso: $_" -ForegroundColor Red
        }
        finally {
            Dismount-RemoteCShare -driveName $drive
        }
    }

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 25. +++)) AD: COMANDOS RED - ADMINISTRACION REMOTA +++++"
            Write-Host "  1. Mostrar Hostname y MAC x IP."
            Write-Host "    1.1 Mostrar direccion IP de PC REMOTO."
            Write-Host "    1.2 Asignar direccion IP fija a PC REMOTO."
            Write-Host "    1.3 Asignar direccion AUTOMATICA, IP DHCP A PC REMOTO."
            Write-Host "    1.4 || MOSTRAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Cyan
            Write-Host "    1.5 || DESHABILITAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Green
            Write-Host "    1.6 || HABILITAR || INTERFACES de RED - en PC REMOTO." -ForegroundColor Green
            Write-Host "    1.7 || DESHABILITAR || ZONA CUBIERTA MOVIL - en PC REMOTO." -ForegroundColor Yellow
            Write-Host "    1.8 || HABILITAR || ZONA CUBIERTA MOVIL - en PC REMOTO." -ForegroundColor Yellow
            Write-Host "    1.9 || HABILITAR || WMI, RPC y PSRemoting - en PC REMOTO." -ForegroundColor Green
            Write-Host "  2. Red Grupo de Trabajo y/o Dominio"
            Write-Host "    2.1 Listar Equipos de un Dominio (todo el segmento)"
            Write-Host "    2.2 Auditoria y Deteccion de Equipos en Red (Nueva Ventana)" -ForegroundColor Cyan
            Write-Host "  3. Reinciar PC remotamente." -ForegroundColor Green
            Write-Host "  4. Apagar PC Remotamente." -ForegroundColor Yellow
            Write-Host "  5. Escritorio Publico PC Remoto." -ForegroundColor Cyan
            Write-Host "  6. Carpeta Boot Inicio PC Remoto."
            Write-Host "  7. Abrir CMD remoto con PsTools."
            Write-Host "  8. Abrir PowerShell remoto con PsTools."
            Write-Host "  9. OPCIONES DE PANEL DE CONTROL"
            Write-Host "    9.1 Modificar Opciones de Energia" -ForegroundColor Cyan
            Write-Host "  ----------------------------------------"
            Write-Host "  10. Impresoras DISPONIBLES en PC Remota."
            Write-Host "    10.1 Impresora HABILITADO en PC REMOTA" -ForegroundColor Cyan
            Write-Host "    10.2 Mostrar Impresoras con P.S. en PC Remota."
            Write-Host "  ----------------------------------------"
            Write-Host "  11. Habilitacion de RSAT - LOCAL"
            Write-Host "    11.1 Habilitar ejecucion remota y de scripts (Local)" -ForegroundColor Cyan
            Write-Host "    11.2 Denegar/Deshabilitar ejecucion remota (Local)" -ForegroundColor Yellow
            Write-Host "    11.3 Instalar todos los componentes de RSAT (Local)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  12. Habilitacion de RSAT - REMOTO"
            Write-Host "    12.1 Habilitar ejecucion de scripts (Remoto)" -ForegroundColor Cyan
            Write-Host "    12.2 Denegar/Deshabilitar ejecucion de scripts (Remoto)" -ForegroundColor Yellow
            Write-Host "    12.3 Instalar todos los componentes de RSAT (Remoto)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  13. OPTIMIZACION Y LIMPIEZA DE SISTEMA REMOTO:" -ForegroundColor Green
            Write-Host "    13.1. Eliminar Archivos TEMPORALES CARPETAS Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.2. Eliminar Archivos Temporales ProgramData Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.3. Liberar RAM Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.4. Liberar Procesador Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.5. Vaciar Papelera de Reciclaje Remoto" -ForegroundColor DarkCyan
            Write-Host "    13.6. Eliminacion avanzada de temporales (Todos los usuarios) Remoto" -ForegroundColor Yellow
            Write-Host "    13.7. Limpieza General de Archivos en PC Remoto" -ForegroundColor Cyan
            Write-Host "  ----------------------------------------"
            Write-Host "  14. defragmentacion PC Remoto" -ForegroundColor Cyan
            Write-Host "    14.1 Desfragmentar Unidad C: (Principal)" -ForegroundColor DarkCyan
            Write-Host "    14.2 Desfragmentar Otras Unidades" -ForegroundColor DarkCyan
            Write-Host "  ----------------------------------------"
            Write-Host "  30. REFRESH." -ForegroundColor Red
            Write-Host "  31. REFRESH DESDE GITHUB (ONLINE)." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==============================================================="
            
            $op25 = Read-Host "Seleccione la tarea a realizar"

            switch ($op25) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Solicitar IP estandarizada (IP completa o 2 ultimos octetos)
                    $IPCompleta = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPCompleta)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConsultando informacion de red para: $IPCompleta" -ForegroundColor Cyan

                    # 3. Ejecutar nbtstat
                    # Se usa --% para asegurar que los argumentos se pasen correctamente en versiones antiguas
                    nbtstat -a $IPCompleta



                    Write-Host "-------------------------------------------------------" -ForegroundColor Cyan
                    Write-Host "FINALIZADO" -ForegroundColor Cyan
                    Write-Host " "
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "1.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos estandarizada
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Consultando informacion de red... ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    # Resolución de Hostname para soporte Kerberos en Dominio
                    $computerTarget = $ipRemota
                    Write-Host "[*] Resolviendo Hostname de $ipRemota..." -ForegroundColor Gray
                    try {
                        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
                        $computerTarget = $entry.HostName.Split('.')[0]
                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                    }
                    catch {
                        # Intento por NetBIOS/nbtstat
                        $nbt = nbtstat -a $ipRemota
                        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
                            $computerTarget = $Matches[1].Trim()
                            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
                        } else {
                            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente (NTLM)." -ForegroundColor Yellow
                        }
                    }

                    try {
                        # 2. Consultas WMI Optimizadas usando el Hostname (o IP fallback)
                        $sys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $computerTarget -ErrorAction Stop
                        $marca = if ($sys.Manufacturer) { $sys.Manufacturer.Trim() } else { "Desconocido" }
                        $modelo = if ($sys.Model) { $sys.Model.Trim() } else { "Desconocido" }

                        # Dominio / Grupo de trabajo
                        $redGrupo = ""
                        if ($sys.PartOfDomain) {
                            $redGrupo = "Dominio: $($sys.Domain)"
                        } else {
                            $redGrupo = "Grupo de Trabajo: $($sys.Domain)"
                        }

                        $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computerTarget -ErrorAction Stop
                        $osName = if ($os.Caption) { $os.Caption.Trim() } else { "Windows (Desconocido)" }
                        $osVer = if ($os.Version) { $os.Version.Trim() } else { "" }
                        $osArch = if ($os.OSArchitecture) { $os.OSArchitecture.Trim() } else { "" }
                        $osDisplay = $osName
                        if ($osVer) { $osDisplay += " ($osVer)" }
                        if ($osArch) { $osDisplay += " $osArch" }

                        # Microprocesador (CPU)
                        $cpu = Get-WmiObject -Class Win32_Processor -ComputerName $computerTarget | Select-Object -First 1
                        $cpuName = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { "Desconocido" }

                        # Memoria RAM
                        $ramSum = (Get-WmiObject -Class Win32_PhysicalMemory -ComputerName $computerTarget | Measure-Object -Property Capacity -Sum).Sum
                        if (-not $ramSum) {
                            $ramSum = $sys.TotalPhysicalMemory
                        }
                        $ramGB = if ($ramSum) { [Math]::Round($ramSum / 1GB, 2) } else { 0 }

                        # Almacenamiento Total (Discos Físicos)
                        $disks = Get-WmiObject -Class Win32_DiskDrive -ComputerName $computerTarget
                        $totalStorageBytes = 0
                        $diskDetails = @()
                        foreach ($disk in $disks) {
                            if ($disk.Size) {
                                $totalStorageBytes += $disk.Size
                                $sizeGB = [Math]::Round($disk.Size / 1GB, 2)
                                $diskDetails += "      - $($disk.Model): $sizeGB GB"
                            }
                        }
                        $totalStorageGB = [Math]::Round($totalStorageBytes / 1GB, 2)

                        # --- MOSTRAR INFORMACIÓN DEL EQUIPO ---
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "            CARACTERISTICAS Y ESPECIFICACIONES             " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Nombre del Equipo (Hostname): " -NoNewline
                        Write-Host "$($sys.Name)" -ForegroundColor Green
                        Write-Host "  Red / Grupo:                  " -NoNewline
                        Write-Host "$redGrupo" -ForegroundColor Green
                        Write-Host "  Marca y Modelo:               " -NoNewline
                        Write-Host "$marca / $modelo" -ForegroundColor Yellow
                        Write-Host "  Sistema Operativo:            " -NoNewline
                        Write-Host "$osDisplay" -ForegroundColor Yellow
                        Write-Host "  Microprocesador:              " -NoNewline
                        Write-Host "$cpuName" -ForegroundColor Yellow
                        Write-Host "  Memoria RAM Instalada:        " -NoNewline
                        Write-Host "$ramGB GB" -ForegroundColor Yellow
                        Write-Host "  Almacenamiento Total:         " -NoNewline
                        Write-Host "$totalStorageGB GB" -ForegroundColor Yellow
                        foreach ($detail in $diskDetails) {
                            Write-Host $detail -ForegroundColor Gray
                        }
                        Write-Host ""

                        # --- DETECTAR INFORMACIÓN DEL USUARIO ACTIVO ---
                        $usuariosActivos = @()

                        # 1. Intentar detectar usuarios interactivos a través de procesos explorer.exe
                        try {
                            $procesosExplorer = Get-WmiObject -Class Win32_Process -ComputerName $computerTarget -Filter "Name='explorer.exe'" -ErrorAction SilentlyContinue
                            if ($procesosExplorer) {
                                foreach ($proc in $procesosExplorer) {
                                    $propietario = $proc.GetOwner()
                                    if ($propietario.ReturnValue -eq 0 -and -not [string]::IsNullOrEmpty($propietario.User)) {
                                        $fechaInicio = ""
                                        try {
                                            if ($proc.CreationDate) {
                                                $fechaInicio = [Management.ManagementDateTimeConverter]::ToDateTime($proc.CreationDate).ToString("dd/MM/yyyy HH:mm:ss")
                                            }
                                        } catch {}

                                        $usuariosActivos += [PSCustomObject]@{
                                            Domain      = $propietario.Domain
                                            User        = $propietario.User
                                            AccountName = "$($propietario.Domain)\$($propietario.User)"
                                            LogonTime   = $fechaInicio
                                        }
                                    }
                                }
                            }
                        }
                        catch {}

                        # 2. Fallback a $sys.UserName en caso de que explorer.exe no arroje resultados
                        if ($usuariosActivos.Count -eq 0 -and -not [string]::IsNullOrEmpty($sys.UserName)) {
                            $partes = $sys.UserName.Split('\')
                            $dom = if ($partes.Count -gt 1) { $partes[0] } else { "" }
                            $usr = if ($partes.Count -gt 1) { $partes[1] } else { $partes[0] }
                            $usuariosActivos += [PSCustomObject]@{
                                Domain      = $dom
                                User        = $usr
                                AccountName = $sys.UserName
                                LogonTime   = "No disponible"
                            }
                        }

                        # Filtrar usuarios únicos por cuenta
                        if ($usuariosActivos.Count -gt 0) {
                            $usuariosUnicos = @()
                            $vistos = @{}
                            foreach ($u in $usuariosActivos) {
                                $clave = $u.AccountName.ToUpper()
                                if (-not $vistos.ContainsKey($clave)) {
                                    $vistos[$clave] = $true
                                    $usuariosUnicos += $u
                                }
                            }
                            $usuariosActivos = $usuariosUnicos
                        }

                        # --- MOSTRAR APARTADO DE INFORMACIÓN DEL USUARIO ACTIVO ---
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "               INFORMACION DEL USUARIO ACTIVO              " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""

                        if ($usuariosActivos.Count -eq 0) {
                            Write-Host "  Estado de Sesion:             " -NoNewline
                            Write-Host "Sin sesion activa (Ningun usuario conectado)" -ForegroundColor Yellow
                        }
                        else {
                            # Consultar perfiles de usuario de forma segura
                            $perfilesRemotos = try {
                                Get-WmiObject -Class Win32_UserProfile -ComputerName $computerTarget -ErrorAction SilentlyContinue
                            } catch { $null }

                            foreach ($u in $usuariosActivos) {
                                # Determinar si es usuario de Dominio o Local
                                $esLocal = ($u.Domain.ToUpper() -eq $sys.Name.ToUpper()) -or ($u.Domain -eq ".") -or (-not $sys.PartOfDomain)
                                $tipoCuenta = ""
                                if ($esLocal) {
                                    $tipoCuenta = "Usuario Local"
                                }
                                else {
                                    $nombreDominio = if ($sys.Domain) { $sys.Domain } else { $u.Domain }
                                    $tipoCuenta = "Usuario de Dominio ($nombreDominio)"
                                }

                                # Intentar obtener Nombre Completo / DisplayName
                                $nombreCompleto = ""
                                if ($esLocal) {
                                    try {
                                        $acc = Get-WmiObject -Class Win32_UserAccount -ComputerName $computerTarget -Filter "Name='$($u.User)' and LocalAccount=True" -ErrorAction SilentlyContinue
                                        if ($acc -and $acc.FullName) { $nombreCompleto = $acc.FullName.Trim() }
                                    } catch {}
                                }
                                else {
                                    try {
                                        $searcher = [adsisearcher]"(sAMAccountName=$($u.User))"
                                        $adUser = $searcher.FindOne()
                                        if ($adUser -and $adUser.Properties["displayname"]) {
                                            $nombreCompleto = $adUser.Properties["displayname"][0].ToString().Trim()
                                        }
                                    } catch {}
                                }
                                if ([string]::IsNullOrEmpty($nombreCompleto)) {
                                    $nombreCompleto = "No especificado / No disponible"
                                }

                                # Obtener Ruta del Perfil
                                $rutaPerfil = ""
                                if ($perfilesRemotos) {
                                    $perfil = $perfilesRemotos | Where-Object { 
                                        ($_.LocalPath -like "*\$($u.User)") -or 
                                        ($_.Loaded -eq $true -and -not $_.Special) 
                                    } | Select-Object -First 1
                                    if ($perfil -and $perfil.LocalPath) {
                                        $rutaPerfil = $perfil.LocalPath
                                    }
                                }
                                if ([string]::IsNullOrEmpty($rutaPerfil)) {
                                    $rutaPerfil = "C:\Users\$($u.User)"
                                }

                                $fechaLogon = if (-not [string]::IsNullOrEmpty($u.LogonTime) -and $u.LogonTime -ne "No disponible") { $u.LogonTime } else { "Sesion activa (Hora no disponible)" }

                                Write-Host "  Usuario con Sesion:           " -NoNewline
                                Write-Host "$($u.AccountName)" -ForegroundColor Green
                                Write-Host "  Nombre Completo:              " -NoNewline
                                Write-Host "$nombreCompleto" -ForegroundColor Yellow
                                Write-Host "  Tipo de Cuenta:               " -NoNewline
                                if ($esLocal) {
                                    Write-Host "$tipoCuenta" -ForegroundColor Yellow
                                } else {
                                    Write-Host "$tipoCuenta" -ForegroundColor Green
                                }
                                Write-Host "  Ruta de Perfil:               " -NoNewline
                                Write-Host "$rutaPerfil" -ForegroundColor Yellow
                                Write-Host "  Inicio de Sesion:             " -NoNewline
                                Write-Host "$fechaLogon" -ForegroundColor Gray
                                Write-Host "  Estado de Sesion:             " -NoNewline
                                Write-Host "Activa (Conectado)" -ForegroundColor Green
                                if ($usuariosActivos.Count -gt 1) {
                                    Write-Host "  ---------------------------------------------------------" -ForegroundColor Gray
                                }
                            }
                        }
                        Write-Host ""

                        # --- OBTENER ADAPTADORES DE RED REMOTOS ---
                        $nicConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $computerTarget -Filter "IPEnabled = TRUE"
                        
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "             CONFIGURACION DE RED Y CONECTIVIDAD           " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  --- Adaptadores de Red Activos ---" -ForegroundColor Yellow
                        Write-Host ""

                        $hayAdaptadorActivo = $false

                        foreach ($config in $nicConfigs) {
                            $ips = @()
                            if ($config.IPAddress) {
                                foreach ($ip in $config.IPAddress) {
                                    if ($ip -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                        $ips += $ip
                                    }
                                }
                            }
                            if ($ips.Count -eq 0) { continue }

                            $hayAdaptadorActivo = $true
                            $adapterInfo = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $computerTarget -Filter "Index = $($config.Index)"
                            
                            $tipoConectividad = "Ethernet (Cableado)"
                            if ($adapterInfo) {
                                $netConnectionId = $adapterInfo.NetConnectionID
                                $adapterTypeId = $adapterInfo.AdapterTypeId
                                if (($netConnectionId -match "Wi-Fi|Wireless|WLAN|Inalámbrica|Inalambrica") -or 
                                    ($config.Description -match "Wi-Fi|Wireless|WLAN|802\.11") -or 
                                    ($adapterTypeId -eq 9)) {
                                    $tipoConectividad = "Wi-Fi (Inalambrico)"
                                }
                            } else {
                                if ($config.Description -match "Wi-Fi|Wireless|WLAN|802\.11") {
                                    $tipoConectividad = "Wi-Fi (Inalambrico)"
                                }
                            }

                            $dhcpStatus = if ($config.DHCPEnabled) { "DHCP" } else { "IP Fija (Estatica)" }
                            $mac = if ($config.MACAddress) { $config.MACAddress.Trim() } else { "No disponible" }

                            # Gateways
                            $gateways = @()
                            if ($config.DefaultIPGateway) {
                                foreach ($gw in $config.DefaultIPGateway) {
                                    if ($gw -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                        $gateways += $gw
                                    }
                                }
                            }

                            # DNS
                            $dnsServers = @()
                            if ($config.DNSServerSearchOrder) {
                                foreach ($dns in $config.DNSServerSearchOrder) {
                                    if ($dns -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                        $dnsServers += $dns
                                    }
                                }
                            }

                            Write-Host "  [+] Adaptador:  " -NoNewline
                            Write-Host $config.Description -ForegroundColor Cyan
                            Write-Host "      Estado:     " -NoNewline
                            Write-Host "Conectado / Activo" -ForegroundColor Green
                            Write-Host "      Conexion:   " -NoNewline
                            Write-Host $tipoConectividad -ForegroundColor Gray
                            Write-Host "      Asignacion: " -NoNewline
                            Write-Host $dhcpStatus -ForegroundColor Gray
                            Write-Host "      Direccion MAC: " -NoNewline
                            Write-Host $mac -ForegroundColor Yellow
                            Write-Host "      IP(s):      " -NoNewline
                            Write-Host ($ips -join ", ") -ForegroundColor Yellow
                            if ($gateways.Count -gt 0) {
                                Write-Host "      Gateway:    " -NoNewline
                                Write-Host ($gateways -join ", ") -ForegroundColor Gray
                            }
                            if ($dnsServers.Count -gt 0) {
                                Write-Host "      DNS:        " -NoNewline
                                Write-Host ($dnsServers -join ", ") -ForegroundColor Green
                            } else {
                                Write-Host "      DNS:        " -NoNewline
                                Write-Host "No configurados" -ForegroundColor DarkGray
                            }
                            Write-Host ""
                        }

                        if (-not $hayAdaptadorActivo) {
                            Write-Host "  No se detectaron adaptadores de red activos con IPv4 configurada en el equipo remoto." -ForegroundColor Red
                        }

                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                    }
                    catch {
                        Write-Host "ERROR: No se pudo establecer conexion con $ipRemota ($computerTarget)." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    
                }

                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # --- CONFIGURACIÓN DE RED REMOTA CON COMPARATIVA ANTES/DESPUÉS ---
                    $ipRemota = Get-StandardIPPrompt -Mensaje "Ingrese la IP ACTUAL completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Conectando a: $ipRemota ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    try {
                        # 1. CAPTURA DE DATOS INICIALES (EL "ANTES")
                        $nicInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipRemota `
                            -Filter "IPEnabled = TRUE" | Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | Select-Object -First 1

                        if (-not $nicInfo) { throw "No se pudo establecer comunicacion inicial con $ipRemota." }
                        
                        $interfaceName = (Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "Index=$($nicInfo.Index)").NetConnectionId
                        $macAddress = $nicInfo.MACAddress
                        $hostName = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota).CSName

                        # MOSTRAR REPORTE INICIAL
                        Write-Host "`n====================================================" -ForegroundColor White
                        Write-Host "         ESTADO ACTUAL (ANTES DEL CAMBIO)" -ForegroundColor Yellow
                        Write-Host "====================================================" -ForegroundColor White
                        Write-Host " HOSTNAME:      $hostName"
                        Write-Host " MAC ADDRESS:   $macAddress"
                        Write-Host " INTERFAZ:      $interfaceName"
                        Write-Host " IP ACTUAL:     $($nicInfo.IPAddress[0])"
                        Write-Host " GATEWAY:       $($nicInfo.DefaultIPGateway -join ', ')"
                        Write-Host " DNS ACTUALES:  $($nicInfo.DNSServerSearchOrder -join ', ')"
                        Write-Host "====================================================`n"

                        # 2. SOLICITUD DE NUEVOS DATOS
                        $nuevaIP = Read-Host "Ingrese la NUEVA IP completa para este equipo"
                        $nuevoGW = Read-Host "Ingrese el NUEVO GATEWAY (Default: 192.168.176.1)"
                        if ($nuevoGW -eq "") { $nuevoGW = "192.168.176.1" }

                        Write-Host "`n[!] Aplicando cambios forzados mediante inyeccion Netsh..." -ForegroundColor Magenta

                        # 3. CONSTRUCCIÓN E INYECCIÓN DE COMANDOS (DIFERIDA Y ASÍNCRONA)
                        $cmdIP = "netsh interface ip set address name=\`"$interfaceName\`" static $nuevaIP 255.255.255.0 $nuevoGW 1"
                        $cmdDNS1 = "netsh interface ip set dns name=\`"$interfaceName\`" static 172.25.108.100"
                        $cmdDNS2 = "netsh interface ip add dns name=\`"$interfaceName\`" 192.168.13.214 index=2"
                        
                        $fullCommand = "cmd.exe /c start /b `"`" cmd.exe /c `"ping -n 5 127.0.0.1 >nul & $cmdIP & $cmdDNS1 & $cmdDNS2`""
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process
                        $process.Create($fullCommand) | Out-Null

                        Write-Host "[*] Comandos diferidos enviados. Esperando 15 segundos para reconexion..." -ForegroundColor Cyan
                        Start-Sleep -Seconds 15

                        # 4. CAPTURA DE DATOS FINALES (EL "DESPUÉS")
                        Write-Host "[*] Generando reporte de validacion...`n" -ForegroundColor Magenta
                        
                        try {
                            # 1. Comprobar primero con ping rápido para evitar hangs de WMI
                            Write-Host "[*] Verificando conectividad IP con ping a $nuevaIP..." -ForegroundColor Gray
                            if (-not (Test-Connection -ComputerName $nuevaIP -Count 1 -Quiet)) {
                                throw "El equipo no responde a ping en la nueva IP $nuevaIP."
                            }

                            # 2. Conexión WMI controlada con Timeout de 5 segundos
                            $options = New-Object System.Management.ConnectionOptions
                            $options.Timeout = New-Object System.TimeSpan(0, 0, 5) # 5 segundos
                            $scope = New-Object System.Management.ManagementScope("\\$nuevaIP\root\cimv2", $options)
                            $scope.Connect()

                            $query = New-Object System.Management.ObjectQuery("SELECT * FROM Win32_NetworkAdapterConfiguration WHERE Index = $($nicInfo.Index)")
                            $searcher = New-Object System.Management.ManagementObjectSearcher($scope, $query)
                            $confirm = $searcher.Get() | Select-Object -First 1

                            if ($confirm) {
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host "        ESTADO FINAL (DESPUES DEL CAMBIO)" -ForegroundColor Green
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host " HOSTNAME:      $hostName"
                                Write-Host " MAC ADDRESS:   $macAddress"
                                Write-Host "----------------------------------------------------"
                                Write-Host " NUEVA IP:      $($confirm.IPAddress[0])" -ForegroundColor Cyan
                                Write-Host " MASCARA:       $($confirm.IPSubnet[0])"
                                Write-Host " NUEVO GW:      $($confirm.DefaultIPGateway -join ', ')" -ForegroundColor Cyan
                                Write-Host " NUEVOS DNS:    $($confirm.DNSServerSearchOrder -join ', ')" -ForegroundColor Cyan
                                Write-Host "====================================================" -ForegroundColor White
                                Write-Host "¡Cambio verificado exitosamente!" -ForegroundColor Green
                            } else {
                                throw "No se pudo recuperar la informacion de red de la interfaz con indice $($nicInfo.Index)."
                            }
                        } 
                        catch {
                            Write-Host "----------------------------------------------------"
                            Write-Host "AVISO: El equipo cambio su IP pero no responde WMI aun o la red se cayo." -ForegroundColor Yellow
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                            Write-Host "Verifique manualmente: ping $nuevaIP" -ForegroundColor White
                            Write-Host "----------------------------------------------------"
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR CRITICO]: $($_.Exception.Message)" -ForegroundColor Red
                    }

                    # --- EL TRUCO PARA QUE NO SE CUELGUE ---
                    # Forzamos la limpieza antes de volver a mostrar el menú
                    [System.GC]::Collect()
                    Write-Host "`nEl cambio de IP ha finalizado..."

                    Read-Host "Presione ENTER para continuar..."

                }

                "1.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # --- CONFIGURACIÓN DE RED REMOTA: REGRESO A DHCP (CORREGIDO) ---
                    $ipRemota = Get-StandardIPPrompt -Mensaje "Ingrese la IP ACTUAL completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)"
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`n--- Conectando a: $ipRemota ---" -ForegroundColor Yellow

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o tenga el firewall activo."
                    }

                    try {
                        # 1. CAPTURA DE DATOS INICIALES (EL "ANTES")
                        # Usamos WMI para obtener la identidad del equipo antes del cambio
                        $nicInfo = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipRemota `
                            -Filter "IPEnabled = TRUE" | Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | Select-Object -First 1

                        if (-not $nicInfo) { throw "No se pudo establecer comunicacion inicial con $ipRemota." }
                        
                        # Obtener nombre de interfaz, MAC y Hostname para el reporte
                        $interfaceName = (Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "Index=$($nicInfo.Index)").NetConnectionId
                        $macAddress = $nicInfo.MACAddress
                        $hostName = (Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota).CSName

                        # REPORTE INICIAL
                        Write-Host "`n====================================================" -ForegroundColor White
                        Write-Host "         ESTADO ACTUAL (ANTES DEL CAMBIO)" -ForegroundColor Yellow
                        Write-Host "====================================================" -ForegroundColor White
                        Write-Host " HOSTNAME:      $hostName"
                        Write-Host " MAC ADDRESS:   $macAddress"
                        Write-Host " INTERFAZ:      $interfaceName"
                        Write-Host " IP ESTATICA:   $($nicInfo.IPAddress[0])"
                        Write-Host "====================================================`n"

                        Write-Host "[!] Forzando cambio a DHCP y DNS Automatico..." -ForegroundColor Magenta

                        # 2. CONSTRUCCIÓN DEL COMANDO (DIFERIDA Y ASÍNCRONA)
                        $cmdIP = "netsh interface ip set address name=\`"$interfaceName\`" source=dhcp"
                        $cmdDNS = "netsh interface ip set dns name=\`"$interfaceName\`" source=dhcp"
                        $fullCommand = "cmd.exe /c start /b `"`" cmd.exe /c `"ping -n 5 127.0.0.1 >nul & $cmdIP & $cmdDNS`""

                        # 3. EJECUCIÓN MEDIANTE PROCESO INDEPENDIENTE
                        # Esto asegura que el cambio se complete aunque la red se reinicie
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process
                        $resultado = $process.Create($fullCommand)

                        if ($resultado.ReturnValue -eq 0) {
                            Write-Host "[OK] Comandos inyectados correctamente." -ForegroundColor Green
                            Write-Host "[*] La red se esta reiniciando para obtener IP del servidor DHCP..." -ForegroundColor Cyan
                            Write-Host "[*] Espere 15 segundos..." -ForegroundColor Gray
                            Start-Sleep -Seconds 15

                            # 4. REPORTE FINAL
                            Write-Host "`n====================================================" -ForegroundColor White
                            Write-Host "        ESTADO FINAL (MODO DINAMICO)" -ForegroundColor Green
                            Write-Host "====================================================" -ForegroundColor White
                            Write-Host " HOSTNAME:      $hostName"
                            Write-Host " MAC ADDRESS:   $macAddress"
                            Write-Host "----------------------------------------------------"
                            Write-Host " CONFIGURACION: DHCP ACTIVADO" 
                            Write-Host " DNS:           AUTOMATICO"
                            Write-Host "====================================================" -ForegroundColor White
                            Write-Host "El equipo ya no depende de una IP fija." -ForegroundColor White
                        }
                        else {
                            Write-Host "Fallo al iniciar el proceso remoto. Codigo: $($resultado.ReturnValue)" -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR]: $($_.Exception.Message)" -ForegroundColor Red
                    }

                    Write-Host "`nScript finalizado."
                    
                    Read-Host "Presione ENTER para continuar..."
                }

                "1.4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # Solicitud estandarizada de IP remota
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConsultando interfaces en: $ipRemota...`n" -ForegroundColor Cyan

                    try {
                        # Consulta de todos los adaptadores sin filtrar por estado o tipo fisico
                        $interfaces = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -ErrorAction Stop

                        # Presentacion de resultados en formato tabla
                        $interfaces | Select-Object Name, NetConnectionID, NetConnectionStatus, PhysicalAdapter, AdapterType | 
                        Format-Table -AutoSize
                        
                        Write-Host "`n[EXITO] Auditoria completada." -ForegroundColor Green
                        Write-Host " "
                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar al equipo o consultar la informacion." -ForegroundColor Red
                        Write-Host "Detalle: $_" -ForegroundColor Yellow
                    }

                    
                }

                "1.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de red estandarizada
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    Write-Host "`nConectando a $ipRemota...`n" -ForegroundColor Cyan

                    if (-not (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet)) {
                        Write-Warning "El equipo $ipRemota no responde a ping. Es posible que este apagado o bloquee el trafico."
                    }

                    try {
                        # 2. Listar interfaces fisicas (PhysicalAdapter = True)
                        $interfaces = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ipRemota -Filter "PhysicalAdapter = True" -ErrorAction Stop
                        
                        # Mostrar tabla numerada para seleccion
                        $lista = @()
                        for ($i = 0; $i -lt $interfaces.Count; $i++) {
                            $obj = New-Object PSObject -Property @{
                                Indice = $i
                                Nombre = $interfaces[$i].Name
                                Estado = $interfaces[$i].NetConnectionStatus
                            }
                            $lista += $obj | Select-Object Indice, Nombre, Estado
                        }
                        $lista | Format-Table -AutoSize

                        # 3. Seleccion y confirmacion
                        $idx = Read-Host "Ingrese el indice de la interfaz que desea DESHABILITAR"
                        
                        if ($idx -ge 0 -and $idx -lt $interfaces.Count) {
                            $seleccion = $interfaces[$idx]
                            
                            # Nueva confirmacion de seguridad
                            $confirmar = Read-Host "ADVERTENCIA: Esta a punto de deshabilitar '$($seleccion.Name)'. Desea continuar? (S/N)"
                            
                            if ($confirmar -eq "S" -or $confirmar -eq "s") {
                                Write-Host " "
                                Write-Host "Deshabilitando: $($seleccion.Name)..." -ForegroundColor Yellow
                                
                                # Ejecutar metodo Disable()
                                $resultado = $seleccion.Disable()
                                
                                if ($resultado.ReturnValue -eq 0) {
                                    Write-Host "[EXITO] Interfaz deshabilitada correctamente." -ForegroundColor Green
                                    Write-Host " "
                                }
                                else {
                                    Write-Host "[ERROR] El sistema devolvio el codigo: $($resultado.ReturnValue). Se requieren privilegios de Administrador en el destino." -ForegroundColor Red
                                }
                            }
                            else {
                                Write-Host "[INFO] Operacion cancelada por el usuario." -ForegroundColor Yellow
                                Write-Host " "
                            }
                        }
                        else {
                            Write-Host "[ERROR] Indice invalido." -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar o gestionar la interfaz." -ForegroundColor Red
                        Write-Host "Detalle: $_" -ForegroundColor Yellow
                    }

                    
                }

                "1.6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    
                }

                "1.7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host ""
                    Write-Host "========================================================"
                    Write-Host " BLOQUEO DE ZONA DE COBERTURA MOVIL"
                    Write-Host " Dominio : gmsantacruz.gov.bo"
                    Write-Host "========================================================"
                    Write-Host ""

                    $IP = Get-StandardIPPrompt

                    if ([string]::IsNullOrWhiteSpace($IP)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    Write-Host ""
                    Write-Host "Direccion IP : $IP" -ForegroundColor Yellow
                    Write-Host ""

                    ##########################################################
                    # Verificar conectividad
                    ##########################################################

                    Write-Host "Verificando conectividad..." -ForegroundColor Cyan

                    if (!(Test-Connection -ComputerName $IP -Count 2 -Quiet)) {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host "El equipo no responde."
                        return
                    }

                    Write-Host "Conexion correcta." -ForegroundColor Green
                    Write-Host ""

                    ##########################################################
                    # Obtener HostName mediante WMI
                    ##########################################################

                    Write-Host "Obteniendo nombre del equipo..." -ForegroundColor Cyan

                    try {
                        $Equipo = Get-WmiObject `
                            Win32_ComputerSystem `
                            -ComputerName $IP `
                            -ErrorAction Stop

                        $HostName = $Equipo.Name

                        Write-Host "Nombre del equipo : $HostName" -ForegroundColor Yellow

                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host "No fue posible obtener el nombre del equipo."
                        Write-Host $_.Exception.Message
                        return
                    }

                    ##########################################################
                    # Verificar WinRM
                    ##########################################################

                    Write-Host ""
                    Write-Host "Verificando WinRM..." -ForegroundColor Cyan

                    $WinRM = $true

                    try {
                        Test-WSMan `
                            -ComputerName $HostName `
                            -ErrorAction Stop | Out-Null
                    }
                    catch {
                        $WinRM = $false
                    }

                    ##########################################################
                    # Habilitar WinRM
                    ##########################################################

                    if (!$WinRM) {
                        Write-Host ""
                        Write-Host "WinRM no esta habilitado."
                        Write-Host "Intentando habilitar WinRM..."

                        try {
                            Invoke-WmiMethod `
                                -Class Win32_Process `
                                -Name Create `
                                -ComputerName $HostName `
                                -ArgumentList "cmd.exe /c winrm.cmd quickconfig -quiet" `
                                -ErrorAction Stop | Out-Null

                            Start-Sleep 8

                            Test-WSMan `
                                -ComputerName $HostName `
                                -ErrorAction Stop | Out-Null

                            Write-Host "WinRM habilitado correctamente." -ForegroundColor Green

                        }
                        catch {
                            Write-Host ""
                            Write-Host "ERROR"
                            Write-Host "No fue posible habilitar WinRM."
                            Write-Host $_.Exception.Message
                            return
                        }
                    }

                    ##########################################################
                    # Aplicar configuracion
                    ##########################################################

                    Write-Host ""
                    Write-Host "Aplicando configuracion..." -ForegroundColor Yellow

                    try {
                        Invoke-Command `
                            -ComputerName $HostName `
                            -Authentication Kerberos `
                            -ErrorAction Stop `
                            -ScriptBlock {

                            $Ruta = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections"

                            if (!(Test-Path $Ruta)) {
                                New-Item `
                                    -Path $Ruta `
                                    -Force | Out-Null
                            }

                            New-ItemProperty `
                                -Path $Ruta `
                                -Name NC_ShowSharedAccessUI `
                                -PropertyType DWord `
                                -Value 0 `
                                -Force | Out-Null

                            Set-Service `
                                SharedAccess `
                                -StartupType Disabled `
                                -ErrorAction SilentlyContinue

                            Stop-Service `
                                SharedAccess `
                                -Force `
                                -ErrorAction SilentlyContinue

                            return "OK"
                        }
                        Write-Host ""
                        Write-Host "=============================================="
                        Write-Host "Proceso finalizado correctamente." -ForegroundColor Green
                        Write-Host "=============================================="
                        Write-Host ""
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"
                        Write-Host ""
                        Write-Host $_.Exception.Message
                        Write-Host ""
                    }
                    
                }

                "1.8" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host ""
                    Write-Host "========================================================"
                    Write-Host " RESTAURAR ZONA DE COBERTURA MOVIL"
                    Write-Host " Dominio : gmsantacruz.gov.bo"
                    Write-Host "========================================================"
                    Write-Host ""

                    $IP = Get-StandardIPPrompt

                    if ([string]::IsNullOrWhiteSpace($IP)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    Write-Host ""
                    Write-Host "Direccion IP : $IP" -ForegroundColor Yellow
                    Write-Host ""

                    Write-Host "Verificando conectividad..." -ForegroundColor Cyan

                    if (!(Test-Connection -ComputerName $IP -Count 2 -Quiet)) {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host "El equipo no responde."
                        return
                    }

                    Write-Host "Conexion correcta." -ForegroundColor Green
                    Write-Host ""

                    Write-Host "Obteniendo nombre del equipo..." -ForegroundColor Cyan

                    try {
                        $Equipo = Get-WmiObject `
                            Win32_ComputerSystem `
                            -ComputerName $IP `
                            -ErrorAction Stop

                        $HostName = $Equipo.Name

                        Write-Host "Nombre del equipo : $HostName" -ForegroundColor Yellow
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host $_.Exception.Message
                        return
                    }

                    Write-Host ""
                    Write-Host "Verificando WinRM..."

                    try {
                        Test-WSMan `
                            -ComputerName $HostName `
                            -ErrorAction Stop | Out-Null
                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR" -ForegroundColor Red
                        Write-Host "WinRM no esta disponible."
                        return
                    }

                    Write-Host ""
                    Write-Host "Restaurando configuracion..." -ForegroundColor Cyan

                    try {
                        Invoke-Command `
                            -ComputerName $HostName `
                            -Authentication Kerberos `
                            -ErrorAction Stop `
                            -ScriptBlock {

                            $Ruta = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Network Connections"

                            if (Test-Path $Ruta) {
                                Remove-ItemProperty `
                                    -Path $Ruta `
                                    -Name "NC_ShowSharedAccessUI" `
                                    -ErrorAction SilentlyContinue
                            }

                            Set-Service `
                                -Name SharedAccess `
                                -StartupType Manual `
                                -ErrorAction SilentlyContinue

                            Start-Service `
                                -Name SharedAccess `
                                -ErrorAction SilentlyContinue

                            return "OK"
                        }

                        Write-Host ""
                        Write-Host "=============================================="
                        Write-Host " CONFIGURACION RESTAURADA" -ForegroundColor Green
                        Write-Host "=============================================="
                        Write-Host ""
                        Write-Host "Equipo : $HostName"
                        Write-Host "Zona de cobertura movil habilitada." -ForegroundColor Green
                        Write-Host ""

                    }
                    catch {
                        Write-Host ""
                        Write-Host "ERROR"  -ForegroundColor Red
                        Write-Host $_.Exception.Message
                        Write-Host ""
                    }
                }

                "1.9" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $target = Get-StandardIPPrompt
                    if (-not [string]::IsNullOrWhiteSpace($target)) {
                        psHabilitarAdministracionRemota -targetInput $target
                    } else {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    Read-Host "Presione ENTER para continuar..."
                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    $baseIP = "192.168.176."
                    $rangoInicio = 1
                    $rangoFin = 254

                    Write-Host "--- Iniciando auditoria de red en: $baseIP$rangoInicio al $rangoFin ---" -ForegroundColor Yellow
                    Write-Host "Analizando configuraciones de red... por favor espere.`n" -ForegroundColor Gray

                    $resultados = @()

                    foreach ($i in $rangoInicio..$rangoFin) {
                        $ipActual = $baseIP + $i
                        
                        # Intento de ping rápido
                        if (Test-Connection -ComputerName $ipActual -Count 1 -BufferSize 16 -Quiet) {
                            try {
                                # Consulta WMI para obtener configuración de red y nombre de host simultáneamente
                                $nic = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipActual `
                                    -Filter "IPEnabled = TRUE" -ErrorAction Stop | 
                                Where-Object { $_.Description -notmatch "Virtual|VPN|Pseudo|Bluetooth" } | 
                                Select-Object -First 1

                                if ($nic) {
                                    $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipActual
                                    
                                    # Determinamos el estado visualmente
                                    $estadoIP = "ESTATICO"
                                    if ($nic.DHCPEnabled) {
                                        $estadoIP = "DHCP"
                                    }
                                    
                                    $obj = New-Object PSObject -Property @{
                                        IP         = $ipActual
                                        HostName   = $sys.CSName
                                        Estado     = $estadoIP
                                        MACAddress = $nic.MACAddress
                                    }
                                    $resultados += $obj | Select-Object IP, HostName, Estado, MACAddress
                                    
                                    # Feedback en consola durante el escaneo
                                    $color = "Yellow"
                                    if ($estadoIP -eq "DHCP") {
                                        $color = "Cyan"
                                    }
                                    Write-Host "[+] Detectado: ${ipActual} - ${estadoIP} ($($sys.CSName))" -ForegroundColor $color
                                }
                            }
                            catch {
                                Write-Host "[!] ${ipActual}: Sin acceso a datos (WMI bloqueado)." -ForegroundColor DarkGray
                            }
                        }
                    }

                    # Presentación de resultados finales en tabla
                    if ($resultados.Count -gt 0) {
                        Write-Host "`n" + ("=" * 60) -ForegroundColor White
                        Write-Host "                REPORTE FINAL DE RED" -ForegroundColor Green
                        Write-Host ("=" * 60) -ForegroundColor White
                        
                        $resultados | Sort-Object Estado | Format-Table -AutoSize
                        
                        Write-Host "Total de equipos detectados: $($resultados.Count)" -ForegroundColor Cyan
                    }
                    else {
                        Write-Host "`nNo se detectaron equipos activos en el segmento." -ForegroundColor Red
                    }

                    Write-Host "`nEl Proceso ha finalizado..."        

                    Read-Host "Presione ENTER para continuar..."
                }

                "2.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host "     AUDITORIA Y DETECCION AVANZADA DE EQUIPOS EN RED (NUEVA VENTANA)     " -ForegroundColor Cyan
                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Extracción de IP del equipo solicitante y propuesta de segmento CIDR
                    $solicitanteIP = "127.0.0.1"
                    $redSugerida = "192.168.176.0/24"
                    try {
                        $ad = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue | 
                            Where-Object { 
                                $_.IPAddress -notlike "127.*" -and 
                                $_.IPAddress -notlike "169.254*" -and 
                                $_.InterfaceAlias -notmatch "VPN|Radmin|Hamachi|vEthernet|Virtual|Pseudo|Loopback" 
                            } | 
                            Sort-Object { 
                                if ($_.IPAddress -like "192.168.*") { 1 } 
                                elseif ($_.IPAddress -like "10.*" -or $_.IPAddress -like "172.*") { 2 } 
                                else { 3 } 
                            } | Select-Object -First 1

                        if ($ad) {
                            $solicitanteIP = $ad.IPAddress
                            $octetos = $solicitanteIP.Split('.')
                            if ($octetos.Count -eq 4) {
                                $redSugerida = "$($octetos[0]).$($octetos[1]).$($octetos[2]).0/24"
                            }
                        }
                    } catch {}

                    Write-Host "  [+] IP del Equipo Solicitante:  " -NoNewline -ForegroundColor White
                    Write-Host "$solicitanteIP" -ForegroundColor Green
                    Write-Host "  [+] Segmento de Red Detectado:  " -NoNewline -ForegroundColor White
                    Write-Host "$redSugerida" -ForegroundColor Yellow
                    Write-Host ""
                    Write-Host "  Ingrese la direccion de red a escanear (ej. 192.168.176.0/24, 192.168.176. o 176)" -ForegroundColor Cyan
                    $entradaRed = Read-Host "  [Presione ENTER para usar $redSugerida]"
                    $entradaRed = $entradaRed.Trim()

                    $segmentoElegido = $redSugerida
                    if (-not [string]::IsNullOrWhiteSpace($entradaRed)) {
                        if ($entradaRed -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.0/\d{1,2}$') {
                            $segmentoElegido = $entradaRed
                        }
                        elseif ($entradaRed -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.?$') {
                            $segmentoElegido = "$($Matches[1]).0/24"
                        }
                        elseif ($entradaRed -match '^\d{1,3}$') {
                            $segmentoElegido = "192.168.$entradaRed.0/24"
                        }
                        else {
                            $segmentoElegido = $entradaRed
                        }
                    }

                    Write-Host "`n[*] Preparando ejecucion en una NUEVA VENTANA..." -ForegroundColor Yellow

                    # 2. Generación del código del script auditor autónomo
                    $scannerCode = @'
param(
    [string]$NetworkCIDR = "192.168.176.0/24",
    [string]$RequestingIP = "127.0.0.1"
)

# Configuración visual de la ventana de auditoría
$Host.UI.RawUI.WindowTitle = "AUDITORIA DE RED: $NetworkCIDR | Solicitante: $RequestingIP | shellWil"
try {
    if ($Host.UI.RawUI.BufferSize.Width -lt 125) {
        $Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(130, 3500)
        $Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(130, 45)
    }
} catch {}

Clear-Host
Write-Host "==========================================================================================================" -ForegroundColor Cyan
Write-Host "                    AUDITORIA AVANZADA: ESCANEO Y DETECCION DE EQUIPOS EN RED                             " -ForegroundColor Cyan
Write-Host "==========================================================================================================" -ForegroundColor Cyan
Write-Host "  IP Solicitante : " -NoNewline -ForegroundColor White
Write-Host "$RequestingIP" -ForegroundColor Green
Write-Host "  Segmento de Red: " -NoNewline -ForegroundColor White
Write-Host "$NetworkCIDR" -ForegroundColor Yellow
Write-Host "  Fecha y Hora   : $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')" -ForegroundColor Gray
Write-Host "==========================================================================================================" -ForegroundColor Cyan

# Extracción de base IP para el segmento
$baseIP = "192.168.176."
if ($NetworkCIDR -match '^(\d{1,3}\.\d{1,3}\.\d{1,3})\.') {
    $baseIP = "$($Matches[1])."
}
$rangoInicio = 1
$rangoFin = 254

# Detección del Gateway por defecto
$defaultGW = ""
try {
    $cfgGW = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -contains $RequestingIP } | Select-Object -First 1
    if ($cfgGW -and $cfgGW.DefaultIPGateway) {
        $defaultGW = $cfgGW.DefaultIPGateway[0]
    }
} catch {}
if ([string]::IsNullOrEmpty($defaultGW)) {
    $defaultGW = "${baseIP}1"
}

# Diccionario OUI para clasificación por hardware (MAC)
$ouiDB = @{
    # Relojes Biométricos
    '00:17:61' = 'Reloj biometrico'; '6C:DF:FB' = 'Reloj biometrico'; 'E0:69:95' = 'Reloj biometrico'
    'C4:2F:90' = 'Reloj biometrico'; '00:0B:82' = 'Reloj biometrico'; '2C:26:17' = 'Reloj biometrico'
    '50:13:95' = 'Reloj biometrico'
    # Fotocopiadoras / Multifuncionales corporativas
    '00:26:73' = 'Fotocopiadora'; '00:00:85' = 'Fotocopiadora'; '00:20:6B' = 'Fotocopiadora'
    '00:04:F2' = 'Fotocopiadora'; '00:17:C8' = 'Fotocopiadora'; '00:C0:EE' = 'Fotocopiadora'
    '00:00:AA' = 'Fotocopiadora'; '00:80:77' = 'Fotocopiadora'; '00:1B:A9' = 'Fotocopiadora'
    '78:8C:77' = 'Fotocopiadora'; '00:00:07' = 'Fotocopiadora'
    # Impresoras de red estándar
    '00:1E:0B' = 'Impresora de red'; '00:25:B3' = 'Impresora de red'; '3C:D9:2B' = 'Impresora de red'
    '70:5A:0F' = 'Impresora de red'; 'A4:5D:36' = 'Impresora de red'; '00:00:48' = 'Impresora de red'
    '00:26:AB' = 'Impresora de red'; '00:01:E6' = 'Impresora de red'
    # Cámaras CCTV / Vigilancia IP
    '58:38:79' = 'Camara CCTV'; '44:19:B6' = 'Camara CCTV'; 'C0:56:E3' = 'Camara CCTV'
    'B4:A3:82' = 'Camara CCTV'; '28:57:BE' = 'Camara CCTV'; '54:C4:15' = 'Camara CCTV'
    'E0:50:8B' = 'Camara CCTV'; '38:AF:29' = 'Camara CCTV'; 'B0:C5:54' = 'Camara CCTV'
    '00:40:8C' = 'Camara CCTV'; '48:EA:63' = 'Camara CCTV'
    # Switches de datos
    '00:00:0C' = 'Switch de datos'; '00:01:42' = 'Switch de datos'; '00:1C:7F' = 'Switch de datos'
    '00:1A:A1' = 'Switch de datos'; '48:8F:5A' = 'Switch de datos'; '6C:3B:6B' = 'Switch de datos'
    'CC:2D:E0' = 'Switch de datos'; 'D4:CA:6D' = 'Switch de datos'; 'D4:F5:EF' = 'Switch de datos'
    'C0:06:C3' = 'Switch de datos'
    # Routers Inalámbricos / Access Points
    '24:A4:3C' = 'Router inalambrico'; 'F0:9F:C2' = 'Router inalambrico'
    '50:C7:BF' = 'Router inalambrico'; 'E8:48:B8' = 'Router inalambrico'
    # Computadoras / Laptops / Servidores
    'F8:BC:12' = 'Computadora'; '7C:57:58' = 'Computadora'; '00:14:22' = 'Computadora'
    '18:66:DA' = 'Computadora'; 'B8:CA:3A' = 'Computadora'; 'AC:16:2D' = 'Computadora'
    'B0:4F:13' = 'Computadora'; 'A0:B3:CC' = 'Computadora'; 'E4:54:E8' = 'Computadora'
    '00:59:07' = 'Computadora'
}

# Función auxiliar de sondeo ultrarrápido de puerto TCP (timeout en ms)
$fnTestPort = {
    param([string]$ip, [int]$port, [int]$timeoutMs = 120)
    try {
        $tcpClient = New-Object System.Net.Sockets.TcpClient
        $asyncRes = $tcpClient.BeginConnect($ip, $port, $null, $null)
        if ($asyncRes.AsyncWaitHandle.WaitOne($timeoutMs, $false) -and $tcpClient.Connected) {
            $tcpClient.Close()
            return $true
        }
        $tcpClient.Close()
        return $false
    } catch { return $false }
}

# --- FASE 1: ESCANEO ASÍNCRONO MULTIHILO (PING PARALELO) ---
Write-Host "`n[*] Enviando sondeo ICMP (Ping) en paralelo a ${baseIP}${rangoInicio} al ${rangoFin}..." -ForegroundColor Yellow
$pingTasks = @()
$pingObjects = @()
foreach ($i in $rangoInicio..$rangoFin) {
    $target = "$baseIP$i"
    $p = New-Object System.Net.NetworkInformation.Ping
    $pingObjects += $p
    $pingTasks += $p.SendPingAsync($target, 300)
}
[System.Threading.Tasks.Task]::WaitAll($pingTasks)

$pingActiveMap = @{}
for ($idx = 0; $idx -lt $pingTasks.Count; $idx++) {
    if ($pingTasks[$idx].Result.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
        $pingActiveMap[$pingTasks[$idx].Result.Address.ToString()] = $true
    }
}
foreach ($p in $pingObjects) { try { $p.Dispose() } catch {} }

# --- FASE 2: CARGA DE TABLA ARP PARA CAPTURA DE MACS ---
$arpCache = @{}
try {
    Get-NetNeighbor -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object {
        if ($_.IPAddress -and $_.LinkLayerAddress -and $_.LinkLayerAddress -ne "00-00-00-00-00-00") {
            $arpCache[$_.IPAddress] = $_.LinkLayerAddress.ToUpper().Replace("-", ":")
        }
    }
} catch {}
try {
    $arpLines = arp -a
    foreach ($line in $arpLines) {
        if ($line -match '^\s*(\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3})\s+([0-9a-fA-F\-]{17})\s+(\S+)') {
            $ipEntry = $Matches[1]
            $macEntry = $Matches[2].ToUpper().Replace("-", ":")
            if (-not $arpCache.ContainsKey($ipEntry)) {
                $arpCache[$ipEntry] = $macEntry
            }
        }
    }
} catch {}

# --- FASE 3: EVALUACIÓN Y CLASIFICACIÓN DETALLADA DE CADA DIRECCIÓN IP ---
Write-Host "[+] Sondeo inicial completado. Clasificando equipos e identificando IPs libres...`n" -ForegroundColor Gray
Write-Host ("  {0,-5} {1,-16} | {2,-24} | {3,-16} | {4,-22} | {5}" -f "EST", "DIRECCION IP", "TIPO DE EQUIPO", "ASIGNACION IP", "NOMBRE DE EQUIPO", "MAC ADDRESS") -ForegroundColor White
Write-Host ("  " + ("-" * 110)) -ForegroundColor Gray

$resultados = @()
$ipsSinAsignar = @()

foreach ($i in $rangoInicio..$rangoFin) {
    $ipActual = "$baseIP$i"
    $isAlivePing = $pingActiveMap.ContainsKey($ipActual)
    $hasArp = $arpCache.ContainsKey($ipActual)

    # Si NO responde a Ping y NO existe en ARP -> IP LIBRE / SIN ASIGNAR
    if (-not $isAlivePing -and -not $hasArp) {
        $ipsSinAsignar += $ipActual
        Write-Host "  [-] " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-16}" -f $ipActual) -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-24}" -f "SIN ASIGNAR") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-16}" -f "LIBRE") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host ("{0,-22}" -f "SIN ASIGNAR") -NoNewline -ForegroundColor DarkGray
        Write-Host " | " -NoNewline -ForegroundColor DarkGray
        Write-Host "(No Asignada)" -ForegroundColor DarkGray
        continue
    }

    # IP ACTIVA: A. Obtención precisa de MAC
    $mac = if ($arpCache.ContainsKey($ipActual)) { $arpCache[$ipActual] } else { "" }
    if ([string]::IsNullOrEmpty($mac)) {
        try {
            $n = Get-NetNeighbor -IPAddress $ipActual -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
            if ($n -and $n.LinkLayerAddress) { $mac = $n.LinkLayerAddress.ToUpper().Replace("-", ":") }
        } catch {}
    }
    if ([string]::IsNullOrEmpty($mac) -and ($ipActual -eq $RequestingIP)) {
        try {
            $localNic = Get-CimInstance Win32_NetworkAdapterConfiguration | Where-Object { $_.IPAddress -contains $ipActual } | Select-Object -First 1
            if ($localNic -and $localNic.MACAddress) { $mac = $localNic.MACAddress.ToUpper().Replace("-", ":") }
        } catch {}
    }
    if ([string]::IsNullOrEmpty($mac)) { $mac = "No disponible" }

    # B. Resolución de Hostname (DNS Asíncrono no bloqueante + Fallback NetBIOS)
    $hostName = ""
    try {
        $asyncDns = [System.Net.Dns]::BeginGetHostEntry($ipActual, $null, $null)
        if ($asyncDns.AsyncWaitHandle.WaitOne(100, $false)) {
            $entry = [System.Net.Dns]::EndGetHostEntry($asyncDns)
            if ($entry -and $entry.HostName) { $hostName = $entry.HostName.Split('.')[0] }
        }
    } catch {}

    if ([string]::IsNullOrEmpty($hostName)) {
        try {
            $nbt = nbtstat -a $ipActual 2>$null
            $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
            if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                $hostName = $Matches[1].Trim()
            }
        } catch {}
    }

    # C. Verificación precisa de Asignación de IP (FIJA / ESTATICA vs DINAMICA / DHCP)
    # Se elimina la relación errónea con el comando 'arp -a'. Se verifica por adaptador real y perfiles.
    $estadoIP = "FIJA (ESTATICA)"
    if ($ipActual -eq $RequestingIP) {
        try {
            $cfgLocal = Get-CimInstance Win32_NetworkAdapterConfiguration -ErrorAction SilentlyContinue | Where-Object { $_.IPAddress -contains $ipActual } | Select-Object -First 1
            if ($cfgLocal -and $cfgLocal.DHCPEnabled) { $estadoIP = "DINAMICA (DHCP)" } else { $estadoIP = "FIJA (ESTATICA)" }
        } catch {}
    } elseif (& $fnTestPort $ipActual 135 70) {
        try {
            $nicRem = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ipActual -Filter "IPEnabled = TRUE" -ErrorAction Stop |
                Where-Object { $_.Description -notmatch "Virtual|VPN|Pseudo|Bluetooth" } | Select-Object -First 1
            if ($nicRem) {
                if ($nicRem.DHCPEnabled) { $estadoIP = "DINAMICA (DHCP)" } else { $estadoIP = "FIJA (ESTATICA)" }
                if ($mac -eq "No disponible" -and $nicRem.MACAddress) { $mac = $nicRem.MACAddress.ToUpper().Replace("-", ":") }
            }
            $sysRem = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipActual -ErrorAction SilentlyContinue
            if ($sysRem -and $sysRem.CSName) { $hostName = $sysRem.CSName }
        } catch {}
    }

    # D. Clasificación del Tipo de Dispositivo (9 Categorías Específicas)
    $tipoEquipo = ""

    # 1. Reloj Biométrico (Puertos 4370 ZK/Anviz, 5005 Suprema o firmas de host)
    if ((& $fnTestPort $ipActual 4370) -or (& $fnTestPort $ipActual 5005) -or ($hostName -match "ZK|BIO|RELOJ|ANVIZ|TIMESTATION|CONTROL-ASISTENCIA")) {
        $tipoEquipo = "Reloj biometrico"
    }
    # 2. Fotocopiadora (Multifuncionales corporativas de alto rendimiento)
    elseif (($hostName -match "RICOH|AFICIO|KONICA|BIZHUB|KYOCERA|TASKALFA|XEROX|WORKCENTRE|ALTALINK|VERSALINK|TOSHIBA|ESTUDIO|SHARP|MX-|DEVELOP|IMAGERUNNER|IR-ADV|COPIADORA|FOTOCOPIADORA") -or
            ((& $fnTestPort $ipActual 9100) -and ((& $fnTestPort $ipActual 21) -or (& $fnTestPort $ipActual 80) -or (& $fnTestPort $ipActual 443)) -and ($mac.StartsWith("00:26:73") -or $mac.StartsWith("00:00:85") -or $mac.StartsWith("00:20:6B") -or $mac.StartsWith("00:04:F2") -or $mac.StartsWith("00:17:C8") -or $mac.StartsWith("00:C0:EE") -or $mac.StartsWith("00:00:AA") -or $mac.StartsWith("00:80:77") -or $mac.StartsWith("00:1B:A9") -or $mac.StartsWith("78:8C:77")))) {
        $tipoEquipo = "Fotocopiadora"
    }
    # 3. Impresora de red (Impresoras láser o inyección estándar)
    elseif ((& $fnTestPort $ipActual 9100) -or (& $fnTestPort $ipActual 515) -or (& $fnTestPort $ipActual 631) -or ($hostName -match "PRN|PRINT|EPSON|BROTHER|HP-PRINT|LASERJET|DESKJET|PAGEWIDE|ZEBRA|SATO|IMPRESORA")) {
        $tipoEquipo = "Impresora de red"
    }
    # 4. DVR (Grabadores de Video Digital / NVR / XVR de seguridad)
    elseif (($hostName -match "DVR|NVR|XVR|HIK-NVR|DAHUA-NVR|GRABADOR|HIKVISION-NVR") -or 
            (((& $fnTestPort $ipActual 8000) -or (& $fnTestPort $ipActual 37777) -or (& $fnTestPort $ipActual 34567)) -and ($hostName -notmatch "CAM|IPC") -and (& $fnTestPort $ipActual 554))) {
        $tipoEquipo = "DVR"
    }
    # 5. Cámara CCTV (Cámaras IP, domos o tubos de videovigilancia)
    elseif ((& $fnTestPort $ipActual 554) -or (& $fnTestPort $ipActual 8899) -or ($hostName -match "CAM|IPC|CAMERA|DOMO|TUBO|BULLET|CCTV|HIK-CAM|DAHUA-CAM")) {
        $tipoEquipo = "Camara CCTV"
    }
    # 6. Router (Gateway de red, puertos de enrutamiento o router de borde)
    elseif (($ipActual -eq $defaultGW) -or (& $fnTestPort $ipActual 8291) -or ($hostName -match "ROUTER|GW|GATEWAY|MIKROTIK|FORTINET|CISCO-ROUTER|PFSENSE|OPNSENSE|EDGEROUTER|FIREWALL")) {
        $tipoEquipo = "Router"
    }
    # 7. Router Inalámbrico (Access Point / AP / WiFi Router)
    elseif ((& $fnTestPort $ipActual 8080) -or ($hostName -match "WIFI|AP-|AP_|WIRELESS|ACCESSPOINT|UNIFI|UAP|AIRMAX|TENDA|MERCUSYS")) {
        $tipoEquipo = "Router inalambrico"
    }
    # 8. Computadora (Estaciones de trabajo, PC, laptops o servidores Windows)
    elseif ((& $fnTestPort $ipActual 445) -or (& $fnTestPort $ipActual 135) -or (& $fnTestPort $ipActual 3389) -or ($hostName -match "DESKTOP|LAPTOP|PC|WIN|SRV|SERVER|WS-|HMP")) {
        $tipoEquipo = "Computadora"
    }
    # 9. Switch de datos (Switches administrables o infraestructura de distribución)
    elseif ((& $fnTestPort $ipActual 22) -or (& $fnTestPort $ipActual 23) -or (& $fnTestPort $ipActual 161) -or ($hostName -match "SW|SWITCH|SW-|CATALYST|PROCURVE|ARUBA|EDGESWITCH")) {
        $tipoEquipo = "Switch de datos"
    }
    else {
        # Búsqueda complementaria por OUI en la base de datos de fabricantes
        if ($mac.Length -ge 8) {
            $prefix = $mac.Substring(0, 8).ToUpper()
            if ($ouiDB.ContainsKey($prefix)) {
                $tipoEquipo = $ouiDB[$prefix]
            }
        }
        if ([string]::IsNullOrEmpty($tipoEquipo)) {
            $tipoEquipo = "Dispositivo de Red"
        }
    }

    if ([string]::IsNullOrEmpty($hostName)) { $hostName = "(Sin Hostname)" }

    # Guardar en resultados
    $obj = [PSCustomObject]@{
        IP         = $ipActual
        HostName   = $hostName
        Tipo       = $tipoEquipo
        Estado     = $estadoIP
        MACAddress = $mac
    }
    $resultados += $obj

    # Asignar color según el tipo de equipo
    $colorTipo = switch ($tipoEquipo) {
        "Computadora"         { "Green" }
        "Impresora de red"    { "Cyan" }
        "Fotocopiadora"       { "DarkCyan" }
        "Switch de datos"     { "White" }
        "Router"              { "Yellow" }
        "Router inalambrico"  { "DarkYellow" }
        "Reloj biometrico"    { "Magenta" }
        "DVR"                 { "DarkRed" }
        "Camara CCTV"         { "Yellow" }
        Default               { "Gray" }
    }

    Write-Host "  [+] " -NoNewline -ForegroundColor Green
    Write-Host ("{0,-16}" -f $ipActual) -NoNewline -ForegroundColor Yellow
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-24}" -f $tipoEquipo) -NoNewline -ForegroundColor $colorTipo
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-16}" -f $estadoIP) -NoNewline -ForegroundColor White
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host ("{0,-22}" -f $hostName) -NoNewline -ForegroundColor Cyan
    Write-Host " | " -NoNewline -ForegroundColor Gray
    Write-Host "$mac" -ForegroundColor Gray
}

# --- FASE 4: REPORTE FINAL TABULADO Y RESUMEN ESTADÍSTICO ---
Write-Host "`n" + ("=" * 110) -ForegroundColor White
Write-Host "                    REPORTE DE AUDITORIA: EQUIPOS DETECTADOS EN EL SEGMENTO                      " -ForegroundColor Green
Write-Host ("=" * 110) -ForegroundColor White

if ($resultados.Count -gt 0) {
    $resultados | Sort-Object { [version]$_.IP } | Format-Table -Property @{Label="IP"; Expression={$_.IP}; Width=16}, @{Label="HostName"; Expression={$_.HostName}; Width=22}, @{Label="Tipo de Dispositivo"; Expression={$_.Tipo}; Width=24}, @{Label="Asignacion"; Expression={$_.Estado}; Width=16}, @{Label="MAC Address"; Expression={$_.MACAddress}; Width=19} -AutoSize
} else {
    Write-Host "`n[!] No se detectaron equipos activos en el segmento." -ForegroundColor Red
}

Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host "RESUMEN DE EQUIPOS DETECTADOS:" -ForegroundColor Yellow
Write-Host ("-" * 80) -ForegroundColor Gray

$cPC     = ($resultados | Where-Object { $_.Tipo -eq "Computadora" }).Count
$cImp    = ($resultados | Where-Object { $_.Tipo -eq "Impresora de red" }).Count
$cFoto   = ($resultados | Where-Object { $_.Tipo -eq "Fotocopiadora" }).Count
$cSwitch = ($resultados | Where-Object { $_.Tipo -eq "Switch de datos" }).Count
$cRouter = ($resultados | Where-Object { $_.Tipo -eq "Router" }).Count
$cWiFi   = ($resultados | Where-Object { $_.Tipo -eq "Router inalambrico" }).Count
$cBio    = ($resultados | Where-Object { $_.Tipo -eq "Reloj biometrico" }).Count
$cDVR    = ($resultados | Where-Object { $_.Tipo -eq "DVR" }).Count
$cCam    = ($resultados | Where-Object { $_.Tipo -eq "Camara CCTV" }).Count
$cOtros  = ($resultados | Where-Object { $_.Tipo -eq "Dispositivo de Red" }).Count

Write-Host "  - Computadoras (PCs / Servidores):     $cPC" -ForegroundColor Green
Write-Host "  - Impresoras de Red:                   $cImp" -ForegroundColor Cyan
Write-Host "  - Fotocopiadoras / Multifuncionales:   $cFoto" -ForegroundColor DarkCyan
Write-Host "  - Switches de Datos:                   $cSwitch" -ForegroundColor White
Write-Host "  - Routers / Gateways:                  $cRouter" -ForegroundColor Yellow
Write-Host "  - Routers Inalambricos (AP / WiFi):    $cWiFi" -ForegroundColor DarkYellow
Write-Host "  - Relojes Biometricos:                 $cBio" -ForegroundColor Magenta
Write-Host "  - Grabadores DVR / NVR:                $cDVR" -ForegroundColor DarkRed
Write-Host "  - Camaras de Seguridad CCTV:           $cCam" -ForegroundColor Yellow
if ($cOtros -gt 0) {
    Write-Host "  - Otros Dispositivos de Red:           $cOtros" -ForegroundColor Gray
}
Write-Host ("-" * 80) -ForegroundColor Gray
Write-Host "  Total de Equipos Activos:              $($resultados.Count)" -ForegroundColor Green
Write-Host "  Total de IPs Libres (SIN ASIGNAR):     $($ipsSinAsignar.Count)" -ForegroundColor DarkGray
Write-Host "  Total de Direcciones Auditadas:        $($resultados.Count + $ipsSinAsignar.Count)" -ForegroundColor Cyan
Write-Host ("=" * 80) -ForegroundColor Gray

Write-Host "`n[+] Auditoria completada. Esta ventana permanece abierta para su consulta." -ForegroundColor Green
Write-Host "Presione cualquier tecla para cerrar esta ventana..." -ForegroundColor Gray
try {
    [void][System.Console]::ReadKey($true)
} catch {}
'@

                    # 3. Guardar el ejecutable de escaneo en la carpeta temporal del usuario
                    $scannerFile = Join-Path $env:TEMP "shellWil_ScanRed.ps1"
                    [System.IO.File]::WriteAllText($scannerFile, $scannerCode, [System.Text.Encoding]::UTF8)

                    # 4. Lanzamiento del proceso en NUEVA VENTANA de PowerShell independiente
                    Write-Host "  [+] Lanzando auditoria en una NUEVA VENTANA..." -ForegroundColor Green
                    Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$scannerFile`"", "-NetworkCIDR", "`"$segmentoElegido`"", "-RequestingIP", "`"$solicitanteIP`""

                    Write-Host "`n==========================================================================" -ForegroundColor Cyan
                    Write-Host "  [OK] El escaneo ha sido iniciado en una ventana independiente." -ForegroundColor Green
                    Write-Host "       Puede revisar el progreso y resultados en dicha ventana mientras" -ForegroundColor Gray
                    Write-Host "       este menu principal continua disponible para otras tareas." -ForegroundColor Gray
                    Write-Host "==========================================================================" -ForegroundColor Cyan
                    Write-Host ""
                    Read-Host "Presione ENTER para volver al menu principal..."
                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   REINICIO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 3. Validar si el equipo responde (Ping) antes de intentar el comando
                    Write-Host "`nVerificando conexion con $IPRemota" -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $IPRemota -Count 1 -Quiet) {
                        Write-Host "[OK] Equipo detectado en la red." -ForegroundColor Green
                        Write-Host "Enviando orden de reinicio forzado..." -ForegroundColor Yellow
                        
                        # 4. Ejecutar el comando de apagado
                        # /r = Reiniciar
                        # /f = Forzar cierre de apps
                        # /t 1 = Tiempo 1 segundo
                        # /m = Nombre/IP del equipo remoto
                        shutdown /r /f /t 1 /m \\$IPRemota
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "EXITO: La orden de reinicio ha sido aceptada por $IPRemota." -ForegroundColor Green
                        }
                        else {
                            Write-Host "ERROR: Acceso denegado o error de red (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                            Write-Host "Asegurese de tener permisos de Admin y que el equipo remoto acepte comandos." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "ERROR: No se pudo establecer contacto con $IPRemota." -ForegroundColor Red
                        Write-Host "El equipo esta apagado o el firewall bloquea el trafico." -ForegroundColor Gray
                    }
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   APAGADO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 3. Validar si el equipo responde (Ping) antes de intentar el comando
                    Write-Host "`nVerificando conexion con $IPRemota" -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $IPRemota -Count 1 -Quiet) {
                        Write-Host "[OK] Equipo detectado en la red." -ForegroundColor Green
                        Write-Host "Enviando orden de apagado forzado..." -ForegroundColor Yellow
                        
                        # 4. Ejecutar el comando de apagado
                        # /s = Apagar
                        # /f = Forzar cierre de apps
                        # /t 1 = Tiempo 1 segundo
                        # /m = Nombre/IP del equipo remoto
                        shutdown /s /f /t 1 /m \\$IPRemota
                        
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "EXITO: La orden de apagado ha sido aceptada por $IPRemota." -ForegroundColor Green
                        }
                        else {
                            Write-Host "ERROR: Acceso denegado o error de red (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                            Write-Host "Asegurese de tener permisos de Admin y que el equipo remoto acepte comandos." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "ERROR: No se pudo establecer contacto con $IPRemota." -ForegroundColor Red
                        Write-Host "El equipo esta apagado o el firewall bloquea el trafico." -ForegroundColor Gray
                    }


                }

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # CONFIGURACIÓN DE POLÍTICA CON MENSAJES DE ESTADO
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        
                        # Si la política es Restringida, intentamos elevarla a RemoteSigned
                        if ($politicaActual -eq "Restricted") {
                            Write-Host "Detectada politica 'Restricted'. Intentando cambiar..." -ForegroundColor Yellow
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            $nuevaPolitica = Get-ExecutionPolicy
                            Write-Host "Cambio exitoso. Politica actual de ejecucion: $nuevaPolitica" -ForegroundColor Green
                        } 
                        else {
                            # Si ya es Bypass, Unrestricted o RemoteSigned, informamos al usuario
                            Write-Host "Politica existente detectada: $politicaActual. No se requieren cambios." -ForegroundColor Cyan
                        }
                    } 
                    catch {
                        # Esta sección se activa si hay una invalidación (como el error de ámbito que tuviste)
                        $politicaEfectiva = Get-ExecutionPolicy
                        Write-Host "Nota: No se pudo modificar la politica (Scope Conflict)." -ForegroundColor Gray
                        Write-Host "Tipo de politica ejecutandose actualmente: $politicaEfectiva" -ForegroundColor White
                    }

                    # ==============================================================================
                    # 2. DEFINICIÓN DE RED Y ENTRADA DE USUARIO
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "     EXPLORADOR DE ESCRITORIO PUBLICO REMOTO  " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # ==============================================================================
                    # 3. CONSTRUCCIÓN DE RUTA Y APERTURA
                    # ==============================================================================
                    $rutaRemota = "\\$IPRemota\c$\Users\Public\Desktop"

                    Write-Host "`nIntentando conectar con: $rutaRemota..." -ForegroundColor Yellow

                    # Validamos si la ruta es accesible antes de intentar abrirla
                    if (Test-Path $rutaRemota) {
                        Write-Host "[OK] Conexion establecida. Abriendo carpeta..." -ForegroundColor Green
                        Start-Process explorer.exe -ArgumentList $rutaRemota
                    }
                    else {
                        Write-Host "ERROR: No se pudo acceder a la ruta." -ForegroundColor Red
                        Write-Host "Verifique que:" -ForegroundColor Gray
                        Write-Host "1. El equipo remoto este encendido."
                        Write-Host "2. Tenga permisos de Administrador (el recurso c$ es administrativo)."
                        Write-Host "3. Comparticion de archivos este activa en la PC remota."
                    }

                }            

                "6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE POLÍTICA CON MENSAJES DE ESTADO
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Write-Host "Detectada politica 'Restricted'. Intentando cambiar..." -ForegroundColor Yellow
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "Cambio exitoso. Politica actual: $(Get-ExecutionPolicy)" -ForegroundColor Green
                        } 
                        else {
                            Write-Host "Tipo de politica ejecutandose actualmente: $politicaActual" -ForegroundColor Cyan
                        }
                    } 
                    catch {
                        Write-Host "Nota: Usando politica de ejecucion efectiva: $(Get-ExecutionPolicy)" -ForegroundColor Gray
                    }

                    # ==============================================================================
                    # 2. ENTRADA DE USUARIO Y DEFINICIÓN DE RUTA
                    # ==============================================================================
                    Write-Host "`n==============================================" -ForegroundColor Cyan
                    Write-Host "    ACCESO A CARPETA STARTUP (Win 7 - 11)     " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $IPRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Definimos la ruta completa al menú de inicio (Carpeta de Inicio común para todos los usuarios)
                    $rutaStartUp = "\\$IPRemota\c$\ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp"

                    # ==============================================================================
                    # 3. VALIDACIÓN Y APERTURA DE LA CARPETA
                    # ==============================================================================
                    Write-Host "`nVerificando acceso a: $rutaStartUp" -ForegroundColor Yellow

                    if (Test-Path $rutaStartUp) {
                        Write-Host "[OK] Conexion exitosa. Abriendo carpeta StartUp..." -ForegroundColor Green
                        # Abre la carpeta en una nueva ventana del Explorador de Windows
                        Start-Process explorer.exe -ArgumentList $rutaStartUp
                    }
                    else {
                        Write-Host "ERROR: No se pudo acceder a la ruta." -ForegroundColor Red
                        Write-Host "Verifique permisos de Admin y que el recurso c$ esté habilitado en $IPRemota." -ForegroundColor Gray
                    }


                }
                "7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE POLÍTICA DE EJECUCIÓN
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "Politica de ejecucion activa: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Nota: Usando politica de ejecucion del sistema: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }

                    Write-Host "Reiniciar PC: shutdown /g /f /t 2" -ForegroundColor Yellow
                    Write-Host "Apagar PC: shutdown /s /f /t 5" -ForegroundColor Yellow
                    Write-Host " "

                    # ==============================================================================
                    # 2. ENTRADA DE DATOS (Equivalente a SET /P)
                    # ==============================================================================
                    Write-Host "`n--- CONEXION REMOTA PSEXEC ---" -ForegroundColor Cyan

                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString # Se oculta la clave por seguridad
                    $IPFinal = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Convertir la clave segura a texto plano para PsExec (requerido por la herramienta)
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                    $psexecPath = "C:\PSTools\PsExec.exe"

                    # ==============================================================================
                    # 3. VALIDACIÓN Y EJECUCIÓN
                    # ==============================================================================
                    if (Test-Path $psexecPath) {
                        Write-Host "`nIniciando sesion remota en $IPFinal..." -ForegroundColor Yellow
                        
                        # Argumentos: 
                        # -u Dominio\Usuario
                        # -p Clave
                        # -i Interactiva
                        # cmd (comando a ejecutar)
                        # Start-Process -FilePath $psexecPath -ArgumentList "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -i cmd" -Wait

                        # -h: Este es el parámetro crucial para ejecutar con privilegios elevados (Run as Administrator)
                        # -i: Mantiene la sesión interactiva para que veas la ventana
                        # -accepteula: Evita interrupciones de licencia

                        $argumentos = "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -h -i -accepteula cmd.exe"

                        Start-Process -FilePath $psexecPath -ArgumentList $argumentos #-Wait
                    } 
                    else {
                        Write-Host "ERROR: No se encontro PsExec.exe en $psexecPath" -ForegroundColor Red
                    }

                    Write-Host "`nSesion finalizada." -ForegroundColor Cyan

                }

                "8" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # 1. CONFIGURACIÓN DE PRIVILEGIOS
                    # ==============================================================================
                    try {
                        $politicaActual = Get-ExecutionPolicy
                        if ($politicaActual -eq "Restricted") {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction SilentlyContinue
                        }
                        Write-Host "Politica de ejecucion activa: $(Get-ExecutionPolicy)" -ForegroundColor Cyan
                    }
                    catch {
                        Write-Host "Nota: Usando politica del sistema: $(Get-ExecutionPolicy)" -ForegroundColor Gray
                    }

                    # Sugerencias visuales de comandos útiles
                    Write-Host "`n[ COMANDOS UTILES ]" -ForegroundColor Gray
                    Write-Host "Reiniciar PC: Restart-Computer -Force" -ForegroundColor Yellow
                    Write-Host "Apagar PC: Stop-Computer -Force" -ForegroundColor Yellow

                    # ==============================================================================
                    # 2. ENTRADA DE DATOS MEJORADA
                    # ==============================================================================
                    Write-Host "`n--- CONEXION REMOTA PSEXEC (POWERSHELL MODE) ---" -ForegroundColor Cyan

                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString 
                    $IPFinal = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Conversión de credencial
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                    $psexecPath = "C:\PSTools\PsExec.exe"

                    # ==============================================================================
                    # 3. EJECUCIÓN CON SOPORTE PARA AUTOCOMPLETADO
                    # ==============================================================================
                    if (Test-Path $psexecPath) {
                        Write-Host "`nAbriendo consola PowerShell en $IPFinal..." -ForegroundColor Green
                        Write-Host "Espere a que cargue el prompt remoto..." -ForegroundColor Gray

                        # -h: Parámetro esencial para solicitar privilegios elevados (High Integrity Token)
                        # -i: Permite que la sesión sea interactiva
                        # -accepteula: Omite el aviso de licencia de Sysinternals
                        # -NoExit: Mantiene la consola abierta tras cargar el perfil
                        # -ExecutionPolicy Bypass: Evita bloqueos por políticas de ejecución en la PC remota

                        $argumentos = "\\$IPFinal -u gmsantacruz\$usu -p $claTexto -h -i -accepteula powershell.exe -NoExit -ExecutionPolicy Bypass"

                        Start-Process -FilePath $psexecPath -ArgumentList $argumentos #-Wait
                    } 
                    else {
                        Write-Host "ERROR: PsExec.exe no detectado en $psexecPath" -ForegroundColor Red
                    }

                    Write-Host "`nSesion finalizada correctamente." -ForegroundColor Cyan
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "9" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    

                    Write-Host "`nSesion finalizada correctamente." -ForegroundColor Cyan
                    Read-Host "Presione ENTER para continuar..."

                }

                "9.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de red estandarizada
                    Write-Host "--- Configuracion de Energia GMSANTACRUZ ---" -ForegroundColor Cyan
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # 2. Entrada de tiempo de pantalla
                    Write-Host "`n--- Configuracion de Tiempos ---" -ForegroundColor White
                    $minutosPantalla = Read-Host "Minutos para apagar la PANTALLA (Ej. 30)"

                    # Validación de entradas numéricas
                    if ($minutosPantalla -notmatch '^\d+$') {
                        Write-Host "ERROR: El valor de minutos debe ser numerico." -ForegroundColor Red
                        Pause
                        break
                    }

                    Write-Host "`nConectando a: $ipRemota..." -ForegroundColor Yellow

                    try {
                        # Verificamos conexión básica
                        if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                            
                            $process = [wmiclass]"\\$ipRemota\root\cimv2:Win32_Process"
                            Write-Host "Aplicando configuraciones en el equipo remoto..." -ForegroundColor Magenta

                            # Definición de comandos
                            # monitor-timeout: Valor ingresado por usuario
                            # standby-timeout: 0 (Nunca)
                            $comandos = @(
                                "powercfg /change monitor-timeout-ac $minutosPantalla",
                                "powercfg /change monitor-timeout-dc $minutosPantalla",
                                "powercfg /change standby-timeout-ac 0",
                                "powercfg /change standby-timeout-dc 0"
                            )

                            $errorDetectado = $false
                            foreach ($cmd in $comandos) {
                                $resultado = $process.Create($cmd)
                                if ($resultado.ReturnValue -ne 0) {
                                    Write-Host "Fallo en: $cmd (Código: $($resultado.ReturnValue))" -ForegroundColor Red
                                    $errorDetectado = $true
                                }
                            }

                            if (-not $errorDetectado) {
                                Write-Host "`n================================================" -ForegroundColor White
                                Write-Host " ¡EXITO! Configuracion aplicada en $ipRemota" -ForegroundColor Green
                                Write-Host " Pantalla: $minutosPantalla minutos" -ForegroundColor White
                                Write-Host " Suspension: Nunca" -ForegroundColor White
                                Write-Host "================================================" -ForegroundColor White
                            }

                        }
                        else {
                            Write-Host "ERROR: El equipo $ipRemota no responde (Offline)." -ForegroundColor Red
                        }
                    }
                    catch {
                        Write-Host "ERROR CRITICO: No se pudo completar la accion." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    #Read-Host
                    
                    Read-Host "Presione ENTER para continuar..."

                }

                "10" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "MOSTRAR IMPRESORAS DISPONIBLES EN UNA PC REMOTA" -ForegroundColor Cyan

                    $computer = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($computer)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }
                    $psExecPath = "C:\PSTools\psexec.exe"

                    if (-not (Test-Path $psExecPath)) {
                        Write-Host "[-] Error: No se encontró PsExec en C:\PSTools" -ForegroundColor Red
                        return
                    }

                    if ($computer) {
                        Write-Host "[*] Consultando todas las impresoras en $computer..." -ForegroundColor Cyan

                        # Ejecutamos WMIC. Agregamos '2>$null' para ignorar el banner de PsExec
                        # El comando busca Name, Default, Network y Status
                        $rawOutput = & $psExecPath \\$computer -accepteula -s cmd /c "wmic printer get Name,Default,Network,Status /format:csv" 2>$null

                        # Encabezado
                        Write-Host "`nREPORTE DE IMPRESORAS: $computer" -ForegroundColor White
                        $formato = "{0,-45} {1,-10} {2,-10} {3,-12}"
                        Write-Host ($formato -f "NOMBRE", "RED", "ESTADO", "PREDETERMINADA")
                        Write-Host ("-" * 82)

                        $encontradas = 0

                        foreach ($line in $rawOutput) {
                            # LIMPIEZA PROFUNDA: Quitamos espacios, retornos de carro y nulos
                            $cleanLine = $line.Trim().Replace("`0", "")
                            
                            # Si la línea tiene comas (formato CSV) y no es el encabezado de WMIC
                            if ($cleanLine -match "," -and -not $cleanLine.StartsWith("Node")) {
                                $data = $cleanLine -split ","
                                
                                # Validamos que tengamos suficientes columnas
                                if ($data.Count -ge 4) {
                                    $encontradas++
                                    # Estructura WMIC CSV: [0]Node, [1]Default, [2]Name, [3]Network, [4]Status
                                    $esPredet = $data[1].Trim()
                                    $nombre = $data[2].Trim()
                                    $esRed = $data[3].Trim()
                                    $estado = $data[4].Trim()

                                    $txtRed = "Local"
                                    if ($esRed -eq "TRUE") {
                                        $txtRed = "SI"
                                    }
                                    $txtPredet = ""
                                    if ($esPredet -eq "TRUE") {
                                        $txtPredet = "<-- PREDET."
                                    }

                                    Write-Host ($formato -f $nombre, $txtRed, $estado, $txtPredet)
                                }
                            }
                        }

                        if ($encontradas -eq 0) {
                            Write-Host "[-] No se detectaron impresoras o hubo un problema de conexión." -ForegroundColor Yellow
                            Write-Host "[!] Verifique que el firewall permita SMB (Puerto 445) y WMI en la PC remota." -ForegroundColor Gray
                        }
                        else {
                            Write-Host "`n[*] Total de impresoras encontradas: $encontradas" -ForegroundColor Green
                        }
                    }

                    Read-Host "Presione ENTER para continuar..."

                }

                "10.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # ==============================================================================
                    # SCRIPT: CONSULTA DE IMPRESORAS REMOTAS CON AUTO-ACTIVACIÓN DE SERVICIO
                    # Objetivo: Obtener modelo, fabricante, puerto y estado de impresoras de un usuario
                    # Compatibilidad: Windows 7, 8.1, 10 y 11 (PC de Escritorio)
                    # ==============================================================================

                    function Mostrar-ImpresorasUsuarioRemoto {
                        param (
                            [string]$ip,
                            [string]$usuarioTarget
                        )

                        Write-Host ''
                        Write-Host '========================================================================' -ForegroundColor Yellow
                        Write-Host '             INSPECCIONANDO IMPRESORAS EN EL EQUIPO REMOTO              ' -ForegroundColor Yellow
                        Write-Host '========================================================================' -ForegroundColor Yellow

                        # 1. VERIFICACIÓN Y AUTO-ACTIVACIÓN DEL SERVICIO REMOTEREGISTRY
                        Write-Host ' -> Verificando estado del servicio "Registro Remoto"...' -ForegroundColor Cyan
                        try {
                            $servicioReg = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='RemoteRegistry'" -ErrorAction Stop
                            
                            if ($servicioReg.StartMode -eq 'Disabled') {
                                Write-Host '    [!] El servicio estaba DESHABILITADO. Cambiando a Automatico...' -ForegroundColor DarkYellow
                                $null = $servicioReg.ChangeStartMode('Automatic')
                                Start-Sleep -Milliseconds 500
                            }
                            
                            if ($servicioReg.State -ne 'Running') {
                                Write-Host '    [!] El servicio estaba DETENIDO. Iniciando servicio remotamente...' -ForegroundColor DarkYellow
                                $null = $servicioReg.StartService()
                                Start-Sleep -Seconds 2
                            }
                            Write-Host ' -> Servicio "Registro Remoto" ACTIVO y operando.' -ForegroundColor Green
                        }
                        catch {
                            Write-Host ' [!] ERROR CRÍTICO: No se pudo verificar o iniciar el servicio "RemoteRegistry".' -ForegroundColor Red
                            Write-Host '     Asegurese de estar ejecutando PowerShell como Administrador.' -ForegroundColor DarkYellow
                            Write-Host '========================================================================' -ForegroundColor Yellow
                            return
                        }

                        # 2. CONEXIÓN AL REGISTRO REMOTO PARA BUSCAR EL SID DEL USUARIO
                        try {
                            $reg = [Microsoft.Win32.RegistryKey]::OpenRemoteBaseKey('Users', $ip)
                            
                            $userSID = $null
                            $subKeys = $reg.GetSubKeyNames()
                            
                            foreach ($key in $subKeys) {
                                if ($key -match '^S-1-5-21-') {
                                    try {
                                        $objSID = New-Object System.Security.Principal.SecurityIdentifier($key)
                                        $resolvedUser = $objSID.Translate([System.Security.Principal.NTAccount])
                                        if ($resolvedUser.Value -match $usuarioTarget) {
                                            $userSID = $key
                                            break
                                        }
                                    }
                                    catch { continue }
                                }
                            }

                            if (-not $userSID) {
                                Write-Host " [!] Error: No se encontro perfil o sesion activa para el usuario '$usuarioTarget'." -ForegroundColor Red
                                Write-Host '     El usuario debe haber iniciado sesion al menos una vez en esta PC.' -ForegroundColor DarkYellow
                                $reg.Close()
                                Write-Host '========================================================================' -ForegroundColor Yellow
                                return
                            }

                            # 3. LEER LA IMPRESORA PREDETERMINADA DEL USUARIO
                            $pathPredeterminada = "$userSID\Software\Microsoft\Windows NT\CurrentVersion\Windows"
                            $keyWindows = $reg.OpenSubKey($pathPredeterminada)
                            $deviceString = $null
                            if ($keyWindows) {
                                $deviceString = $keyWindows.GetValue('Device')
                            }
                            $nombrePredeterminada = ''
                            if ($deviceString) {
                                $nombrePredeterminada = ($deviceString -split ',')[0]
                            }
                            if ($keyWindows) { $keyWindows.Close() }

                            # 4. CONSULTAR IMPRESORAS VÍA WMI (Compatible desde Windows 7)
                            $wmiImpresoras = Get-WmiObject -Class Win32_Printer -ComputerName $ip -ErrorAction SilentlyContinue

                            if (-not $wmiImpresoras) {
                                Write-Host ' [!] No se pudieron extraer las impresoras del sistema a traves de WMI.' -ForegroundColor Red
                                $reg.Close()
                                Write-Host '========================================================================' -ForegroundColor Yellow
                                return
                            }

                            # 5. PROCESAR E IMPRIMIR LA TABLA DE DATOS PUNTUALES
                            Write-Host ''
                            $resultadoTabla = foreach ($impresora in $wmiImpresoras) {
                                
                                # Clasificación del estado "Predeterminado"
                                $esPredeterminada = 'No'
                                if ($impresora.Name -eq $nombrePredeterminada) {
                                    $esPredeterminada = 'PREDETERMINADO'
                                }

                                # Identificación simplificada de Fabricantes basado en el Driver
                                $fabricante = 'Generico / Virtual'
                                if ($impresora.DriverName -match 'HP|Hewlett') { $fabricante = 'HP' }
                                elseif ($impresora.DriverName -match 'Epson') { $fabricante = 'Epson' }
                                elseif ($impresora.DriverName -match 'Canon') { $fabricante = 'Canon' }
                                elseif ($impresora.DriverName -match 'Brother') { $fabricante = 'Brother' }
                                elseif ($impresora.DriverName -match 'Ricoh') { $fabricante = 'Ricoh' }
                                elseif ($impresora.DriverName -match 'Zebra') { $fabricante = 'Zebra' }
                                else { $fabricante = ($impresora.DriverName -split ' ')[0] }

                                # Estado operacional puntual (Activo / No Activo)
                                $estadoActivo = 'Activo'
                                if ($impresora.DetectedErrorState -ne 0 -or $impresora.PrinterStatus -eq 1 -or $impresora.WorkOffline) {
                                    $estadoActivo = 'No Activo'
                                }

                                # AJUSTE: Mapeo ordenado incluyendo el Nombre/Modelo de la impresora
                                New-Object PSObject -Property @{
                                    'Nombre / Modelo' = $impresora.Name
                                    'Fabricante'      = $fabricante
                                    'Predeterminado'  = $esPredeterminada
                                    'Puerto'          = $impresora.PortName
                                    'Estado'          = $estadoActivo
                                } | Select-Object 'Nombre / Modelo', Fabricante, Predeterminado, Puerto, Estado
                            }

                            # Mostrar tabla organizada de forma limpia y ajustada automáticamente al ancho
                            $resultadoTabla | Format-Table -AutoSize
                            $reg.Close()

                        }
                        catch [UnauthorizedAccessException] {
                            Write-Host ' [!] ERROR DE PRIVILEGIOS: Acceso denegado al registro remoto.' -ForegroundColor Red
                            Write-Host '     Asegurese de que su cuenta tenga permisos de administrador en la PC destino.' -ForegroundColor DarkYellow
                        }
                        catch {
                            Write-Host ' [!] ERROR INESPERADO al comunicarse con la base del registro de la PC remota.' -ForegroundColor Red
                        }
                        Write-Host '========================================================================' -ForegroundColor Yellow
                    }

                    # --- Bloque de Control / Ejecución Inicial ---
                    Write-Host '--- Monitor de Impresoras GMSANTACRUZ ---' -ForegroundColor Cyan
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) {
                        Write-Host 'Operacion cancelada.' -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }
                    $fullIP = $ipRemota
                    Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                            
                    try {
                        # 3. Ejecución optimizada de quser (query user)
                        $resultado = quser /server:$fullIP 2>&1

                        if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                            Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                        }
                        elseif ($resultado -like "*Error*") {
                            Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                            Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                        }
                        else {
                            $resultado | Where-Object { $_.Trim() -ne "" }
                        }
                    }
                    catch {
                        Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                    }

                    Write-Host ""
                    Write-Host '========================================================================' -ForegroundColor Yellow
                    $usuarioInput = Read-Host 'Ingrese el NOMBRE DE USUARIO de dominio'

                    if ([string]::IsNullOrEmpty($usuarioInput)) {
                        Write-Host 'ERROR: El nombre de usuario no puede estar vacio.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        break
                    }

                    Write-Host ''
                    Write-Host "Verificando enlace de red con $ipRemota..." -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                        Mostrar-ImpresorasUsuarioRemoto -ip $ipRemota -usuarioTarget $usuarioInput
                    }
                    else {
                        Write-Host "ERROR: El equipo $ipRemota se encuentra fuera de linea (Offline)." -ForegroundColor Red
                    }

                    Write-Host ''                    
            
                }

                "10.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos
                    $targetIP = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($targetIP)) {
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    if ($true) {
                        Write-Host "`n--- Filtrando Impresoras Fisicas en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Obtención de datos WMI
                            $printers = Get-WmiObject -Class Win32_Printer -ComputerName $targetIP -ErrorAction Stop

                            if ($printers) {
                                # 3. Filtrado y Procesamiento
                                $reporte = $printers | ForEach-Object {
                                    # Filtro para ignorar impresoras virtuales comunes
                                    if ($_.Name -notmatch "PDF|XPS|OneNote|Microsoft|Send To|Fax") {
                                        
                                        # Determinación de estado (Online/Offline)
                                        $estado = "Conectado"
                                        if ($_.WorkOffline -eq $true -or $_.PrinterStatus -eq 7) { 
                                            $estado = "Sin Conexion" 
                                        }

                                        # Construcción del objeto de salida
                                        $fabricante = $_.DriverName
                                        if ($_.DriverName -match ' ') {
                                            $fabricante = $_.DriverName.Split(' ')[0]
                                        }
                                        $predeterminada = ""
                                        if ($_.Default) {
                                            $predeterminada = "  [ACTIVA]"
                                        }

                                        New-Object PSObject -Property @{
                                            Fabricante     = $fabricante
                                            Nombre         = $_.Name
                                            Estado         = $estado
                                            Predeterminada = $predeterminada
                                            Puerto         = $_.PortName
                                        } | Select-Object Fabricante, Nombre, Estado, Predeterminada, Puerto
                                    }
                                }

                                # 4. Mostrar resultados
                                if ($reporte) {
                                    $reporte | Sort-Object Estado | Format-Table -AutoSize
                                }
                                else {
                                    Write-Host "No se encontraron impresoras físicas (solo virtuales)." -ForegroundColor Cyan
                                }
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP. Verifique red y permisos." -ForegroundColor Red
                        }
                    }
            
                    else {
                        Write-Host "Entrada invalida." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan
                }

                "11" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (11.1, 11.2 o 11.3)" -ForegroundColor Yellow
                }

                "11.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Habilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    # 1. Habilitar PSRemoting sin verificación de red pública
                    try {
                        Write-Host "Iniciando servicio WinRM (PSRemoting)..." -ForegroundColor Gray
                        Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
                        Write-Host "[OK] PSRemoting habilitado localmente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ADVERTENCIA: No se pudo habilitar PSRemoting localmente." -ForegroundColor Yellow
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    # 2. Configurar ExecutionPolicy con escalamiento de ámbitos
                    try {
                        Write-Host "Estableciendo politica de ejecucion a RemoteSigned (LocalMachine)..." -ForegroundColor Gray
                        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
                        Write-Host "[OK] Politica establecida a RemoteSigned para LocalMachine." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Restriccion detectada para LocalMachine. Intentando para CurrentUser..." -ForegroundColor Yellow
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "[OK] Politica establecida a RemoteSigned para CurrentUser." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "GPO bloquea cambios de politica de ejecucion persistentes." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                            Write-Host "Intentando habilitar temporalmente para este proceso..." -ForegroundColor Cyan
                            Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                            Write-Host "[OK] Politica establecida a Bypass para el proceso actual." -ForegroundColor Green
                        }
                    }
                }

                "11.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Deshabilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    # 1. Deshabilitar PSRemoting
                    try {
                        Write-Host "Deteniendo y deshabilitando servicio WinRM..." -ForegroundColor Gray
                        Disable-PSRemoting -Force -ErrorAction Stop
                        Write-Host "[OK] PSRemoting deshabilitado localmente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ADVERTENCIA: No se pudo deshabilitar PSRemoting localmente." -ForegroundColor Yellow
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    # 2. Configurar ExecutionPolicy a Restricted
                    try {
                        Write-Host "Estableciendo politica de ejecucion a Restricted (LocalMachine)..." -ForegroundColor Gray
                        Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force -ErrorAction Stop
                        Write-Host "[OK] Politica establecida a Restricted para LocalMachine." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Restriccion detectada para LocalMachine. Intentando para CurrentUser..." -ForegroundColor Yellow
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force -ErrorAction Stop
                            Write-Host "[OK] Politica establecida a Restricted para CurrentUser." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "GPO bloquea cambios de politica de ejecucion." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                        }
                    }
                }

                "11.3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Buscando componentes de RSAT localmente..." -ForegroundColor Cyan
                    try {
                        # Importar explícitamente Dism
                        Import-Module -Name Dism -ErrorAction SilentlyContinue

                        if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                            throw "El cmdlet 'Get-WindowsCapability' no está disponible en este equipo."
                        }

                        $capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
                        if ($capabilities.Count -eq 0) {
                            Write-Host "Todos los componentes de RSAT ya estan instalados." -ForegroundColor Green
                        }
                        else {
                            Write-Host "Se encontraron $($capabilities.Count) componentes para instalar." -ForegroundColor Cyan
                            
                            # Bypass temporal de WSUS si aplica localmente
                            $regPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                            $wsusBypassed = $false
                            $originalUseWUServer = $null
                            
                            if (Test-Path $regPath) {
                                $val = Get-ItemProperty -Path $regPath -Name "UseWUServer" -ErrorAction SilentlyContinue
                                if ($val -and $val.UseWUServer -eq 1) {
                                    Write-Host "Detectado WSUS activo. Desactivando temporalmente para descargar directamente de Windows Update..." -ForegroundColor Yellow
                                    $originalUseWUServer = 1
                                    Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value 0 -Force -ErrorAction SilentlyContinue
                                    Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                                    $wsusBypassed = $true
                                }
                            }

                            try {
                                foreach ($cap in $capabilities) {
                                    Write-Host "Instalando $($cap.Name)..." -ForegroundColor Yellow
                                    try {
                                        Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                                        Write-Host "Instalado con éxito: $($cap.Name)" -ForegroundColor Green
                                    }
                                    catch {
                                        Write-Host "ERROR al instalar $($cap.Name): $($_.Exception.Message)" -ForegroundColor Red
                                    }
                                }
                            }
                            finally {
                                # Restaurar configuración original de WSUS
                                if ($wsusBypassed -and $originalUseWUServer -ne $null) {
                                    Write-Host "Restaurando configuracion original de WSUS..." -ForegroundColor Gray
                                    Set-ItemProperty -Path $regPath -Name "UseWUServer" -Value $originalUseWUServer -Force -ErrorAction SilentlyContinue
                                    Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                                }
                            }
                            Write-Host "Instalacion de RSAT completada." -ForegroundColor Green
                        }
                    }
                    catch {
                        Write-Host "Error al instalar RSAT localmente: $($_.Exception.Message)" -ForegroundColor Red
                    }
                }

                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (12.1, 12.2 o 12.3)" -ForegroundColor Yellow
                }

                "12.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        
                        Write-Host "Habilitando ejecucion remota en $ipRemota..." -ForegroundColor Cyan
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "Comando de habilitacion enviado correctamente via WMI. Esperando 5 segundos..." -ForegroundColor Green
                                Start-Sleep -Seconds 5
                            }
                            else {
                                Write-Host "Error al crear proceso via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                            }
                        }
                        else {
                            Write-Host "WMI no responde. Intentando via PsExec si esta disponible..." -ForegroundColor Yellow
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if (Test-Path $psexecPath) {
                                $arg = "\\$ipRemota -accepteula -s powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force }`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }

                "12.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $ipRemota = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($ipRemota)) { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        
                        Write-Host "Deshabilitando ejecucion remota en $ipRemota..." -ForegroundColor Cyan
                        $process = Get-WmiObject -List -ComputerName $ipRemota -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Disable-PSRemoting -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force }`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "Comando de deshabilitacion enviado correctamente via WMI. Esperando 5 segundos..." -ForegroundColor Green
                                Start-Sleep -Seconds 5
                            }
                            else {
                                Write-Host "Error al crear proceso via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                            }
                        }
                        else {
                            Write-Host "WMI no responde. Intentando via PsExec si esta disponible..." -ForegroundColor Yellow
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if (Test-Path $psexecPath) {
                                $arg = "\\$ipRemota -accepteula -s powershell.exe -NoProfile -Command `"try { Disable-PSRemoting -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force } catch { Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force }`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }

                "12.3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    $targetInput = Get-StandardIPPrompt
                    if ([string]::IsNullOrWhiteSpace($targetInput)) { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        # Determinar si es IP o Hostname directamente
                        $targetMachine = ""
                        $ipRemota = ""
                        
                        if ($targetInput -match "^[a-zA-Z]") {
                            $targetMachine = $targetInput.Trim()
                            Write-Host "Usando Nombre de Equipo proporcionado: $targetMachine" -ForegroundColor Green
                        }
                        else {
                            $ipRemota = $targetInput.Trim()
                            Write-Host "Direccion IP de destino: $ipRemota" -ForegroundColor Cyan
                            
                            Write-Host "Resolviendo nombre de equipo (Hostname) necesario para la conexion..." -ForegroundColor Cyan
                            try {
                                $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota -ErrorAction Stop
                                $targetMachine = $sys.CSName
                                Write-Host "[+] Nombre de equipo resuelto exitosamente via WMI: $targetMachine" -ForegroundColor Green
                            }
                            catch {
                                try {
                                    $targetMachine = [System.Net.Dns]::GetHostEntry($ipRemota).HostName.Split('.')[0]
                                    Write-Host "[+] Nombre de equipo resuelto via DNS: $targetMachine" -ForegroundColor Green
                                }
                                catch {
                                    try {
                                        # Intento por NetBIOS/nbtstat
                                        $nbt = nbtstat -a $ipRemota
                                        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                                        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
                                            $targetMachine = $Matches[1].Trim()
                                            Write-Host "[+] Nombre de equipo resuelto via NetBIOS: $targetMachine" -ForegroundColor Green
                                        } else {
                                            throw "No se pudo resolver via NetBIOS"
                                        }
                                    }
                                    catch {
                                        Write-Host "ADVERTENCIA: No se pudo resolver la IP a un Nombre de Equipo automaticamente." -ForegroundColor Yellow
                                        $manualHost = Read-Host "Ingrese el NOMBRE DE EQUIPO (Hostname) del equipo remoto manualmente (Deje vacio para usar IP)"
                                        if (-not [string]::IsNullOrWhiteSpace($manualHost)) {
                                            $targetMachine = $manualHost.Trim()
                                        } else {
                                            $targetMachine = $ipRemota
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ([string]::IsNullOrWhiteSpace($targetMachine)) {
                            Write-Host "ERROR: Se requiere un nombre de equipo o IP para continuar." -ForegroundColor Red
                        }
                        else {
                            # --- 1. SELECCION DE COMPONENTES RSAT ---
                            Write-Host "`n--- SELECCION DE COMPONENTES RSAT A INSTALAR ---" -ForegroundColor Yellow
                            Write-Host " [1] Paquete Esencial (Active Directory DS/LDS, DNS, DHCP, GPMC) [Recomendado - Rapido]" -ForegroundColor Cyan
                            Write-Host "     * Herramientas prioritarias para administracion de Dominio y Red" -ForegroundColor Gray
                            Write-Host " [2] Todos los componentes RSAT disponibles [Completo - Mayor tiempo]" -ForegroundColor White
                            Write-Host "     * Instala todas las herramientas de administracion remota (~18)" -ForegroundColor Gray
                            Write-Host " [3] Personalizado (Ingresar patron, ej: Rsat.ActiveDirectory* o Rsat.Dns*)" -ForegroundColor White
                            $compOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
                            if ([string]::IsNullOrWhiteSpace($compOpt)) { $compOpt = "1" }

                            $targetPatterns = @()
                            if ($compOpt -eq "2") {
                                $targetPatterns = @("Rsat.*")
                                Write-Host "[*] Criterio: Todos los componentes RSAT." -ForegroundColor Cyan
                            }
                            elseif ($compOpt -eq "3") {
                                $customPat = Read-Host "Ingrese el patron a buscar (ej: Rsat.ActiveDirectory*)"
                                if ([string]::IsNullOrWhiteSpace($customPat)) {
                                    $targetPatterns = @("Rsat.*")
                                } else {
                                    $targetPatterns = @($customPat.Trim())
                                }
                                Write-Host "[*] Criterio personalizado: $($targetPatterns -join ', ')" -ForegroundColor Cyan
                            }
                            else {
                                $targetPatterns = @(
                                    "Rsat.ActiveDirectory.DS-LDS.Tools*",
                                    "Rsat.Dns.Tools*",
                                    "Rsat.DHCP.Tools*",
                                    "Rsat.GroupPolicy.Management.Tools*"
                                )
                                Write-Host "[*] Criterio: Paquete Esencial de Administracion." -ForegroundColor Cyan
                            }

                            # --- 2. SELECCION DE AUTENTICACION ---
                            Write-Host "`n--- OPCIONES DE AUTENTICACION ---" -ForegroundColor Yellow
                            Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Integrado)"
                            Write-Host " [2] Usuario de Dominio (Active Directory - ej: DOMINIO\usuario)"
                            Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador o NOMBREPC\Administrador)"
                            $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
                            if ([string]::IsNullOrWhiteSpace($authOpt)) { $authOpt = "1" }
                            
                            $cred = $null
                            $usu = ""
                            $claTexto = ""
                            
                            if ($authOpt -eq "2") {
                                $domDefecto = $env:USERDOMAIN
                                Write-Host "Dominio detectado: $domDefecto" -ForegroundColor Cyan
                                $dom = Read-Host "Ingrese el nombre del Dominio (Presione Enter para usar '$domDefecto')"
                                if ([string]::IsNullOrWhiteSpace($dom)) { $dom = $domDefecto }
                                $usuSimple = Read-Host "Ingrese el nombre de usuario de Dominio"
                                if (-not [string]::IsNullOrWhiteSpace($usuSimple)) {
                                    $usu = "$dom\$usuSimple"
                                    $cla = Read-Host "Ingrese la contrasena del usuario" -AsSecureString
                                    $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                                }
                            }
                            elseif ($authOpt -eq "3") {
                                $usuSimple = Read-Host "Ingrese el nombre del Administrador Local (ej: Administrador)"
                                if (-not [string]::IsNullOrWhiteSpace($usuSimple)) {
                                    if ($usuSimple -notmatch "^([^\\]+)\\" -and $usuSimple -notmatch "^\.\\") {
                                        $usu = ".\$usuSimple"
                                    } else {
                                        $usu = $usuSimple
                                    }
                                    $cla = Read-Host "Ingrese la contrasena local" -AsSecureString
                                    $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                                }
                            }

                            # --- 3. SELECCION DE METODO DE CONEXION ---
                            Write-Host "`n--- METODOS DE CONEXION DISPONIBLES ---" -ForegroundColor Yellow
                            Write-Host " [1] Auto-detectar (WinRM via Tarea SYSTEM; si falla usar PsExec)" -ForegroundColor Cyan
                            Write-Host " [2] Forzar WinRM (PowerShell Remoting - Tarea SYSTEM)"
                            Write-Host " [3] Forzar PsExec (Microsoft Sysinternals - SYSTEM -s)"
                            $connOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
                            if ([string]::IsNullOrWhiteSpace($connOpt)) { $connOpt = "1" }

                            # --- 4. RUTA DE ORIGEN OFFLINE (OPCIONAL) ---
                            Write-Host "`n--- ORIGEN DE INSTALACION (OPCIONAL) ---" -ForegroundColor Yellow
                            $sourcePath = Read-Host "Ingrese ruta local o de red (Source) de archivos FOD/RSAT (Enter para descargar de Internet)"
                            if (-not [string]::IsNullOrWhiteSpace($sourcePath)) {
                                $sourcePath = $sourcePath.Trim()
                            } else {
                                $sourcePath = ""
                            }

                            # --- 5. DIAGNOSTICO DE RED Y PUERTOS ---
                            Write-Host "`n[*] Verificando conexion de red con $targetMachine..." -ForegroundColor Cyan
                            $pingOk = Test-Connection -ComputerName $targetMachine -Count 1 -Quiet
                            if ($pingOk) {
                                Write-Host "[+] Ping respondido por $targetMachine." -ForegroundColor Green
                            } else {
                                Write-Host "[-] El equipo no responde a Ping (ICMP bloqueado en firewall o equipo apagado)." -ForegroundColor Yellow
                            }

                            $port445 = $false
                            $port5985 = $false
                            
                            Write-Host "[*] Comprobando puerto 445 (SMB/PsExec)..." -ForegroundColor Yellow
                            try {
                                $tcpSMB = New-Object System.Net.Sockets.TcpClient
                                $connectionSMB = $tcpSMB.BeginConnect($targetMachine, 445, $null, $null)
                                $waitSMB = $connectionSMB.AsyncWaitHandle.WaitOne(1000, $false)
                                if ($waitSMB) {
                                    $tcpSMB.EndConnect($connectionSMB)
                                    $port445 = $true
                                    Write-Host "[+] Puerto 445 (SMB) ABIERTO." -ForegroundColor Green
                                } else {
                                    Write-Host "[-] Puerto 445 (SMB) CERRADO o bloqueado." -ForegroundColor Yellow
                                }
                                $tcpSMB.Close()
                            } catch {
                                Write-Host "[-] Error al verificar puerto 445: $($_.Exception.Message)" -ForegroundColor Red
                            }

                            Write-Host "[*] Comprobando puerto 5985 (WinRM HTTP)..." -ForegroundColor Yellow
                            try {
                                $tcpRM = New-Object System.Net.Sockets.TcpClient
                                $connectionRM = $tcpRM.BeginConnect($targetMachine, 5985, $null, $null)
                                $waitRM = $connectionRM.AsyncWaitHandle.WaitOne(1000, $false)
                                if ($waitRM) {
                                    $tcpRM.EndConnect($connectionRM)
                                    $port5985 = $true
                                    Write-Host "[+] Puerto 5985 (WinRM) ABIERTO." -ForegroundColor Green
                                } else {
                                    Write-Host "[-] Puerto 5985 (WinRM) CERRADO o bloqueado." -ForegroundColor Yellow
                                }
                                $tcpRM.Close()
                            } catch {
                                Write-Host "[-] Error al verificar puerto 5985: $($_.Exception.Message)" -ForegroundColor Red
                            }

                            # --- 6. DETERMINAR METODO A USAR ---
                            $usarWinRM = $false
                            $usarPsExec = $false

                            if ($connOpt -eq "2") {
                                $usarWinRM = $true
                            }
                            elseif ($connOpt -eq "3") {
                                $usarPsExec = $true
                            }
                            else {
                                if ($port5985) {
                                    $usarWinRM = $true
                                    Write-Host "[*] Metodo seleccionado: WinRM (Puerto 5985 abierto)." -ForegroundColor Cyan
                                }
                                elseif ($port445) {
                                    $usarPsExec = $true
                                    Write-Host "[*] Metodo seleccionado: PsExec (Puerto 445 abierto, WinRM cerrado)." -ForegroundColor Cyan
                                }
                                else {
                                    $usarWinRM = $true
                                    Write-Host "[*] Advertencia: Ningun puerto estandar respondio. Se intentara WinRM..." -ForegroundColor Yellow
                                }
                            }

                            $psexecPath = "C:\PSTools\PsExec.exe"
                            $psexecFound = $false
                            if (Test-Path $psexecPath) {
                                $psexecFound = $true
                            } else {
                                if (Test-Path ".\PsExec.exe") {
                                    $psexecPath = (Resolve-Path ".\PsExec.exe").Path
                                    $psexecFound = $true
                                } else {
                                    $where = Get-Command psexec -ErrorAction SilentlyContinue
                                    if ($where) {
                                        $psexecPath = $where.Definition
                                        $psexecFound = $true
                                    }
                                }
                            }

                            # --- 7. WORKER SCRIPT REMOTO (Contexto NT AUTHORITY\SYSTEM) ---
                            # Este script se ejecuta en la PC remota con maximos privilegios locales
                            $workerBody = @'
$logFile = "C:\Windows\Temp\Install-RSAT.log"
$statFile = "C:\Windows\Temp\Install-RSAT.status"

function Write-WorkerLog {
    param([string]$msg, [string]$type = "INFO")
    $ts = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line = "[$ts] [$type] $msg"
    Add-Content -Path $logFile -Value $line -Encoding UTF8 -Force -ErrorAction SilentlyContinue
}

try {
    "IN_PROGRESS" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    Write-WorkerLog "Iniciando instalacion remota de RSAT en contexto SYSTEM ($env:USERNAME)..." "INFO"

    # A. Verificacion y configuracion de servicios criticos
    $services = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
    foreach ($s in $services) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                $wmiSvc = Get-WmiObject -Class Win32_Service -Filter "Name='$s'" -ErrorAction SilentlyContinue
                if ($wmiSvc -and $wmiSvc.StartMode -eq "Disabled") {
                    $wmiSvc.ChangeStartMode("Manual") | Out-Null
                    Write-WorkerLog "Servicio $s cambiado de Disabled a Manual." "INFO"
                }
                if ($svc.Status -ne "Running") {
                    Start-Service -Name $s -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    Write-WorkerLog "Servicio $s iniciado." "INFO"
                }
            }
        } catch {
            Write-WorkerLog "Aviso en servicio $s: $($_.Exception.Message)" "WARN"
        }
    }

    # B. Bypass de WSUS y directiva Servicing (Descarga directa desde Microsoft Update)
    $wsusReg = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
    $servicingReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"
    $origUseWUServer = $null
    $origRepairSource = $null
    $wsusModified = $false
    $servicingModified = $false

    if ([string]::IsNullOrEmpty($offlineSource)) {
        try {
            if (Test-Path $wsusReg) {
                $p = Get-ItemProperty -Path $wsusReg -Name "UseWUServer" -ErrorAction SilentlyContinue
                if ($p -and $p.UseWUServer -eq 1) {
                    $origUseWUServer = 1
                    Set-ItemProperty -Path $wsusReg -Name "UseWUServer" -Value 0 -Force -ErrorAction SilentlyContinue
                    $wsusModified = $true
                    Write-WorkerLog "Bypass WSUS: UseWUServer establecido a 0 temporalmente." "INFO"
                }
            }

            if (-not (Test-Path $servicingReg)) {
                New-Item -Path $servicingReg -Force | Out-Null
            }
            $pServ = Get-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
            if ($pServ) {
                $origRepairSource = $pServ.RepairContentServerSource
            }
            Set-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -Value 2 -Force -ErrorAction SilentlyContinue
            Set-ItemProperty -Path $servicingReg -Name "UseWindowsUpdate" -Value 1 -Force -ErrorAction SilentlyContinue
            $servicingModified = $true
            Write-WorkerLog "Directiva Servicing configurada para descarga directa de Windows Update." "INFO"

            # Reinicio limpio de wuauserv sin saturar alertas
            Stop-Service -Name "wuauserv" -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Service -Name "wuauserv" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Write-WorkerLog "Servicio Windows Update reiniciado correctamente." "INFO"
        } catch {
            Write-WorkerLog "Aviso al configurar directivas de Windows Update: $($_.Exception.Message)" "WARN"
        }
    }

    # C. Escaneo de Componentes RSAT
    Import-Module Dism -ErrorAction SilentlyContinue
    Write-WorkerLog "Escaneando componentes RSAT pendientes..." "INFO"
    $allNotPresent = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
    
    $toInstall = @()
    foreach ($cap in $allNotPresent) {
        foreach ($pat in $targetPatterns) {
            if ($cap.Name -like $pat) {
                $toInstall += $cap
                break
            }
        }
    }

    $successCount = 0
    $failCount = 0

    if ($toInstall.Count -eq 0) {
        Write-WorkerLog "Todos los componentes solicitados ya se encuentran instalados." "INFO"
        "COMPLETED_NOTHING_TODO" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    }
    else {
        Write-WorkerLog "Se encontraron $($toInstall.Count) componentes para instalar." "INFO"
        $idx = 0
        foreach ($cap in $toInstall) {
            $idx++
            Write-WorkerLog "[$idx/$($toInstall.Count)] Iniciando instalacion de $($cap.Name)..." "START"
            try {
                if (-not [string]::IsNullOrEmpty($offlineSource)) {
                    Add-WindowsCapability -Online -Name $cap.Name -Source $offlineSource -LimitAccess -ErrorAction Stop | Out-Null
                } else {
                    Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                }

                $chk = Get-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue
                if ($chk -and $chk.State -eq "Installed") {
                    Write-WorkerLog "[$idx/$($toInstall.Count)] Instalado con EXITO: $($cap.Name)" "SUCCESS"
                    $successCount++
                } else {
                    Write-WorkerLog "[$idx/$($toInstall.Count)] No se pudo confirmar estado instalado para: $($cap.Name)" "FAIL"
                    $failCount++
                }
            } catch {
                Write-WorkerLog "[$idx/$($toInstall.Count)] ERROR al instalar $($cap.Name): $($_.Exception.Message)" "FAIL"
                $failCount++
            }
        }

        # Estado final
        if ($failCount -eq 0 -and $successCount -gt 0) {
            "COMPLETED_SUCCESS:$successCount" | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } elseif ($successCount -gt 0 -and $failCount -gt 0) {
            "COMPLETED_PARTIAL:OK=$successCount,FAIL=$failCount" | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } else {
            "COMPLETED_FAILED:$failCount" | Out-File -FilePath $statFile -Encoding UTF8 -Force
        }
    }
} catch {
    Write-WorkerLog "Error critico general: $($_.Exception.Message)" "ERROR"
    "COMPLETED_FATAL:$($_.Exception.Message)" | Out-File -FilePath $statFile -Encoding UTF8 -Force
} finally {
    # D. Restauracion de directivas originales
    Write-WorkerLog "Restaurando directivas y servicios originales..." "INFO"
    try {
        if ($wsusModified -and $origUseWUServer -ne $null) {
            Set-ItemProperty -Path $wsusReg -Name "UseWUServer" -Value $origUseWUServer -Force -ErrorAction SilentlyContinue
        }
        if ($servicingModified) {
            if ($origRepairSource -ne $null) {
                Set-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -Value $origRepairSource -Force -ErrorAction SilentlyContinue
            } else {
                Remove-ItemProperty -Path $servicingReg -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
            }
            Remove-ItemProperty -Path $servicingReg -Name "UseWindowsUpdate" -ErrorAction SilentlyContinue
        }
        Stop-Service -Name "wuauserv" -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 1
        Start-Service -Name "wuauserv" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
    } catch {}

    Write-WorkerLog "Operacion de instalacion de RSAT concluida." "DONE"
}
'@

                            # Ensamblado del worker script con parámetros incrustados
                            $patternsFormatted = ($targetPatterns | ForEach-Object { "`"$_`"" }) -join ", "
                            $workerHeader = "`$targetPatterns = @($patternsFormatted)`n`$offlineSource = `"$sourcePath`"`n"
                            $fullWorkerScript = $workerHeader + $workerBody

                            $exitoEjecucion = $false

                            # --- 8. EJECUCION VIA WINRM (TAREA PROGRAMADA SYSTEM) ---
                            if ($usarWinRM) {
                                Write-Host "`n[*] Desplegando tarea remota bajo NT AUTHORITY\SYSTEM via WinRM..." -ForegroundColor Yellow
                                if ($usu -ne "") {
                                    Write-Host "    Autenticacion: $usu" -ForegroundColor Cyan
                                } else {
                                    Write-Host "    Autenticacion: Usuario actual de Windows" -ForegroundColor Cyan
                                }

                                $initScriptBlock = {
                                    param($scriptContent)
                                    
                                    # Asegurar C:\Windows\Temp
                                    if (-not (Test-Path "C:\Windows\Temp")) {
                                        New-Item -Path "C:\Windows\Temp" -ItemType Directory -Force | Out-Null
                                    }

                                    # Limpiar logs y estado anteriores
                                    Remove-Item "C:\Windows\Temp\Install-RSAT.log" -Force -ErrorAction SilentlyContinue
                                    Remove-Item "C:\Windows\Temp\Install-RSAT.status" -Force -ErrorAction SilentlyContinue
                                    Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue

                                    # Escribir el worker script en disco
                                    [System.IO.File]::WriteAllText("C:\Windows\Temp\Install-RSAT-Worker.ps1", $scriptContent, [System.Text.Encoding]::UTF8)

                                    $taskName = "Install-RSAT-Task"
                                    try {
                                        Unregister-ScheduledTask -TaskName $taskName -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                    } catch {}

                                    $registered = $false
                                    try {
                                        $action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1"
                                        $principal = New-ScheduledTaskPrincipal -UserId "NT AUTHORITY\SYSTEM" -LogonType ServiceAccount -RunLevel Highest
                                        $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit (New-TimeSpan -Hours 2)
                                        Register-ScheduledTask -TaskName $taskName -Action $action -Principal $principal -Settings $settings -Force | Out-Null
                                        Start-ScheduledTask -TaskName $taskName | Out-Null
                                        $registered = $true
                                    }
                                    catch {
                                        # Fallback con schtasks.exe si el modulo ScheduledTasks tuviera restricciones
                                        $cmdCreate = "schtasks.exe /create /f /tn `"$taskName`" /ru `"SYSTEM`" /rl HIGHEST /tr `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1`" /sc ONCE /st 00:00"
                                        cmd.exe /c $cmdCreate 2>&1 | Out-Null
                                        cmd.exe /c "schtasks.exe /run /tn `"$taskName`"" 2>&1 | Out-Null
                                        $registered = $true
                                    }

                                    return $registered
                                }

                                try {
                                    $lanzado = $false
                                    if ($cred -ne $null) {
                                        $lanzado = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                                    } else {
                                        $lanzado = Invoke-Command -ComputerName $targetMachine -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                                    }

                                    if ($lanzado) {
                                        Write-Host "[+] Tarea iniciada en $targetMachine. Transmitiendo progreso en vivo:`n" -ForegroundColor Green
                                        
                                        $lastLine = 0
                                        $terminado = $false
                                        $maxMinutes = 35
                                        $startWait = Get-Date
                                        $finalStatus = ""

                                        $pollBlock = {
                                            param($fromIndex)
                                            $log = "C:\Windows\Temp\Install-RSAT.log"
                                            $st = "C:\Windows\Temp\Install-RSAT.status"
                                            $lines = @()
                                            $total = 0
                                            if (Test-Path $log) {
                                                try {
                                                    $all = Get-Content $log -Encoding UTF8 -ErrorAction SilentlyContinue
                                                    if ($all) {
                                                        $total = $all.Count
                                                        if ($total -gt $fromIndex) {
                                                            $lines = $all[$fromIndex..($total - 1)]
                                                        }
                                                    }
                                                } catch {}
                                            }
                                            $status = "RUNNING"
                                            if (Test-Path $st) {
                                                try {
                                                    $status = (Get-Content $st -Raw -ErrorAction SilentlyContinue).Trim()
                                                } catch {}
                                            }
                                            return @{ Lines = $lines; Total = $total; Status = $status }
                                        }

                                        while (-not $terminado) {
                                            Start-Sleep -Seconds 3
                                            
                                            $pollRes = $null
                                            try {
                                                if ($cred -ne $null) {
                                                    $pollRes = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $pollBlock -ArgumentList $lastLine -ErrorAction SilentlyContinue
                                                } else {
                                                    $pollRes = Invoke-Command -ComputerName $targetMachine -ScriptBlock $pollBlock -ArgumentList $lastLine -ErrorAction SilentlyContinue
                                                }
                                            } catch {}

                                            if ($pollRes) {
                                                $lastLine = $pollRes.Total
                                                if ($pollRes.Lines) {
                                                    foreach ($l in $pollRes.Lines) {
                                                        if ($l -match "\[SUCCESS\]") {
                                                            Write-Host "  $l" -ForegroundColor Green
                                                        }
                                                        elseif ($l -match "\[FAIL\]" -or $l -match "\[ERROR\]") {
                                                            Write-Host "  $l" -ForegroundColor Red
                                                        }
                                                        elseif ($l -match "\[START\]") {
                                                            Write-Host "  $l" -ForegroundColor Cyan
                                                        }
                                                        elseif ($l -match "\[WARN\]") {
                                                            Write-Host "  $l" -ForegroundColor Yellow
                                                        }
                                                        else {
                                                            Write-Host "  $l" -ForegroundColor Gray
                                                        }
                                                    }
                                                }

                                                if ($pollRes.Status -like "COMPLETED_*") {
                                                    $terminado = $true
                                                    $finalStatus = $pollRes.Status
                                                }
                                            }

                                            # Timeout de seguridad
                                            if (((Get-Date) - $startWait).TotalMinutes -gt $maxMinutes) {
                                                Write-Host "`n[-] Se supero el tiempo limite de espera ($maxMinutes minutos)." -ForegroundColor Red
                                                break
                                            }
                                        }

                                        # Limpieza en la PC remota
                                        $cleanupBlock = {
                                            try {
                                                Unregister-ScheduledTask -TaskName "Install-RSAT-Task" -Confirm:$false -ErrorAction SilentlyContinue | Out-Null
                                            } catch {}
                                            cmd.exe /c "schtasks.exe /delete /f /tn \`"Install-RSAT-Task\`"" 2>&1 | Out-Null
                                            Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue
                                        }
                                        try {
                                            if ($cred -ne $null) {
                                                Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $cleanupBlock -ErrorAction SilentlyContinue | Out-Null
                                            } else {
                                                Invoke-Command -ComputerName $targetMachine -ScriptBlock $cleanupBlock -ErrorAction SilentlyContinue | Out-Null
                                            }
                                        } catch {}

                                        # Evaluar resultado final
                                        if ($finalStatus -like "COMPLETED_SUCCESS*" -or $finalStatus -eq "COMPLETED_NOTHING_TODO") {
                                            $exitoEjecucion = $true
                                        }
                                        elseif ($finalStatus -like "COMPLETED_PARTIAL*") {
                                            $exitoEjecucion = $true
                                            Write-Host "`n[!] La instalacion finalizo con algunos componentes pendientes o fallidos." -ForegroundColor Yellow
                                        }
                                        else {
                                            Write-Host "`n[-] La instalacion no concluyo exitosamente ($finalStatus)." -ForegroundColor Red
                                        }
                                    }
                                }
                                catch {
                                    Write-Host "[-] Error al ejecutar via WinRM: $($_.Exception.Message)" -ForegroundColor Red
                                    if ($connOpt -eq "1" -and $port445 -and $psexecFound) {
                                        Write-Host "[*] Fallback: Intentando instalacion con PsExec como SYSTEM..." -ForegroundColor Yellow
                                        $usarPsExec = $true
                                    } else {
                                        Write-Host "Asegurese de que la PC destino tenga habilitado WinRM y el firewall permita el puerto 5985." -ForegroundColor Yellow
                                    }
                                }
                            }

                            # --- 9. EJECUCION VIA PSEXEC (-s SYSTEM) ---
                            if ($usarPsExec -and -not $exitoEjecucion) {
                                if (-not $psexecFound) {
                                    Write-Host "`n[ERROR] Se requiere PsExec pero no se encontro PsExec.exe en C:\PSTools, en el PATH, ni en la carpeta actual." -ForegroundColor Red
                                }
                                else {
                                    Write-Host "`n[*] Iniciando instalacion remota via PsExec como SYSTEM (-s -h)..." -ForegroundColor Yellow
                                    
                                    # Codificar el worker script en Base64
                                    $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullWorkerScript)
                                    $encoded = [Convert]::ToBase64String($bytes)
                                    
                                    $argsBase = "-accepteula -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                                    
                                    if ($usu -ne "") {
                                        Write-Host "Usando credenciales de: $usu" -ForegroundColor Cyan
                                        $argsFull = "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argsBase"
                                    } else {
                                        Write-Host "Usando credenciales del usuario actual..." -ForegroundColor Cyan
                                        $argsFull = "\\$targetMachine $argsBase"
                                    }

                                    try {
                                        Write-Host "Ejecutando PsExec en: $psexecPath" -ForegroundColor Gray
                                        $p = Start-Process -FilePath $psexecPath -ArgumentList $argsFull -Wait -NoNewWindow -PassThru -ErrorAction Stop
                                        if ($p -and $p.ExitCode -eq 0) {
                                            Write-Host "[OK] Proceso de instalacion finalizado via PsExec con exito!" -ForegroundColor Green
                                            $exitoEjecucion = $true
                                        } else {
                                            $code = if ($p) { $p.ExitCode } else { "N/A" }
                                            Write-Host "[-] PsExec retorno codigo de salida: $code" -ForegroundColor Red
                                        }
                                    } catch {
                                        Write-Host "[-] Error al ejecutar PsExec: $($_.Exception.Message)" -ForegroundColor Red
                                    }
                                }
                            }

                            # --- 10. MENSAJE FINAL DE ESTADO ---
                            if ($exitoEjecucion) {
                                Write-Host "`n========================================================" -ForegroundColor Green
                                Write-Host "   PROCESO DE INSTALACION DE RSAT REMOTO COMPLETADO" -ForegroundColor White -BackgroundColor DarkGreen
                                Write-Host "========================================================" -ForegroundColor Green
                            } else {
                                Write-Host "`n========================================================" -ForegroundColor Red
                                Write-Host "      ERROR: NO SE PUDO INSTALAR RSAT EN LA PC REMOTA" -ForegroundColor White -BackgroundColor DarkRed
                                Write-Host "========================================================" -ForegroundColor Red
                                Write-Host "Revise los registros en la PC remota: C:\Windows\Temp\Install-RSAT.log" -ForegroundColor Yellow
                            }

                            Write-Host " "
                            Read-Host "Presione ENTER para continuar..."
                        }
                    }
                }

                "13" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (13.1 a 13.7)" -ForegroundColor Yellow
                    Write-Host ""
                }

                "13.1" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos TEMPORALES CARPETAS"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanTempFolders -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.2" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminar Archivos Temporales ProgramData"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanProgramData -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.3" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar RAM Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanRAM -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.4" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Liberar Procesador Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanCPU -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.5" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Vaciar Papelera de Reciclaje"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanRecycleBin -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.6" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Eliminacion Avanzada (Todos los Usuarios)"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanAdvancedProfiles -ctx $ctx
                    }
                    Write-Host ""
                }

                "13.7" {
                    cabecera
                    menuOpcion "Se encuentra en: OPTIMIZACION Y LIMPIEZA REMOTA -> Limpieza General de Archivos en PC Remoto"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        Invoke-RemoteCleanGeneral -ctx $ctx
                    }
                    Write-Host ""
                }

                "14" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (14.1 o 14.2)" -ForegroundColor Yellow
                    Write-Host ""
                    Read-Host "Presione ENTER para continuar..."
                }

                "14.1" {
                    cabecera
                    menuOpcion "Se encuentra en: DEFRAGMENTACION REMOTA -> Unidad C: (Principal)"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        Ejecutar-DefragRemoto -ipRemota $ipRemota -cred $cred -driveLetter "C"
                    }
                    Write-Host ""
                }

                "14.2" {
                    cabecera
                    menuOpcion "Se encuentra en: DEFRAGMENTACION REMOTA -> Otras Unidades"
                    
                    $ctx = Get-RemoteConnectionContext
                    if ($null -ne $ctx) {
                        $ipRemota = $ctx.ComputerName
                        $cred = $ctx.Credential
                        
                        Write-Host "Obteniendo listado de unidades logicas en el equipo remoto..." -ForegroundColor Yellow
                        try {
                            if ($null -ne $cred) {
                                $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $ipRemota -Credential $cred -ErrorAction Stop
                            } else {
                                $disks = Get-WmiObject -Class Win32_LogicalDisk -Filter "DriveType = 3" -ComputerName $ipRemota -ErrorAction Stop
                            }

                            if ($disks) {
                                Write-Host "`n=== UNIDADES LOGICAS DETECTADAS EN EL EQUIPO REMOTO ===" -ForegroundColor Cyan
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                                Write-Host ("{0,-10} {1,-25} {2,-14} {3,-14}" -f "Unidad", "Etiqueta", "Tamano (GB)", "Libre (GB)") -ForegroundColor White
                                foreach ($d in $disks) {
                                    $sizeGB = [Math]::Round($d.Size / 1GB, 2)
                                    $freeGB = [Math]::Round($d.FreeSpace / 1GB, 2)
                                    $label = if ($d.VolumeName) { $d.VolumeName } else { "[Sin Etiqueta]" }
                                    Write-Host ("{0,-10} {1,-25} {2,-14} {3,-14}" -f $d.DeviceID, $label, $sizeGB, $freeGB) -ForegroundColor White
                                }
                                Write-Host "------------------------------------------------------------------`n" -ForegroundColor Gray

                                $letra = Read-Host "Ingrese la letra de la unidad a desfragmentar (ej. D)"
                                $letra = $letra.Replace(":", "").Trim().ToUpper()

                                $validLetters = $disks | ForEach-Object { $_.DeviceID.Replace(":", "").Trim().ToUpper() }
                                if ($letra -and $validLetters -contains $letra) {
                                    Ejecutar-DefragRemoto -ipRemota $ipRemota -cred $cred -driveLetter $letra
                                }
                                else {
                                    Write-Host "[ERROR] La unidad seleccionada no existe o no es valida." -ForegroundColor Red
                                }
                            }
                            else {
                                Write-Host "[ADVERTENCIA] No se detectaron unidades de disco local en el equipo remoto." -ForegroundColor Yellow
                            }
                        }
                        catch {
                            Write-Host "[ERROR] No se pudo obtener el listado de unidades: $_" -ForegroundColor Red
                        }
                    }
                    Write-Host ""
                }

                "30" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    Write-Host "`n[!] Reiniciando herramienta..." -ForegroundColor Cyan

                    # Si estamos en entorno de desarrollo, reconstruir primero
                    psReconstruirSiDesarrollo

                    # Start-Sleep -Milliseconds 500
                    Start-Sleep -Seconds 2
                    
                    # Recuperamos la ruta que guardamos en la cabecera .bat
                    $ruta = $env:SCRIPT_PATH
                    Write-Host "Ruta del Software:....... $ruta" -ForegroundColor Green
                    Start-Sleep -Seconds 3
                    
                    if ($ruta -and (Test-Path $ruta)) {
                        # Lanzamos el proceso usando CMD para que interprete el .bat correctamente
                        Start-Process cmd.exe -ArgumentList "/c `"$ruta`""
                        exit
                    }
                    else {
                        Write-Error "Error: No se pudo localizar la variable SCRIPT_PATH."
                        Pause
                    }
                }

                "31" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }

                "100" {
                    $salirSub100 = $false
                    do {
                        try {
                            cabecera
                            Write-Header " 100. CAPTURA DE PANTALLA REMOTA (SCREENSHOT) "
                            Write-Host "  1. Tomar captura usando PsExec (Recomendado)." -ForegroundColor Green
                            Write-Host "  2. Tomar captura usando Tarea Programada (Alternativa)." -ForegroundColor Yellow
                            Write-Host "  --------------------------------------------------"
                            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R"
                            Write-Header "==============================================================="
                            
                            $op100 = Read-Host "Seleccione la tarea a realizar"
                            
                            switch ($op100) {
                                "1" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 100 ;;; Opcion: $op100"
                                    
                                    Write-Host "`n--- CAPTURA DE PANTALLA REMOTA CON PSEXEC ---" -ForegroundColor Cyan
                                    
                                    $usu = Read-Host "Introduzca Usuario dominio (gmsantacruz\usuario)"
                                    $cla = Read-Host "Introduzca clave de usuario" -AsSecureString
                                    
                                    $IPFinal = Get-StandardIPPrompt
                                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                                        Write-Host "Operacion cancelada." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                                    $psexecPath = "C:\PSTools\PsExec.exe"
                                    
                                    if (-not (Test-Path $psexecPath)) {
                                        Write-Host "[-] ERROR: PsExec.exe no detectado en $psexecPath" -ForegroundColor Red
                                        Write-Host "Coloque PsExec.exe en C:\PSTools\ para habilitar esta funcion." -ForegroundColor Gray
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    # Resolución de Hostname para soporte Kerberos en Dominio
                                    $computerTarget = $IPFinal
                                    Write-Host "[*] Resolviendo Hostname de $IPFinal..." -ForegroundColor Gray
                                    try {
                                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                                        $computerTarget = $entry.HostName.Split('.')[0]
                                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                                    }
                                    catch {
                                        Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente: $IPFinal" -ForegroundColor Yellow
                                    }
                                    
                                    # 1. Detectar ID de sesión activa del usuario (con reintento de habilitación de administración remota)
                                    Write-Host "[*] Detectando sesion de usuario activa..." -ForegroundColor Gray
                                    $sessionId = $null
                                    $intentosMax = 2
                                    $intento = 0
                                    
                                    while ($null -eq $sessionId -and $intento -lt $intentosMax) {
                                        $intento++
                                        try {
                                            # Obtener ID de la sesión donde corre explorer.exe
                                            $sessionId = (Get-CimInstance -ClassName Win32_Process -Filter "Name = 'explorer.exe'" -ComputerName $computerTarget).SessionId | Select-Object -First 1
                                        }
                                        catch {
                                            Write-Host "[-] No se pudo consultar la sesion via WMI (Intento $intento de $intentosMax)." -ForegroundColor Yellow
                                        }
                                        
                                        # Fallback a qwinsta si falla WMI
                                        if ($null -eq $sessionId) {
                                            $qwinstaOut = qwinsta /server:$computerTarget
                                            foreach ($line in $qwinstaOut) {
                                                if ($line -like "*Active*") {
                                                    $parts = $line -split '\s+'
                                                    if ($parts[2] -match '^\d+$') { $sessionId = $parts[2] }
                                                    elseif ($parts[3] -match '^\d+$') { $sessionId = $parts[3] }
                                                }
                                            }
                                        }
                                        
                                        # Si falla la detección en el primer intento, ejecutamos el script de habilitación remota reutilizando la función
                                        if ($null -eq $sessionId -and $intento -lt $intentosMax) {
                                            Write-Host "`n[!] No se pudo conectar a $computerTarget. Intentando habilitar WMI/RPC/WinRM con las credenciales proporcionadas..." -ForegroundColor Magenta
                                            psHabilitarAdministracionRemota -targetInput $computerTarget -username $usu -passwordText $claTexto
                                            Write-Host "[*] Reintentando conexion..." -ForegroundColor Cyan
                                            Start-Sleep -Seconds 3
                                        }
                                    }
                                    
                                    if ($null -eq $sessionId) {
                                        Write-Host "[-] ERROR: No se pudo identificar una sesion de usuario activa en $computerTarget." -ForegroundColor Red
                                        Write-Host "Es posible que la PC este bloqueada, sin usuarios activos o inaccesible por completo." -ForegroundColor Gray
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    Write-Host "[+] Sesion activa detectada: ID $sessionId" -ForegroundColor Green
                                    
                                    # 2. Generar el script de captura temporal y el wrapper VBS para ejecución silenciosa
                                    $localTempScript = Join-Path $env:TEMP "cap_temp.ps1"
                                    $localTempVBS = Join-Path $env:TEMP "run_temp.vbs"
                                    $remoteTempDir = "\\$computerTarget\c$\Windows\Temp"
                                    $remoteTempScript = "$remoteTempDir\cap.ps1"
                                    $remoteTempVBS = "$remoteTempDir\run.vbs"
                                    
                                    $scriptCode = @"
[System.Reflection.Assembly]::LoadWithPartialName('System.Drawing') | Out-Null
[System.Reflection.Assembly]::LoadWithPartialName('System.Windows.Forms') | Out-Null
try {
    `$bounds = [System.Windows.Forms.Screen]::PrimaryScreen.Bounds
    `$bmp = New-Object System.Drawing.Bitmap `$bounds.Width, `$bounds.Height
    `$graphics = [System.Drawing.Graphics]::FromImage(`$bmp)
    `$graphics.CopyFromScreen(`$bounds.Location, [System.Drawing.Point]::Empty, `$bounds.Size)
    `$graphics.Dispose()
    `$bmp.Save('C:\Windows\Temp\screen.png', [System.Drawing.Imaging.ImageFormat]::Png)
    `$bmp.Dispose()
    Write-Output "Captura de pantalla realizada con exito."
} catch {
    Write-Error `$_.Exception.Message
}
"@

                                    # El parámetro 0 oculta la ventana por completo. True hace que wscript espere a que termine PowerShell.
                                    $vbsCode = @"
Set objShell = CreateObject("WScript.Shell")
objShell.Run "powershell.exe -NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Windows\Temp\cap.ps1", 0, True
"@
                                    
                                    try {
                                        # Escribir archivos temporales locales
                                        $scriptCode | Out-File -FilePath $localTempScript -Encoding utf8 -Force
                                        $vbsCode | Out-File -FilePath $localTempVBS -Encoding ascii -Force
                                        
                                        # Copiar archivos al host remoto
                                        if (Test-Path $remoteTempDir) {
                                            Copy-Item -Path $localTempScript -Destination $remoteTempScript -Force | Out-Null
                                            Copy-Item -Path $localTempVBS -Destination $remoteTempVBS -Force | Out-Null
                                        } else {
                                            throw "No se puede acceder al recurso compartido administrativo en $remoteTempDir"
                                        }
                                    }
                                    catch {
                                        Write-Host "[-] ERROR: Fallo al copiar los scripts de ejecucion al host remoto: $_" -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }
                                    
                                    # 3. Ejecutar de forma silenciosa mediante wscript.exe en la sesión interactiva del usuario
                                    Write-Host "[*] Ejecutando captura de pantalla de forma silenciosa..." -ForegroundColor Yellow
                                    $argumentos = "\\$computerTarget -u gmsantacruz\$usu -p $claTexto -s -i $sessionId -accepteula wscript.exe C:\Windows\Temp\run.vbs"
                                    
                                    $proc = Start-Process -FilePath $psexecPath -ArgumentList $argumentos -NoNewWindow -PassThru -Wait
                                    
                                    # 4. Recuperar la imagen, guardarla en C:\spscreen y abrirla
                                    $remoteImage = "\\$computerTarget\c$\Windows\Temp\screen.png"
                                    $localDestFolder = "C:\spscreen"
                                    
                                    if (-not (Test-Path $localDestFolder)) {
                                        New-Item -ItemType Directory -Path $localDestFolder -Force | Out-Null
                                        Write-Host "[*] Creado directorio local $localDestFolder" -ForegroundColor Gray
                                    }
                                    
                                    $localImageName = "Captura_${computerTarget}_$(Get-Date -Format 'yyyyMMdd_HHmmss').png"
                                    $localImageFullPath = Join-Path $localDestFolder $localImageName
                                    
                                    if (Test-Path $remoteImage) {
                                        Move-Item -Path $remoteImage -Destination $localImageFullPath -Force
                                        Write-Host "[+] EXITO: Captura guardada en $localImageFullPath" -ForegroundColor Green
                                        # Abrir la imagen en el visor predeterminado
                                        Start-Process $localImageFullPath
                                    } else {
                                        Write-Host "[-] ERROR: No se genero la captura. Verifique los permisos de administrador en la maquina destino." -ForegroundColor Red
                                    }
                                    
                                    # 5. Limpieza local y remota de rastros
                                    if (Test-Path $remoteTempScript) { Remove-Item -Path $remoteTempScript -Force | Out-Null }
                                    if (Test-Path $remoteTempVBS) { Remove-Item -Path $remoteTempVBS -Force | Out-Null }
                                    if (Test-Path $localTempScript) { Remove-Item -Path $localTempScript -Force | Out-Null }
                                    if (Test-Path $localTempVBS) { Remove-Item -Path $localTempVBS -Force | Out-Null }
                                    
                                    Read-Host "`nPresione ENTER para continuar..."
                                }
                                
                                "2" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 100 ;;; Opcion: $op100"
                                    Write-Host "`n--- CAPTURA DE PANTALLA REMOTA CON TAREA PROGRAMADA ---" -ForegroundColor Cyan
                                    Write-Host "[INFO] Esta funcionalidad esta en fase de planificacion y diseño." -ForegroundColor Yellow
                                    Write-Host "En proximas versiones podra ejecutarse sin requerir PsExec." -ForegroundColor Gray
                                    Read-Host "`nPresione ENTER para continuar..."
                                }
                                
                                "0" {
                                    $salirSub100 = $true
                                }
                            }
                        }
                        catch {
                            Write-Host "[-] ERROR: Ocurrio un fallo en el submenu de captura: $_" -ForegroundColor Red
                            Read-Host "Presione ENTER para continuar..."
                        }
                    } while (-not $salirSub100)
                }

                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 25: Presione ENTER para continuar..." }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
		
        finally {
            # *************************************************************************************
            # BLOQUE DE LIMPIEZA Y REFRESCO (Se ejecuta después de cada opción)
            # *************************************************************************************
            
            # 1. Liberar memoria de objetos COM/WMI/CIM colgados
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()

            # 2. Eliminar variables temporales de la sesión para evitar errores de "cadena de entrada"
            # Mantenemos variables críticas del script
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID|RemoteTarget' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.25*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.26 ******************************************************
#**********************************************************************************************************************************
