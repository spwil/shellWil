<# :
@echo off
:: Guardamos la ruta exacta antes de entrar a PowerShell, estos fragmentos son para que que powershell se ejecute en una extension .bat;; Script Híbrido (Polyglot)
set "SCRIPT_PATH=%~f0"
powershell -NoProfile -ExecutionPolicy Bypass -Command "iex ((Get-Content '%~f0') -join [Environment]::NewLine)"
exit /b
#>

<#
.SYNOPSIS
    Script de mantenimiento optimizado con correccion de sintaxis.
#>

function psLimpiarRAM {
    Write-Host "`n******* OPTIMIZACION DE RAM *******" -ForegroundColor Cyan
    
    # Definimos el codigo C# como una cadena simple para evitar el error de 'Atributo inesperado'
    $codigoC = "
        using System;
        using System.Runtime.InteropServices;
        public class RamUtil {
            [DllImport(`"psapi.dll`")]
            public static extern bool EmptyWorkingSet(IntPtr hProcess);
        }
    "

    # Cargamos el tipo solo si no existe
    if (-not ([System.Management.Automation.PSTypeName]"RamUtil").Type) {
        Add-Type -TypeDefinition $codigoC -ErrorAction SilentlyContinue
    }

    try {
        $procesos = [System.Diagnostics.Process]::GetProcesses()
        foreach ($p in $procesos) {
            if ($p.Id -gt 4) { # Omitimos Idle y System
                try {
                    [RamUtil]::EmptyWorkingSet($p.Handle) | Out-Null
                } catch {}
            }
            if ($p) { $p.Dispose() }
        }
        Write-Host "RAM optimizada correctamente." -ForegroundColor Green
    } catch {
        Write-Host "Error al optimizar." -ForegroundColor Red
    }
}

function Write-Header {
    param([string]$texto)
    
    $ancho = $texto.Length + 15
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor White -BackgroundColor DarkBlue
    Write-Host "$linea" -ForegroundColor Yellow
}

function menuOpcion {
    param([string]$texto)
    
    $ancho = $texto.Length + 5
    $linea = "=" * $ancho
    Write-Host "`n$linea" -ForegroundColor Yellow
    Write-Host "| $texto |" -ForegroundColor Black -BackgroundColor Yellow
    Write-Host "$linea" -ForegroundColor Yellow
}

#****************************************************** CABECERA ******************************************************************
function cabecera {

    Clear-Host
    $Host.UI.RawUI.WindowTitle = "Bienvenido: $env:COMPUTERNAME\$env:USERNAME ;; Copyright  spWil Derechos Reservados ;; Version 1.8.0"
    $os = Get-WmiObject Win32_OperatingSystem
    $user = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    $fecha = Get-Date -Format "dd/MM/yyyy HH:mm:ss"

    # Datos de ejecucion
    Write-Host " SO: $($os.Caption) ; Version S.O.: $($os.Version)"  -ForegroundColor Cyan
    Write-Host " Usuario: $user  ;  Fecha:   $fecha"  -ForegroundColor Cyan
    Write-Host " Ing. Wilson Yucra - Soft. Administracion y Gestion del Sistema Operativo" -ForegroundColor Cyan
    Write-Host " ------------------------------------------------------------------------"  -ForegroundColor Cyan
}
#************************************************** FIN CABECERA ******************************************************************

function psReconstruirSiDesarrollo {
    $ruta = $env:SCRIPT_PATH
    if ($ruta) {
        # Resolver el directorio padre
        $parentDir = Split-Path $ruta
        $buildScript = Join-Path $parentDir "build.ps1"
        if (Test-Path $buildScript) {
            Write-Host "`n[DEV] Entorno de desarrollo detectado." -ForegroundColor Yellow
            Write-Host "[DEV] Ejecutando build.ps1 para actualizar ShellSW.bat..." -ForegroundColor Yellow
            try {
                # Iniciar la reconstrucción de forma síncrona
                $p = Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$buildScript`"" -NoNewWindow -PassThru -Wait
                if ($p.ExitCode -eq 0) {
                    Write-Host "[DEV] Reconstruccion completa y exitosa." -ForegroundColor Green
                } else {
                    Write-Host "[DEV] Error en la reconstruccion (Codigo de salida: $($p.ExitCode))." -ForegroundColor Red
                }
            } catch {
                Write-Host "[DEV] Fallo al ejecutar el script de ensamblado: $_" -ForegroundColor Red
            }
        }
    }
}

function psHabilitarAdministracionRemota {
    param(
        [string]$targetInput,
        [string]$baseIP = "192.168.176."
    )

    # --- HABILITACIÓN REMOTA DE ADMINISTRACIÓN ---
    if ([string]::IsNullOrEmpty($targetInput)) {
        $targetInput = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o la IP completa / Nombre de Equipo"
    }
    
    if ($targetInput -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Red
        return
    }

    $ipRemota = $targetInput
    if ($targetInput -notmatch "\." -and $targetInput -notmatch "^[a-zA-Z]") {
        $ipRemota = $baseIP + $targetInput
    }

    # 1. Resolución de Hostname
    $computerTarget = $ipRemota
    Write-Host "`n[*] Resolviendo Hostname de $ipRemota para habilitar Kerberos..." -ForegroundColor Yellow
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
        $computerTarget = $entry.HostName.Split('.')[0]
        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
    }
    catch {
        $nbt = nbtstat -a $ipRemota
        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
            $computerTarget = $Matches[1].Trim()
            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
        } else {
            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
        }
    }

    # 2. Verificar conectividad
    Write-Host "`n[*] Verificando enlace con $computerTarget (Ping)..." -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $computerTarget -Count 1 -Quiet)) {
        Write-Warning "El equipo $computerTarget no responde a ping. Es posible que este apagado o tenga el firewall activo."
    }

    # 3. Construcción del Bloque de Comandos de Firewall y Servicios
    $cmds = @(
        'netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes',
        'netsh advfirewall firewall set rule group="Instrumentacion de administracion de Windows (WMI)" new enable=yes',
        'netsh advfirewall firewall set rule group="Windows Remote Management" new enable=yes',
        'netsh advfirewall firewall set rule group="Administracion remota de Windows" new enable=yes',
        'netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes',
        'netsh advfirewall firewall set rule group="Compartir archivos e impresoras" new enable=yes',
        'netsh advfirewall firewall set rule group="Remote Administration" new enable=yes',
        'netsh advfirewall firewall set rule group="Administracion remota" new enable=yes'
    )
    $cmdFirewall = $cmds -join " & "
    $cmdPS = "powershell.exe -NoProfile -Command `"try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}; try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}`""
    $fullCommand = "cmd.exe /c $cmdFirewall & $cmdPS"

    $exito = $false

    # A. Método 1: PsExec (Puerto SMB 445)
    $psexecPath = "C:\PSTools\PsExec.exe"
    $psexecFound = $false
    if (Test-Path $psexecPath) {
        $psexecFound = $true
    } else {
        $where = Get-Command psexec -ErrorAction SilentlyContinue
        if ($where) {
            $psexecPath = $where.Definition
            $psexecFound = $true
        }
    }

    if ($psexecFound) {
        Write-Host "[*] Intentando habilitacion via PsExec (SMB puerto 445)..." -ForegroundColor Yellow
        $argsList = "\\$computerTarget -accepteula -s cmd.exe /c $fullCommand"
        $p = Start-Process -FilePath $psexecPath -ArgumentList $argsList -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
        if ($p -and $p.ExitCode -eq 0) {
            Write-Host "[OK] Habilitacion remota ejecutada exitosamente via PsExec!" -ForegroundColor Green
            $exito = $true
        } else {
            $code = if ($p) { $p.ExitCode } else { "N/A" }
            Write-Host "[-] PsExec no pudo completar la accion (Codigo: $code)." -ForegroundColor Yellow
        }
    } else {
        Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
    }

    # B. Método 2: WinRM / PSRemoting (WS-Man 5985)
    if (-not $exito) {
        Write-Host "[*] Intentando habilitacion via WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
        try {
            Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                netsh advfirewall firewall set rule group="Windows Management Instrumentation (WMI)" new enable=yes
                netsh advfirewall firewall set rule group="Instrumentacion de administracion de Windows (WMI)" new enable=yes
                netsh advfirewall firewall set rule group="File and Printer Sharing" new enable=yes
                netsh advfirewall firewall set rule group="Compartir archivos e impresoras" new enable=yes
                netsh advfirewall firewall set rule group="Remote Administration" new enable=yes
                netsh advfirewall firewall set rule group="Administracion remota" new enable=yes
            } -ErrorAction Stop | Out-Null
            Write-Host "[OK] Habilitacion remota ejecutada exitosamente via WinRM!" -ForegroundColor Green
            $exito = $true
        }
        catch {
            Write-Host "[-] WinRM no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # C. Método 3: WMI (WMI 135)
    if (-not $exito) {
        Write-Host "[*] Intentando habilitacion via WMI (Win32_Process)..." -ForegroundColor Yellow
        try {
            $result = Invoke-WmiMethod -Class Win32_Process -Name Create -ComputerName $computerTarget -ArgumentList $fullCommand -ErrorAction Stop
            if ($result -and $result.ReturnValue -eq 0) {
                Write-Host "[OK] Comando enviado via WMI con exito!" -ForegroundColor Green
                $exito = $true
            } else {
                $val = if ($result) { $result.ReturnValue } else { "N/A" }
                Write-Host "[-] WMI retorno codigo de error: $val" -ForegroundColor Yellow
            }
        }
        catch {
            Write-Host "[-] WMI/RPC no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # 4. Reporte final
    if ($exito) {
        Write-Host "`n================================================" -ForegroundColor White
        Write-Host "   CONFIGURACION DE ADMINISTRACION HABILITADA" -ForegroundColor Green
        Write-Host "================================================" -ForegroundColor White
        Write-Host "El equipo remoto $computerTarget ahora deberia aceptar"
        Write-Host "consultas de red, WMI, ping y PSRemoting."
        Write-Host "================================================" -ForegroundColor White
    } else {
        Write-Host "`n================================================" -ForegroundColor White
        Write-Host "       ERROR: NO SE PUDO CONFIGURAR EL EQUIPO" -ForegroundColor Red
        Write-Host "================================================" -ForegroundColor White
        Write-Host "No se pudo conectar por WMI, WinRM ni PsExec."
        Write-Host "Asegurese de:"
        Write-Host "1. Que PsExec este en C:\PSTools\PsExec.exe"
        Write-Host "2. Que su usuario tenga privilegios de Administrador"
        Write-Host "   en el equipo remoto $computerTarget."
        Write-Host "================================================" -ForegroundColor White
    }
}

function psGestionarServiciosUpdateRemoto {
    param(
        [string]$targetInput,
        [string]$accion,
        [string]$baseIP = "192.168.176."
    )

    cabecera
    menuOpcion "ADMINISTRACION REMOTA: $accion DE SERVICIOS WINDOWS UPDATE"

    # --- ENTRADA DE DATOS ---
    if ([string]::IsNullOrEmpty($targetInput)) {
        $targetInput = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
    }
    
    if ($targetInput -eq "") {
        Write-Host "Operacion cancelada." -ForegroundColor Red
        return
    }

    $ipRemota = $targetInput
    if ($targetInput -notmatch "\." -and $targetInput -notmatch "^[a-zA-Z]") {
        $ipRemota = $baseIP + $targetInput
    }

    # 1. Resolución de Hostname
    $computerTarget = $ipRemota
    Write-Host "`n[*] Resolviendo Hostname de $ipRemota para la conexion..." -ForegroundColor Yellow
    try {
        $entry = [System.Net.Dns]::GetHostEntry($ipRemota)
        $computerTarget = $entry.HostName.Split('.')[0]
        Write-Host "[+] Hostname resuelto: $computerTarget" -ForegroundColor Green
    }
    catch {
        $nbt = nbtstat -a $ipRemota
        $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
        if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
            $computerTarget = $Matches[1].Trim()
            Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
        } else {
            Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
        }
    }

    # 2. Verificar conectividad
    Write-Host "`n[*] Verificando enlace con $computerTarget (Ping)..." -ForegroundColor Yellow
    if (-not (Test-Connection -ComputerName $computerTarget -Count 1 -Quiet)) {
        Write-Warning "El equipo $computerTarget no responde a ping. Es posible que este apagado o tenga el firewall activo."
    }

    $ip = if ($ipRemota) { $ipRemota } else { $computerTarget }

    # --- ACCION: ESTADO ---
    if ($accion -eq "Estado") {
        $serviciosConsulta = @("wuauserv", "bits", "dosvc", "TrustedInstaller", "cryptsvc")
        $estadoResultados = @()
        $queryExito = $false
        
        # Intentar consultar via WMI
        Write-Host "`n[*] Consultando estado de servicios via WMI (RPC/DCOM)..." -ForegroundColor Yellow
        try {
            foreach ($serv in $serviciosConsulta) {
                $serviceWmi = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='$serv'" -ErrorAction Stop
                if ($serviceWmi) {
                    $estadoResultados += [PSCustomObject]@{
                        Servicio    = $serv
                        Nombre      = $serviceWmi.DisplayName
                        TipoInicio  = $serviceWmi.StartMode
                        Estado      = $serviceWmi.State
                        Metodo      = "WMI"
                    }
                } else {
                    throw "Servicio no encontrado"
                }
            }
            $queryExito = $true
        }
        catch {
            Write-Host "[-] WMI no pudo consultar todos los servicios. Intentando via WinRM..." -ForegroundColor Yellow
            $estadoResultados = @() # limpiar
        }

        # Intentar consultar via WinRM
        if (-not $queryExito) {
            try {
                $remoteResults = Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                    param($servs)
                    Get-Service -Name $servs | ForEach-Object {
                        [PSCustomObject]@{
                            Servicio    = $_.Name
                            Nombre      = $_.DisplayName
                            TipoInicio  = $_.StartType.ToString()
                            Estado      = $_.Status.ToString()
                        }
                    }
                } -ArgumentList (,$serviciosConsulta) -ErrorAction Stop
                
                foreach ($res in $remoteResults) {
                    $estadoResultados += [PSCustomObject]@{
                        Servicio    = $res.Servicio
                        Nombre      = $res.Nombre
                        TipoInicio  = $res.TipoInicio
                        Estado      = $res.Estado
                        Metodo      = "WinRM"
                    }
                }
                $queryExito = $true
            }
            catch {
                Write-Host "[-] WinRM no disponible para consulta. Intentando via PsExec..." -ForegroundColor Yellow
                $estadoResultados = @() # limpiar
            }
        }

        # Intentar consultar via PsExec
        if (-not $queryExito) {
            # Localizar PsExec
            $psexecPath = "C:\PSTools\PsExec.exe"
            $psexecFound = $false
            if (Test-Path $psexecPath) { $psexecFound = $true }
            else {
                if (Test-Path ".\PsExec.exe") { $psexecPath = ".\PsExec.exe"; $psexecFound = $true }
                else {
                    $where = Get-Command psexec -ErrorAction SilentlyContinue
                    if ($where) { $psexecPath = $where.Definition; $psexecFound = $true }
                }
            }

            if ($psexecFound) {
                try {
                    foreach ($serv in $serviciosConsulta) {
                        $output = & $psexecPath \\$computerTarget -accepteula -h -s cmd.exe /c "sc query $serv & sc qc $serv" 2>$null
                        
                        $state = "Desconocido"
                        $startMode = "Desconocido"
                        
                        foreach ($line in $output) {
                            if ($line -match "STATE\s*:\s*\d+\s+([A-Z_]+)") {
                                $state = $Matches[1]
                            }
                            if ($line -match "START_TYPE\s*:\s*\d+\s+([A-Z_]+)") {
                                $startMode = $Matches[1]
                            }
                        }

                        $estadoResultados += [PSCustomObject]@{
                            Servicio    = $serv
                            Nombre      = $serv # fallback
                            TipoInicio  = $startMode
                            Estado      = $state
                            Metodo      = "PsExec (sc)"
                        }
                    }
                    $queryExito = $true
                }
                catch {
                    Write-Host "[-] PsExec fallo al consultar." -ForegroundColor Red
                }
            }
        }

        # Mostrar resultados
        if ($queryExito -and $estadoResultados.Count -gt 0) {
            Write-Host "`n==========================================================================" -ForegroundColor White
            Write-Host "          ESTADO DE SERVICIOS WINDOWS UPDATE EN: $computerTarget" -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor White
            
            # Encabezado de la tabla
            Write-Host ("  {0,-18} {1,-18} {2,-15} {3,-15}" -f "Servicio", "Tipo de Inicio", "Estado Actual", "Metodo")
            Write-Host "  ------------------------------------------------------------------------"
            
            foreach ($res in $estadoResultados) {
                $color = if ($res.Estado -match "RUNNING|Running|RUN") { "Green" } else { "Yellow" }
                
                # Imprimir con colores para el estado
                Write-Host "  " -NoNewline
                Write-Host ("{0,-18}" -f $res.Servicio) -NoNewline
                Write-Host ("{0,-18}" -f $res.TipoInicio) -NoNewline
                Write-Host ("{0,-15}" -f $res.Estado) -ForegroundColor $color -NoNewline
                Write-Host ("{0,-15}" -f $res.Metodo)
            }
            Write-Host "==========================================================================`n" -ForegroundColor White
        } else {
            Write-Host "`n========================================================" -ForegroundColor Red
            Write-Host "         ERROR AL CONSULTAR EL ESTADO DE SERVICIOS" -ForegroundColor White -BackgroundColor DarkRed
            Write-Host "========================================================" -ForegroundColor Red
            Write-Host "No se pudo conectar por WMI, WinRM ni PsExec en $computerTarget."
        }
        return
    }

    # --- ACCIONES: HABILITAR / DESHABILITAR ---
    if ($accion -eq "Habilitar") {
        $serviciosConfig = @(
            @{ Name = "wuauserv"; StartMode = "Automatic"; ScStart = "auto"; Action = "Start" },
            @{ Name = "bits"; StartMode = "Manual"; ScStart = "demand"; Action = "Start" },
            @{ Name = "dosvc"; StartMode = "Manual"; ScStart = "demand"; Action = "Start" },
            @{ Name = "TrustedInstaller"; StartMode = "Manual"; ScStart = "demand"; Action = "None" },
            @{ Name = "cryptsvc"; StartMode = "Automatic"; ScStart = "auto"; Action = "Start" }
        )
    } else {
        $serviciosConfig = @(
            @{ Name = "wuauserv"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "bits"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "dosvc"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" },
            @{ Name = "TrustedInstaller"; StartMode = "Disabled"; ScStart = "disabled"; Action = "Stop" }
        )
    }

    $exito = $false

    # A. Método 1: WMI (WMI 135) - Muy compatible sin WinRM
    Write-Host "`n[*] Intentando configurar servicios via WMI (RPC/DCOM)..." -ForegroundColor Yellow
    $wmiExito = $true
    foreach ($sConfig in $serviciosConfig) {
        $serv = $sConfig.Name
        $mode = $sConfig.StartMode
        $act = $sConfig.Action
        
        try {
            $serviceWmi = Get-WmiObject -Class Win32_Service -ComputerName $ip -Filter "Name='$serv'" -ErrorAction Stop
            if ($serviceWmi) {
                # Cambiar StartMode
                $resMode = $serviceWmi.ChangeStartMode($mode).ReturnValue
                # Cambiar Estado
                $resAct = 0
                if ($act -eq "Start") {
                    $resAct = $serviceWmi.StartService().ReturnValue
                } elseif ($act -eq "Stop") {
                    $resAct = $serviceWmi.StopService().ReturnValue
                }
                
                # Validar éxito considerando códigos de retorno especiales en WMI:
                # ChangeStartMode: 0 = Éxito. (Para dosvc a veces falla con 2 [Acceso Denegado] pero se corrige por WinRM/PsExec).
                # StartService: 0 = Éxito, 10 = Ya iniciado (también éxito para nuestro propósito).
                # StopService: 0 = Éxito, 5 = Detenido/No acepta control, 6 = No activo (también éxito).
                $isModeOk = ($resMode -eq 0)
                $isActOk = $false
                
                if ($act -eq "Start") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 10)
                } elseif ($act -eq "Stop") {
                    $isActOk = ($resAct -eq 0 -or $resAct -eq 5 -or $resAct -eq 6)
                } else {
                    $isActOk = $true # Acción "None"
                }

                if ($isModeOk -and $isActOk) {
                    Write-Host " -> Servicio ${serv}: Modo=$mode, Accion=$act [OK]" -ForegroundColor Green
                } else {
                    $wmiExito = $false
                    # Cambiamos a color amarillo para advertir que requiere fallback, sin asustar al usuario con un error rojo fatal
                    Write-Host " -> Servicio ${serv}: Requiere fallback (ModoRes=$resMode, ActRes=$resAct)." -ForegroundColor Yellow
                }
            } else {
                $wmiExito = $false
                Write-Host " -> Servicio ${serv}: No encontrado via WMI." -ForegroundColor Yellow
            }
        }
        catch {
            $wmiExito = $false
            Write-Host " -> Servicio ${serv}: Error de conexion WMI." -ForegroundColor Yellow
        }
    }

    if ($wmiExito) {
        $exito = $true
    }

    # B. Método 2: WinRM / PSRemoting (WinRM 5985)
    if (-not $exito) {
        Write-Host "`n[*] WMI no completo todas las configuraciones de forma directa. Intentando via WinRM (PowerShell Remoting)..." -ForegroundColor Yellow
        try {
            Invoke-Command -ComputerName $computerTarget -ScriptBlock {
                param($config)
                foreach ($s in $config) {
                    $name = $s.Name
                    $mode = $s.StartMode
                    $act = $s.Action
                    
                    Set-Service -Name $name -StartupType $mode -ErrorAction SilentlyContinue
                    if ($act -eq "Start") {
                        Start-Service -Name $name -ErrorAction SilentlyContinue
                    } elseif ($act -eq "Stop") {
                        Stop-Service -Name $name -Force -ErrorAction SilentlyContinue
                    }
                }
            } -ArgumentList (,$serviciosConfig) -ErrorAction Stop
            Write-Host "[OK] Servicios configurados exitosamente via WinRM!" -ForegroundColor Green
            $exito = $true
        }
        catch {
            Write-Host "[-] WinRM no esta disponible en ${computerTarget}: $($_.Exception.Message)" -ForegroundColor Yellow
        }
    }

    # C. Método 3: PsExec (SMB 445)
    if (-not $exito) {
        Write-Host "`n[*] WinRM no disponible. Intentando via PsExec (SMB)..." -ForegroundColor Yellow
        
        $psexecPath = "C:\PSTools\PsExec.exe"
        $psexecFound = $false
        if (Test-Path $psexecPath) {
            $psexecFound = $true
        } else {
            if (Test-Path ".\PsExec.exe") {
                $psexecPath = ".\PsExec.exe"
                $psexecFound = $true
            } else {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) {
                    $psexecPath = $where.Definition
                    $psexecFound = $true
                }
            }
        }

        if ($psexecFound) {
            $psExito = $true
            foreach ($sConfig in $serviciosConfig) {
                $serv = $sConfig.Name
                $scMode = $sConfig.ScStart
                $act = $sConfig.Action
                
                # Configurar StartupType
                $argsConfig = "\\$computerTarget -accepteula -s cmd.exe /c sc config $serv start= $scMode"
                $pConfig = Start-Process -FilePath $psexecPath -ArgumentList $argsConfig -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                
                # Iniciar o detener
                $argsAct = ""
                if ($act -eq "Start") {
                    $argsAct = "\\$computerTarget -accepteula -s cmd.exe /c sc start $serv"
                } elseif ($act -eq "Stop") {
                    $argsAct = "\\$computerTarget -accepteula -s cmd.exe /c sc stop $serv"
                }
                
                if ($argsAct -ne "") {
                    Start-Process -FilePath $psexecPath -ArgumentList $argsAct -Wait -NoNewWindow -ErrorAction SilentlyContinue | Out-Null
                }
                
                if ($pConfig -and $pConfig.ExitCode -eq 0) {
                    Write-Host " -> Servicio $serv configurado via PsExec [OK]" -ForegroundColor Green
                } else {
                    $psExito = $false
                    $code = if ($pConfig) { $pConfig.ExitCode } else { "N/A" }
                    Write-Host " -> Error al configurar $serv via PsExec (Codigo: $code)." -ForegroundColor Red
                }
            }
            if ($psExito) {
                $exito = $true
            }
        } else {
            Write-Host "[-] PsExec.exe no detectado en C:\PSTools ni en el PATH. Omitiendo." -ForegroundColor Gray
        }
    }

    # 4. Reporte final
    if ($exito) {
        Write-Host "`n========================================================" -ForegroundColor Green
        Write-Host "   SERVICIOS WINDOWS UPDATE CONFIGURADOS CON EXITO" -ForegroundColor White -BackgroundColor DarkGreen
        Write-Host "========================================================" -ForegroundColor Green
        Write-Host "La accion de '$accion' se ejecuto correctamente."
    } else {
        Write-Host "`n========================================================" -ForegroundColor Red
        Write-Host "        ERROR AL CONFIGURAR LOS SERVICIOS REMOTOS" -ForegroundColor White -BackgroundColor DarkRed
        Write-Host "========================================================" -ForegroundColor Red
        Write-Host "No se pudo conectar por WMI, WinRM ni PsExec en $computerTarget."
    }
}

#******************************************************** SUB MENU.20 *************************************************************
#**********************************************************************************************************************************

function psSubMenu20 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "Opcion  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "1. Informacion de la MEMORIA RAM."
            Write-Host "2. Informacion del DISCO DURO."
            Write-Host "  2.1. Capacidad y tipo de DISCO DURO."
            Write-Host "3. Mostrar Unidades Logicas del DISCO DURO."
            Write-Host "4. Aplicaciones que se INICIAN con el SISTEMA OPERATIVO."
            Write-Host "5. Mostrar Errores con aplicaciones en el SISTEMA OPERATIVO."
            Write-Host "6. Mostrar informacion del BIOS."
            Write-Host "  6.1. Modo de Instalacion de Windows Legacy o UEFI."
            Write-Host "7. Mostrar informacion de la PC HARDWARE."
            Write-Host "8. Propiedades del Sistema Operativo (SYSTEMINFO)."
            Write-Host "  8.1. Mostrar Version de Windows."
            Write-Host "  8.2. Mostrar Version de Windows."
            Write-Host "  8.3. Mostrar Version de Windows Script Host."
            Write-Host "  8.4. Mostrar Version WinVer."
            Write-Host "******************************************************************************************"
            Write-Host "9. Escaneo de archivos protegidos del S.O. - Revision Rapida. (sfc /scannow)."
            Write-Host "10. Escanea danios en almacen de componentes "DISM 1" - Dism.exe /Online /Cleanup-Image /ScanHealth"
            Write-Host "11. Comprobacion RAPIDA si imagen esta marcada como daniado "DISM 2" - DISM /Online /Cleanup-Image /CheckHealth"
            Write-Host "12. Si es posible realiza operacion de reparacion automatica "DISM 3" - DISM /Online /Cleanup-Image /RestoreHealth"
            Write-Host "13. Limpia los componentes reemplazados "DISM 4" - Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
            Write-Host "14. Revision Exhaustivo "ANALISIS PROFUNDO" (dism) - Escaneo, reparacion, limpieza y verificacion"
            Write-Host "******************************************************************************************"
            Write-Host "17. Listar Usuarios Windows"
            Write-Host "18. Recursos Compartidos de Windows"
            Write-Host "19. Todo sobre format HDD y SDD"
            Write-Host "  19.1 Formateo y verificacion  de sectores: format X: /fs:ntfs /p:1" -ForegroundColor Cyan
            Write-Host "  19.2 Formateo formateo rapido NTFS: format.com $letraLimpia /fs:ntfs /q" -ForegroundColor Cyan
            Write-Host "  19.3 Formateo formateo rapido FAT32: format.com $letraLimpia /fs:fat32 /q" -ForegroundColor Cyan
            Write-Host "  19.4 Formateo formateo rapido exFAT: format.com $letraLimpia /fs:exfat /q" -ForegroundColor Cyan
            Write-Host "21. Preparar Dipositivo Externo para instalacion y/o Recuperacion"
            Write-Host "  21.1 USB externo para instalacion de S.O. en MBR-Legacy - Win7 o superior - SIN BootSect" 
            Write-Host "  21.2 USB externo para instalacion de S.O. en MBR-Legacy - Win7 o superior - CON BootSect"
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=============================================================================="
            
            $op = Read-Host "Seleccione la tarea a realizar"

            switch ($op) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DE MEMORIA RAM *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Obtener datos de hardware (Capa física)
                    $physicalMem = Get-WmiObject Win32_PhysicalMemory
                    $memArray = Get-WmiObject -Class Win32_PhysicalMemoryArray
                    # 2. Obtener datos del Sistema Operativo (Uso en tiempo real)
                    $osMem = Get-WmiObject Win32_OperatingSystem
                    $memTotal = [Math]::Round($osMem.TotalVisibleMemorySize / 1MB, 2)
                    $memLibre = [Math]::Round($osMem.FreePhysicalMemory / 1MB, 2)
                    $memEnUso = [Math]::Round($memTotal - $memLibre, 2)
                    $porcentajeUso = [Math]::Round(($memEnUso / $memTotal) * 100, 1)

                    # Función para traducir el tipo de memoria
                    function Get-MemoryType ($type, $speed) {
                        switch ($type) {
                            20 { return "DDR" }
                            21 { return "DDR2" }
                            24 { return "DDR3" }
                            26 { return "DDR4" }
                            34 { return "DDR5" }
                            0 {
                                # Si es 0, intentamos adivinar por la velocidad (MHz)
                                if ($speed -ge 4800) { return "DDR5 (Estimado)" }
                                if ($speed -ge 2133) { return "DDR4 (Estimado)" }
                                if ($speed -ge 1333) { return "DDR3 (Estimado)" }
                                return "Desconocido"
                            }
                            Default { return "Otro ($type)" }
                        }
                    }

                    # 3. Mostrar Capacidad de la Placa y Estado de Uso
                    Write-Host "Capacidad Maxima Soportada : $([Math]::Round($memArray.MaxCapacity / 1MB, 0)) GB"
                    Write-Host "Ranuras Totales            : $($memArray.MemoryDevices)"
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "Memoria Total instalada    : $memTotal GB" -ForegroundColor White
                    Write-Host "Memoria en Uso             : $memEnUso GB ($porcentajeUso%)" -ForegroundColor Yellow
                    Write-Host "Memoria Disponible         : $memLibre GB" -ForegroundColor Green
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 4. Detalle de los Módulos (Físico)
                    $detalleModulos = $physicalMem | Select-Object `
                        DeviceLocator, 
                    Manufacturer, 
                    @{Name = "Capacidad"; Expression = { [Math]::Round($_.Capacity / 1GB, 0), "GB" -join " " } },
                    @{Name = "Tipo"; Expression = { Get-MemoryType $_.SMBIOSMemoryType $_.Speed } },
                    @{Name = "Velocidad"; Expression = { $_.Speed, "MHz" -join " " } },
                    PartNumber

                    Write-Host "Detalle por Ranura:" -ForegroundColor Cyan
                    $detalleModulos | Format-Table -AutoSize
                }
                "2" { 
                    cabecera                
                    menuOpcion "Haz elegido el SUB_MENU:  $opcion ;;; Opcion:  $op "

                    #wmic diskdrive get caption,InterfaceType,name,serialnumber,Signature,Size,status
                    
                    Write-Host "`n******* DETALLE DE UNIDADES DE DISCO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    Get-WmiObject Win32_DiskDrive | Select-Object `
                        Caption, 
                    InterfaceType, 
                    DeviceID, 
                    SerialNumber, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } }, 
                    Status | 
                    Format-Table -AutoSize

                    #otra alternativa
                    #Get-PhysicalDisk | Select-Object `
                    #FriendlyName, 
                    #SerialNumber, 
                    #MediaType, 
                    #@{Name="Tamaño(GB)"; Expression={[Math]::Round($_.Size / 1GB, 2)}}, 
                    #OperationalStatus, 
                    #HealthStatus | 
                    #Format-Table -AutoSize

                }
                "2.1" { 
                    #clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* CAPACIDAD Y TIPO DE DISCO DURO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Verificar si existe Get-PhysicalDisk (Windows 8+)
                    if (Get-Command Get-PhysicalDisk -ErrorAction SilentlyContinue) {
                        # Obtenemos todos los discos físicos ordenados por DeviceID
                        $discos = Get-PhysicalDisk | Sort-Object DeviceId

                        if ($null -eq $discos) {
                            Write-Host "No se detectaron unidades de disco en este equipo." -ForegroundColor Yellow
                        }
                        else {
                            foreach ($disk in $discos) {
                                # Intentamos obtener detalles adicionales de almacenamiento
                                $storageDetails = $null
                                try {
                                    $storageDetails = $disk | Get-StorageReliabilityCounter -ErrorAction SilentlyContinue
                                } catch {}

                                # Determinar el tipo de disco
                                $tipoDisco = "Disco Rigido (HDD)"
                                if ($disk.BusType -eq "USB" -or $disk.MediaType -eq "Removable" -or $disk.MediaType -eq "External") {
                                    $tipoDisco = "Unidad Extraible"
                                }
                                elseif ($disk.MediaType -eq "SSD") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.FriendlyName -match "SSD|Solid State|NVMe") {
                                    $tipoDisco = "Disco Solido (SSD)"
                                }
                                elseif ($disk.BusType -eq "USB") {
                                    $tipoDisco = "Unidad Extraible"
                                }

                                # Estado de salud
                                $salud = $disk.HealthStatus

                                # Formatear capacidad
                                $capacidadGB = "$([Math]::Round($disk.Size / 1GB, 2)) GB"

                                Write-Host "[ Unidad: $($disk.FriendlyName) ]" -ForegroundColor White -BackgroundColor DarkBlue
                                
                                # Preparar variables para evitar lógica compleja en el hashtable
                                $usoVida = "N/A"
                                if ($storageDetails -and $storageDetails.Wear -ne $null) {
                                    $usoVida = "$($storageDetails.Wear)%"
                                }

                                $temp = "N/A"
                                if ($storageDetails -and $storageDetails.Temperature -ne $null) {
                                    $temp = "$($storageDetails.Temperature)°C"
                                }

                                $nSerie = "Desconocido"
                                if ($disk.SerialNumber) {
                                    $nSerie = $disk.SerialNumber.Trim()
                                }

                                # Tabla de información técnica compatible en formato de lista idéntico al de la imagen
                                New-Object PSObject -Property @{
                                    "Numero"      = $disk.DeviceId
                                    "Modelo"      = $disk.FriendlyName
                                    "Tipo"        = $tipoDisco
                                    "Protocolo"   = $disk.BusType  # NVMe, SATA, USB
                                    "Capacidad"   = $capacidadGB
                                    "EstadoSalud" = $salud
                                    "Uso_Vida"    = $usoVida
                                    "Temp"        = $temp
                                    "N_Serie"     = $nSerie
                                } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                                
                                Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                            }
                        }
                    }
                    else {
                        Write-Host "Nota: Get-PhysicalDisk no esta disponible en este sistema operativo (compatible en Windows 8+)." -ForegroundColor Yellow
                        Write-Host "Obteniendo informacion detallada de unidades fisicas a traves de WMI..." -ForegroundColor Yellow
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        
                        $discosWmi = Get-WmiObject Win32_DiskDrive | Sort-Object Index
                        foreach ($d in $discosWmi) {
                            # Determinar el tipo de disco para Windows 7
                            $tipoDisco = "Disco Rigido (HDD)"
                            if ($d.InterfaceType -eq "USB" -or $d.MediaType -match "External|Removable" -or $d.Model -match "USB|SD Card|Card Reader") {
                                $tipoDisco = "Unidad Extraible"
                            }
                            elseif ($d.Model -match "SSD|Solid State|NVMe|SATA SSD") {
                                $tipoDisco = "Disco Solido (SSD)"
                            }

                            # Estado de salud
                            $salud = $d.Status
                            if ($salud -eq "OK") { $salud = "Healthy" }

                            # Capacidad en GB
                            $capacidadGB = "$([Math]::Round([double]$d.Size / 1GB, 2)) GB"

                            $nSerie = "Desconocido"
                            if ($d.SerialNumber) {
                                $nSerie = $d.SerialNumber.Trim()
                            }

                            Write-Host "[ Unidad: $($d.Model) ]" -ForegroundColor White -BackgroundColor DarkBlue
                            
                            New-Object PSObject -Property @{
                                "Numero"      = $d.Index
                                "Modelo"      = $d.Model
                                "Tipo"        = $tipoDisco
                                "Protocolo"   = $d.InterfaceType  # IDE, SCSI, USB, etc.
                                "Capacidad"   = $capacidadGB
                                "EstadoSalud" = $salud
                                "Uso_Vida"    = "N/A (Requiere Windows 8+)"
                                "Temp"        = "N/A (Requiere Windows 8+)"
                                "N_Serie"     = $nSerie
                            } | Select-Object Numero, Modelo, Tipo, Protocolo, Capacidad, EstadoSalud, Uso_Vida, Temp, N_Serie | Format-List
                            
                            Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                        }
                    }
                }
                "3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DE UNIDADES DE ALMACENAMIENTO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos discos locales (DriveType=3) usando WMI para compatibilidad total
                    $unidades = Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3"

                    foreach ($u in $unidades) {
                        
                        # Forzamos [double] para evitar errores de desbordamiento en discos grandes
                        $totalBytes = [double]$u.Size
                        $freeBytes = [double]$u.FreeSpace
                        
                        # Conversión a GB (1024^3)
                        $totalGB = [Math]::Round($totalBytes / 1GB, 2)
                        $libreGB = [Math]::Round($freeBytes / 1GB, 2)
                        $usadoGB = [Math]::Round($totalGB - $libreGB, 2)
                        
                        # Cálculo de porcentaje de uso
                        if ($totalGB -gt 0) {
                            $porcentajeUsado = [Math]::Round(($usadoGB / $totalGB) * 100, 1)
                        }
                        else {
                            $porcentajeUsado = 0
                        }

                        # Creación de objeto compatible con PowerShell 2.0
                        $discoReporte = New-Object PSObject
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Unidad" -Value $u.DeviceID
                        # $discoReporte | Add-Member -MemberType NoteProperty -Name "Nombre" -Value ($u.VolumeName if ($u.VolumeName) { $u.VolumeName } else { "Sin Etiqueta" })
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Formato" -Value $u.FileSystem
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Total (GB)" -Value $totalGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Libre (GB)" -Value $libreGB
                        $discoReporte | Add-Member -MemberType NoteProperty -Name "Ocupado (GB)" -Value "$usadoGB ($porcentajeUsado%)"
                        
                        # Salida del objeto
                        $discoReporte
                    }

                    # ****
                    Write-Host "`n******* ANALISIS DE ALMACENAMIENTO (DISCOS LOCALES) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    # Obtenemos los discos logicos tipo 3 (Discos Locales)
                    Get-WmiObject Win32_LogicalDisk -Filter "DriveType=3" | ForEach-Object {
                        # Calculos matematicos
                        $sizeGB = [Math]::Round($_.Size / 1GB, 2)
                        $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
                        $usedGB = [Math]::Round($sizeGB - $freeGB, 2)
                        $percentFree = [Math]::Round(($freeGB / $sizeGB) * 100, 1)
                        $percentUsed = 100 - $percentFree
                        # Crear un objeto con la informacion detallada compatible
                        New-Object PSObject -Property @{
                            "Unidad"        = $_.DeviceID
                            "Nombre"        = $_.VolumeName
                            "Formato"       = $_.FileSystem
                            "Tamaño Total"  = "$sizeGB GB"
                            "Espacio Libre" = "$freeGB GB ($percentFree%)"
                            "Espacio Usado" = "$usedGB GB ($percentUsed%)"
                            "Estado"        = $_.Status
                        } | Select-Object Unidad, Nombre, Formato, "Tamaño Total", "Espacio Libre", "Espacio Usado", Estado
                    } | Format-Table -AutoSize
                    Write-Host "Nota: Si el espacio libre es menor al 10%, se recomienda limpieza." -ForegroundColor Yellow
                    # ****

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* PROGRAMAS DE INICIO CON ESTADO DE PROCESO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # 1. Foto instantánea de procesos (optimizamos RAM al no llamar a Get-Process en cada ciclo)
                    $procesosActivos = Get-Process | Select-Object Name, Id

                    # 2. Obtener comandos de inicio
                    $startupCommands = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupCommands) {
                        # LIMPIEZA DEL COMANDO: 
                        # Extraemos el nombre limpio del ejecutable ignorando comillas, rutas y parámetros (.exe)
                        # Ejemplo: "C:\Archivos de programa\App.exe" --silent  =>  App
                        $rawCommand = $item.Command.Split('"').Where({ $_ -ne "" })[0]
                        $nombreLimpio = [System.IO.Path]::GetFileNameWithoutExtension($rawCommand)

                        # 3. Buscar coincidencia en procesos activos
                        $procesoMatch = $procesosActivos | Where-Object { $_.Name -eq $nombreLimpio }
                        
                        # 4. Definir color y texto según si está activo o no
                        $statusColor = "Gray"
                        $pidDisplay = "No activo"
                        
                        if ($procesoMatch) {
                            $statusColor = "Green"
                            $pidDisplay = ($procesoMatch.Id -join ", ") # Por si hay varias instancias abiertas
                        }

                        # 5. Mostrar la información en formato lista organizada
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        Write-Host "PID          : " -NoNewline; Write-Host $pidDisplay -ForegroundColor $statusColor
                        Write-Host "Ejecutable   : $($item.Command)"
                        Write-Host "Usuario      : $($item.User)"
                        Write-Host "Ubicación    : $($item.Location)"
                        if ($item.Description -and $item.Description -ne $item.Caption) {
                            Write-Host "Descripción  : $($item.Description)"
                        }
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* REPORTE DETALLADO DE PROGRAMAS DE INICIO *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de inicio
                    $startupItems = Get-WmiObject -Class Win32_StartupCommand

                    foreach ($item in $startupItems) {
                        # Resaltamos el nombre del programa en azul
                        Write-Host "[ $($item.Caption.ToUpper()) ]" -ForegroundColor White -BackgroundColor DarkBlue
                        
                        # Creamos un objeto personalizado para mostrar los datos ordenados
                        New-Object PSObject -Property @{
                            "Comando/Ruta" = $item.Command
                            "Usuario"      = $item.User
                            "Ubicación"    = $item.Location
                            "Descripción"  = $item.Description
                        } | Select-Object "Comando/Ruta", Usuario, "Ubicación", "Descripción" | Format-List
                        
                        Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                    }

                }
                "6" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL SISTEMA (BIOS/FIRMWARE) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la BIOS mediante WMI
                    $bios = Get-WmiObject -Class Win32_BIOS

                    if ($bios) {
                        # Creamos un objeto compatible con PowerShell 2.0 (Windows 7)
                        $infoBIOS = New-Object PSObject
                        
                        # Usamos la sintaxis completa para evitar parámetros ambiguos
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $bios.Manufacturer
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Nombre_Version" -Value $bios.Name
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Version_SMBIOS" -Value $bios.SMBIOSBIOSVersion
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Estado" -Value $bios.Status
                        $infoBIOS | Add-Member -MemberType NoteProperty -Name "Idioma" -Value $bios.CurrentLanguage

                        # Mostramos la información
                        $infoBIOS | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información de la BIOS." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "6.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # Método directo basado en la variable de entorno de firmware
                    $firmware = $env:firmware_type

                    if ($null -eq $firmware) {
                        # Si la variable está vacía, consultamos la carpeta de Windows
                        if (Test-Path "$env:windir\Panther\setupact.log") {
                            # (Usa el código del log anterior como respaldo)
                        }
                        else {
                            Write-Host "Modo de arranque: Legacy / BIOS (Detectado por exclusión)" -ForegroundColor Yellow
                        }
                    }
                    else {
                        Write-Host "Modo de arranque: $firmware" -ForegroundColor Yellow
                    }
                }
                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n******* DETALLE DEL PROCESADOR (CPU) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtenemos la información de la CPU
                    $cpu = Get-WmiObject -Class Win32_Processor

                    if ($cpu) {
                        # 1. Procesamos la arquitectura antes para evitar el error del 'if'
                        $archText = "32-bit"
                        if ($cpu.AddressWidth -eq 64) {
                            $archText = "64-bit"
                        }

                        # 2. Creamos el objeto (Sintaxis compatible con PS 2.0)
                        $infoCPU = New-Object PSObject
                        
                        # 3. Asignamos los miembros usando la sintaxis completa y segura
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cpu.Name
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cpu.Manufacturer
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $archText
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Nucleos_Fisicos" -Value $cpu.NumberOfCores
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Hilos_Logicos" -Value $cpu.NumberOfLogicalProcessors
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Velocidad_Base" -Value "$($cpu.MaxClockSpeed) MHz"
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "Socket" -Value $cpu.SocketDesignation
                        $infoCPU | Add-Member -MemberType NoteProperty -Name "ID_Procesador" -Value $cpu.ProcessorId

                        # Mostramos el resultado
                        $infoCPU | Format-List
                    }
                    else {
                        Write-Host "No se pudo obtener información del procesador." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                }
                "8" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "`n==================================================================" -ForegroundColor White
                    Write-Host "         REPORTE DETALLADO DE SISTEMA (Mantenimiento SW)" -ForegroundColor Cyan
                    Write-Host "==================================================================" -ForegroundColor White

                    # 1. Recolección previa de datos (WMI)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $cs = Get-WmiObject Win32_ComputerSystem
                    $bios = Get-WmiObject Win32_BIOS
                    $cpu = Get-WmiObject Win32_Processor

                    # 2. Preparación de variables de tiempo y memoria
                    $totalRAM = [Math]::Round([double]$cs.TotalPhysicalMemory / 1GB, 2)
                    $freeRAM = [Math]::Round([double]$os.FreePhysicalMemory / 1MB, 2)
                    $lastBoot = $os.ConvertToDateTime($os.LastBootUpTime)
                    $installDate = $os.ConvertToDateTime($os.InstallDate)
                    $arch = if ($os.OSArchitecture) { $os.OSArchitecture } else { "No detectada" }

                    # --- SECCION 1: IDENTIFICACIÓN DEL EQUIPO ---
                    Write-Host "[ IDENTIFICACION DEL HARDWARE ]" -ForegroundColor Yellow
                    $ident = New-Object PSObject
                    $ident | Add-Member -MemberType NoteProperty -Name "Equipo" -Value $cs.Name
                    $ident | Add-Member -MemberType NoteProperty -Name "Fabricante" -Value $cs.Manufacturer
                    $ident | Add-Member -MemberType NoteProperty -Name "Modelo" -Value $cs.Model
                    $ident | Add-Member -MemberType NoteProperty -Name "N_Serie" -Value $bios.SerialNumber
                    $ident | Format-List

                    # --- SECCIÓN 2: SOFTWARE Y SISTEMA OPERATIVO ---
                    Write-Host "[ SISTEMA OPERATIVO ]" -ForegroundColor Yellow
                    $soft = New-Object PSObject
                    $soft | Add-Member -MemberType NoteProperty -Name "Nombre_SO" -Value $os.Caption
                    $soft | Add-Member -MemberType NoteProperty -Name "Version" -Value $os.Version
                    $soft | Add-Member -MemberType NoteProperty -Name "Arquitectura" -Value $arch
                    $soft | Add-Member -MemberType NoteProperty -Name "Instalacion" -Value $installDate
                    $soft | Add-Member -MemberType NoteProperty -Name "Directorio" -Value $os.WindowsDirectory
                    $soft | Format-List

                    # --- SECCIÓN 3: COMPONENTES PRINCIPALES (CPU/RAM) ---
                    Write-Host "[ COMPONENTES INTERNOS ]" -ForegroundColor Yellow

                    $hard = New-Object PSObject
                    $hard | Add-Member -MemberType NoteProperty -Name "Procesador" -Value $cpu.Name
                    $hard | Add-Member -MemberType NoteProperty -Name "Nucleos_Hilos" -Value "$($cpu.NumberOfCores) Cores / $($cpu.NumberOfLogicalProcessors) Threads"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Total" -Value "$totalRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "RAM_Disponible" -Value "$freeRAM GB"
                    $hard | Add-Member -MemberType NoteProperty -Name "BIOS_Version" -Value $bios.SMBIOSBIOSVersion
                    $hard | Format-List

                    # --- SECCIÓN 4: ESTADO Y CONTEXTO ---
                    Write-Host "[ ESTADO Y RED ]" -ForegroundColor Yellow
                    $estado = New-Object PSObject
                    $estado | Add-Member -MemberType NoteProperty -Name "Dominio_Grupo" -Value $cs.Domain
                    $estado | Add-Member -MemberType NoteProperty -Name "Usuario_Logueado" -Value $cs.UserName
                    $estado | Add-Member -MemberType NoteProperty -Name "Ultimo_Reinicio" -Value $lastBoot
                    $estado | Add-Member -MemberType NoteProperty -Name "Uptime_Minutos" -Value ([Math]::Round((Get-Date).Subtract($lastBoot).TotalMinutes, 0))
                    $estado | Format-List

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "8.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"
                
                    systeminfo | find /i "Sistema Operativo"

                }
                "8.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    wmic cpu get caption

                }
                "8.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # slmgr /dlv
                    Start-Process "slmgr" -ArgumentList "/dlv" -Wait
                    

                }
                "8.4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Start-Process "winver" -Wait
                }
                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis de escaneo terminado: OK"

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green
                    Read-Host
                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "******* ANALISIS DE INTEGRIDAD DE IMAGEN (DISM) /ScanHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión de Windows a través de WMI (Compatible con Win 7)
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3) # Ej: 6.1 (Win7), 6.3 (Win8.1), 10.0 (Win10/11)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # Lógica de ejecución según versión
                    if ($version -ge 6.2) {
                        # Windows 8, 8.1, 10 y 11
                        Write-Host "Iniciando ScanHealth nativo..." -ForegroundColor Yellow
                        
                        # Ejecución de DISM
                        & dism.exe /Online /Cleanup-Image /ScanHealth

                        # Comprobación de éxito ($LASTEXITCODE es el equivalente a %errorlevel%)
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito.  ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrió un error durante la operación (COdigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    }
                    elseif ($version -eq 6.1) {
                        # Windows 7
                        Write-Host "Nota: En Windows 7, /ScanHealth no existe nativamente en DISM." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /scannow' o instalar System Update Readiness Tool." -ForegroundColor Gray
                        
                        # Alternativa segura para Windows 7
                        Write-Host "Ejecutando comprobaciOn alternativa (SFC)..." -ForegroundColor White
                        & sfc /scannow
                    }
                    else {
                        Write-Host "Lo sentimos, esta opción no esta disponible en este sistema operativo." -ForegroundColor Red
                    }

                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "/CheckHealth: Realiza una comprobacion rapida para ver si la imagen esta marcada como daniada, solo verifica una marca de corrupcion"
                    Write-Host "******* VERIFICACION DE SALUD DE IMAGEN (DISM) /CheckHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener la versión del SO mediante WMI
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /CheckHealth solo está disponible en versiones >= 6.2 (Win 8/10/11)
                    if ($version -ge 6.2) {
                        Write-Host "Ejecutando DISM /CheckHealth..." -ForegroundColor Yellow
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /CheckHealth

                        # $LASTEXITCODE es el equivalente nativo a %errorlevel%
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La operacion se completo con exito. ::: OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error durante la operacion (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso específico para Windows 7
                        Write-Host "Nota: En Windows 7, DISM no soporta /CheckHealth nativamente." -ForegroundColor Yellow
                        Write-Host "Se recomienda usar 'sfc /verifyonly' para verificar integridad." -ForegroundColor White
                        
                        & sfc /verifyonly

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La verificacion se completo. Revise los resultados arriba." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC detecto problemas o no pudo ejecutarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Esta opcion no es compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para reparar la imagen del sistema operativo, buscando y restaurando archivos corruptos o dañados mediante la comparacion con copias de archivos sanos de los servidores de Windows Update. Esta herramienta es util para solucionar problemas con los archivos de sistema, especialmente cuando el comando SFC /ScanNow no es suficiente o no funciona"
                    Write-Host "******* REPARACION DE IMAGEN DE SISTEMA (DISM) /RestoreHealth *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # DISM /RestoreHealth requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando reparacion automatica (/RestoreHealth)..." -ForegroundColor Yellow
                        Write-Host "Este proceso puede tardar varios minutos y requiere internet." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /RestoreHealth

                        # Verificamos el código de salida
                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "La imagen se reparo correctamente.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE). Verifique su conexion a Internet." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: No existe RestoreHealth nativo
                        Write-Host "Nota: Windows 7 no soporta /RestoreHealth via DISM." -ForegroundColor Yellow
                        Write-Host "Ejecutando reparacion de archivos de sistema (SFC)..." -ForegroundColor White
                        
                        & sfc /scannow

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "SFC finalizo con exito." -ForegroundColor Green
                        }
                        else {
                            Write-Host "SFC encontro errores o no pudo completarse." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Opcion no compatible con esta version de Windows." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Green
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Para eliminar archivos antiguos y de sistema que ya no son necesarios, con el fin de optimizar y liberar espacio en tu sistema Windows."
                    Write-Host "`n******* LIMPIEZA DE COMPONENTES (DISM / StartComponentCleanup) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    # Obtener versión del sistema operativo
                    $os = Get-WmiObject Win32_OperatingSystem
                    $version = [double]$os.Version.Substring(0, 3)

                    Write-Host "Sistema detectado: $($os.Caption)" -ForegroundColor Gray

                    # /StartComponentCleanup requiere Windows 8 o superior (v6.2+)
                    if ($version -ge 6.2) {
                        Write-Host "Iniciando limpieza de la carpeta WinSxS..." -ForegroundColor Yellow
                        Write-Host "Este proceso reduce el tamanio de la carpeta de sistema." -ForegroundColor Gray
                        
                        # Ejecutamos DISM nativo
                        & dism.exe /Online /Cleanup-Image /StartComponentCleanup

                        if ($LASTEXITCODE -eq 0) {
                            Write-Host "Limpieza de componentes completada con exito.   :::  OK" -ForegroundColor Green
                        }
                        else {
                            Write-Host "Ocurrio un error ($LASTEXITCODE) durante la limpieza." -ForegroundColor Red
                        }
                    } 
                    elseif ($version -eq 6.1) {
                        # Caso Windows 7: Usamos el motor de limpieza de disco nativo
                        Write-Host "Nota: Windows 7 no soporta /StartComponentCleanup." -ForegroundColor Yellow
                        Write-Host "Iniciando limpieza de actualizaciones obsoletas via Cleanmgr..." -ForegroundColor White
                        
                        # Inicia la limpieza de archivos de sistema de forma automatizada
                        # Nota: Requiere que el usuario haya corrido Cleanmgr con SAGESET antes, 
                        # o simplemente lo lanzamos para que el técnico elija.
                        & cleanmgr.exe /sagerun:1
                        
                        Write-Host "Se ha lanzado el Liberador de espacio en disco (Windows 7)." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Opcion no compatible con versiones anteriores a Windows 7." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /ScanHealth"
                    Dism.exe /Online /Cleanup-Image /ScanHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /ScanHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /RestoreHealth"
                    Dism.exe /Online /Cleanup-Image /RestoreHealth
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /RestoreHealth  ::: OK" -ForegroundColor Green
                    
                    Write-Host ""
                    Write-Host "Ejecutando.....: Dism.exe /Online /Cleanup-Image /StartComponentCleanup"
                    Dism.exe /Online /Cleanup-Image /StartComponentCleanup
                    Write-Host "Analisis terminado: Dism.exe /Online /Cleanup-Image /StartComponentCleanup  ::: OK" -ForegroundColor Green
                    
                    Write-Host
                    Write-Host "Ejecutando.....: Sfc /Scannow"
                    Sfc /Scannow
                    Write-Host "Analisis terminado: Sfc /Scannow ::: OK" -ForegroundColor Green
                }

                "17" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    query user

                }
                "18" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    net share
                }
                "19.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO SEGURO DE UNIDADES (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO SEGURO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /p:1 realiza un formateo lento escribiendo ceros" -ForegroundColor Yellow
                    Write-Host "en cada sector de la unidad para mayor seguridad.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo
                        Write-Host "`nIniciando formateo NTFS seguro de la unidad $letraLimpia con verificacion de sectores (/p:1)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Invocación directa del ejecutable del sistema
                            & format.com $letraLimpia /fs:ntfs /p:1
                            Write-Host "`n[EXITO] El proceso de formateo ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false) # El ciclo siempre evalua a falso para ejecutarse exactamente una vez

                    # Cierre ordenado y controlado (La consola nunca se cierra sola)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    

                }

                "19.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido
                        Write-Host "`nIniciando formateo NTFS RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /q en lugar de /p:1
                            & format.com $letraLimpia /fs:ntfs /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan

                }

                "19.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES EN FAT32 (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido en FAT32
                        Write-Host "`nIniciando formateo FAT32 RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /fs:fat32 y /q
                            & format.com $letraLimpia /fs:fat32 /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido en FAT32 ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    Write-Host "Presione ENTER para finalizar el script..."
                    
                }

                "19.4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # ==============================================================================
                    # SCRIPT DE FORMATEO RÁPIDO DE UNIDADES EN exFAT (Compatible con Windows 7 hasta Windows 11)
                    # ==============================================================================
                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "       HERRAMIENTA DE FORMATEO RÁPIDO GMSANTACRUZ   " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "NOTA: El parametro /q realiza un formateo rapido liberando el indice" -ForegroundColor Yellow
                    Write-Host "de archivos en pocos segundos de manera eficiente.`n" -ForegroundColor Yellow

                    # Bucle contenedor de una sola ejecucion para permitir salidas limpias usando 'break'
                    do {
                        # 1. Listar las unidades disponibles usando WMI (Compatibilidad total con Win 7)
                        Write-Host "--- Unidades de Disco Detectadas ---" -ForegroundColor White
                        $unidades = Get-WmiObject -Class Win32_LogicalDisk | Where-Object { $_.DriveType -eq 2 -or $_.DriveType -eq 3 }

                        if ($null -eq $unidades) {
                            Write-Host "[ERROR] No se encontraron unidades de almacenamiento validas." -ForegroundColor Red
                            break # Sale de la opcion de formateo de manera segura sin cerrar la consola
                        }

                        # Mostrar las unidades en un formato limpio y ordenado
                        foreach ($u in $unidades) {
                            # Convertir tamaño a GB de forma compatible con .NET
                            $tamanoGB = if ($u.Size) { [Math]::Round($u.Size / 1GB, 2) } else { "Desconocido" }
                            $libreGB = if ($u.FreeSpace) { [Math]::Round($u.FreeSpace / 1GB, 2) } else { "Desconocido" }
                            
                            # Determinar tipo de unidad de forma amigable
                            $tipo = if ($u.DriveType -eq 2) { "Extraible/USB" } else { "Disco Local" }
                            
                            Write-Host "  -> Unidad: [$($u.DeviceID)] | Tipo: $tipo | Etiqueta: $($u.VolumeName) | Tamano: $tamanoGB GB | Libre: $libreGB GB" -ForegroundColor Green
                        }

                        # 2. Captura y validación de la unidad elegida
                        Write-Host "`n--- Seleccion de Unidad ---" -ForegroundColor White
                        $unidadElegida = (Read-Host "Ingrese la letra de la unidad a formatear de forma RAPIDA (Ej: X o X:)").Trim().ToUpper()

                        # Limpiar la entrada por si el usuario introduce "X:" o solo "X"
                        if ($unidadElegida -match "^[A-Z]:$") {
                            $letraLimpia = $unidadElegida
                        }
                        elseif ($unidadElegida -match "^[A-Z]$") {
                            $letraLimpia = "$unidadElegida" + ":"
                        }
                        else {
                            Write-Host "[ERROR] Formato de letra de unidad no valido." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Verificar que la unidad seleccionada exista en la lista detectada
                        $verificarUnidad = $unidades | Where-Object { $_.DeviceID -eq $letraLimpia }

                        if ($null -eq $verificarUnidad) {
                            Write-Host "[ERROR] La unidad $letraLimpia no existe o no esta disponible para formatear." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # Evitar formatear por accidente la unidad del sistema (C:)
                        if ($letraLimpia -eq "C:") {
                            Write-Host "[ADVERTENCIA CRITICA] No esta permitido formatear la unidad del sistema (C:) por seguridad." -ForegroundColor Red
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 3. Doble confirmación de seguridad antes de proceder
                        Write-Host "`n==================================================" -ForegroundColor Red
                        Write-Host "¡ADVERTENCIA CRITICA! SE PERDERAN TODOS LOS DATOS EN LA UNIDAD $letraLimpia" -ForegroundColor Red
                        Write-Host "==================================================" -ForegroundColor Red
                        $confirmacion1 = Read-Host "Esta seguro de que desea continuar con el formateo RAPIDO, Escriba 'Y' para confirmar"

                        if ($confirmacion1 -ne "Y") {
                            Write-Host "Proceso cancelado por el usuario." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        $confirmacion2 = Read-Host "Ultima confirmacion: Ingrese nuevamente la letra de la unidad para proceder ($letraLimpia)"
                        if ($confirmacion2.Trim().ToUpper() -ne $letraLimpia.Replace(":", "")) {
                            Write-Host "`nLas confirmaciones no coinciden. Proceso abortado de manera segura." -ForegroundColor Yellow
                            break # Sale de la opcion de formateo sin cerrar la consola
                        }

                        # 4. Ejecución del comando de Formateo Rápido en exFAT
                        Write-Host "`nIniciando formateo exFAT RAPIDO de la unidad $letraLimpia (/q)..." -ForegroundColor Cyan
                        Write-Host "Por favor, siga las instrucciones en pantalla del comando nativo de Windows:`n" -ForegroundColor Yellow

                        try {
                            # Se invoca format.com aplicando el parametro /fs:exfat y /q
                            & format.com $letraLimpia /fs:exfat /q
                            Write-Host "`n[EXITO] El proceso de formateo rapido en exFAT ha concluido en la unidad $letraLimpia." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "`n[ERROR OCURRIDO]: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    # Cierre ordenado y controlado (La consola permanece abierta de forma segura)
                    Write-Host "`n==================================================" -ForegroundColor Cyan
                }

                "21.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    # Nota: Ejecutar siempre como Administrador.
                    function Preparar-USB-Legacy {
                        Clear-Host
                        Write-Host "--- Herramienta de Preparacion USB Legacy (MBR) ---" -ForegroundColor Cyan
                        Write-Host "Requisito: Ejecutar como Administrador" -ForegroundColor Yellow

                        # 1. Listar unidades extraibles
                        $discos = Get-WmiObject Win32_DiskDrive | Where-Object { $_.InterfaceType -eq "USB" }

                        if ($null -eq $discos) {
                            Write-Host "[ERROR] No se detectaron unidades USB." -ForegroundColor Red
                            return
                        }

                        $discos | Select-Object DeviceID, Model, Size | Format-Table -AutoSize
                        
                        $eleccion = Read-Host "Ingrese el numero de indice del disco (Ejemplo: 1)"
                        
                        if ($null -eq $eleccion -or $eleccion -notmatch '^\d+$') {
                            Write-Host "[ERROR] Entrada invalida. Operacion cancelada." -ForegroundColor Red
                            return
                        }

                        $discoSeleccionado = $discos[$eleccion]
                        $driveLetter = $discoSeleccionado.DeviceID

                        # 2. Confirmacion de seguridad
                        $confirmar = Read-Host "ADVERTENCIA: Se borraran todos los datos en $driveLetter. Continuar? (S/N)"
                        if ($confirmar -ne 'S') {
                            Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                            return
                        }

                        # 3. Ejecucion de Diskpart mediante Pipe (Estable)
                        try {
                            Write-Host "Procesando particiones mediante Diskpart..." -ForegroundColor Yellow
                            
                            $comandos = (
                                "select disk $eleccion",
                                "clean",
                                "create partition primary",
                                "format fs=ntfs quick",
                                "active",
                                "assign",
                                "exit"
                            )
                            
                            # Envio al pipeline para mantener la consola abierta
                            $comandos | diskpart | Out-Null
                            
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "[EXITO] La unidad ha sido formateada y marcada como Activa." -ForegroundColor Green
                                Write-Host "Para finalizar, ejecuta: bootsect /nt60 X: (donde X es la letra asignada)" -ForegroundColor Cyan
                            }
                            else {
                                Write-Host "[ERROR] Diskpart finalizo con codigo de error: $LASTEXITCODE" -ForegroundColor Red
                            }
                            
                        }
                        catch {
                            Write-Host "[ERROR CRITICO] Ocurrio un fallo durante la operacion: $_" -ForegroundColor Red
                        }
                        finally {
                            Write-Host "`nProceso finalizado." -ForegroundColor Cyan
                        }
                    }

                    Preparar-USB-Legacy
                    
                }

                "21.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    
                }

                "21.3" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op"

                    
                }

                

                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 20: Presione ENTER para continuar..." }

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.20*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.21 ******************************************************
#**********************************************************************************************************************************
function psSubMenu21 {
    

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header "21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "1. Reestablecer la tienda de Windows."
            Write-Host "2. Clave de Sistema Operativo Windows."
            Write-Host "3. Eliminar "Desktop.ini" (Aviso que se ejecuta automaticamente)."
            Write-Host "-----------------------------------------------------------."
            Write-Host "4. Web Definicion ANTIVIRUS DE WINDOWS."
            Write-Host "***********************************************************."
            Write-Host "5. Administracion de Discos Duros."
            Write-Host "6. Administrador de dispositivos."
            Write-Host "7. Administracion de Impresion."
            Write-Host "8. Conexion de Red."
            Write-Host "9. Herramienta de Diagnostico DirectX."
            Write-Host "10. Informacion del Sistema - VENTANA."
            Write-Host "***********************************************************."
            Write-Host ""
            Write-Host "0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "=========================================================="
            
            $op21 = Read-Host "Seleccione la tarea a realizar"

            switch ($op21) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "wsreset" -Wait

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    $licencia = (Get-WmiObject SoftwareLicensingService).OA3xOriginalProductKey

                    if ([string]::IsNullOrWhiteSpace($licencia)) {
                        Write-Warning "No se encontró una clave OA3.0 en el firmware de este equipo."
                    }
                    else {
                        Write-Host "La clave detectada es: $licencia" -ForegroundColor Green
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""

                }
                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    # 1. Definimos las rutas usando variables de entorno para mayor compatibilidad
                    $rutas = @(
                        "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\Startup\desktop.ini",
                        "$env:Public\Desktop\desktop.ini"
                    )

                    Write-Host "Has elegido ELIMINAR archivos desktop.ini." -ForegroundColor Cyan

                    foreach ($ruta in $rutas) {
                        if (Test-Path -Path $ruta) {
                            try {
                                # -Force es necesario porque desktop.ini tiene atributos de sistema/oculto
                                Remove-Item -Path $ruta -Force -ErrorAction Stop
                                Write-Host "Eliminado con exito: $ruta" -ForegroundColor Green
                            }
                            catch {
                                Write-Warning "No se pudo eliminar $ruta. Es posible que requiera permisos de Administrador."
                            }
                        }
                        else {
                            Write-Host "El archivo no existe en: $ruta" -ForegroundColor Gray
                        }
                    }

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process "https://www.microsoft.com/en-us/wdsi/definitions"       

                    # Este comando descarga e instala las últimas definiciones silenciosamente
                    Update-MpSignature     

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""  

                }
                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process diskmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process devmgmt.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process printmanagement.msc
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "8" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process ncpa.cpl
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
        
                "9" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process dxdiag  -Wait
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "10" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op21"

                    Start-Process msinfo32
                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } #Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 21: Presione ENTER para continuar..." }

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.21*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.22 ******************************************************
#**********************************************************************************************************************************
function psSubMenu22 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  1. Ver estado Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  2. Detener Servicio Actualizacion Windows 7 en adelante."
            Write-Host "  3. Iniciar Servicio Actualizacion Windows 10."
            Write-Host "  4. Agregar Registro Detener Actualizacion Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  5. Abrir ventana de Administrador de Servicios de Windows."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  6. Herramienta de eliminacion de Software malintencionado."
            Write-Host "  -----------------------------------------------------------."
            Write-Host "  7. Pasos para restaurar indice de Windows."
            Write-Host "  8. Aplicaciones y procesos en la PC."
            Write-Host "     8.1 Cerrar aplicaciones de Usuario."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==========================================================="
            
            $op22 = Read-Host "Seleccione la tarea a realizar"

            switch ($op22) {
                "1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Configuración de codificación para evitar problemas con tildes en versiones antiguas
                    $OutputEncoding = [System.Text.Encoding]::UTF8

                    Write-Host "Este script verifica si los servicios de los cuales depende Windows Update estan corriendo" -ForegroundColor Cyan
                    Write-Host ""

                    # Pausa inicial (Equivalente a TIMEOUT /T 4)
                    Start-Sleep -Seconds 4

                    # Lista de servicios a verificar
                    # Nota: UsoSvc y WaasMedicSvc solo aparecerán en Windows 10/11
                    $servicios = @(
                        "BITS", 
                        "UsoSvc", 
                        "wuauserv", 
                        "WaasMedicSvc"
                    )

                    foreach ($nombreSvc in $servicios) {
                        # Intentamos obtener el servicio silenciosamente
                        $svc = Get-Service -Name $nombreSvc -ErrorAction SilentlyContinue
                        
                        if ($svc) {
                            # Si el servicio existe, mostramos su nombre real y su estado
                            $estado = $svc.Status.ToString().ToUpper()
                            
                            # Color diferenciador: Verde si corre, Rojo si está detenido
                            $color = if ($estado -eq "RUNNING") { "Green" } else { "Yellow" }
                            
                            Write-Host "Servicio: $($svc.DisplayName) ($nombreSvc)"
                            Write-Host "ESTADO: $estado" -ForegroundColor $color
                        }
                        else {
                            # Si el servicio no existe (como UsoSvc en Win 7)
                            Write-Host "Servicio: $nombreSvc - [NO INSTALADO EN ESTE SISTEMA]" -ForegroundColor Gray
                        }
                        
                        Write-Host ("-" * 30)
                        Start-Sleep -Seconds 2
                    }

                    Write-Host ""
                    Write-Host "-------------------------------------------------------" -ForegroundColor White
                    Write-Host "Si todo aca dice STOPPED o STOPPING, entonces SERVICIOS DETENIDOS" -ForegroundColor Cyan
                    Write-Host "-------------------------------------------------------"
                    Write-Host ""

                    # Write-Host "Presione una tecla para continuar . . ."
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }
                "2" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible con PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Write-Host "Presione una tecla para salir..."
                        $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        exit
                    }

                    Write-Host "--- DESACTIVACION DE SERVICIOS DE ACTUALIZACION ---" -ForegroundColor Cyan
                    Write-Host "Este script desactiva BITS, wuauserv y servicios de mantenimiento (Win10+)."
                    Write-Host "Presione CTRL+C en los proximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios y su ruta en el registro
                    # Nota: UsoSvc y WaasMedicSvc no existen en Win7, el script los saltará automáticamente.
                    $servicios = @("UsoSvc", "WaasMedicSvc", "BITS", "wuauserv")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/3] Modificando Registro para desactivar el inicio..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # Configurar Start = 4 (Deshabilitado)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 4 -Force
                            Write-Host "OK: $svcName configurado como Deshabilitado."
                            
                            # Caso especial: Cambiar ObjectName a 'Guest' para bloquear ejecución (el 'truco' del original)
                            if ($svcName -eq "wuauserv") {
                                Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "Guest" -Force
                                Write-Host "CRITICO: Credenciales de $svcName cambiadas a 'Guest'." -ForegroundColor Cyan
                            }
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (Normal en Windows 7)." -ForegroundColor Gray
                        }
                    }

                    Start-Sleep -Seconds 2

                    Write-Host "`n[2/3] Deteniendo servicios activos..." -ForegroundColor Yellow
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            if ($svc.Status -ne 'Stopped') {
                                Write-Host "Deteniendo $svcName..." -NoNewline
                                Stop-Service -Name $svcName -Force -ErrorAction SilentlyContinue
                                Write-Host " [HECHO]" -ForegroundColor Green
                            }
                            else {
                                Write-Host "$svcName ya se encuentra detenido." -ForegroundColor Gray
                            }
                        }
                        Start-Sleep -Milliseconds 500
                    }

                    Write-Host "`n[3/3] Verificación final de estado:" -ForegroundColor Yellow
                    Write-Host "-------------------------------------------------------"
                    foreach ($svcName in $servicios) {
                        $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue
                        if ($svc) {
                            $color = if ($svc.Status -eq 'Stopped') { "Green" } else { "Red" }
                            Write-Host "Servicio: $($svcName.PadRight(15)) Estado: $($svc.Status)" -ForegroundColor $color
                        }
                    }
                    Write-Host "-------------------------------------------------------"
                    Write-Host "Si el estado es STOPPED, la operacion fue exitosa."
                    Write-Host "`nPresione cualquier tecla para continuar..."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")

                }

                "3" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificación de privilegios de Administrador (Compatible PS v2.0+)
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
                    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
                        Write-Host "ERROR: Este script DEBE ejecutarse como Administrador." -ForegroundColor Red
                        Write-Host "Haga clic derecho sobre el archivo y seleccione 'Ejecutar con PowerShell'."
                        Pause
                        exit
                    }

                    Clear-Host
                    Write-Host "--- RESTAURACIÓN DE SERVICIOS DE ACTUALIZACIÓN ---" -ForegroundColor Cyan
                    Write-Host "Restaurando permisos de ejecución e identidad LocalSystem..."
                    Write-Host "Presione CTRL+C en los próximos 10 segundos para cancelar..."

                    Start-Sleep -Seconds 10

                    # Lista de servicios a restaurar
                    $servicios = @("wuauserv", "UsoSvc", "BITS", "WaasMedicSvc")
                    $registryPath = "HKLM:\SYSTEM\CurrentControlSet\Services"

                    Write-Host "`n[1/2] Restaurando identidad y tipo de inicio en el Registro..." -ForegroundColor Yellow

                    foreach ($svcName in $servicios) {
                        $fullPath = "$registryPath\$svcName"
                        
                        if (Test-Path $fullPath) {
                            # 1. Restaurar Identidad a 'LocalSystem' (fundamental para que el servicio arranque)
                            Set-ItemProperty -Path $fullPath -Name "ObjectName" -Value "LocalSystem" -Force
                            
                            # 2. Restaurar Inicio a '3' (Manual)
                            Set-ItemProperty -Path $fullPath -Name "Start" -Value 3 -Force
                            
                            Write-Host "OK: $svcName restaurado a LocalSystem y modo Manual." -ForegroundColor Green
                            Start-Sleep -Seconds 2
                        }
                        else {
                            Write-Host "SKIP: $svcName no existe en este sistema (ignorado)." -ForegroundColor Gray
                        }
                    }

                    Write-Host "`n[2/2] Finalizando..." -ForegroundColor Yellow
                    Write-Host "------------------------------------------------------------------------------------------"
                    Write-Host "LISTO, todo restaurado." -ForegroundColor White
                    Write-Host "ES NECESARIO REINICIAR el sistema para que los cambios de identidad surtan efecto." -ForegroundColor Red
                    Write-Host "Una vez reiniciada la PC, los servicios podrán arrancar cuando Windows los necesite."
                    Write-Host "------------------------------------------------------------------------------------------"

                    Write-Host "`nPresione cualquier tecla para continuar . . ."
                    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    
                }
                
                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # 1. Verificacion de privilegios de Administrador
                    $currentIdentity = [Security.Principal.WindowsIdentity]::GetCurrent()
                    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal($currentIdentity)
                    $adminRole = [Security.Principal.WindowsBuiltInRole]::Administrator

                    if (-not $currentPrincipal.IsInRole($adminRole)) {
                        Write-Host 'ERROR: Ejecute PowerShell como ADMINISTRADOR.' -ForegroundColor Red
                        Write-Host 'Presione una tecla para salir...'
                        $null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')
                        exit
                    }

                    $regPath = 'SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
                    Write-Host '--- FORZANDO DESACTIVACION DE ACTUALIZACIONES ---' -ForegroundColor Cyan

                    # Funcion para crear la clave y el valor
                    function Set-WindowsUpdatePolicy {
                        param($Name, $Value)
                        try {
                            $fullPath = "HKLM:\$regPath"
                            if (!(Test-Path $fullPath)) { 
                                New-Item -Path $fullPath -Force | Out-Null 
                            }
                            Set-ItemProperty -Path $fullPath -Name $Name -Value $Value -PropertyType 'DWord' -Force -ErrorAction 'Stop'
                            return $true
                        }
                        catch {
                            # Fallback a REG.EXE para maxima compatibilidad en Windows 7
                            $cmd = "reg add ""HKLM\$regPath"" /v $Name /t REG_DWORD /d $Value /f"
                            Invoke-Expression $cmd | Out-Null
                            return $?
                        }
                    }

                    # Aplicar las politicas
                    $items = @{ 'NoAutoUpdate' = 1; 'AUOptions' = 1 }

                    foreach ($key in $items.Keys) {
                        $val = $items[$key]
                        Write-Host "Configurando $key... " -NoNewline
                        if (Set-WindowsUpdatePolicy -Name $key -Value $val) {
                            Write-Host 'OK' -ForegroundColor Green
                        }
                        else {
                            Write-Host 'FALLO' -ForegroundColor Red
                        }
                    }

                    # 2. Refrescar las politicas del sistema
                    Write-Host 'Actualizando directivas de grupo...' -ForegroundColor Yellow
                    gpupdate /force | Out-Null

                    Write-Host '-------------------------------------------------------'
                    Write-Host 'PROCESO COMPLETADO' -ForegroundColor Cyan
                    Write-Host 'Si hubo fallos, revise si un antivirus bloquea el registro.'
                    Write-Host '-------------------------------------------------------'

                    
                }

                "5" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process services.msc

                    Write-Host "Proceso ejecutado..."

                }
                "6" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    Start-Process mrt

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "7" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # Titulo principal
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host '    GUIA DE REPARACION: DISM CON FUENTE EXTERNA (WIM)' -ForegroundColor Cyan
                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' Realice estos pasos cuando "DISM /RestoreHealth" falle.' -ForegroundColor White
                    Write-Host ''

                    # Paso 1
                    Write-Host ' 1. MONTAR LA IMAGEN' -ForegroundColor Yellow
                    Write-Host '    Monte la imagen ISO de Windows en su sistema.'
                    Write-Host ''

                    # Paso 2
                    Write-Host ' 2. OBTENER INFORMACION DEL ARCHIVO WIM' -ForegroundColor Yellow
                    Write-Host '    Abra una terminal como administrador y ejecute:'
                    Write-Host '    dism /get-wiminfo /wimfile:N:\sources\install.wim' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    NOTA: Reemplace ' -NoNewline
                    Write-Host 'N:\sources\install.wim' -ForegroundColor Magenta -NoNewline
                    Write-Host ' con su ruta real.'
                    Write-Host '    En el listado, busque el INDICE que corresponde a su version de Windows.'
                    Write-Host ''

                    # Paso 3
                    Write-Host ' 3. EJECUTAR RESTAURACION CON FUENTE' -ForegroundColor Yellow
                    Write-Host '    Escriba el siguiente comando siguiendo este formato:'
                    Write-Host '    dism /online /cleanup-image /RestoreHealth /source:N:\sources\install.wim:6 /limitaccess' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''
                    Write-Host '    IMPORTANTE REVISAR:' -ForegroundColor Red
                    Write-Host '    * El numero de INDICE (al final de la ruta, ej: :6)'
                    Write-Host '    * La ruta exacta donde esta el archivo.'
                    Write-Host '    * La extension (.wim o .esd).'
                    Write-Host ''

                    # Paso final
                    Write-Host ' 4. VERIFICACION FINAL' -ForegroundColor Yellow
                    Write-Host '    Al terminar, ejecute el comando para reparar archivos de sistema:'
                    Write-Host '    sfc /scannow' -ForegroundColor Green -BackgroundColor Black
                    Write-Host ''

                    Write-Host '===========================================================' -ForegroundColor Cyan
                    Write-Host ' '
                    
                    #$null = $Host.UI.RawUI.ReadKey('NoEcho,IncludeKeyDown')

                }

                "8.1" { 
                    cabecera
                    menuOpcion "Haz elegido el SUB_MENU: $opcion ;;; Opcion: $op22"

                    # ==============================================================================
                    # Script: Monitor_Aplicaciones_Mejorado.ps1
                    # Compatibilidad: Windows 7, 8.1, 10, 11 (PowerShell 2.0+)
                    # Mejora: Opción de salida explícita y cancelación de cierre.
                    # ==============================================================================

                    Write-Host "Analizando aplicaciones abiertas con ventana activa..." -ForegroundColor Yellow
                    Write-Host ""

                    # 1. Obtener procesos con ventana principal
                    $procesosUsuario = Get-Process | Where-Object { $_.MainWindowTitle -ne "" }

                    $reporteApps = foreach ($p in $procesosUsuario) {
                        $ramMB = [Math]::Round($p.WorkingSet64 / 1MB, 2)
                        
                        New-Object PSObject -Property @{
                            ID         = $p.Id
                            Aplicacion = $p.ProcessName
                            Ventana    = if ($p.MainWindowTitle.Length -gt 45) { $p.MainWindowTitle.Substring(0, 42) + "..." } else { $p.MainWindowTitle }
                            RAM_MB     = $ramMB
                        }
                    }

                    # 2. Mostrar tabla de aplicaciones
                    $reporteApps | Select-Object ID, Aplicacion, RAM_MB, Ventana | 
                    Sort-Object RAM_MB -Descending | 
                    Format-Table -AutoSize

                    Write-Host ""
                    Write-Host "--- GESTION DE PROCESOS ---" -ForegroundColor Cyan
                    Write-Host "Opciones: Ingrese el [PID] para cerrar, o la letra [S] para Salir sin cambios." -ForegroundColor White

                    # 3. Interacción con opción de salida mejorada
                    $entrada = Read-Host "Seleccione una opcion"

                    # Validar si el usuario quiere salir (Letra S o vacío)
                    if ($entrada -eq "S" -or $entrada -eq "s" -or $entrada -eq "") {
                        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                    } 
                    # Validar si la entrada es un número (PID)
                    elseif ($entrada -match '^\d+$') {
                        try {
                            $target = Get-Process -Id $entrada -ErrorAction Stop
                            Stop-Process -Id $entrada -Force
                            Write-Host "La aplicacion '$($target.ProcessName)' (PID: $entrada) ha sido cerrada." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "Error: No se encontro el PID o acceso denegado." -ForegroundColor Red
                        }
                    } 
                    else {
                        Write-Host "Entrada no valida. No se realizaron cambios." -ForegroundColor Red
                    }

                    # 4. Cierre del script (estándar de compatibilidad)
                    Write-Host ""
                    Write-Host "Saliendo del programa..." -ForegroundColor Gray
                    Start-Sleep -Seconds 2

                    Write-Host "Proceso ejecutado..."                    
                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { 
                Read-Host "SUB_MENU 22: Presione ENTER para continuar..." 
            }
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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.22*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.23 ******************************************************
#**********************************************************************************************************************************
function psSubMenu23 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 23. ---)) LOCAL: HELPDESK LOCAL - HERRAMIENTAS DE SISTEMA."
            Write-Host "  1. Abrir PowerShell Administrador."
            Write-Host "  2. Mostrar Unidades Logicas de Almacenamiento."
            Write-Host "     2.1. Mostrar Unidadles logicas - DETALLE."
            Write-Host "  3. Informacion Corta de PC."
            Write-Host "     3.1. Informacion Corta de Procesador."
            Write-Host "  4. Mostrar Direccion IP Ethernet Asignada."
            Write-Host "     4.1. Mostrar Interfaces con Direcciones IP Ethernet."
            Write-Host "     4.2. Mostrar Direccion IP PUBLICA"
            Write-Host "  5. Gestion de Red Local:" -ForegroundColor Green
            Write-Host "    5.1. Resetear IP Red LAN." -ForegroundColor Cyan
            Write-Host "    5.2. Resetear IP Red y Asignar DHCP." -ForegroundColor Cyan
            Write-Host "    5.3. Mostrar Claves MAC Address." -ForegroundColor Cyan
            Write-Host "    5.4. Actualizacion y Diagnostico de Politicas (gpupdate)." -ForegroundColor Cyan
            Write-Host "  11. Vaciar Papelera de Reciclaje"
            Write-Host "  12. Revisiones Instaladas de Windows."
            Write-Host "  ------------------------------------"
            Write-Host "  20. Estado de bateria Laptop."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "===================================================================="
            
            $op23 = Read-Host "Seleccione la tarea a realizar"

            switch ($op23) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Start-Process powershell -Verb RunAs

                    Write-Host "Proceso ejecutado..."
                    Write-Host ""
                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener Unidades Lógicas (Equivalente a Get-PSDrive)
                    Write-Host "--- UNIDADES LOGICAS DEL SISTEMA ---" -ForegroundColor Green
                    Get-PSDrive -PSProvider FileSystem | Select-Object Name, 
                    @{Name = "Used(GB)"; Expression = { "{0:N2}" -f ($_.Used / 1GB) } }, 
                    @{Name = "Free(GB)"; Expression = { "{0:N2}" -f ($_.Free / 1GB) } }, 
                    @{Name = "Total(GB)"; Expression = { "{0:N2}" -f (($_.Used + $_.Free) / 1GB) } } | Format-Table -AutoSize

                    Write-Host "`n--- DISCOS FISICOS DETECTADOS ---" -ForegroundColor Green

                    # 2. Obtener Discos Físicos (Compatible con Windows 7, 8, 10 y 11)
                    # Usamos Win32_DiskDrive porque Get-PhysicalDisk falla en Windows 7
                    Get-WmiObject -Class Win32_DiskDrive | Select-Object Model, 
                    @{Name = "Interface"; Expression = { $_.InterfaceType } }, 
                    @{Name = "Size(GB)"; Expression = { "{0:N2}" -f ($_.Size / 1GB) } }, 
                    Status | Format-Table -AutoSize

                    Write-Host "`nPresione una tecla para salir..."
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                    Write-Host ""

                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información extendida de las unidades usando .NET
                    # Este método es compatible con todas las versiones de PowerShell y Windows
                    $drives = [System.IO.DriveInfo]::GetDrives()

                    Write-Host "--- DETALLE DE ALMACENAMIENTO DEL SISTEMA ---" -ForegroundColor Cyan
                    Write-Host ""

                    $reporte = foreach ($d in $drives) {
                        # Inicializamos variables para evitar errores en unidades vacías (como lectoras de DVD)
                        $totalGB = 0
                        $freeGB = 0
                        $percentFree = 0
                        $status = "Listo"

                        if ($d.IsReady) {
                            $totalGB = [Math]::Round($d.TotalSize / 1GB, 2)
                            $freeGB = [Math]::Round($d.TotalFreeSpace / 1GB, 2)
                            # Calcular porcentaje de espacio libre
                            if ($totalGB -gt 0) {
                                $percentFree = [Math]::Round(($freeGB / $totalGB) * 100, 1)
                            }
                        }
                        else {
                            $status = "No disponible / Sin medio"
                        }

                        # Creamos un objeto personalizado para un formato limpio
                        New-Object PSObject -Property @{
                            'Letra'     = $d.Name
                            'Etiqueta'  = if ($d.IsReady) { $d.VolumeLabel } else { "---" }
                            'Formato'   = if ($d.IsReady) { $d.DriveFormat } else { "---" }
                            'Tipo'      = $d.DriveType
                            'Total(GB)' = $totalGB
                            'Libre(GB)' = $freeGB
                            'Libre(%)'  = $percentFree
                            'Estado'    = $status
                        }
                    }

                    # 2. Mostrar la tabla organizada por nombre de unidad
                    $reporte | Select-Object Letra, Etiqueta, Tipo, Formato, 'Total(GB)', 'Libre(GB)', 'Libre(%)', Estado | Format-Table -AutoSize

                    Write-Host ""
                    Write-Host "Nota: Las unidades con 0.00 GB suelen ser lectores de tarjetas o CD-ROM sin disco." -ForegroundColor Gray
                    
                    #$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")  #Espera que el usuario presione una tecla
                    Write-Host ""
                    
                }
                
                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información del Sistema
                    $sysInfo = Get-WmiObject -Class Win32_ComputerSystem
                    # 2. Obtener información de la BIOS
                    $biosInfo = Get-WmiObject -Class Win32_BIOS
                    # 3. Obtener información del Sistema Operativo (Extra para contexto)
                    $osInfo = Get-WmiObject -Class Win32_OperatingSystem

                    Write-Host "--- INFORMACION DEL HARDWARE Y SISTEMA ---" -ForegroundColor Cyan

                    # Presentación organizada de datos del sistema
                    $propiedadesSistema = @{
                        'Fabricante'      = $sysInfo.Manufacturer
                        'Modelo'          = $sysInfo.Model
                        'Usuario Actual'  = $sysInfo.UserName
                        'RAM Total (GB)'  = [Math]::Round($sysInfo.TotalPhysicalMemory / 1GB, 2)
                        'Tipo de Sistema' = $sysInfo.SystemType
                    }

                    New-Object PSObject -Property $propiedadesSistema | Select-Object Fabricante, Modelo, 'RAM Total (GB)', 'Tipo de Sistema', 'Usuario Actual' | Format-List

                    Write-Host "--- DETALLES DE LA BIOS ---" -ForegroundColor Cyan

                    # Presentación organizada de datos de la BIOS
                    $propiedadesBios = @{
                        'Nombre'          = $biosInfo.Name
                        'Version'         = $biosInfo.SMBIOSBIOSVersion
                        'Fabricante BIOS' = $biosInfo.Manufacturer
                        'Numero Serie'    = $biosInfo.SerialNumber
                        'Version Mayor'   = $biosInfo.SMBIOSMajorVersion
                    }

                    New-Object PSObject -Property $propiedadesBios | Select-Object 'Numero Serie', Fabricante, Version, Nombre | Format-List

                    Write-Host "--- SISTEMA OPERATIVO ---" -ForegroundColor Cyan
                    Write-Host "Version: $($osInfo.Caption) ($($osInfo.Version))"
                    Write-Host "Arquitectura: $($osInfo.OSArchitecture)"
                    Write-Host ""

            
                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener información del procesador usando WMI (Compatible con PS 2.0 en adelante)
                    $cpuInfo = Get-WmiObject -Class Win32_Processor

                    Write-Host "--- DETALLES DEL PROCESADOR (CPU) ---" -ForegroundColor Cyan
                    Write-Host ""

                    # 2. Creamos un objeto con las propiedades más relevantes, limpiando datos técnicos innecesarios
                    $reporte = $cpuInfo | Select-Object `
                        Name, 
                    Manufacturer, 
                    @{Name = "Nucleos_Fisicos"; Expression = { $_.NumberOfCores } },
                    @{Name = "Hilos_Logicos"; Expression = { $_.NumberOfLogicalProcessors } },
                    @{Name = "Velocidad_Max(MHz)"; Expression = { $_.MaxClockSpeed } },
                    @{Name = "Arquitectura"; Expression = {
                            switch ($_.Architecture) {
                                0 { "x86 (32-bit)" }
                                6 { "Itanium" }
                                9 { "x64 (64-bit)" }
                                default { "Desconocida" }
                            }
                        }
                    },
                    SocketDesignation,
                    L2CacheSize,
                    L3CacheSize

                    # 3. Mostrar resultados en formato de lista para mejor lectura
                    $reporte | Format-List



                    Write-Host "------------------------------------------------------------"
                    Write-Host "Informacion obtenida via WMI - Compatible Win7 y posteriores" -ForegroundColor Cyan
                    Write-Host ""

                }
                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener configuraciones de red con IP habilitada
                    # Usamos Get-WmiObject por ser el estandar mas compatible con Windows 7
                    $networkConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled=TRUE"

                    Write-Host "--- DIRECCIONES IP ACTIVAS EN EL SISTEMA ---" -ForegroundColor Cyan
                    Write-Host ""

                    # 2. Procesar y limpiar la informacion
                    $reporte = foreach ($config in $networkConfigs) {
                        # Extraemos solo la primera direccion IPv4 (usualmente la principal)
                        # y eliminamos las llaves si existen
                        $ipPrincipal = $config.IPAddress[0]
                        $macAddress = $config.MACAddress
                        $descripcion = $config.Description

                        New-Object PSObject -Property @{
                            'Adaptador'    = $descripcion
                            'Direccion_IP' = $ipPrincipal
                            'MAC_Address'  = $macAddress
                            'DHCP'         = if ($config.DHCPEnabled) { "Si" } else { "No" }
                        }
                    }

                    # 3. Mostrar tabla formateada
                    $reporte | Select-Object Adaptador, Direccion_IP, DHCP, MAC_Address | Format-Table -AutoSize



                    Write-Host "-------------------------------------------------------"
                    Write-Host "Nota: Se muestra la IPv4 principal por adaptador." -ForegroundColor Cyan
                    Write-Host " "

                }
                
                "4.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Configuración de entorno y limpieza
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "    REPORTE DE TODAS LAS INTERFACES Y DIRECCIONES IP      " -ForegroundColor Cyan
                    Write-Host "      Compatibilidad Universal: Windows 7, 8, 10 y 11      " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan

                    # 2. Obtener datos de Hardware (Win32_NetworkAdapter) y Configuración (Win32_NetworkAdapterConfiguration)
                    # Usamos Get-WmiObject para asegurar funcionamiento en PowerShell 2.0 (Win 7)
                    $allHW = Get-WmiObject -Class Win32_NetworkAdapter
                    $allConfigs = Get-WmiObject -Class Win32_NetworkAdapterConfiguration

                    $reporteGlobal = foreach ($hw in $allHW) {
                        # Relacionamos el hardware con su configuración de IP usando el Index
                        $config = $allConfigs | Where-Object { $_.Index -eq $hw.DeviceID }
                        
                        # Extraemos IPs y Máscaras (si existen)
                        $ipv4 = "---"
                        $mask = "---"
                        if ($config.IPAddress) {
                            $ipv4 = $config.IPAddress | Where-Object { $_ -like '*.*.*.*' } | Select-Object -First 1
                            $mask = $config.IPSubnet | Where-Object { $_ -like '*.*.*.*' } | Select-Object -First 1
                        }

                        # Clasificación de Tecnología
                        $tipo = "Fisica (Ethernet)"
                        if ($hw.Name -match "Wi-Fi|Wireless|802.11") { $tipo = "Wi-Fi" }
                        elseif ($hw.Name -match "Bluetooth") { $tipo = "Bluetooth" }
                        elseif ($hw.Name -match "Virtual|VMware|VirtualBox|Hyper-V|TAP|VPN|Pseudo") { $tipo = "Virtual" }

                        # Estado de conexión
                        $estado = switch ($hw.NetConnectionStatus) {
                            2 { "Conectado" }
                            7 { "Deshabilitado" }
                            default { "Desconectado/Inactivo" }
                        }

                        # Solo incluimos interfaces con MAC o que sean relevantes para el usuario
                        if ($hw.MACAddress -and $hw.NetConnectionID) {
                            New-Object PSObject -Property @{
                                'Interface'    = $hw.NetConnectionID
                                'Tecnologia'   = $tipo
                                'Estado'       = $estado
                                'Direccion_IP' = $ipv4
                                'Mascara'      = $mask
                            }
                        }
                    }

                    # 3. Mostrar el reporte unificado
                    $reporteGlobal | Select-Object Tecnologia, Interface, Estado, Direccion_IP, Mascara | Sort-Object Tecnologia | Format-Table -AutoSize



                    Write-Host "-----------------------------------------------------------"
                    Write-Host "DETALLE DE ANALISIS:" -ForegroundColor Yellow
                    Write-Host "* FISICAS: Conexiones por cable (Ethernet)."
                    Write-Host "* WI-FI: Adaptadores inalambricos."
                    Write-Host "* BLUETOOTH: Enlaces de red de corto alcance."
                    Write-Host "* VIRTUALES: Adaptadores de software (VPN, Maquinas Virtuales)."
                    Write-Host "-----------------------------------------------------------"

                    Write-Host " "
                }
                "4.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener la IP Pública directamente en la consola
                    Write-Host "Consultando IP publica actual..." -ForegroundColor Cyan

                    try {
                        # Usamos el cliente Web de .NET para maxima compatibilidad con Windows 7 (PS 2.0)
                        $webClient = New-Object System.Net.WebClient
                        $ipPublica = $webClient.DownloadString("http://ifconfig.me/ip").Trim()
                        Write-Host "Tu IP Publica es: " -NoNewline
                        Write-Host $ipPublica -ForegroundColor Green -BackgroundColor Black
                    }
                    catch {
                        Write-Host "No se pudo obtener la IP automaticamente." -ForegroundColor Red
                    }

                    Write-Host "`n-------------------------------------------------------"

                    # 2. Abrir el navegador en un sitio de verificacion
                    Write-Host "Abriendo navegador para verificacion visual..." -ForegroundColor Yellow

                    $url = "https://www.cualesmiip.com"

                    # Usamos Start-Process de forma generica para que abra el NAVEGADOR PREDETERMINADO
                    # Esto asegura que funcione en Win 7 (IE/Chrome) y Win 10/11 (Edge)
                    try {
                        Start-Process $url
                    }
                    catch {
                        # Fallback: Intento directo si el anterior falla en entornos muy antiguos
                        [System.Diagnostics.Process]::Start($url)
                    }

                    Write-Host "-------------------------------------------------------"
                    Write-Host " "                

                }
                "5.1" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Resetear IP Red LAN"

                    Write-Host "`n******* RESTABLECIMIENTO DE PROTOCOLO IP (TCP/IP) *******" -ForegroundColor Cyan
                    Write-Host "------------------------------------------------------------------" -ForegroundColor Gray

                    $logPath = "C:\temp"
                    $logFile = "$logPath\resetLan.txt"

                    if (-not (Test-Path $logPath)) {
                        New-Item -Path $logPath -ItemType Directory -Force | Out-Null
                    }

                    Write-Host "Iniciando reset de interfaz IP..." -ForegroundColor Yellow

                    & netsh int ip reset $logFile

                    if ($LASTEXITCODE -eq 0) {
                        Write-Host "El protocolo IP se restablecio correctamente." -ForegroundColor Green
                        Write-Host "Log generado en: $logFile" -ForegroundColor Gray
                        Write-Host "NOTA: ES NECESARIO REINICIAR EL EQUIPO PARA APLICAR CAMBIOS." -ForegroundColor Red -BackgroundColor White
                    }
                    else {
                        Write-Host "Ocurrio un error al intentar restablecer el protocolo (Codigo: $LASTEXITCODE)." -ForegroundColor Red
                    }

                    Write-Host "------------------------------------------------------------------" -ForegroundColor Green
                }
                "5.2" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Resetear IP y Asignar DHCP"

                    Write-Host "Resetear IP Red y Asignar DHCP"
                    netsh winsock reset
                    netsh int ip reset c:\resetLan.txt
                    ipconfig /release
                    ipconfig /renew
                    ipconfig /flushdns
                }
                "5.3" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Mostrar Claves MAC Address"

                    getmac /v /fo list
                }
                "5.4" {
                    cabecera
                    menuOpcion "Se encuentra en: Gestion de Red Local -> Actualizacion y Diagnostico de Politicas"

                    Write-Host "ipconfig /flushdns: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    ipconfig /flushdns
                    ipconfig /registerdns
                    ipconfig /displaydns
                        
                    Write-Host "netsh interface ip delete arpcache: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    netsh interface ip delete arpcache
                        
                    Write-Host "netsh winsock reset catalog: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    netsh winsock reset catalog
                        
                    Write-Host "wuauclt /detectnow: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    wuauclt /detectnow
                        
                    Write-Host "GPUPDATE /FORCE: ---------> E J E C U T A N D O <---------" -ForegroundColor Yellow
                    GPUPDATE /FORCE

                    Write-Host "Proceso realizado..." -ForegroundColor Green
                    Write-Host ""
                }
                "11" { 

                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Write-Host "--- INICIANDO LIMPIEZA DE PAPELERA DE RECICLAJE ---" -ForegroundColor Cyan

                    # Intentar el método moderno (Win 10/11) y si falla, usar el método universal (Win 7)
                    try {
                        # El parámetro -Force evita que pida confirmación por cada archivo
                        # -ErrorAction Stop nos permite saltar al 'catch' si el comando no existe
                        Clear-RecycleBin -Confirm:$false -ErrorAction Stop
                        Write-Host "Papelera vaciada usando comando nativo." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Comando nativo no disponible. Usando metodo de compatibilidad (Win 7)..." -ForegroundColor Yellow
                        try {
                            # Método COM: funciona desde Windows XP hasta Windows 11
                            $shell = New-Object -ComObject Shell.Application
                            $recycler = $shell.Namespace(0xa) # 0xa es el ID constante para la Papelera
                            $recycler.Items() | ForEach-Object { Remove-Item $_.Path -Recurse -Force }
                            Write-Host "Papelera vaciada con exito." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "ERROR: No se pudo completar la limpieza." -ForegroundColor Red
                        }
                    }

                    Write-Host "-------------------------------------------------------"
                    Write-Host " "

                }
                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Obtener los parches de seguridad y actualizaciones (QuickFixEngineering)
                    # Usamos Get-WmiObject para asegurar compatibilidad con PS 2.0 (Win 7)
                    Write-Host "Consultando el historial de actualizaciones instaladas..." -ForegroundColor Cyan
                    Write-Host "Esto puede tardar unos segundos dependiendo del equipo..." -ForegroundColor Gray

                    $updates = Get-WmiObject -Class Win32_QuickFixEngineering

                    # 2. Formatear y mostrar la información relevante
                    $reporte = foreach ($update in $updates) {
                        New-Object PSObject -Property @{
                            'ID_Parche'     = $update.HotFixID
                            'Descripcion'   = $update.Description
                            'Instalado_Por' = $update.InstalledBy
                            'Fecha'         = $update.InstalledOn
                        }
                    }

                    # 3. Mostrar tabla organizada por fecha (si es posible)
                    $reporte | Select-Object ID_Parche, Descripcion, Fecha, Instalado_Por | Format-Table -AutoSize



                    Write-Host "-------------------------------------------------------"
                    Write-Host "Total de parches detectados: $($updates.Count)" -ForegroundColor Yellow
                    Write-Host "-------------------------------------------------------"

                    Write-Host " "

                }

                "20" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    # 1. Configuración de pantalla
                    Clear-Host
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "      ANALISIS DE SALUD Y DESGASTE DE LA BATERIA           " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan

                    # 2. Obtener datos de hardware vía WMI (Compatible con Windows 7 en adelante)
                    $battery = Get-WmiObject -Class Win32_Battery

                    if (-not $battery) {
                        Write-Host "ERROR: No se detecto una bateria. Este equipo podria ser una PC de escritorio." -ForegroundColor Red
                        return
                    }

                    # 3. Cálculos de Capacidad y Desgaste
                    # FullChargeCapacity = Capacidad actual máxima
                    # DesignCapacity     = Capacidad de fábrica original
                    $capActual = $battery.FullChargeCapacity
                    $capDiseno = $battery.DesignCapacity

                    if ($capActual -and $capDiseno) {
                        $porcentajeVida = [Math]::Round(($capActual / $capDiseno) * 100, 1)
                        $porcentajeDesgaste = [Math]::Round(100 - $porcentajeVida, 1)
                    }
                    else {
                        $porcentajeVida = "No disponible"
                        $porcentajeDesgaste = "No disponible"
                    }

                    # 4. Resumen en Pantalla
                    Write-Host "`n--- RESUMEN TECNICO ---" -ForegroundColor Yellow
                    Write-Host "Nombre/Modelo:    $($battery.DeviceID)"
                    Write-Host "Quimica:          $($battery.Chemistry)"
                    Write-Host "Capacidad Diseno: $($capDiseno) mWh"
                    Write-Host "Capacidad Actual: $($capActual) mWh"
                    Write-Host ""
                    Write-Host "PORCENTAJE DE VIDA:     " -NoNewline; Write-Host "$porcentajeVida%" -ForegroundColor Green
                    Write-Host "PORCENTAJE DE DESGASTE: " -NoNewline; Write-Host "$porcentajeDesgaste%" -ForegroundColor Red
                    Write-Host "-----------------------------------------------------------"

                    # 5. Generación del Reporte HTML (Solo Windows 8, 10 y 11)
                    $rutaHTML = "C:\estadoBateria.html"
                    $osVersion = [Environment]::OSVersion.Version.Major

                    # Si es Windows 8 o superior (Version 6.2+)
                    if ($osVersion -ge 10 -or ($osVersion -eq 6 -and [Environment]::OSVersion.Version.Minor -ge 2)) {
                        Write-Host "`nGenerando reporte detallado HTML..." -ForegroundColor Cyan
                        try {
                            # Ejecutamos el comando original
                            powercfg /batteryreport /output $rutaHTML
                            
                            if (Test-Path $rutaHTML) {
                                Write-Host "Archivo generado en: $rutaHTML" -ForegroundColor Green
                                Write-Host "Abriendo el reporte en el navegador..." -ForegroundColor Gray
                                Start-Process $rutaHTML
                            }
                        }
                        catch {
                            Write-Host "Error al generar el HTML. Asegurese de ejecutar como Administrador." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "`nNota: El comando /batteryreport no existe en Windows 7." -ForegroundColor Yellow
                        Write-Host "Se ha mostrado el resumen basado en datos de hardware WMI." -ForegroundColor Gray
                    }



                    Write-Host " "


                }
                
                "0" { 
                    #$salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch            
            if (-not $salirSub) { Read-Host "SUB_MENU 23: Presione ENTER para continuar..." }

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.23*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.24 ******************************************************
#**********************************************************************************************************************************
function psSubMenu24 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 24. ***)) LOCAL: COMANDOS WINDOWS 11 *****"
            Write-Host "  1. Abrir Dispositivos e Impresoras."
            Write-Host "  2. Configuracion de Dispositivos General."
            Write-Host "  3. Accesibilidad - Filtros de Color."
            Write-Host "  4. Accesibilidad - Puntero Mouse."
            Write-Host "  5. Accesibilidad - Cursor Texto."
            Write-Host "  6. PANTALLA PRINCIPAL - CONFIGURACION."
            Write-Host "  7. Pantalla de Dispositivos e Impresoras."
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "===================================================================="
            
            $op24 = Read-Host "Seleccione la tarea a realizar"

            switch ($op24) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    Write-Host "--- ABRIENDO PANEL DE DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El comando 'shell:::' funciona en el explorador de archivos de todas las versiones de Windows
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo abrir la ventana de impresoras." -ForegroundColor Red
                    }

                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # Obtener la version mayor del sistema (6 = Win 7/8, 10 = Win 10/11)
                    $osVersion = [Environment]::OSVersion.Version.Major

                    if ($osVersion -ge 10) {
                        Write-Host "Detectado Windows 10/11. Abriendo Configuracion Moderna..." -ForegroundColor Cyan
                        Start-Process "ms-settings:printers"
                    }
                    else {
                        Write-Host "Detectado Windows antiguo. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        Start-Process "control" -ArgumentList "printers"
                    }

                    Write-Host " "

                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    
                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- AABRIENDO CONFIGURACION DE COLOR Y ACCESIBILIDAD ---" -ForegroundColor Cyan
                    
                    # $os = Get-WmiObject Win32_OperatingSystem

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir filtros de color directamente
                        Write-Host "Detectado Windows 10/11. Abriendo Filtros de Color..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad clásico
                        Write-Host "Windows 7/8 detectado. Abriendo Centro de Accesibilidad (Optimizar presentacion visual)..." -ForegroundColor Yellow
                        # El ID 0x17 corresponde a la optimización de pantalla
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"
                        
                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-colorfilter"
                    }

                    Write-Host " "
            
                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE PUNTERO Y MOUSE ---" -ForegroundColor Cyan


                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de Accesibilidad
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    } 
                    else {
                        # Windows 7 y 8: Abrir las Propiedades del Mouse clásicas
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control clasico..." -ForegroundColor Yellow
                        # 'main.cpl' es el archivo de sistema para las propiedades del mouse
                        Start-Process "control.exe" -ArgumentList "main.cpl,,1" 

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-mousepointer"
                    }
                    Write-Host " "

                }            

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"


                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major
                    Write-Host "--- ABRIENDO CONFIGURACION DE CURSOR DE TEXTO ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Abrir la interfaz moderna de accesibilidad del cursor
                        Write-Host "Detectado Windows 10/11. Abriendo configuracion moderna..." -ForegroundColor Green
                        Start-Process "ms-settings:easeofaccess-cursor"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Centro de Accesibilidad en la sección de optimización visual
                        Write-Host "Detectado Windows 7/8. Abriendo Centro de Accesibilidad clasico..." -ForegroundColor Yellow
                        # Esta página permite ajustar el grosor del cursor de parpadeo en versiones antiguas
                        Start-Process "control.exe" -ArgumentList "/name Microsoft.EaseOfAccessCenter", "/page pageVisualOptimization"

                        # Para win 10
                        Write-Host "Windows 10 o posterior..." -ForegroundColor Yellow
                        Start-Process "ms-settings:easeofaccess-cursor"


                    }
                    Write-Host " "

                }
                "6" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"

                    # 1. Identificar la versión del sistema
                    $osVersion = [Environment]::OSVersion.Version.Major

                    Write-Host "--- ABRIENDO CONFIGURACION ADICIONAL (EXTRAS) ---" -ForegroundColor Cyan

                    if ($osVersion -ge 10) {
                        # Windows 10 y 11: Intentar abrir la sección de Extras moderna
                        Write-Host "Detectado Windows 10/11. Abriendo Extras/Configuracion adicional..." -ForegroundColor Green
                        # Nota: Si el fabricante no incluyó extras, esta página podría abrir el Inicio de Configuración
                        Start-Process "ms-settings:extras"
                    } 
                    else {
                        # Windows 7 y 8: Abrir el Panel de Control principal
                        # Dado que 'extras' no existe como tal, abrimos la vista de iconos para que el usuario elija
                        Write-Host "Detectado Windows 7/8. Abriendo Panel de Control (Vista de iconos)..." -ForegroundColor Yellow
                        Start-Process "control.exe"
                    }
                    Write-Host " "

                }

                "7" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op24"
                    
                    Write-Host "--- ACCEDIENDO A DISPOSITIVOS E IMPRESORAS ---" -ForegroundColor Cyan

                    try {
                        # El protocolo 'shell:::' es el método más estable entre versiones de SO
                        Start-Process "shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}"
                        Write-Host "Ventana abierta con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error: No se pudo invocar la interfaz de dispositivos." -ForegroundColor Red
                    }
                    Write-Host " "

                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            }  # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 24: Presione ENTER para continuar..." }
        } #Cierra try

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.24*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.25 ******************************************************
#**********************************************************************************************************************************
function psSubMenu25 {
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

                    # 1. Solicitar los 2 ultimos octeto al usuario
                    # Se usa Read-Host que es el equivalente a 'SET /P'
                    $segmentoFinal = Read-Host "Introduzca los 2 ultimos segmentos IP (192.168.XXX.xxx) y presione Enter"

                    # 2. Construir la dirección IP completa
                    $IPCompleta = "192.168.$segmentoFinal"

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

                    # 1. Entrada de datos
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOcteto

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
                        $sysInfo = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $computerTarget -ErrorAction Stop
                        
                        # Obtenemos la configuracion de red filtrando solo adaptadores físicos activos
                        $nic = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $computerTarget `
                            -Filter "IPEnabled = TRUE" -ErrorAction Stop | 
                        Where-Object { $_.Description -notmatch "Virtual|Pseudo|Bluetooth|VPN" } | 
                        Select-Object -First 1

                        if ($nic) {
                            # 3. Formateo de la salida
                            $dnsActuales = "N/A"
                            if ($nic.DNSServerSearchOrder) {
                                $dnsActuales = $nic.DNSServerSearchOrder -join ", "
                            }
                            $tipoIP = "ESTATICA (MANUAL)"
                            if ($nic.DHCPEnabled) {
                                $tipoIP = "DINAMICA (DHCP)"
                            }

                            Write-Host "`n================================================" -ForegroundColor White
                            Write-Host " INFORMACION DETALLADA DEL EQUIPO" -ForegroundColor Green
                            Write-Host "================================================" -ForegroundColor White
                            
                            Write-Host " HOST NAME:       $($sysInfo.CSName)" -ForegroundColor Cyan
                            Write-Host " DIRECCION MAC:   $($nic.MACAddress)" -ForegroundColor Yellow
                            Write-Host " TIPO DE IP:      $tipoIP"
                            Write-Host "------------------------------------------------"
                            Write-Host " DIRECCION IP:    $($nic.IPAddress[0])"
                            Write-Host " MASCARA:         $($nic.IPSubnet[0])"
                            Write-Host " GATEWAY:         $($nic.DefaultIPGateway -join ', ')"
                            Write-Host " DNS:             $dnsActuales"
                            Write-Host "================================================`n"
                        } 
                        else {
                            Write-Host "No se encontro un adaptador de red activo en $ipRemota." -ForegroundColor Red
                        }
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
                    $baseIP = "192.168.176."
                    $ultimoOctetoActual = Read-Host "Ingrese el ultimo octeto de la IP ACTUAL (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOctetoActual

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
                    $baseIP = "192.168.176."
                    $ultimoOctetoActual = Read-Host "Ingrese el ultimo octeto de la IP ACTUAL (192.168.176.XXX)"
                    $ipRemota = $baseIP + $ultimoOctetoActual

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

                    # Solicitud del ultimo octeto para la IP remota
                    $octeto4 = Read-Host "Ingrese el ULTIMO octeto de la IP remota (192.168.176.XXX)"
                    $ipRemota = "192.168.176.$octeto4"

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

                    # 1. Entrada de red
                    $octeto4 = Read-Host "Ingrese el ULTIMO octeto de la IP remota (192.168.176.XXX)"
                    $ipRemota = "192.168.176.$octeto4"

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

                    $Segmento = "192.168.176."

                    $Octeto = Read-Host "Ingrese el ultimo octeto del segmento 192.168.176.XXX"

                    if ([string]::IsNullOrEmpty($Octeto)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    $IP = $Segmento + $Octeto

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

                    $Segmento = "192.168.176."

                    $Octeto = Read-Host "Ingrese el ultimo octeto del segmento 192.168.176.XXX"

                    if ([string]::IsNullOrEmpty($Octeto)) {
                        Write-Host ""
                        Write-Host "Debe ingresar un valor." -ForegroundColor Red
                        return
                    }

                    $IP = $Segmento + $Octeto

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
                    psHabilitarAdministracionRemota
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

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Definir el segmento de red
                    $segmento = "192.168"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   REINICIO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmento.XXX.xxx"
                    $IPRemota = "$segmento.$ultimoOcteto"

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

                    # 1. Definir el segmento de red
                    $segmento = "192.168"

                    # 2. Solicitar la entrada del usuario (Equivalente a SET /P)
                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "   APAGADO REMOTO DE EQUIPOS (Win 7 - 11)    " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmento.XXX.xxx"
                    $IPRemota = "$segmento.$ultimoOcteto"

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
                    # ==============================================================================
                    $segmentoBase = "192.168"

                    Write-Host "==============================================" -ForegroundColor Cyan
                    Write-Host "     EXPLORADOR DE ESCRITORIO PUBLICO REMOTO  " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    # El usuario debe ingresar algo como "176.80"
                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmentoBase.XXX.xxx"
                    $IPRemota = "$segmentoBase.$ultimoOcteto"

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
                    $segmentoBase = "192.168"

                    Write-Host "`n==============================================" -ForegroundColor Cyan
                    Write-Host "    ACCESO A CARPETA STARTUP (Win 7 - 11)     " -ForegroundColor Cyan
                    Write-Host "==============================================" -ForegroundColor Cyan

                    # El usuario debe ingresar algo como "176.80"
                    $ultimoOcteto = Read-Host "Introduzca los 2 ultimos segmentos IP para $segmentoBase.XXX.xxx"
                    $IPRemota = "$segmentoBase.$ultimoOcteto"

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
                    $ipPC = Read-Host "Introduzca ultimo octeto IP (192.168.176.xxx)"

                    # Convertir la clave segura a texto plano para PsExec (requerido por la herramienta)
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))

                    $IPFinal = "192.168.176.$ipPC"
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
                    $ipPC = Read-Host "Introduzca ultimo octeto IP (192.168.176.xxx)"

                    # Conversión de credencial
                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))

                    $IPFinal = "192.168.176.$ipPC"
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

                    # 1. Entrada de red (Dos últimos octetos)
                    Write-Host "--- Configuracion de Energia GMSANTACRUZ ---" -ForegroundColor Cyan
                    $octeto3 = "176"
                    $octeto4 = Read-Host "Ingrese el CUARTO octeto (192.168.$octeto3.XXX)"
                    $ipRemota = "192.168.$octeto3.$octeto4"

                    # 2. Entrada de tiempo de pantalla
                    Write-Host "`n--- Configuracion de Tiempos ---" -ForegroundColor White
                    $minutosPantalla = Read-Host "Minutos para apagar la PANTALLA (Ej. 30)"

                    # Validación de entradas numéricas
                    if ($octeto3 -notmatch '^\d+$' -or $octeto4 -notmatch '^\d+$' -or $minutosPantalla -notmatch '^\d+$') {
                        Write-Host "ERROR: Todos los valores deben ser numericos." -ForegroundColor Red
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

                    $computer = Read-Host "`nIngrese el nombre o IP de la PC remota"
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
                    $octeto3 = '176'
                    $octeto4 = Read-Host 'Ingrese el CUARTO octeto (192.168.176.XXX)'

                    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    # 2. Captura del último OCTETO con validación simple
                    $baseIP = "192.168.$octeto3."
                    $hostID = $octeto4

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                                
                        try {
                            # 3. Ejecución optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de éxito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos líneas vacías y mostramos la tabla de quser
                                $resultado | Where-Object { $_.Trim() -ne "" }
                            }
                        }
                        catch {
                            Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Debe ingresar solo numeros (0-255)." -ForegroundColor Red
                    }

                    # Pausa para ver los resultados antes de cerrar la consola
                    #Write-Host "`nPresione cualquier tecla para finalizar esta consulta..."
                    # $null = [Console]::ReadKey()   # Esperar a presionar una tecla
                    Write-Host ""
                    Write-Host '========================================================================' -ForegroundColor Yellow
                    # Read-Host "  P R E S I O N E   ||| E N T E R |||   P A R A   C O N T I N U A R ..."
                    # !!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!!
                    $usuarioInput = Read-Host 'Ingrese el NOMBRE DE USUARIO de dominio'
                    $ipRemota = "192.168.$octeto3.$octeto4"

                    if ($octeto4 -notmatch '^\d+$') {
                        Write-Host 'ERROR: El octeto ingresado debe ser un numero valido.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        # exit
                    }

                    if ([string]::IsNullOrEmpty($usuarioInput)) {
                        Write-Host 'ERROR: El nombre de usuario no puede estar vacio.' -ForegroundColor Red
                        $null = Read-Host -Prompt 'Presione ENTER para salir...'
                        # exit
                    }

                    Write-Host ''
                    Write-Host "Verificando enlace de red con $ipRemota..." -ForegroundColor Yellow

                    if (Test-Connection -ComputerName $ipRemota -Count 1 -Quiet) {
                        Mostrar-ImpresorasUsuarioRemoto -ip $ipRemota -usuarioTarget $usuarioInput
                    }
                    else {
                        Write-Host "ERROR: El equipo $ipRemota se encuentra fuera de linea (Offline)." -ForegroundColor Red
                    }

                    # Cierre limpio de consola
                    Write-Host ''                    
            
                }

                "10.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                    # 1. Entrada de datos
                    $baseIP = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $baseIP + $hostID
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
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o IP completa"
                    if ($ultimoOcteto -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        $ipRemota = $ultimoOcteto
                        if ($ultimoOcteto -notmatch "\.") {
                            $ipRemota = $baseIP + $ultimoOcteto
                        }
                        
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
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX) o IP completa"
                    if ($ultimoOcteto -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        $ipRemota = $ultimoOcteto
                        if ($ultimoOcteto -notmatch "\.") {
                            $ipRemota = $baseIP + $ultimoOcteto
                        }
                        
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
                    $baseIP = "192.168.176."
                    $targetInput = Read-Host "Ingrese el ultimo octeto (192.168.176.XXX), IP completa o Nombre de Equipo"
                    if ($targetInput -eq "") { 
                        Write-Host "Operacion cancelada." -ForegroundColor Red
                    }
                    else {
                        # Determinar si es IP o Hostname directamente
                        $targetMachine = ""
                        $ipRemota = ""
                        
                        if ($targetInput -match "^[a-zA-Z]") {
                            $targetMachine = $targetInput
                            Write-Host "Usando Nombre de Equipo proporcionado: $targetMachine" -ForegroundColor Green
                        }
                        else {
                            $ipRemota = $targetInput
                            if ($targetInput -notmatch "\.") {
                                $ipRemota = $baseIP + $targetInput
                            }
                            Write-Host "Direccion IP de destino: $ipRemota" -ForegroundColor Cyan
                            
                            Write-Host "Resolviendo nombre de equipo (Hostname) necesario para la conexion..." -ForegroundColor Cyan
                            try {
                                $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota -ErrorAction Stop
                                $targetMachine = $sys.CSName
                                Write-Host "Nombre de equipo resuelto exitosamente via WMI: $targetMachine" -ForegroundColor Green
                            }
                            catch {
                                try {
                                    $targetMachine = [System.Net.Dns]::GetHostEntry($ipRemota).HostName.Split('.')[0]
                                    Write-Host "Nombre de equipo resuelto via DNS: $targetMachine" -ForegroundColor Green
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
                                            throw "No se pudo resolver"
                                        }
                                    }
                                    catch {
                                        Write-Host "ADVERTENCIA: No se pudo resolver la IP a un Nombre de Equipo automaticamente." -ForegroundColor Yellow
                                        $manualHost = Read-Host "Ingrese el NOMBRE DE EQUIPO (Hostname) del equipo remoto manualmente (Deje vacio para usar IP)"
                                        if ($manualHost -ne "") {
                                            $targetMachine = $manualHost
                                        } else {
                                            $targetMachine = $ipRemota
                                        }
                                    }
                                }
                            }
                        }
                        
                        if ([string]::IsNullOrEmpty($targetMachine)) {
                            Write-Host "ERROR: Se requiere un nombre de equipo para continuar." -ForegroundColor Red
                        }
                        else {
                            # --- 1. SELECCION DE AUTENTICACION ---
                            Write-Host "`n--- OPCIONES DE AUTENTICACION ---" -ForegroundColor Yellow
                            Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Credenciales integradas)"
                            Write-Host " [2] Usuario de Dominio (Active Directory - ej: DOMINIO\usuario)"
                            Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador o NOMBREPC\Administrador)"
                            $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
                            if ($authOpt -eq "") { $authOpt = "1" }
                            
                            $cred = $null
                            $usu = ""
                            $claTexto = ""
                            
                            if ($authOpt -eq "2") {
                                $domDefecto = $env:USERDOMAIN
                                Write-Host "Dominio detectado localmente: $domDefecto" -ForegroundColor Cyan
                                $dom = Read-Host "Ingrese el nombre del Dominio (Presione Enter para usar '$domDefecto')"
                                if ($dom -eq "") { $dom = $domDefecto }
                                $usuSimple = Read-Host "Ingrese el nombre de usuario de Dominio"
                                if ($usuSimple -ne "") {
                                    $usu = "$dom\$usuSimple"
                                    $cla = Read-Host "Ingrese la contrasena del usuario" -AsSecureString
                                    $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                                    $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
                                }
                            }
                            elseif ($authOpt -eq "3") {
                                $usuSimple = Read-Host "Ingrese el nombre del Administrador Local (ej: Administrador)"
                                if ($usuSimple -ne "") {
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

                            # --- 2. SELECCION DE METODO DE CONEXION ---
                            Write-Host "`n--- METODOS DE CONEXION DISPONIBLES ---" -ForegroundColor Yellow
                            Write-Host " [1] Auto-detectar (Intentar WinRM primero, si falla o esta cerrado usar PsExec)"
                            Write-Host " [2] Forzar WinRM (PowerShell Remoting - Puerto 5985/5986)"
                            Write-Host " [3] Forzar PsExec (Microsoft Sysinternals - Puerto SMB 445)"
                            $connOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
                            if ($connOpt -eq "") { $connOpt = "1" }

                            # --- 3. RUTA DE ORIGEN OFFLINE (OPCIONAL) ---
                            $sourcePath = Read-Host "Ingrese la ruta de origen local o red (Source) de los archivos FOD/RSAT (Deje vacio para descargar desde Internet)"

                            # --- 4. DIAGNOSTICO DE CONECTIVIDAD Y PUERTOS ---
                            Write-Host "`n[*] Iniciando diagnostico de red..." -ForegroundColor Cyan
                            $pingOk = Test-Connection -ComputerName $targetMachine -Count 1 -Quiet
                            if ($pingOk) {
                                Write-Host "[+] Ping exitoso a $targetMachine." -ForegroundColor Green
                            } else {
                                Write-Host "[-] El equipo no responde a Ping (puede tener ICMP bloqueado en el firewall)." -ForegroundColor Yellow
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

                            # --- 5. DETERMINAR METODO A USAR ---
                            $usarWinRM = $false
                            $usarPsExec = $false

                            if ($connOpt -eq "2") {
                                $usarWinRM = $true
                            }
                            elseif ($connOpt -eq "3") {
                                $usarPsExec = $true
                            }
                            else {
                                # Auto-detectar
                                if ($port5985) {
                                    $usarWinRM = $true
                                    Write-Host "[*] Auto-detectado: Usando WinRM ya que el puerto 5985 esta abierto." -ForegroundColor Cyan
                                }
                                elseif ($port445) {
                                    $usarPsExec = $true
                                    Write-Host "[*] Auto-detectado: Usando PsExec ya que el puerto 445 esta abierto y WinRM cerrado." -ForegroundColor Cyan
                                }
                                else {
                                    # Fallback general
                                    $usarWinRM = $true
                                    Write-Host "[*] Ningun puerto responde. Se intentara WinRM por defecto." -ForegroundColor Yellow
                                }
                            }

                            # --- 6. DEFINIR EL SCRIPTBLOCK DE INSTALACION ---
                            $scriptString = {
                                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force
                                Import-Module -Name Dism -ErrorAction SilentlyContinue

                                if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                                    throw "El cmdlet 'Get-WindowsCapability' no esta disponible en este equipo. Requiere Windows 10/11 o Windows Server 2016 o posterior."
                                }

                                # --- A. CONFIGURACION DE SERVICIOS CRITICOS ---
                                $servicios = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
                                $originalStates = @{}

                                Write-Output "[*] Configurando servicios de actualizacion en la PC remota..."
                                foreach ($serv in $servicios) {
                                    $s = Get-Service -Name $serv -ErrorAction SilentlyContinue
                                    if ($s) {
                                        # Guardar estado actual
                                        $wmiServ = Get-WmiObject -Class Win32_Service -Filter "Name='$serv'"
                                        if ($wmiServ) {
                                            $originalStates[$serv] = @{
                                                "StartMode" = $wmiServ.StartMode
                                                "State" = $s.Status
                                            }

                                            # Si el servicio esta deshabilitado, cambiar a Manual
                                            if ($wmiServ.StartMode -eq "Disabled") {
                                                Write-Output " -> Cambiando temporalmente $serv a modo Manual..."
                                                $wmiServ.ChangeStartMode("Manual") | Out-Null
                                            }
                                        }

                                        # Si el servicio no esta corriendo, iniciarlo
                                        if ($s.Status -ne "Running") {
                                            Write-Output " -> Iniciando servicio $serv..."
                                            Start-Service -Name $serv -ErrorAction SilentlyContinue
                                        }
                                    }
                                }

                                # --- B. CONFIGURACION DE PROXY ---
                                $proxyModificado = $false
                                if ([string]::IsNullOrEmpty($offlineSource)) {
                                    $proxyQuery = netsh winhttp show proxy
                                    if ($proxyQuery -match "Direct access" -or $proxyQuery -match "Acceso directo") {
                                        Write-Output "[*] Configurando temporalmente el proxy del sistema importandolo desde IE..."
                                        $importResult = netsh winhttp import proxy source=ie
                                        if ($importResult -match "Simple Proxy" -or $importResult -match "Proxy de servidor" -or $importResult -match "bypass") {
                                            $proxyModificado = $true
                                        }
                                    }
                                }

                                # --- C. BYPASS DE WSUS PARA INSTALACION DESDE INTERNET ---
                                $wsusRegPath = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU"
                                $servicingRegPath = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"
                                
                                $originalUseWUServer = $null
                                $originalRepairContentSource = $null
                                $wsusBypassed = $false
                                $servicingModified = $false

                                if ([string]::IsNullOrEmpty($offlineSource)) {
                                    # Desactivar WSUS
                                    if (Test-Path $wsusRegPath) {
                                        $val = Get-ItemProperty -Path $wsusRegPath -Name "UseWUServer" -ErrorAction SilentlyContinue
                                        if ($val -and $val.UseWUServer -eq 1) {
                                            Write-Output "[*] Detectado servidor WSUS activo. Desactivando UseWUServer temporalmente..."
                                            $originalUseWUServer = 1
                                            Set-ItemProperty -Path $wsusRegPath -Name "UseWUServer" -Value 0 -Force -ErrorAction SilentlyContinue
                                            $wsusBypassed = $true
                                        }
                                    }

                                    # Forzar la fuente de descarga en Servicing
                                    if (-not (Test-Path $servicingRegPath)) {
                                        New-Item -Path $servicingRegPath -Force | Out-Null
                                    }
                                    $valServ = Get-ItemProperty -Path $servicingRegPath -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
                                    if ($valServ) {
                                        $originalRepairContentSource = $valServ.RepairContentServerSource
                                    }
                                    Write-Output "[*] Configurando descarga directa desde servidores de Microsoft Update..."
                                    Set-ItemProperty -Path $servicingRegPath -Name "RepairContentServerSource" -Value 2 -Force -ErrorAction SilentlyContinue
                                    Set-ItemProperty -Path $servicingRegPath -Name "UseWindowsUpdate" -Value 1 -Force -ErrorAction SilentlyContinue
                                    $servicingModified = $true

                                    if ($wsusBypassed -or $servicingModified) {
                                        Write-Output "[*] Reiniciando servicio de Windows Update para aplicar directivas..."
                                        Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                                    }
                                }

                                # --- D. INSTALACION ---
                                try {
                                    Write-Output "[*] Escaneando componentes de RSAT..."
                                    $capabilities = Get-WindowsCapability -Online | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
                                    if ($capabilities.Count -eq 0) {
                                        Write-Output "[+] Todos los componentes de RSAT ya estan instalados en este equipo."
                                    }
                                    else {
                                        Write-Output "[+] Se encontraron $($capabilities.Count) componentes pendientes de instalacion."
                                        foreach ($cap in $capabilities) {
                                            Write-Output "`n[+] Iniciando instalacion de $($cap.Name)..."
                                            $success = $false
                                            $err = ""
                                            try {
                                                if (-not [string]::IsNullOrEmpty($offlineSource)) {
                                                    Write-Output " -> Instalando desde origen offline: $offlineSource"
                                                    Add-WindowsCapability -Online -Name $cap.Name -Source $offlineSource -LimitAccess -ErrorAction Stop | Out-Null
                                                }
                                                else {
                                                    Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                                                }
                                                Write-Output "[OK] Se instalo: $($cap.Name)"
                                                $success = $true
                                            }
                                            catch {
                                                $err = $_.Exception.Message
                                                Write-Output "[ERROR] Fallo al instalar $($cap.Name): $err"
                                            }
                                        }
                                        Write-Output "`n[+] Proceso de instalacion finalizado."
                                    }
                                }
                                finally {
                                    # --- E. RESTAURAR CONFIGURACIONES ---
                                    Write-Output "`n[*] Restaurando configuraciones del sistema original..."
                                    
                                    # Restaurar Proxy
                                    if ($proxyModificado) {
                                        Write-Output " -> Restableciendo proxy WinHTTP..."
                                        netsh winhttp reset proxy | Out-Null
                                    }

                                    # Restaurar Registro
                                    $needWuRestart = $false
                                    if ($wsusBypassed -and $originalUseWUServer -ne $null) {
                                        Write-Output " -> Re-habilitando UseWUServer..."
                                        Set-ItemProperty -Path $wsusRegPath -Name "UseWUServer" -Value $originalUseWUServer -Force -ErrorAction SilentlyContinue
                                        $needWuRestart = $true
                                    }
                                    if ($servicingModified) {
                                        if ($originalRepairContentSource -ne $null) {
                                            Write-Output " -> Restaurando RepairContentServerSource ($originalRepairContentSource)..."
                                            Set-ItemProperty -Path $servicingRegPath -Name "RepairContentServerSource" -Value $originalRepairContentSource -Force -ErrorAction SilentlyContinue
                                        } else {
                                            Write-Output " -> Eliminando RepairContentServerSource..."
                                            Remove-ItemProperty -Path $servicingRegPath -Name "RepairContentServerSource" -ErrorAction SilentlyContinue
                                        }
                                        Remove-ItemProperty -Path $servicingRegPath -Name "UseWindowsUpdate" -ErrorAction SilentlyContinue
                                        $needWuRestart = $true
                                    }

                                    if ($needWuRestart) {
                                        Write-Output " -> Aplicando cambios al servicio Windows Update..."
                                        Restart-Service -Name "wuauserv" -Force -ErrorAction SilentlyContinue
                                    }

                                    # Restaurar Servicios
                                    foreach ($serv in $servicios) {
                                        if ($originalStates.ContainsKey($serv)) {
                                            $orig = $originalStates[$serv]
                                            $s = Get-Service -Name $serv -ErrorAction SilentlyContinue
                                            if ($s) {
                                                # Detener si no estaba corriendo originalmente
                                                if ($orig.State -ne "Running" -and $s.Status -eq "Running") {
                                                    Write-Output " -> Deteniendo servicio $serv..."
                                                    Stop-Service -Name $serv -Force -ErrorAction SilentlyContinue
                                                }
                                                # Cambiar a Disabled si originalmente estaba deshabilitado
                                                if ($orig.StartMode -eq "Disabled") {
                                                    Write-Output " -> Deshabilitando servicio $serv..."
                                                    $wmiServ = Get-WmiObject -Class Win32_Service -Filter "Name='$serv'"
                                                    if ($wmiServ) {
                                                        $wmiServ.ChangeStartMode("Disabled") | Out-Null
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    Write-Output "[+] Restauracion completada con exito."
                                }
                            }

                            # --- 7. EJECUCION DE LOS METODOS ---
                            $exitoEjecucion = $false

                            # --- RUTA DE PSEXEC ---
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            $psexecFound = $false
                            if (Test-Path $psexecPath) {
                                $psexecFound = $true
                            } else {
                                # Buscar en el directorio actual
                                if (Test-Path ".\PsExec.exe") {
                                    $psexecPath = ".\PsExec.exe"
                                    $psexecFound = $true
                                } else {
                                    $where = Get-Command psexec -ErrorAction SilentlyContinue
                                    if ($where) {
                                        $psexecPath = $where.Definition
                                        $psexecFound = $true
                                    }
                                }
                            }

                            # --- INTENTO WINRM ---
                            if ($usarWinRM) {
                                Write-Host "`n[*] Iniciando instalacion remota via WinRM (Invoke-Command)..." -ForegroundColor Yellow
                                if ($usu -ne "") {
                                    Write-Host "Usando credenciales explicitas de: $usu" -ForegroundColor Cyan
                                } else {
                                    Write-Host "Usando credenciales del usuario actual..." -ForegroundColor Cyan
                                }

                                try {
                                    $paramPrefix = "`$offlineSource = `"$sourcePath`"`n"
                                    $fullScriptText = $paramPrefix + $scriptString.ToString()
                                    $sb = [ScriptBlock]::Create($fullScriptText)
                                    
                                    if ($cred -ne $null) {
                                        Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sb -ErrorAction Stop
                                    } else {
                                        Invoke-Command -ComputerName $targetMachine -ScriptBlock $sb -ErrorAction Stop
                                    }
                                    Write-Host "[OK] Instalacion finalizada via WinRM con éxito!" -ForegroundColor Green
                                    $exitoEjecucion = $true
                                }
                                catch {
                                    Write-Host "[-] Error al ejecutar via WinRM: $($_.Exception.Message)" -ForegroundColor Red
                                    if ($connOpt -eq "1" -and $port445 -and $psexecFound) {
                                        Write-Host "[*] Fallback: Intentando con PsExec de manera automatica..." -ForegroundColor Yellow
                                        $usarPsExec = $true
                                    } else {
                                        Write-Host "Asegurese de que la PC de destino tenga habilitado WinRM y el firewall permita la conexion (puerto 5985/5986)." -ForegroundColor Yellow
                                        if (-not $psexecFound) {
                                            Write-Host "Sugerencia: Coloque PsExec.exe en C:\PSTools o en la carpeta del script para tener una alternativa potente." -ForegroundColor Cyan
                                        }
                                    }
                                }
                            }

                            # --- INTENTO PSEXEC ---
                            if ($usarPsExec -and -not $exitoEjecucion) {
                                if (-not $psexecFound) {
                                    Write-Host "`n[ERROR] Se requiere PsExec pero no se encontro PsExec.exe en C:\PSTools, en el PATH, ni en la carpeta actual." -ForegroundColor Red
                                    Write-Host "Por favor, descargue PsExec desde Microsoft Sysinternals e instálelo para usar esta opcion." -ForegroundColor Cyan
                                }
                                else {
                                    Write-Host "`n[*] Iniciando instalacion remota via PsExec (Contexto SYSTEM)..." -ForegroundColor Yellow
                                    
                                    # Preparar script
                                    $paramPrefix = "`$offlineSource = `"$sourcePath`"`n"
                                    $fullScriptText = $paramPrefix + $scriptString.ToString()

                                    # Codificar en Base64
                                    $bytes = [System.Text.Encoding]::Unicode.GetBytes($fullScriptText)
                                    $encoded = [Convert]::ToBase64String($bytes)
                                    
                                    # Argumentos basicos
                                    $argsBase = "-accepteula -h -s powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"

                                    # Si hay credenciales, las inyectamos
                                    if ($usu -ne "") {
                                        Write-Host "Usando credenciales explicitas de: $usu" -ForegroundColor Cyan
                                        # En PsExec, si no usamos -s, corre en el contexto del usuario pero elevado por -h.
                                        # Pero RSAT requiere privilegios SYSTEM o Administrador Local muy elevados.
                                        # Intentamos correr como SYSTEM y autenticar SMB con las credenciales dadas.
                                        $argsFull = "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argsBase"
                                    }
                                    else {
                                        Write-Host "Usando credenciales del usuario actual..." -ForegroundColor Cyan
                                        $argsFull = "\\$targetMachine $argsBase"
                                    }

                                    try {
                                        Write-Host "Ejecutando PsExec en: $psexecPath" -ForegroundColor Gray
                                        $p = Start-Process -FilePath $psexecPath -ArgumentList $argsFull -Wait -NoNewWindow -PassThru -ErrorAction Stop
                                        if ($p -and $p.ExitCode -eq 0) {
                                            Write-Host "[OK] Instalacion finalizada via PsExec con exito!" -ForegroundColor Green
                                            $exitoEjecucion = $true
                                        } else {
                                            $codigo = if ($p) { $p.ExitCode } else { "N/A" }
                                            Write-Host "[-] PsExec retorno un codigo de error: $codigo." -ForegroundColor Red
                                            
                                            # Si fallo con el usuario actual y con -s, puede ser que el sistema requiera token de usuario.
                                            # Intentamos correr sin -s (en el contexto del usuario proporcionado directamente)
                                            if ($usu -ne "") {
                                                Write-Host "[*] Reintentando PsExec sin el parametro -s (modo Usuario Administrativo)..." -ForegroundColor Yellow
                                                $argsNoSystem = "\\$targetMachine -u `"$usu`" -p `"$claTexto`" -accepteula -h powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                                                $p2 = Start-Process -FilePath $psexecPath -ArgumentList $argsNoSystem -Wait -NoNewWindow -PassThru -ErrorAction Stop
                                                if ($p2 -and $p2.ExitCode -eq 0) {
                                                    Write-Host "[OK] Instalacion finalizada via PsExec en modo Usuario Administrativo!" -ForegroundColor Green
                                                    $exitoEjecucion = $true
                                                } else {
                                                    $codigo2 = if ($p2) { $p2.ExitCode } else { "N/A" }
                                                    Write-Host "[-] El reintento de PsExec sin -s tambien fallo (Codigo: $codigo2)." -ForegroundColor Red
                                                }
                                            }
                                        }
                                    }
                                    catch {
                                        Write-Host "[-] Error al ejecutar PsExec: $($_.Exception.Message)" -ForegroundColor Red
                                    }
                                }
                            }

                            if ($exitoEjecucion) {
                                Write-Host "`n========================================================" -ForegroundColor Green
                                Write-Host "   PROCESO DE INSTALACION DE RSAT REMOTO COMPLETADO" -ForegroundColor White -BackgroundColor DarkGreen
                                Write-Host "========================================================" -ForegroundColor Green
                            } else {
                                Write-Host "`n========================================================" -ForegroundColor Red
                                Write-Host "      ERROR: NO SE PUDO INSTALAR RSAT EN LA PC REMOTA" -ForegroundColor White -BackgroundColor DarkRed
                                Write-Host "========================================================" -ForegroundColor Red
                                Write-Host "Revise los errores de conexion anteriores." -ForegroundColor Yellow
                            }
                        }
                    }
                }

                "13" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"

                                        
                    Write-Host " "
                    Read-Host "Presione ENTER para continuar..."

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
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
function psSubMenu26 {
    # Detección y fallback de Active Directory usando ADSI (LDAP nativo sin RSAT)
    if (-not (Get-Command Get-ADUser -ErrorAction SilentlyContinue)) {
        Write-Host "[INFO] Modulo ActiveDirectory (RSAT) no detectado. Cargando emulacion LDAP nativa..." -ForegroundColor Yellow
        Start-Sleep -Milliseconds 500

        # Declarar funciones de compatibilidad
        function Get-ADUser {
            param(
                [Parameter(Position=0, Mandatory=$true)]
                [string]$Identity,
                [Parameter(Position=1)]
                [string[]]$Properties
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                
                # Función para traducir fechas de LargeInteger
                filter Get-ADDate {
                    if ($null -eq $_ -or $_.Value -eq 0 -or $_.Value -eq 9223372036854775807) { return $null }
                    try {
                        if ($_ -is [System.Int64] -or $_ -is [System.Int32]) {
                            return [DateTime]::FromFileTime($_)
                        }
                        # Intento de invocacion de LargeInteger compatible con PowerShell 2.0 (sin -shl)
                        $high = $_.GetType().InvokeMember("HighPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $low = $_.GetType().InvokeMember("LowPart", [System.Reflection.BindingFlags]::GetProperty, $null, $_, $null)
                        $intVal = ([int64]$high * 4294967296) + [uint32]$low
                        return [DateTime]::FromFileTime($intVal)
                    } catch {}
                    return $null
                }

                $prop = @{}
                $prop["Name"] = [string]$entry.Properties["name"].Value
                $prop["DisplayName"] = [string]$entry.Properties["displayName"].Value
                $prop["SamAccountName"] = [string]$entry.Properties["samAccountName"].Value
                $prop["Title"] = [string]$entry.Properties["title"].Value
                $prop["Office"] = [string]$entry.Properties["physicalDeliveryOfficeName"].Value
                $prop["Department"] = [string]$entry.Properties["department"].Value
                $prop["Description"] = [string]$entry.Properties["description"].Value
                $prop["OfficePhone"] = [string]$entry.Properties["telephoneNumber"].Value
                $prop["PostalCode"] = [string]$entry.Properties["postalCode"].Value
                $prop["GivenName"] = [string]$entry.Properties["givenName"].Value
                $prop["Surname"] = [string]$entry.Properties["sn"].Value
                $prop["UserPrincipalName"] = [string]$entry.Properties["userPrincipalName"].Value
                $prop["ObjectClass"] = [string]$entry.SchemaClassName
                if ($entry.Guid) {
                    $prop["ObjectGUID"] = [Guid]$entry.Guid
                } else {
                    $prop["ObjectGUID"] = $null
                }

                if ($entry.Properties["objectSid"].Value) { 
                    $prop["SID"] = (New-Object System.Security.Principal.SecurityIdentifier($entry.Properties["objectSid"].Value, 0)).Value 
                } else {
                    $prop["SID"] = $null
                }

                $uac = $entry.Properties["userAccountControl"].Value
                if ($uac) {
                    $prop["Enabled"] = -not ($uac -band 2)
                    $prop["PasswordExpired"] = [bool]($uac -band 0x800000)
                    $prop["PasswordNeverExpires"] = [bool]($uac -band 0x10000)
                } else {
                    $prop["Enabled"] = $true
                    $prop["PasswordExpired"] = $false
                    $prop["PasswordNeverExpires"] = $false
                }

                $prop["PasswordLastSet"] = $entry.Properties["pwdLastSet"].Value | Get-ADDate
                $prop["AccountExpirationDate"] = $entry.Properties["accountExpires"].Value | Get-ADDate
                
                $lastLogonVal = $entry.Properties["lastLogonTimestamp"].Value
                if ($null -eq $lastLogonVal) { $lastLogonVal = $entry.Properties["lastLogon"].Value }
                $prop["LastLogonDate"] = $lastLogonVal | Get-ADDate

                $managerDN = $entry.Properties["manager"].Value
                if ($managerDN) {
                    $prop["Manager"] = ($managerDN -split ',')[0].Replace('CN=','')
                } else {
                    $prop["Manager"] = $null
                }

                $groups = @()
                foreach ($g in $entry.Properties["memberOf"]) {
                    $groups += $g
                }
                $prop["MemberOf"] = $groups

                return New-Object PSObject -Property $prop
            }
            return $null
        }

        function Set-ADAccountPassword {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Identity,
                [Parameter(Mandatory=$true)]
                [System.Security.SecureString]$NewPassword,
                [switch]$Reset
            )
            
            $BSTR = [System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($NewPassword)
            $PlainPassword = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                $entry.Invoke("SetPassword", $PlainPassword)
                $entry.CommitChanges()
            } else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }

        function Set-ADUser {
            param(
                [Parameter(Mandatory=$true)]
                [string]$Identity,
                [bool]$ChangePasswordAtLogon
            )
            
            $searcher = [adsisearcher]"(samAccountName=$Identity)"
            $result = $searcher.FindOne()
            if ($result) {
                $entry = $result.GetDirectoryEntry()
                if ($ChangePasswordAtLogon) {
                    $entry.Properties["pwdLastSet"].Value = 0
                } else {
                    $entry.Properties["pwdLastSet"].Value = -1
                }
                $entry.CommitChanges()
            } else {
                throw "No se pudo encontrar al usuario '$Identity' en el dominio."
            }
        }
    }

    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 26. ===)) AD: COMANDOS AD ====="
            Write-Host "  1. GESTION DE USUARIO DE DOMINIO | ACTIVE DIRECTORY |"
            Write-Host "    1.1 Mostrar Datos de Usuario de Dominio con C.I, Cargo, Lugar."
            Write-Host "    1.2 Mostrar ultima conexion de Usuario"
            Write-Host "    1.3 Mostrar Datos de Usuario de Dominio, fecha cambio clave." -ForegroundColor Green
            Write-Host "    1.4. Cambiar Clave de Usuario de Dominio." -ForegroundColor Red
            Write-Host "    1.5 Reporte detallado de Usuario de Dominio."
            Write-Host ""
            Write-Host "  2. GESTION DE USUARIO REMOTO RECURSOS COMPARTIDOS"
            Write-Host "    2.1 Mostrar usuario PC Remota." -ForegroundColor Cyan
            Write-Host "    2.2 Mostrar usuarios activos y no activos del Dominio - PC Remota." -ForegroundColor Cyan
            Write-Host "    2.5 Mostrar Carpetas Compartidas en PC Remota."
            Write-Host ""
            Write-Host "  3. GESTION DE USUARIO | USUARIO LOCAL |"
            Write-Host "    3.1 Cambiar contrasenia de USUARIO LOCAL en PC REMOTO" -ForegroundColor Cyan            
            Write-Host ""
            Write-Host "  30. REFRESH." -ForegroundColor Red
            Write-Host "  31. REFRESH DESDE GITHUB (ONLINE)." -ForegroundColor Cyan
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Header "==============================="
            
            $op26 = Read-Host "Seleccione la tarea a realizar"

            switch ($op26) {
                "1.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "OfficePhone : Carnet de Identidad de persona" -ForegroundColor Cyan
                    Write-Host ""
                    # 1. Solicitar el nombre de usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir las propiedades extendidas que queremos extraer
                    $propiedades = @(
                        "Description",    # Descripción
                        "Title",          # Cargo / Puesto
                        "Office",         # Oficina (PhysicalDeliveryOfficeName)
                        "Department",     # Área / Departamento
                        "Manager",        # Dependencia (Jefe Directo)
                        "OfficePhone",    # Teléfono
                        "PostalCode",     # Código Postal
                        "SID"             # Identificador de Seguridad
                    )

                    try {
                        # Ejecutar la consulta y forzar el formato de lista detallada
                        Get-ADUser -Identity $dato -Properties $propiedades | Format-List `
                            DistinguishedName, 
                        Enabled, 
                        GivenName, 
                        Name, 
                        ObjectClass, 
                        ObjectGUID, 
                        @{Label = "Cargo"; Expression = { $_.Title } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Area"; Expression = { $_.Department } },
                        @{Label = "Dependencia (Manager)"; Expression = { $_.Manager } },
                        OfficePhone, 
                        PostalCode, 
                        SamAccountName, 
                        SID, 
                        Surname, 
                        UserPrincipalName
                    }
                    catch {
                        Write-Host "Error: No se encontro al usuario '$dato' o no hay conexion con el AD." -ForegroundColor Red
                    }

                }
                "1.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario
                    $usuario = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. Obtener datos básicos y última conexión del AD
                        $adUser = Get-ADUser -Identity $usuario -Properties LastLogonDate, Description, Title

                        if ($adUser) {
                            Write-Host "--- INFORMACION DE CONEXION ---" -ForegroundColor Cyan
                            Write-Host "Usuario:        $($adUser.Name)"
                            Write-Host "Ultimo Logueo:  $($adUser.LastLogonDate)"
                            Write-Host "Estado:         $(if($adUser.Enabled){'Activo'}else{'Deshabilitado'})"
                            
                            # 3. Intentar obtener los equipos desde los Logs de Seguridad (Event ID 4624)
                            # Nota: Esto requiere privilegios de admin y que los logs no se hayan sobrescrito
                            Write-Host "Buscando rastros en logs de seguridad (esto puede tardar)..." -ForegroundColor Yellow
                            
                            $hoy = Get-Date
                            $eventos = Get-WinEvent -FilterHashtable @{
                                LogName   = 'Security'; 
                                ID        = 4624; 
                                StartTime = $hoy.AddDays(-7) # Últimos 7 días
                            } -ErrorAction SilentlyContinue | Where-Object {
                                $_.Properties[5].Value -eq $usuario
                            }

                            if ($eventos) {
                                Write-Host "Equipos detectados recientemente:" -ForegroundColor Green
                                $eventos | ForEach-Object {
                                    $computadora = $_.Properties[18].Value
                                    if ($computadora -and $computadora -ne "-") {
                                        $fecha = $_.TimeCreated
                                        Write-Host "- [$fecha] en el equipo: $computadora"
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "No se encontraron registros recientes en los logs locales de este equipo." -ForegroundColor Gray
                            }
                        }
                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario o acceder a los logs." -ForegroundColor Red
                    }


                }

                "1.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar usuario
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    # 2. Definir propiedades a consultar
                    $props = @(
                        "PasswordExpired", "PasswordLastSet", "PasswordNeverExpires", 
                        "AccountExpirationDate", "MemberOf", "Description", 
                        "Office", "OfficePhone", "DisplayName"
                    )

                    try {
                        $user = Get-ADUser -Identity $dato -Properties $props

                        # 3. Determinar lógica de expiración de cuenta
                        $estadoExp = if ($null -eq $user.AccountExpirationDate) { "Sin fecha de expiracion" } 
                        else { "Expira el: $($user.AccountExpirationDate)" }

                        # 4. Mostrar Resumen Corto pero Completo
                        Write-Host "--- RESUMEN DE USUARIO: $($user.DisplayName) ---" -ForegroundColor Cyan
                        
                        $user | Select-Object `
                        @{Label = "Nombre Completo"; Expression = { $_.DisplayName } },
                        @{Label = "Estado Cuenta"; Expression = { if ($_.Enabled) { "Activo" }else { "Deshabilitado" } } },
                        @{Label = "Oficina"; Expression = { $_.Office } },
                        @{Label = "Descripcion"; Expression = { $_.Description } },
                        @{Label = "Ultimo Cambio Pass"; Expression = { $_.PasswordLastSet } },
                        @{Label = "Pass Expirada"; Expression = { $_.PasswordExpired } },
                        @{Label = "Pass Nunca Expira"; Expression = { $_.PasswordNeverExpires } },
                        @{Label = "Expiracion de Usuario"; Expression = { $estadoExp } } | 
                        Format-List

                        # Apartado de Grupos (Resumen corto)
                        Write-Host "Membresia de Grupos:" -ForegroundColor Yellow
                        $user.MemberOf | ForEach-Object { Write-Host " - $(($_ -split ',')[0].Replace('CN=',''))" }

                    }
                    catch {
                        Write-Host "Error: No se pudo encontrar al usuario '$dato'." -ForegroundColor Red
                    }


                }

                "1.4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Solicitar el nombre de usuario (Equivalente a SET /P)
                    $usuarioAD = Read-Host "Introduzca el usuario de dominio"

                    # 2. Solicitar la contraseña de forma segura (Asteriscos)
                    # Usamos un bloque try/catch para manejar errores de permisos o de usuario no encontrado
                    try {
                        Write-Host "Preparando cambio de contrasenia para: $usuarioAD" -ForegroundColor Cyan
                        
                        # Captura la contraseña de forma segura (AsSecureString oculta la entrada)
                        $NuevaContrasenia = Read-Host "Introduzca la nueva contrasenia para $usuarioAD" -AsSecureString

                        # 3. Aplicar el cambio (Equivalente a Reset de Administrador)
                        Set-ADAccountPassword -Identity $usuarioAD -NewPassword $NuevaContrasenia -Reset
                        
                        # 4. Forzar que el usuario cambie la contraseña en el próximo inicio de sesión (Opcional pero recomendado)
                        Set-ADUser -Identity $usuarioAD -ChangePasswordAtLogon $false

                        Write-Host "EXITO: La contrasenia se ha actualizado correctamente." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "ERROR: No se pudo cambiar la contrasenia." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor White
                    }

                    

                }            

                "1.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Entrada de datos
                    $dato = Read-Host "Introduzca el usuario de dominio"

                    try {
                        # 2. Obtención de datos extendidos
                        # Agregamos: Enabled (Estado), Office (Oficina) y Description (Descripción)
                        $user = Get-ADUser -Identity $dato -Properties LastLogonDate, MemberOf, AccountExpirationDate, Title, Department, PasswordLastSet, Enabled, Office, Description

                        if ($user) {
                            Write-Host "`n====================================================" -ForegroundColor Cyan
                            Write-Host "   REPORTE DETALLADO DE SEGURIDAD: $($user.Name)"
                            Write-Host "====================================================" -ForegroundColor Cyan

                            # --- NUEVO APARTADO: DATOS DE FILIACIÓN ---
                            Write-Host "[*] DATOS GENERALES:" -ForegroundColor Yellow
                            $estado = if ($user.Enabled) { "ACTIVO" } else { "DESHABILITADO" }
                            Write-Host "    Estado Usuario: $estado"
                            Write-Host "    Oficina:        $($user.Office)"
                            Write-Host "    Descripcion:    $($user.Description)"
                            Write-Host "    Cargo:          $($user.Title)"
                            Write-Host "    Area/Depto:     $($user.Department)"

                            # --- APARTADO: ULTIMO CAMBIO DE CONTRASEÑA ---
                            Write-Host "`n[*] FECHA ULTIMO CAMBIO DE CONTRASENIA:" -ForegroundColor Yellow
                            if ($user.PasswordLastSet) { 
                                Write-Host "    $($user.PasswordLastSet)" 
                            }
                            else { 
                                Write-Host "    El usuario nunca ha cambiado su contrasenia." 
                            }
                            
                            # --- APARTADO: CONEXIÓN Y ESTADO ---
                            Write-Host "`n[*] ULTIMA CONEXION ESTABLECIDA:" -ForegroundColor Yellow
                            if ($user.LastLogonDate) { 
                                Write-Host "    $($user.LastLogonDate)" 
                            }
                            else { 
                                Write-Host "    Nunca ha iniciado sesión o el dato no se ha replicado." 
                            }

                            # --- APARTADO: EXPIRACIÓN DE CUENTA ---
                            Write-Host "`n[*] ESTADO DE LA CUENTA Y EXPIRACION:" -ForegroundColor Yellow
                            if ($null -eq $user.AccountExpirationDate) {
                                Write-Host "    La cuenta no tiene fecha de expiracion (Nunca expira)."
                            }
                            else {
                                $fechaExp = $user.AccountExpirationDate
                                Write-Host "    FECHA DE EXPIRACION: $fechaExp"
                                if ($fechaExp -lt (Get-Date)) {
                                    Write-Host "    AVISO: La cuenta ya ha expirado." -ForegroundColor Red
                                }
                            }

                            # --- APARTADO: MEMBRESÍA DE GRUPOS ---
                            Write-Host "`n[*] GRUPOS A LOS QUE PERTENECE:" -ForegroundColor Yellow
                            if ($user.MemberOf) {
                                foreach ($grupoDN in $user.MemberOf) {
                                    $nombreGrupo = ($grupoDN -split ",")[0].Replace("CN=", "")
                                    Write-Host "    - $nombreGrupo"
                                }
                            }
                            else {
                                Write-Host "    El usuario no pertenece a grupos adicionales."
                            }

                            # --- APARTADO: RASTREO DE EQUIPOS ---
                            Write-Host "`n[*] RASTREO DE EQUIPOS RECIENTES (LOGS LOCALES):" -ForegroundColor Yellow
                            $eventos = Get-WinEvent -FilterHashtable @{LogName = 'Security'; ID = 4624 } -MaxEvents 100 -ErrorAction SilentlyContinue | 
                            Where-Object { $_.Properties[5].Value -eq $dato }
                            
                            if ($eventos) {
                                $eventos | ForEach-Object {
                                    $pc = $_.Properties[18].Value
                                    if ($pc -and $pc -ne "-") { 
                                        Write-Host "    - Detectado en: $pc ($($_.TimeCreated))" 
                                    }
                                } | Select-Object -Unique
                            }
                            else {
                                Write-Host "    No se hallaron registros en este equipo."
                            }
                            Write-Host "====================================================" -ForegroundColor Cyan
                        }
                    }
                    catch {
                        Write-Host "`nError: No se pudo obtener informacion del usuario '$dato'." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)"
                    }

                    Write-Host "`n====================================================" -ForegroundColor Cyan

                }

                "2.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Definición del segmento de red base
                    $baseIP = "192.168.176."

                    # 2. Captura del último OCTETO con validación simple
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    if ($hostID -match '^\d{1,3}$') {
                        $fullIP = $baseIP + $hostID
                        Write-Host "`n--- Consultando Host: $fullIP ---" -ForegroundColor Cyan
                        
                        try {
                            # 3. Ejecución optimizada de quser (query user)
                            # Redirigimos el error 2 al flujo de éxito para procesar el texto de "No hay usuarios"
                            $resultado = quser /server:$fullIP 2>&1

                            # 4. Procesamiento de la respuesta
                            if ($resultado -like "*No hay ningún usuario*" -or $resultado -like "*No user exists*") {
                                Write-Host "Estado: Equipo encendido, pero sin sesiones activas." -ForegroundColor Cyan
                            }
                            elseif ($resultado -like "*Error*") {
                                Write-Host "Error: No se pudo establecer conexion RPC con $fullIP." -ForegroundColor Red
                                Write-Host "Verifique que el equipo esté en línea y el Firewall permita RPC." -ForegroundColor Gray
                            }
                            else {
                                # Limpiamos líneas vacías y mostramos la tabla de quser
                                $resultado | Where-Object { $_.Trim() -ne "" }
                            }
                        }
                        catch {
                            Write-Host "Error inesperado al ejecutar el comando." -ForegroundColor Red
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Debe ingresar solo numeros (0-255)." -ForegroundColor Red
                    }

                    # Pausa para ver los resultados antes de cerrar la consola
                    # Write-Host "`nPresione cualquier tecla para finalizar esta consulta..."
                    # $null = [Console]::ReadKey()
                    
                }

                "2.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    Write-Host "--- Auditoria de Usuarios: Equipo Remoto ---" -ForegroundColor Cyan

                    # 1. Solicitud de entrada con validacion basica
                    $octeto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX)"

                    if ($octeto -notmatch '^\d{1,3}$') {
                        Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                        break
                    }

                    $ip = "192.168.176.$octeto"
                    Write-Host "Conectando a $ip..." -ForegroundColor Yellow

                    # 2. Bloque de ejecucion con manejo de errores
                    try {
                        # Consultar usuario actual
                        $pc = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
                        $usuarioActual = $pc.UserName

                        # Consultar perfiles historicos (Excluye cuentas especiales del sistema)
                        $perfiles = Get-WmiObject -Class Win32_UserProfile -ComputerName $ip -Filter "Special=False" -ErrorAction Stop

                        # 3. Presentacion de resultados
                        Write-Host "`n--- Resultado de la Auditoria ---" -ForegroundColor Green
                        
                        # Mostrar usuario activo
                        Write-Host "Usuario Activo Actualmente:" -ForegroundColor White
                        if ($null -eq $usuarioActual) {
                            Write-Host "  No hay ningun usuario con sesion iniciada." -ForegroundColor Gray
                        }
                        else {
                            Write-Host "  $usuarioActual" -ForegroundColor Cyan
                        }

                        # Mostrar historial de perfiles (Solo nombres)
                        Write-Host "`nUsuarios que han iniciado sesion anteriormente:" -ForegroundColor White
                        $listaUsuarios = foreach ($perfil in $perfiles) {
                            $nombreUsuario = $perfil.LocalPath.Split('\')[-1]
                            
                            New-Object PSObject -Property @{
                                Usuario = $nombreUsuario
                            } | Select-Object Usuario
                        }

                        if ($null -eq $listaUsuarios) {
                            Write-Host "  No se encontraron perfiles de usuario adicionales." -ForegroundColor Gray
                        }
                        else {
                            $listaUsuarios | Sort-Object Usuario | Format-Table -AutoSize
                        }

                    }
                    catch {
                        Write-Host "`n[ERROR] No se pudo conectar al equipo $ip." -ForegroundColor Red
                        Write-Host "Razon: $_" -ForegroundColor Red
                        Write-Host "Asegurese de tener permisos de administrador en la maquina remota." -ForegroundColor Yellow
                    }
                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }


                "2.5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # 1. Configuración del segmento
                    $segmento = "192.168.176."
                    $hostID = Read-Host "Ingrese el ultimo OCTETO del segmento 192.168.176.XXX"

                    # Validar que la entrada sea numérica
                    if ($hostID -match '^\d{1,3}$') {
                        $targetIP = $segmento + $hostID
                        Write-Host "`n--- Buscando recursos compartidos en: $targetIP ---" -ForegroundColor Yellow

                        try {
                            # 2. Uso de Get-WmiObject para máxima compatibilidad (Win7 en adelante)
                            # Filtramos Type=0 para mostrar solo carpetas compartidas por el usuario
                            # (Type 2147483648 son recursos administrativos ocultos)
                            $shares = Get-WmiObject -Class Win32_Share -ComputerName $targetIP -ErrorAction Stop | 
                            Where-Object { $_.Type -eq 0 }

                            if ($shares) {
                                Write-Host "Recursos encontrados:" -ForegroundColor Green
                                $shares | Select-Object @{Name = "Carpeta"; Expression = { $_.Name } }, 
                                @{Name = "Ruta Local"; Expression = { $_.Path } }, 
                                @{Name = "Descripcion"; Expression = { $_.Description } } | 
                                Format-Table -AutoSize
                            }
                            else {
                                Write-Host "No se encontraron carpetas compartidas (públicas) en este equipo." -ForegroundColor Cyan
                            }
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar a $targetIP." -ForegroundColor Red
                            Write-Host "Causas posibles: Equipo apagado, IP incorrecta o Firewall bloqueando WMI/RPC." -ForegroundColor Gray
                        }
                    }
                    else {
                        Write-Host "Entrada invalida. Ingrese solo números." -ForegroundColor Red
                    }

                    Write-Host "`Consulta finalizado..." -ForegroundColor Cyan

                }

                "3.1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    # ==============================================================================
                    #   HERRAMIENTA REMOTA DE GESTIÓN DE USUARIOS LOCALES (GMSANTACRUZ)
                    #   Compatibilidad: Windows 7 hasta Windows 11
                    # ==============================================================================

                    Clear-Host
                    Write-Host "==================================================" -ForegroundColor Cyan
                    Write-Host "     GESTOR DE USUARIOS LOCALES REMOTOS           " -ForegroundColor Cyan
                    Write-Host "==================================================" -ForegroundColor Cyan

                    do {
                        # 1. Construcción de la Dirección IP
                        Write-Host "--- Estructura de Red ---\n" -ForegroundColor White
                        $ultimoOcteto = Read-Host "Ingrese el ULTIMO octeto para el segmento 192.168.176.xxx"
                        
                        # Validación básica de entrada numérica
                        if ($ultimoOcteto -notmatch '^\d+$' -or [int]$ultimoOcteto -lt 1 -or [int]$ultimoOcteto -gt 254) {
                            Write-Host "[ERROR] El octeto ingresado no es valido." -ForegroundColor Red
                            break
                        }
                        
                        $ipRemota = "192.168.176.$ultimoOcteto"
                        Write-Host "Conectando a: $ipRemota..." -ForegroundColor Yellow

                        # 2. Manejo opcional de credenciales de Dominio
                        $opcionCred = Read-Host "¿Desea usar credenciales de un usuario de Dominio? (SI/NO)"
                        $usarCredenciales = $false
                        $credenciales = $null

                        if ($opcionCred.ToUpper() -eq "SI") {
                            Write-Host "Solicitando credenciales de Administrador de Dominio..." -ForegroundColor Yellow
                            $credenciales = Get-Credential
                            $usarCredenciales = $true
                        }

                        # 3. Listar cuentas locales mediante ADSI (WinNT)
                        Write-Host "`nObteniendo listado de cuentas locales de la PC remota..." -ForegroundColor Yellow
                        
                        try {
                            # Conexión al contenedor de la máquina remota
                            if ($usarCredenciales) {
                                # Se utiliza el ensamblador nativo de .NET para pasar las credenciales de forma segura
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $pcRemotaObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota,computer", $username, $password)
                            }
                            else {
                                $pcRemotaObj = [ADSI]"WinNT://$ipRemota,computer"
                            }

                            # Filtrar solo objetos de tipo "User" (Cuentas de usuario)
                            $usuariosLocales = $pcRemotaObj.Children | Where-Object { $_.SchemaClassName -eq "user" }

                            if ($null -eq $usuariosLocales) {
                                Write-Host "[ERROR] No se pudieron recuperar los usuarios o la lista esta vacia." -ForegroundColor Red
                                break
                            }

                            # Mostrar los usuarios en una tabla limpia
                            Write-Host "`n--- Cuentas Locales Detectadas ---" -ForegroundColor White
                            $listaVisual = @()
                            foreach ($u in $usuariosLocales) {
                                # Propiedades extendidas nativas de la cuenta
                                $disabled = $u.Properties.UserFlags.Value -band 2 # 2 = ADS_UF_ACCOUNTDISABLE
                                $estado = if ($disabled) { "Deshabilitado" } else { "Activo" }
                                
                                $obj = New-Object PSObject -Property @{
                                    "Nombre de Usuario" = $u.Name
                                    "Estado"            = $estado
                                    "Descripcion"       = $u.Description
                                }
                                $listaVisual += $obj | Select-Object "Nombre de Usuario", Estado, Descripcion
                            }
                            
                            $listaVisual | Format-Table -AutoSize
                            
                        }
                        catch {
                            Write-Host "[ERROR CRITICO] No se pudo establecer la conexion remota via RPC/ADSI: $_" -ForegroundColor Red
                            break
                        }

                        # 4. Selección del usuario al que se le cambiará la contraseña
                        Write-Host "--------------------------------------------------" -ForegroundColor Cyan
                        $usuarioSeleccionado = Read-Host "Ingrese el NOMBRE del usuario local a modificar"
                        
                        # Validar que el usuario ingresado exista en el listado previo
                        $existeUsuario = $listaVisual | Where-Object { $_."Nombre de Usuario".ToUpper() -eq $usuarioSeleccionado.ToUpper() }

                        if (-not $existeUsuario) {
                            Write-Host "[ERROR] El usuario '$usuarioSeleccionado' no pertenece a las cuentas locales de la PC remota." -ForegroundColor Red
                            break
                        }

                        # 5. Ingreso y cambio de la nueva contraseña
                        $nuevaPassword = Read-Host "Ingrese la NUEVA CONTRASENIA para el usuario ($usuarioSeleccionado)"
                        $confirmarPassword = Read-Host "Confirme la NUEVA CONTRASENIA"

                        if ($nuevaPassword -ne $confirmarPassword) {
                            Write-Host "[ERROR] Las contrasenias no coinciden. Operacion cancelada." -ForegroundColor Red
                            break
                        }

                        # 6. Aplicar el cambio de contraseña de forma remota
                        try {
                            Write-Host "`nAplicando cambios en el sistema remoto..." -ForegroundColor Yellow
                            
                            # Obtener el objeto ADSI específico del usuario seleccionado
                            if ($usarCredenciales) {
                                $username = $credenciales.UserName
                                $password = $credenciales.GetNetworkCredential().Password
                                $usuarioObj = New-Object System.DirectoryServices.DirectoryEntry("WinNT://$ipRemota/$usuarioSeleccionado,user", $username, $password)
                            }
                            else {
                                $usuarioObj = [ADSI]"WinNT://$ipRemota/$usuarioSeleccionado,user"
                            }

                            # Invocar el método nativo .SetPassword() de la API de Windows
                            $usuarioObj.SetPassword($nuevaPassword)
                            $usuarioObj.CommitChanges()

                            Write-Host "[EXITO] La contrasenia del usuario local '$usuarioSeleccionado' ha sido cambiada correctamente en $ipRemota." -ForegroundColor Green

                        }
                        catch {
                            Write-Host "[ERROR] Fallo al cambiar la contrasenia: $_" -ForegroundColor Red
                        }

                    } while ($false)

                    Write-Host "`n==================================================" -ForegroundColor Cyan
                    Write-Host "`Proceso finalizado..." -ForegroundColor Cyan
                    
                }

                "3.2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

                    
                }

                "3.3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
   
                }

                "30" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"

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
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op26"
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }
                
                "0" { 
                    # $salirSub = $true 
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 26: Presione ENTER para continuar..." }
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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.26*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.27 ******************************************************
#**********************************************************************************************************************************
function psSubMenu27 {
    $salirSub = $false
    do {
        try {
            #cabecera con informacion del autor
            cabecera
            Write-Header " 27. ###)) ONLINE: Herramientas en INTERNET #####"
            Write-Host "  1. Revision TECLADO PC online - wikiversus.com"
            Write-Host "  2. Revision Teclado PC online - https://en.key-test.ru"
            Write-Host "  3. Revision Teclado PC online - https://www.onlinemictest.com/es/prueba-de-teclado"
            Write-Host "  4. Revisar MOUSE PC online - https://keyboardtester.co/mouse-click-tester"
            Write-Host "  5. Web Recortar Videos - https://online-video-cutter.com/es."
            Write-Host "  ------------------------------------------------------"
            Write-Host "  10. Testear Monitor PC - https://www.eizo.be/monitor-test."
            Write-Host "  ------------------------------------------------------"
            Write-Host "  20. Buscador de Seriales 1 - https://smartserials.com."
            Write-Host "  21. Buscador de Seriales 2 - https://keygenninja.com."
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Host ""
            Write-Header "==============================="
            
            $op27 = Read-Host "Seleccione la tarea a realizar"

            switch ($op27) {
                "1" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    # Abrir en Chrome (Modo Incógnito)
                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://www.wikiversus.com/gaming/teclados/test-key-rollover-y-anti-ghosting/"

                    # Abrir en Brave (Modo Incógnito)
                    Start-Process "msedge.exe" -ArgumentList "-inprivate", "https://www.wikiversus.com/gaming/teclados/test-key-rollover-y-anti-ghosting/"
                }
                "2" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://en.key-test.ru/"

                }

                "3" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "--incognito", "https://www.onlinemictest.com/es/prueba-de-teclado/"

                }

                "4" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://keyboardtester.co/mouse-click-tester"

                }            

                "5" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://online-video-cutter.com/es/"
                }

                "10" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://www.eizo.be/monitor-test/"

                }

                "20" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://smartserials.com"

                }

                "21" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op27"

                    Start-Process "chrome.exe" -ArgumentList "https://keygenninja.com/"

                }

                "0" { 
                    #$salirSub = $true # Antigua sentencia para volver al MENU DE INICIO
                    menuPrincipal
                }
                Default { 
                    Write-Host "Opcion invalida." -ForegroundColor Red 
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "SUB_MENU 27: Presione ENTER para continuar..." }  # VERIFICAR SI CORRESPONDE AQUI

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}

#************************************************* FIN SUB MENU.27*****************************************************************
#**********************************************************************************************************************************

#************************************************ MENU PRINCIPAL ******************************************************************
#**********************************************************************************************************************************
function psSubMenu28 {
    $salirSub = $false
    do {
        try {
            cabecera
            Write-Header " 28. ---)) AD: GESTION HELPDESK -----"
            Write-Host "  1. Habilitar ejecucion remota de scripts (en PC REMOTA)" -ForegroundColor Cyan
            Write-Host "  2. Ejecutar GPUPDATE /FORCE en PC REMOTA" -ForegroundColor Yellow
            Write-Host "  3. Mostrar Caracteristicas de PC Remoto (Info Hardware/OS/Red)" -ForegroundColor Green
            Write-Host "  ------------------------------------------------------"
            Write-Host "  4. Habilitacion de Administracion Remota"
            Write-Host "    4.1 || HABILITAR || WMI, RPC y PSRemoting - en PC REMOTO." -ForegroundColor Green
            Write-Host "  ------------------------------------------------------"
            Write-Host "  5. Servicios Windows Update"
            Write-Host "    5.1 || HABILITAR || Servicios de Actualizacion (Remoto)" -ForegroundColor Green
            Write-Host "    5.2 || DESHABILITAR || Servicios de Actualizacion (Remoto)" -ForegroundColor Red
            Write-Host "    5.3 || ESTADO || de Servicios Windows Update (Remoto)" -ForegroundColor Cyan
            Write-Host "  ------------------------------------------------------"
            Write-Host "  0. V O L V E R   A L   M E N U    P R I N C I P A L"
            Write-Host ""
            Write-Header "==============================="
            
            $op28 = Read-Host "Seleccione la tarea a realizar"

            # Helper para pedir IP / Hostname y resolverlo
            $obtenerDestino = {
                $baseIP = "192.168.176."
                $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
                if ($ultimoOcteto -eq "") { return $null }
                
                $ipRemota = ""
                $targetMachine = ""
                
                if ($ultimoOcteto -match "^[a-zA-Z]") {
                    # Es un hostname directo
                    $targetMachine = $ultimoOcteto
                }
                else {
                    # Es un octeto o IP
                    $ipRemota = if ($ultimoOcteto -match "\.") { $ultimoOcteto } else { $baseIP + $ultimoOcteto }
                    Write-Host "Resolviendo nombre de equipo (Hostname) necesario para WinRM..." -ForegroundColor Cyan
                    try {
                        $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ipRemota -ErrorAction Stop
                        $targetMachine = $sys.CSName
                        Write-Host "Nombre de equipo resuelto: $targetMachine" -ForegroundColor Green
                    }
                    catch {
                        try {
                            $targetMachine = [System.Net.Dns]::GetHostEntry($ipRemota).HostName
                            Write-Host "Nombre de equipo resuelto via DNS: $targetMachine" -ForegroundColor Green
                        }
                        catch {
                            Write-Host "ADVERTENCIA: No se pudo resolver la IP automaticamente." -ForegroundColor Yellow
                            $manualHost = Read-Host "Ingrese el NOMBRE DE EQUIPO (Hostname) del equipo remoto manualmente"
                            if ($manualHost -ne "") {
                                $targetMachine = $manualHost
                            }
                            else {
                                $targetMachine = $ipRemota # fallback a la IP
                            }
                        }
                    }
                }
                return @{ IP = $ipRemota; Hostname = $targetMachine }
            }

            switch ($op28) {
                "1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    $destino = & $obtenerDestino
                    if ($destino) {
                        $target = $destino.Hostname
                        $ip = if ($destino.IP) { $destino.IP } else { $target }
                        
                        Write-Host "Habilitando ejecucion remota de scripts en $target ($ip)..." -ForegroundColor Cyan
                        
                        # Usamos WMI primero (RPC/DCOM) por máxima compatibilidad en habilitación inicial
                        $process = Get-WmiObject -List -ComputerName $ip -Class Win32_Process -ErrorAction SilentlyContinue
                        if ($process) {
                            $cmd = "powershell.exe -NoProfile -Command `"try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}; try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}`""
                            $result = $process.Create($cmd)
                            if ($result.ReturnValue -eq 0) {
                                Write-Host "[OK] Comando de habilitacion enviado correctamente via WMI." -ForegroundColor Green
                            }
                            else {
                                Write-Host "Error al enviar comando via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                            }
                        }
                        else {
                            $psexecPath = "C:\PSTools\PsExec.exe"
                            if (Test-Path $psexecPath) {
                                $arg = "\\$ip -accepteula -s powershell.exe -NoProfile -Command `"try { Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force } catch {}; try { Enable-PSRemoting -SkipNetworkProfileCheck -Force } catch {}`""
                                Start-Process -FilePath $psexecPath -ArgumentList $arg -Wait -NoNewWindow
                                Write-Host "[OK] Comando enviado via PsExec." -ForegroundColor Green
                            }
                            else {
                                Write-Host "ERROR: No se pudo conectar via WMI ni se encontro PsExec en C:\PSTools\PsExec.exe" -ForegroundColor Red
                            }
                        }
                    }
                }
                "2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    $destino = & $obtenerDestino
                    if ($destino) {
                        $target = $destino.Hostname
                        $ip = if ($destino.IP) { $destino.IP } else { $target }
                        
                        Write-Host "Ejecutando GPUPDATE /FORCE en $target..." -ForegroundColor Cyan
                        
                        try {
                            # Intentamos usar WinRM interactivo para ver los resultados en tiempo real
                            Invoke-Command -ComputerName $target -ScriptBlock {
                                gpupdate /force
                            } -ErrorAction Stop
                        }
                        catch {
                            Write-Host "WinRM no disponible. Intentando ejecucion en segundo plano via WMI..." -ForegroundColor Yellow
                            $process = Get-WmiObject -List -ComputerName $ip -Class Win32_Process -ErrorAction SilentlyContinue
                            if ($process) {
                                $result = $process.Create("cmd.exe /c gpupdate /force")
                                if ($result.ReturnValue -eq 0) {
                                    Write-Host "[OK] Proceso gpupdate lanzado en segundo plano via WMI." -ForegroundColor Green
                                }
                                else {
                                    Write-Host "Error al ejecutar gpupdate via WMI (Codigo: $($result.ReturnValue))." -ForegroundColor Red
                                }
                            }
                            else {
                                $psexecPath = "C:\PSTools\PsExec.exe"
                                if (Test-Path $psexecPath) {
                                    & $psexecPath \\$ip -accepteula -s cmd.exe /c "gpupdate /force"
                                    Write-Host "[OK] GPUPDATE ejecutado via PsExec." -ForegroundColor Green
                                }
                                else {
                                    Write-Host "ERROR: No se pudo realizar la conexion." -ForegroundColor Red
                                }
                            }
                        }
                    }
                }
                "3" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    
                    # Para WMI, preferimos usar la IP si está disponible, o el Hostname
                    $baseIP = "192.168.176."
                    $ultimoOcteto = Read-Host "Ingrese el ultimo octeto de la IP (192.168.176.XXX), IP completa o Nombre de Equipo"
                    if ($ultimoOcteto -ne "") {
                        $ip = if ($ultimoOcteto -match "^[a-zA-Z]") { $ultimoOcteto } elseif ($ultimoOcteto -match "\.") { $ultimoOcteto } else { $baseIP + $ultimoOcteto }
                        
                        Write-Host "`nConsultando caracteristicas extendidas en: $ip..." -ForegroundColor Cyan
                        try {
                            # 1. Sistema Operativo y Hostname
                            $os = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $ip -ErrorAction Stop
                            $cs = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $ip -ErrorAction Stop
                            $cpu = Get-WmiObject -Class Win32_Processor -ComputerName $ip -ErrorAction Stop | Select-Object -First 1
                            
                            # 2. Determinar Tipo de Arranque (UEFI vs Legacy) y Tabla (GPT vs MBR)
                            $bootStyle = "LEGACY (BIOS)"
                            $partitionStyle = "MBR"
                            
                            $partitions = Get-WmiObject -Class Win32_DiskPartition -ComputerName $ip -ErrorAction SilentlyContinue
                            if ($partitions) {
                                if ($partitions | Where-Object { $_.Type -like "*GPT*" -or $_.Type -like "*EFI*" -or $_.Name -like "*EFI*" }) {
                                    $bootStyle = "UEFI"
                                }
                                else {
                                    if (Test-Path "\\$ip\c$\Windows\Boot\EFI" -ErrorAction SilentlyContinue) {
                                        $bootStyle = "UEFI"
                                    }
                                }
                                if ($partitions | Where-Object { $_.Type -like "*GPT*" }) {
                                    $partitionStyle = "GPT"
                                }
                            }
                            else {
                                if (Test-Path "\\$ip\c$\Windows\Boot\EFI" -ErrorAction SilentlyContinue) {
                                    $bootStyle = "UEFI"
                                    $partitionStyle = "GPT"
                                }
                            }
                            
                            # Intentar afinar partición de disco de sistema 0
                            try {
                                $bootDisk = Get-WmiObject -Class Win32_DiskDrive -ComputerName $ip | Where-Object { $_.Index -eq 0 } -ErrorAction SilentlyContinue
                                if ($bootDisk -and $bootDisk.GPTSignature -ne $null) {
                                    $partitionStyle = "GPT"
                                }
                            }
                            catch {}

                            # 3. Detectar Usuario Activo (Local o Dominio)
                            $activeUser = "Ninguno (Sin sesion activa)"
                            try {
                                $explorers = Get-WmiObject -Class Win32_Process -ComputerName $ip -Filter "Name='explorer.exe'" -ErrorAction Stop
                                if ($explorers) {
                                    $users = @()
                                    foreach ($exp in $explorers) {
                                        $owner = $exp.GetOwner()
                                        if ($owner.ReturnValue -eq 0) {
                                            $users += "$($owner.Domain)\$($owner.User)"
                                        }
                                    }
                                    if ($users.Count -gt 0) {
                                        $activeUser = ($users | Select-Object -Unique) -join ", "
                                    }
                                }
                                else {
                                    if ($cs.UserName) { $activeUser = $cs.UserName }
                                }
                            }
                            catch {
                                if ($cs.UserName) { $activeUser = $cs.UserName }
                            }
                            
                            # 4. Discos Físicos (HDD vs SSD)
                            $disksInfo = try {
                                Get-WmiObject -Namespace root\Microsoft\Windows\Storage -Class MSFT_PhysicalDisk -ComputerName $ip -ErrorAction Stop | ForEach-Object {
                                    $type = if ($_.MediaType -eq 3) { "HDD" } elseif ($_.MediaType -eq 4) { "SSD" } else { "Desconocido" }
                                    "   - Disco $($_.DeviceId): $($_.Model.Trim()) ($type)"
                                }
                            }
                            catch {
                                Get-WmiObject -Class Win32_DiskDrive -ComputerName $ip | ForEach-Object {
                                    "   - Disco $($_.Index): $($_.Model.Trim()) (Interfaz: $($_.InterfaceType))"
                                }
                            }

                            # 5. Unidades Lógicas disponibles
                            $logicalDrivesInfo = try {
                                Get-WmiObject -Class Win32_LogicalDisk -ComputerName $ip -Filter "DriveType=3" -ErrorAction Stop | ForEach-Object {
                                    $totalGB = [Math]::Round($_.Size / 1GB, 2)
                                    $freeGB = [Math]::Round($_.FreeSpace / 1GB, 2)
                                    $pctFree = if ($_.Size -gt 0) { [Math]::Round(($_.FreeSpace / $_.Size) * 100, 1) } else { 0 }
                                    "   - Unidad $($_.DeviceID) ($($_.VolumeName)) [$($_.FileSystem)] -> Total: $totalGB GB | Libre: $freeGB GB ($pctFree% libre)"
                                }
                            }
                            catch {
                                @("   - No se pudieron consultar las unidades logicas.")
                            }
                            
                            # 6. Adaptadores de Red activos (Detalle completo)
                            $adaptersInfo = Get-WmiObject -Class Win32_NetworkAdapter -ComputerName $ip | 
                            Where-Object { $_.PhysicalAdapter -and $_.NetConnectionStatus -eq 2 } | 
                            ForEach-Object {
                                $config = Get-WmiObject -Class Win32_NetworkAdapterConfiguration -ComputerName $ip -Filter "Index=$($_.Index)" -ErrorAction SilentlyContinue
                                $ips = "N/A"
                                $masks = "N/A"
                                $gateways = "N/A"
                                $dns = "N/A"
                                if ($config) {
                                    if ($config.IPAddress) { $ips = $config.IPAddress[0] }
                                    if ($config.IPSubnet) { $masks = $config.IPSubnet[0] }
                                    if ($config.DefaultIPGateway) { $gateways = $config.DefaultIPGateway -join ", " }
                                    if ($config.DNSServerSearchOrder) { $dns = $config.DNSServerSearchOrder -join ", " }
                                }
                                $netType = if ($_.Name -match "Wireless|Wi-Fi|WiFi|802\.11") { "Wi-Fi" } else { "Ethernet" }
                                "   - $($_.Name) ($netType)`n     IP: $ips | Mascara: $masks`n     Gateway: $gateways`n     DNS: $dns`n     MAC: $($_.MACAddress)"
                            }

                            # 7. Gestión de Impresoras (Predeterminada vs Disponibles con Estado)
                            $defaultPrinterInfo = "Ninguna o sin informacion."
                            $availablePrinters = @()
                            try {
                                $printers = Get-WmiObject -Class Win32_Printer -ComputerName $ip -ErrorAction Stop
                                if ($printers) {
                                    foreach ($p in $printers) {
                                        $estado = if ($p.WorkOffline -or $p.PrinterStatus -eq 7) { "No Activo" } else { "Activo" }
                                        $desc = "$($p.Name) [Puerto: $($p.PortName)] (Estado: $estado)"
                                        if ($p.Default) {
                                            $defaultPrinterInfo = $desc
                                        }
                                        else {
                                            $availablePrinters += "   - $desc"
                                        }
                                    }
                                }
                            }
                            catch {
                                $defaultPrinterInfo = "Error al consultar impresoras."
                            }

                            # Imprimir Reporte Formateado Completo
                            Write-Host "`n======================================================================" -ForegroundColor White
                            Write-Host "          INFORMACION DETALLADA DE SOPORTE REMOTO: $($os.CSName)" -ForegroundColor Green
                            Write-Host "======================================================================" -ForegroundColor White
                            Write-Host " Hostname:            $($os.CSName)"
                            Write-Host " Usuario Activo:      $activeUser" -ForegroundColor Cyan
                            Write-Host " Sistema de Arranque: $bootStyle ($partitionStyle)" -ForegroundColor Yellow
                            Write-Host " Sistema Operativo:   $($os.Caption) ($($os.OSArchitecture))"
                            Write-Host " Version S.O.:        $($os.Version) (Build $($os.BuildNumber))"
                            Write-Host " Procesador:          $($cpu.Name.Trim())"
                            Write-Host " Memoria RAM:         $([Math]::Round($cs.TotalPhysicalMemory / 1GB, 2)) GB"
                            
                            Write-Host "`n Unidades de Disco Fisico:" -ForegroundColor Green
                            if ($disksInfo) { $disksInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se detectaron unidades físicas." -ForegroundColor Yellow }
                            
                            Write-Host "`n Unidades Logicas Disponibles:" -ForegroundColor Green
                            if ($logicalDrivesInfo) { $logicalDrivesInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se detectaron unidades lógicas." -ForegroundColor Yellow }
                            
                            Write-Host "`n Adaptadores de Red Activos:" -ForegroundColor Green
                            if ($adaptersInfo) { $adaptersInfo | ForEach-Object { Write-Host $_ } } else { Write-Host "   No se encontraron adaptadores de red activos." -ForegroundColor Yellow }
                            
                            Write-Host "`n Gestion de Impresion:" -ForegroundColor Green
                            Write-Host "  * Impresora Predeterminada:" -ForegroundColor White
                            Write-Host "    $defaultPrinterInfo" -ForegroundColor Cyan
                            if ($availablePrinters) {
                                Write-Host "  * Otras Impresoras Disponibles:" -ForegroundColor White
                                $availablePrinters | ForEach-Object { Write-Host $_ }
                            }
                            Write-Host "======================================================================`n" -ForegroundColor White
                            
                        }
                        catch {
                            Write-Host "ERROR: No se pudo conectar o extraer informacion del equipo $ip." -ForegroundColor Red
                            Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                        }
                    }
                }
                "4" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    Write-Host "Por favor seleccione una sub-opcion especifica (4.1)" -ForegroundColor Yellow
                }
                "4.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    psHabilitarAdministracionRemota
                }
                "5" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op28"
                    Write-Host "Por favor seleccione una sub-opcion especifica (5.1, 5.2 o 5.3)" -ForegroundColor Yellow
                }
                "5.1" {
                    psGestionarServiciosUpdateRemoto -accion "Habilitar"
                }
                "5.2" {
                    psGestionarServiciosUpdateRemoto -accion "Deshabilitar"
                }
                "5.3" {
                    psGestionarServiciosUpdateRemoto -accion "Estado"
                }
                "0" {
                    menuPrincipal
                }
                Default {
                    Write-Host "Opcion invalida." -ForegroundColor Red
                }
            }
            if (-not $salirSub) { Read-Host "SUB_MENU 28: Presione ENTER para continuar..." }
        }
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
        finally {
            [System.GC]::Collect()
            [System.GC]::WaitForPendingFinalizers()
            Get-Variable | Where-Object { 
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue
            Start-Sleep -Milliseconds 200
        }
    } while (-not $salirSub)
}
function menuPrincipal {
    Clear-Host
    $salirPrincipal = $false

    # 1. Validacion de privilegios de Administrador
    $currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
    if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
        Write-Host "ERROR: Debes ejecutar este script como ADMINISTRADOR." -ForegroundColor Red
        Pause
        exit
    }

    do {
        try {
            #cabecera con informacion del autor
            cabecera

            Write-Header " ATENCION: ESTA HERRAMIENTA REALIZA CAMBIOS EN EL SISTEMA OPERATIVO"
            #Write-Host "======================================================================" -ForegroundColor Cyan -BackgroundColor Black
            Write-Host "  1.  Mostrar IP LOCAL (Ipconfig)"
            Write-Host "  2.  Mostrar Nombre (HOSTNAME)"
            Write-Host "  3.  Desfragmentar Unidad C: (Principal)" -ForegroundColor DarkCyan
            Write-Host "  4.  Desfragmentar Otras Unidades (HDD)"
            Write-Host "    4.1 Optimizar Unidades de SSD (alternativa a defrag)."
            Write-Host "  5.  Eliminar Archivos Temporales S.O." -ForegroundColor DarkCyan
            Write-Host "  6.  Liberar Recursos" -ForegroundColor Green
            Write-Host "    6.1 Eliminar Archivos TEMPORALES CARPETAS" -ForegroundColor DarkCyan
            Write-Host "    6.2 Eliminar Archivos Temporales ProgramData." -ForegroundColor DarkCyan
            Write-Host "    6.3 Liberar RAM." -ForegroundColor DarkCyan
            Write-Host "    6.4 Liberar Procesador." -ForegroundColor DarkCyan
            Write-Host "  7.  Resetear Internet Explorer"
            Write-Host "  9.  Abrir Internet Explorer con Topacio"
            Write-Host "  10. Ping Infraestructura"
            Write-Host "  11. Revisar Unidades (CHKDSK) - Reparar, localizar y desmontar - chkdsk.exe /F /R /X." -ForegroundColor DarkCyan
            Write-Host "  12. Mostrar Todo el Contenido de UNIDAD (ATTRIB)."
            Write-Host "  13. Abrir Google CHROME con Buscador (Modo Incognito)."
            Write-Host "  14. Abrir Propiedades de INTERNET EXPLORER."
            Write-Host "  15. Cerrar Proceso Explorer.exe (explorer)." -ForegroundColor DarkCyan
            Write-Host "  16. Abrir Proceso Explorer.exe (explorer)."
            Write-Host "  17. Abrir Administrador de Tareas (taskmgr)."
            Write-Host "  18. Abrir Simbolo de SISTEMA (cmd)."
            Write-Host "  19. Abrir PowerShell Administrador"
            Write-Host "  20. ---)) LOCAL: INFORMACION SISTEMA CMD [RAM] [HDD] - DISM - RESETEAR RED."
            Write-Host "  21. ---)) LOCAL: VENTANAS ADMINISTRACION WINDOWS - ANTIVIRUS."
            Write-Host "  22. ---)) LOCAL: SERVICIOS WINDOWS - HERRAMIENTAS AVANZADOS."
            Write-Host "  23. ---)) LOCAL: HELPDESK LOCAL - HERRAMIENTAS DE SISTEMA." -ForegroundColor Green
            Write-Host "  24. ***)) LOCAL: COMANDOS WINDOWS 11 *****"
            Write-Host "  25. +++)) AD: COMANDOS RED - ADMINISTRACION REMOTA +++++" -ForegroundColor Cyan
            Write-Host "  26. ===)) AD: COMANDOS AD =====" -ForegroundColor Cyan
            Write-Host "  27. ###)) ONLINE: Herramientas en INTERNET #####"
            Write-Host "  28. ---)) AD: GESTION HELPDESK -----" -ForegroundColor Cyan
            Write-Host "  29. ***)) LOCAL: APAGADO Y REINICIADO DE PC *****"
            Write-Host "    29.1 Apagar PC." -ForegroundColor Green
            Write-Host "    29.2 Reiniciar Sistema Operativo (shutdown)." -ForegroundColor Green
            Write-Host "  30. REFRESH (Modo LOCAL)."
            Write-Host "  31. REFRESH desde GitHub (Online)." -ForegroundColor Cyan
            Write-Host "  0.  Salir"
            Write-Host "======================================================================" -ForegroundColor Yellow
            
            Write-Host $header -ForegroundColor Cyan

            # 3. Bucle Principal

            $opcion = Read-Host "Seleccione una opcion"

            switch ($opcion) {
                "1" { 
                    # Clear-Host 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Write-Host "--- Configuracion IP ---" -ForegroundColor Yellow
                    ipconfig 

                    #Read-Host "Presione Enter para volver..."
                    Write-Host " "
                }
                "2" { 
                    # Clear-Host 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Write-Host "Nombre del Equipo: $(hostname)" -ForegroundColor Green 
                    Write-Host " "
                        
                }
                "3" { 
                    # clear-Host 
                    cabecera
                    menuOpcion "Haz elegido la opcion:  $opcion"

                    Write-Host "Desfragmentando C:..." -ForegroundColor Green
                    DEFRAG.exe C:\ /B /U /V /H
                    # El parámetro /B en el comando defrag se usa para realizar una optimización de arranque
                    Write-Host " "
                }
                "4" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # $u = Read-Host "Letra de unidad (ej. D:)"
                    # if ($u) { defrag $u /U /V } 
                        
                    fsutil fsinfo drives
                    powershell.exe Get-Volume
                    $unit = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    DEFRAG.exe /U /O /V /H ${unit}":"
                        
                    # /A /U /V /H
                        
                    #Read-Host "Presione Enter para volver..."
                    Write-Host " "
                }

                "4.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    fsutil fsinfo drives
                    # powershell.exe Get-WmiObject Win32_LogicalDisk
                    powershell.exe Get-Volume
                    Write-Host ""
                    $unidad = Read-Host "Letra de la unidad a desfragmentar y presiona ENTER"
                    Optimize-Volume -DriveLetter ${unidad} -ReTrim -Verbose
                        
                    Write-Host " "
                }
                "5" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Write-Host "Iniciando Liberador de espacio (Configuracion 64)..." -ForegroundColor Yellow
                    try {
                        # Ejecuta el proceso de limpieza
                        Start-Process "cleanmgr.exe" -ArgumentList "/sagerun:64" -Wait
                        Write-Host "Limpieza completada con exito." -ForegroundColor Green
                    }
                    catch {
                        Write-Host "Error al ejecutar Cleanmgr." -ForegroundColor Red
                    }
                        
                    Write-Host " "
                }
                "6.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    # 1. Definir rutas usando variables de entorno de forma segura
                    $userTemp = "$env:TEMP"             # C:\Users\Nombre\AppData\Local\Temp
                    $systemTemp = "$env:SystemRoot\Temp"  # C:\Windows\Temp
                    $prefetch = "$env:SystemRoot\Prefetch"

                    Write-Host "Iniciando limpieza profunda de temporales..." -ForegroundColor Yellow

                    # 2. Limpieza de Temporales de Usuario
                    Write-Host " > Limpiando Temp de Usuario..." -NoNewline
                    Remove-Item -Path "$userTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 3. Limpieza de Temporales del Sistema
                    Write-Host " > Limpiando Temp de Windows..." -NoNewline
                    Remove-Item -Path "$systemTemp\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 4. Limpieza de Prefetch
                    Write-Host " > Limpiando Prefetch..." -NoNewline
                    Remove-Item -Path "$prefetch\*" -Recurse -Force -ErrorAction SilentlyContinue
                    Write-Host " [OK]" -ForegroundColor Green

                    # 5. Abrir carpetas para verificación (Opcional, emulando tu .bat)
                    Start-Process explorer.exe $userTemp
                    Start-Process explorer.exe $prefetch

                    Write-Host "Limpieza finalizada correctamente." -ForegroundColor White -BackgroundColor DarkGreen
                        
                    Write-Host ""
                }
                "6.2" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    # 1. Definimos las carpetas que NO queremos tocar bajo ninguna circunstancia
                    $excluir = @("*Microsoft*", "*Package Cache*", "*Antivirus*", "*SoftwareLicensing*", "*NVIDIA*")

                    # 2. Ejecutamos la búsqueda con filtros de seguridad
                    Get-ChildItem -Path "C:\ProgramData" -Recurse -File -Force -ErrorAction SilentlyContinue | 
                    Where-Object {
                        # Filtro 1: Que no esté en la lista de exclusión
                        $itemPath = $_.FullName
                        $safe = $true
                        foreach ($pattern in $excluir) {
                            if ($itemPath -like $pattern) { $safe = $false; break }
                        }

                        # Filtro 2: Solo extensiones típicas de basura y con más de 7 días
                        $safe -and 
                        ($_.Extension -match "\.(tmp|log|bak|old|chk|temp)$") -and 
                        ($_.LastWriteTime -lt (Get-Date).AddDays(-7))
                    } | 
                    Remove-Item -Force -ErrorAction SilentlyContinue
                        
                    Write-Host "Proceso finalizado" -ForegroundColor Green
                    Write-Host ""
                        
                }

                "6.3" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                    psLimpiarRAM

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green

                }

                "6.4" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # ==============================================================================
                    # Script: Optimizar_CPU.ps1
                    # Compatibilidad: Windows 7, 8.1, 10, 11 (PowerShell 2.0+)
                    # Descripción: Identifica y ajusta procesos con alto consumo de recursos.
                    # ==============================================================================

                    Write-Host "--- Reporte de Estado Inicial del Procesador ---" -ForegroundColor Yellow

                    # 1. Obtener carga total del procesador usando WMI (Máxima compatibilidad)
                    $cpuLoad = (Get-WmiObject Win32_Processor).LoadPercentage
                    Write-Host "Carga actual del sistema: $cpuLoad%" -ForegroundColor Cyan

                    # 2. Identificar procesos que consumen más del 20% de CPU
                    # Usamos Get-Process y seleccionamos los primeros 10 por uso de tiempo de CPU
                    $procesosPesados = Get-Process | Sort-Object CPU -Descending | Select-Object -First 10

                    Write-Host "`nTop 10 procesos por consumo acumulado:" -ForegroundColor Yellow
                    $procesosPesados | Format-Table Name, ID, CPU, PriorityClass -AutoSize

                    # 3. Acción de optimización: Cambiar prioridad a 'BelowNormal' 
                    # Esto evita que los procesos "estrangulen" el sistema sin llegar a cerrarlos bruscamente.
                    foreach ($proc in $procesosPesados) {
                        if ($proc.Name -ne "Idle" -and $proc.Name -ne "powershell") {
                            try {
                                $proc.PriorityClass = "BelowNormal"
                                Write-Host "Prioridad ajustada para: $($proc.Name) (ID: $($proc.Id))" -ForegroundColor Green
                            }
                            catch {
                                Write-Host "No se pudo cambiar prioridad de: $($proc.Name) (Permisos insuficientes)" -ForegroundColor Gray
                            }
                        }
                    }

                    # 4. Limpieza de memoria de trabajo (Working Set)
                    # Ayuda a liberar presión indirecta sobre el procesador al reducir el paginado
                    Write-Host "`nLiberando memoria de trabajo innecesaria..." -ForegroundColor Yellow
                    [System.GC]::Collect()

                    Write-Host "`nOptimizacion completada." -ForegroundColor White

                    # 5. Opción de cierre (Basado en el archivo previo 'Cerrar Ventana PowerShell')
                    Write-Host "`nProceso finalizado..." -ForegroundColor Yellow
                    Write-Host ""
                        
                    # $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
                        
                        

                }

                "7" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process iexplore.exe
                    taskkill.exe /F /IM iexplore.exe /T

                    # Limpiar todo (Equivalente a 255)
                    Write-Host "Iniciado limpieza de todo lo (Equivalente a 255)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 255" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    # Limpiar datos específicos incluyendo complementos (Equivalente a 4351)
                    Write-Host "Iniciado limpieza de datos específicos incluyendo complementos (Equivalente a 4351)"
                    Start-Process "rundll32.exe" -ArgumentList "InetCpl.cpl,ClearMyTracksByProcess 4351" -Wait
                    Write-Host " [OK]" -ForegroundColor Green

                    Start-Process "rundll32.exe" -ArgumentList "inetcpl.cpl,ResetIEtoDefaults" -Wait
                    Write-Host "Proceso de restablecimiento finalizado." -ForegroundColor Green

                    Write-Host ""

                }

                "9" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        

                    Write-Host "Iniciando IE..." -ForegroundColor Yellow
                    Start-Process -FilePath "C:\Program Files\Internet Explorer\iexplore.exe" -ArgumentList "https://topacioprod.gmsantacruz.gob.bo/"

                    Write-Host ""

                }
                "10" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # Definimos las IPs y sus etiquetas en una tabla para facilitar cambios
                    $destinos = @(
                        @{Nombre = "DNS Google 1 - 8.8.8.8"; IP = "8.8.8.8" },
                        @{Nombre = "Bolivianita - 192.168.13.249"; IP = "192.168.13.249" },
                        @{Nombre = "Berilo 1 - 192.168.13.243"; IP = "192.168.13.243" },
                        @{Nombre = "Berilo 2 - 192.168.13.36"; IP = "192.168.13.36" },
                        @{Nombre = "SRV H. PLAN - 192.168.176.254"; IP = "192.168.176.254" },
                        @{Nombre = "DNS 1 GAM - 172.25.108.100"; IP = "172.25.108.100" },
                        @{Nombre = "DNS 2 GAM - 192.168.13.214"; IP = "192.168.13.214" }
                    )

                    Write-Host "Iniciando monitoreo de red en ventanas independientes..." -ForegroundColor Cyan

                    foreach ($item in $destinos) {
                        # Ejecutamos CMD, le pasamos el título y el comando Ping infinito (-t)
                        Start-Process cmd.exe -ArgumentList "/c title $($item.Nombre) && ping $($item.IP) -t"
                    }

                        
                    Write-Host ""

                }
                "10.1" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    $ip = Read-Host "IP/Host para Ping"

                    if ($ip) {
                        # start: abre nueva ventana
                        # cmd /k: ejecuta el comando y mantiene la ventana abierta
                        # ping -t: ping continuo en CMD
                        Start-Process cmd.exe "/k ping $ip -t"
                    }

                    Write-Host ""
                }
                "11" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    # 1. Mostrar información de las unidades de forma legible
                    Write-Host "--- UNIDADES DETECTADAS ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, 
                    @{Name = "Tipo"; Expression = { $_.Description } }, 
                    @{Name = "Tamaño(GB)"; Expression = { [Math]::Round($_.Size / 1GB, 2) } } | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letra = Read-Host "Escribe la letra de la unidad a REVISAR (ejemplo: D)"

                    # Limpiar la entrada (por si el usuario escribió "D:" o "d ")
                    $unidad = $letra.Replace(":", "").Trim().ToUpper()

                    # 3. Validación y ejecución
                    if (-not [string]::IsNullOrWhiteSpace($unidad) -and $unidad.Length -eq 1) {
                            
                        $pathUnidad = "${unidad}:"
                        Write-Host "Preparando CHKDSK para la unidad $pathUnidad..." -ForegroundColor Yellow
                        Write-Host "Nota: Si la unidad está en uso, se solicitara programar para el proximo reinicio." -ForegroundColor Gray

                        # Ejecución de chkdsk con los parámetros originales
                        # /F (Corregir), /R (Recuperar sectores), /X (Forzar desmontaje)
                        chkdsk.exe $pathUnidad /F /R /X
                    }
                    else {
                        Write-Host "Error: Letra de unidad no valida." -ForegroundColor Red
                    }                

                    Write-Host ""
                }
                "12" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    # 1. Mostrar información de las unidades de forma profesional
                    Write-Host "--- UNIDADES DISPONIBLES ---" -ForegroundColor Cyan
                    Get-WmiObject Win32_LogicalDisk | Select-Object DeviceID, VolumeName, Description | Format-Table -AutoSize

                    # 2. CAPTURA DE DATO: Solicitar la letra de la unidad
                    $letraInput = Read-Host "Escribe la letra de la UNIDAD para quitar atributos"
                    $unidad = $letraInput.Replace(":", "").Trim().ToUpper() + ":\"

                    # 3. Validación de existencia
                    if (Test-Path $unidad) {
                        Write-Host "`nQuitando atributos (Solo lectura, Sistema, Oculto) en $unidad..." -ForegroundColor Yellow
                            
                        # Buscamos todos los archivos y carpetas de forma recursiva
                        $elementos = Get-ChildItem -Path $unidad -Recurse -Force -ErrorAction SilentlyContinue

                        foreach ($item in $elementos) {
                            try {
                                # Establecemos los atributos a "Normal" (equivale a quitar R, S, H, A)
                                Set-ItemProperty -Path $item.FullName -Name Attributes -Value "Normal"
                            }
                            catch {
                                # Algunos archivos del sistema pueden estar bloqueados, los ignoramos
                                continue
                            }
                        }
                            
                        Write-Host "Proceso completado en $unidad" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Error: La unidad $unidad no existe o no es válida." -ForegroundColor Red
                    }

                    Write-Host ""
                }
                "13" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "chrome.exe" -ArgumentList "--incognito"

                    Write-Host ""
                }
                "14" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"
                        
                    Start-Process "control.exe" -ArgumentList "inetcpl.cpl"

                    Write-Host ""
                }
                "15" { 
                    # clear-Host
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "taskkill.exe" -ArgumentList "/F /IM explorer.exe" -NoNewWindow -Wait

                    Write-Host ""
                }
                "16" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "explorer.exe"               

                    Write-Host ""
                }

                "17" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process taskmgr

                    Write-Host ""
                }

                "18" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process cmd

                    Write-Host ""
                }

                "19" { 
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "PowerShell.exe"

                    Write-Host ""
                }

                "20" { 
                    # Llamada a submenu.20
                    psSubMenu20
                }
                "21" { 
                    # Llamada a submenu.21
                    psSubMenu21
                }
                "22" { 
                    # Llamada a submenu.22
                    psSubMenu22
                }
                "23" { 
                    # Llamada a submenu.23
                    psSubMenu23
                }
                "24" { 
                    # Llamada a submenu.24
                    psSubMenu24
                }
                "25" { 
                    # Llamada a submenu.25
                    psSubMenu25
                }
                "26" { 
                    # Llamada a submenu.26
                    psSubMenu26
                }
                "27" { 
                    # Llamada a submenu.27
                    psSubMenu27
                }
                "28" {
                    # Llamada a submenu.28
                    psSubMenu28
                }
                
                "29.1" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/s /f /t 5"

                    Write-Host ""
                        
                }
                "29.2" {
                    cabecera
                    menuOpcion "Haz elegido la opcion: $opcion"

                    Start-Process "shutdown.exe" -ArgumentList "/g /f /t 5"

                    Write-Host ""
                        
                }
                "30" {
                    cabecera
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
                    Write-Host "`n[!] Descargando y reiniciando desde repositorio remoto..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 2
                    Start-Process powershell.exe -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-Command", "irm https://raw.githubusercontent.com/spwil/shellWil/main/ShellSW.bat | iex"
                    exit
                }

                "1010" {
                    cabecera
                    menuOpcion "MODO DESARROLLADOR: PUBLICAR EN GITHUB (Opcion 1010)"
                    
                    # 1. Resolver ruta del repositorio
                    $repoPath = if ($env:SCRIPT_PATH) { Split-Path $env:SCRIPT_PATH } else { $PSScriptRoot }
                    if (-not $repoPath) { $repoPath = Get-Location }

                    # 2. Detección técnica estricta de entorno de desarrollo
                    $esDesarrollo = $false
                    $gitPath = Get-Command git -ErrorAction SilentlyContinue
                    
                    if ($gitPath -and (Test-Path (Join-Path $repoPath ".git"))) {
                        Push-Location $repoPath
                        try {
                            $remoteUrl = git remote get-url origin 2>$null
                            # Validamos que el origin coincida con el repositorio del proyecto
                            if ($remoteUrl -like "*spwil/shellWil*") {
                                $esDesarrollo = $true
                            }
                        }
                        finally {
                            Pop-Location
                        }
                    }

                    if (-not $esDesarrollo) {
                        Write-Host "`n[INFO] Esta opcion solo esta disponible en el entorno de desarrollo autorizado." -ForegroundColor Yellow
                        Write-Host "No se detecto la carpeta local de Git o el repositorio origin correcto." -ForegroundColor Gray
                        Write-Host ""
                    }
                    else {
                        # 3. Auto-compilación automática
                        Write-Host "`n[*] Iniciando auto-compilacion del script unificado (build.ps1)..." -ForegroundColor Cyan
                        psReconstruirSiDesarrollo

                        # 4. Mostrar resumen de cambios
                        Push-Location $repoPath
                        try {
                            Write-Host "`n[*] Resumen de archivos modificados para subir:" -ForegroundColor Yellow
                            $gitStatus = git status -s
                            if ([string]::IsNullOrEmpty($gitStatus)) {
                                Write-Host "No hay cambios pendientes de confirmacion en el repositorio." -ForegroundColor Green
                                Pop-Location
                                return
                            }
                            Write-Host $gitStatus -ForegroundColor Gray
                            Write-Host ""

                            # 5. Solicitar descripción del commit
                            $desc = Read-Host "Ingrese la descripcion para el commit (Mensaje de Git)"
                            if ([string]::IsNullOrEmpty($desc)) {
                                Write-Host "`n[!] Operacion cancelada: El mensaje de commit no puede estar vacio." -ForegroundColor Red
                                Pop-Location
                                return
                            }

                            # 6. Confirmación de seguridad
                            $confirmar = Read-Host "¿Proceder con la actualizacion en GitHub? (S/N) [N]"
                            if ($confirmar -notmatch "^[sS]$") {
                                Write-Host "`n[!] Operacion cancelada por el usuario." -ForegroundColor Yellow
                                Pop-Location
                                return
                            }

                            # 7. Ejecución de Git
                            Write-Host "`n[*] Agregando archivos al area de preparacion (git add -A)..." -ForegroundColor Gray
                            git add -A
                            
                            Write-Host "[*] Confirmando cambios localmente (git commit)..." -ForegroundColor Gray
                            $commitResult = git commit -m "$desc" 2>&1
                            Write-Host $commitResult -ForegroundColor Gray

                            # Detectar rama activa actual dinámicamente
                            $activeBranch = git branch --show-current
                            if ([string]::IsNullOrEmpty($activeBranch)) {
                                $activeBranch = "main" # fallback
                            }

                            Write-Host "[*] Subiendo cambios a GitHub en la rama '$activeBranch' (git push)..." -ForegroundColor Yellow
                            $pushResult = git push origin $activeBranch 2>&1
                            
                            # Comprobar código de salida
                            if ($LASTEXITCODE -eq 0) {
                                Write-Host "`n[OK] ¡Repositorio de GitHub actualizado exitosamente en la rama '$activeBranch'!" -ForegroundColor Green
                            } else {
                                Write-Host "`n[ERROR] Ocurrio un problema al subir los cambios." -ForegroundColor Red
                                Write-Host "Detalle del error:" -ForegroundColor Red
                                Write-Host $pushResult -ForegroundColor Gray
                            }
                        }
                        catch {
                            Write-Host "`n[ERROR NO ESPERADO] Error al interactuar con Git: $_" -ForegroundColor Red
                        }
                        finally {
                            Pop-Location
                        }
                    }
                    Write-Host ""
                }

                "0" { 
                    #$salirPrincipal = $true 
                    Write-Host "C E R R A N D O   A P L I C A C I O N  ..." -ForegroundColor Magenta

                    Write-Host "La tarea ha finalizado. La consola se cerrara en 3 segundos..." -ForegroundColor Cyan
                    Start-Sleep -Seconds 3

                    # Comando para cerrar
                    exit
                }

                Default { 
                    Write-Host "OPCION INVALIDO." -ForegroundColor Red 
                    Start-Sleep -Seconds 1
                }
            } # Cierra switch
            if (-not $salirSub) { Read-Host "MENU PRINCIPAL: Presione ENTER para continuar..." }
        } # Cierra try

        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."            
        } # Cierra catch

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
                $_.Name -notmatch 'salirPrincipal|opcion|SCRIPT_PATH|PWD|PS|HOME|Error|PID' 
            } | Remove-Variable -ErrorAction SilentlyContinue

            # 3. Pequeña pausa para estabilizar procesos de red si fuera necesario
            Start-Sleep -Milliseconds 200
        }

    } while (-not $salirPrincipal)
}
#************************************************* FIN PRINCIPAL ******************************************************************
#**********************************************************************************************************************************


# Ejecutar el MENU PRINCIPAL
menuPrincipal
