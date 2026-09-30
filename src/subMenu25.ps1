function psSubMenu25 {
    # ==============================================================================
    #   FUNCIONES AUXILIARES DE CONEXION Y ANALISIS REMOTO (OPTIMIZACION Y LIMPIEZA)
    # ==============================================================================

    function Get-StandardIPPrompt {
        param(
            [string]$Mensaje = "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos (ej: 176.50)",
            [pscredential]$Credential = $null,
            [switch]$OmitUserInfo
        )
        $inputRaw = Read-Host $Mensaje
        if ([string]::IsNullOrWhiteSpace($inputRaw)) {
            return ""
        }
        $inputRaw = $inputRaw.Trim()

        $resolvedIP = ""
        # Modalidad 1: IP Completa (formato X.X.X.X)
        if ($inputRaw -match '^(\d{1,3}\.){3}\d{1,3}$') {
            $resolvedIP = $inputRaw
        }
        # Modalidad 2: 2 ultimos octetos (ej: 176.50 o 13.15) -> Asume prefijo 192.168.
        elseif ($inputRaw -match '^\d{1,3}\.\d{1,3}$') {
            $resolvedIP = "192.168.$inputRaw"
        }
        # Tolerancia: 1 octeto (ej: 50) -> Asume prefijo 192.168.176.
        elseif ($inputRaw -match '^\d{1,3}$') {
            $resolvedIP = "192.168.176.$inputRaw"
        }
        # Nombre de equipo (Hostname) o formato extendido
        else {
            $resolvedIP = $inputRaw
        }

        # Visualizar inmediatamente la tarjeta del usuario activo como primera salida tras digitar la IP
        if (-not $OmitUserInfo -and -not [string]::IsNullOrWhiteSpace($resolvedIP)) {
            psMostrarInformacionUsuarioActivo -TargetIP $resolvedIP -Credential $Credential
        }

        return $resolvedIP
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

    # ==============================================================================
    #   FUNCIONES DE SONDEO RAPIDO, SNMP NATIVO Y CLASIFICACION DE HARDWARE
    # ==============================================================================

    function Test-PortQuick {
        param(
            [string]$ComputerName,
            [int]$Port,
            [int]$TimeoutMs = 120
        )
        try {
            $tcp = New-Object System.Net.Sockets.TcpClient
            $async = $tcp.BeginConnect($ComputerName, $Port, $null, $null)
            if ($async.AsyncWaitHandle.WaitOne($TimeoutMs, $false) -and $tcp.Connected) {
                $tcp.Close()
                return $true
            }
            $tcp.Close()
            return $false
        } catch {
            return $false
        }
    }

    function Enable-LocalTrustedHostsConfig {
        try {
            $wsmanService = Get-Service -Name "WinRM" -ErrorAction SilentlyContinue
            if ($wsmanService -and $wsmanService.Status -ne "Running") {
                Start-Service -Name "WinRM" -ErrorAction SilentlyContinue
            }
            $currentTH = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
            if ($currentTH -ne "*") {
                Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
            }
        } catch {}
    }

    function Invoke-InstalarRSATLocal {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 11.3"
        Write-Host "`n--- INSTALACION DE COMPONENTES RSAT LOCALES ---" -ForegroundColor Cyan

        $isAdmin = Test-IsProcessAdmin
        if (-not $isAdmin) {
            Write-Host "`n[ERROR] La instalacion de componentes RSAT requiere privilegios de Administrador (Token Elevado)." -ForegroundColor Red
            Write-Host "Por favor ejecute la consola con 'Ejecutar como Administrador' para realizar esta accion." -ForegroundColor Yellow
            return
        }

        try {
            # Asegurar servicios previos necesarios para Features on Demand
            $preReqServices = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
            foreach ($s in $preReqServices) {
                try {
                    $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
                    if ($svc) {
                        if ($svc.StartType -eq "Disabled") {
                            Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                        }
                        if ($svc.Status -ne "Running") {
                            Start-Service -Name $s -ErrorAction SilentlyContinue
                        }
                    }
                } catch {}
            }

            # Importar explícitamente Dism
            Import-Module -Name Dism -ErrorAction SilentlyContinue

            if (-not (Get-Command -Name Get-WindowsCapability -ErrorAction SilentlyContinue)) {
                throw "El cmdlet 'Get-WindowsCapability' no esta disponible en este equipo."
            }

            Write-Host "Consultando componentes RSAT pendientes de instalacion..." -ForegroundColor Gray
            $capabilities = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like "Rsat.*" -and $_.State -eq "NotPresent" }
            if (-not $capabilities -or $capabilities.Count -eq 0) {
                Write-Host "[OK] Todos los componentes de RSAT ya estan instalados en este equipo." -ForegroundColor Green
                return
            }

            Write-Host "Se encontraron $($capabilities.Count) componentes disponibles para instalar." -ForegroundColor Cyan
            
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
                        Write-Host "Instalado con exito: $($cap.Name)" -ForegroundColor Green
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
            Write-Host "`n[EXITO] Proceso de instalacion de componentes RSAT completado." -ForegroundColor Green
        }
        catch {
            Write-Host "`nError al instalar componentes RSAT localmente: $($_.Exception.Message)" -ForegroundColor Red
        }
    }

    function Invoke-HabilitarServiciosRSATLocal {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 11.1"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "       HABILITACION Y CONFIGURACION DE SERVICIOS RSAT (PC LOCAL)          " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $isAdmin = Test-IsProcessAdmin
        $modoAuditoria = $false

        if (-not $isAdmin) {
            Write-Host "`n[AVISO DE PRIVILEGIOS DE ADMINISTRADOR]" -ForegroundColor Yellow
            Write-Host "El proceso actual se esta ejecutando como USUARIO ESTANDAR (No Elevado)." -ForegroundColor White
            Write-Host "Para iniciar servicios del sistema, configurar el Firewall y WinRM," -ForegroundColor Gray
            Write-Host "se requieren privilegios de Administrador local (Token Elevado)." -ForegroundColor Gray
            Write-Host ""
            Write-Host "  [1] Auto-elevar con UAC (Abrir consola como Administrador)" -ForegroundColor Cyan
            Write-Host "  [2] Proporcionar credenciales de Administrador (Dominio / Local)" -ForegroundColor Cyan
            Write-Host "  [3] Continuar en Modo AUDITORIA / DIAGNOSTICO (Solo Lectura)" -ForegroundColor Gray
            Write-Host "  [0] Cancelar y regresar al menu" -ForegroundColor Yellow
            Write-Host ""

            $opEle = Read-Host "Seleccione una alternativa [3]"
            if ([string]::IsNullOrWhiteSpace($opEle)) { $opEle = "3" }

            switch ($opEle.Trim()) {
                "1" {
                    $scriptFile = if ($env:SCRIPT_PATH -and (Test-Path $env:SCRIPT_PATH)) { 
                        $env:SCRIPT_PATH 
                    } elseif (Test-Path "E:\shellWil\ShellSW.bat") { 
                        "E:\shellWil\ShellSW.bat" 
                    } else { 
                        Join-Path $PSScriptRoot "..\ShellSW.bat" 
                    }

                    Write-Host "`n[*] Solicitando elevacion UAC de Windows..." -ForegroundColor Cyan
                    try {
                        Start-Process -FilePath "cmd.exe" -ArgumentList "/c `"$scriptFile`"" -Verb RunAs -ErrorAction Stop
                        Write-Host "[OK] Solicitud de elevacion enviada. Se abrira una nueva consola con privilegios." -ForegroundColor Green
                        return
                    } catch {
                        Write-Host "[-] Elevacion cancelada o rechazada: $($_.Exception.Message)" -ForegroundColor Yellow
                        Write-Host "Continuando en Modo Auditoria..." -ForegroundColor Gray
                        $modoAuditoria = $true
                    }
                }
                "2" {
                    Write-Host "`nIngrese credenciales con permisos de Administrador (ej: DOMINIO\Usuario o .\Administrador):" -ForegroundColor Cyan
                    $admCred = Get-Credential
                    if ($admCred) {
                        Write-Host "[*] Credenciales recibidas para $($admCred.UserName)." -ForegroundColor Green
                        Write-Host "[*] Iniciando proceso elevado con credenciales administrativas..." -ForegroundColor Cyan
                        try {
                            $scriptFile = if ($env:SCRIPT_PATH -and (Test-Path $env:SCRIPT_PATH)) { $env:SCRIPT_PATH } else { "E:\shellWil\ShellSW.bat" }
                            Start-Process -FilePath "powershell.exe" -Credential $admCred -ArgumentList "-NoProfile -ExecutionPolicy Bypass -Command `"& { (Get-Content '$scriptFile') | iex; subMenu25 }`"" -ErrorAction Stop
                            Write-Host "[OK] Proceso iniciado con las credenciales suministradas." -ForegroundColor Green
                            return
                        } catch {
                            Write-Host "[-] No se pudo iniciar el proceso delegado: $($_.Exception.Message)" -ForegroundColor Yellow
                            Write-Host "Continuando en Modo Auditoria..." -ForegroundColor Gray
                            $modoAuditoria = $true
                        }
                    } else {
                        Write-Host "Operacion cancelada por el usuario." -ForegroundColor Yellow
                        return
                    }
                }
                "3" {
                    Write-Host "`n[*] Continuando en Modo Auditoria (Solo Lectura)..." -ForegroundColor Yellow
                    $modoAuditoria = $true
                }
                "0" {
                    Write-Host "Operacion cancelada." -ForegroundColor Yellow
                    return
                }
                default {
                    Write-Host "Opcion no reconocida. Continuando en Modo Auditoria..." -ForegroundColor Yellow
                    $modoAuditoria = $true
                }
            }
        }

        # -------------------------------------------------------------------------
        # FASE 1: DIRECTIVA DE EJECUCION DE SCRIPTS (Manejo inteligente de GPO)
        # -------------------------------------------------------------------------
        Write-Host "`n--- [1/5] DIRECTIVA DE EJECUCION DE SCRIPTS ---" -ForegroundColor Yellow
        try {
            $polList = Get-ExecutionPolicy -List
            $mPol = ($polList | Where-Object { $_.Scope -eq 'MachinePolicy' }).ExecutionPolicy
            $uPol = ($polList | Where-Object { $_.Scope -eq 'UserPolicy' }).ExecutionPolicy
            $hasGpo = ($mPol -ne 'Undefined' -or $uPol -ne 'Undefined')

            if ($hasGpo) {
                $gpoName = if ($mPol -ne 'Undefined') { "MachinePolicy: $mPol" } else { "UserPolicy: $uPol" }
                Write-Host "[INFO] Directiva de Dominio (GPO) detectada activa ($gpoName)." -ForegroundColor Cyan
                Write-Host "[*] Aplicando ambito 'Process' (Bypass) para garantizar ejecucion sin alterar GPO..." -ForegroundColor Gray
                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                Write-Host "[OK] Politica temporal 'Bypass' aplicada con exito a este proceso (GPO respetada)." -ForegroundColor Green
            }
            else {
                $effectivePol = Get-ExecutionPolicy
                if ($effectivePol -in @('RemoteSigned', 'Unrestricted', 'Bypass')) {
                    Write-Host "[OK] Directiva efectiva actual ya permite ejecucion de scripts: $effectivePol" -ForegroundColor Green
                }
                else {
                    if ($isAdmin -and -not $modoAuditoria) {
                        try {
                            Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction Stop
                            Write-Host "[OK] Directiva establecida a RemoteSigned para LocalMachine." -ForegroundColor Green
                        } catch {
                            try {
                                Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force -ErrorAction Stop
                                Write-Host "[OK] Directiva establecida a RemoteSigned para CurrentUser." -ForegroundColor Green
                            } catch {
                                Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                                Write-Host "[OK] Directiva establecida a Bypass para el proceso actual." -ForegroundColor Green
                            }
                        }
                    } else {
                        Set-ExecutionPolicy -ExecutionPolicy Bypass -Scope Process -Force -ErrorAction SilentlyContinue
                        Write-Host "[OK] Directiva establecida a Bypass para el proceso actual." -ForegroundColor Green
                    }
                }
            }
        } catch {
            Write-Host "[-] Aviso en directiva de ejecucion: $($_.Exception.Message)" -ForegroundColor Yellow
        }

        # -------------------------------------------------------------------------
        # FASE 2: SERVICIOS DEL SISTEMA PARA RSAT Y ADMINISTRACION
        # -------------------------------------------------------------------------
        Write-Host "`n--- [2/5] SERVICIOS DEL SISTEMA PARA RSAT ---" -ForegroundColor Yellow
        $rsatServices = @(
            @{ Name = "WinRM"; Display = "Administracion remota de Windows (WinRM)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "RemoteRegistry"; Display = "Registro remoto (RemoteRegistry)"; DesiredMode = "Manual"; Required = $false },
            @{ Name = "LanmanWorkstation"; Display = "Estacion de trabajo (LanmanWorkstation / SMB)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "LanmanServer"; Display = "Servidor (LanmanServer / Comparticion)"; DesiredMode = "Automatic"; Required = $false },
            @{ Name = "RpcSs"; Display = "Llamada a procedimiento remoto (RPC)"; DesiredMode = "Automatic"; Required = $true },
            @{ Name = "wuauserv"; Display = "Windows Update (Descarga/FOD de componentes RSAT)"; DesiredMode = "Manual"; Required = $false }
        )

        foreach ($s in $rsatServices) {
            $svcName = $s.Name
            $svcDisp = $s.Display
            $svc = Get-Service -Name $svcName -ErrorAction SilentlyContinue

            if (-not $svc) {
                Write-Host "[-] Servicio $svcDisp no encontrado en este sistema." -ForegroundColor DarkYellow
                continue
            }

            $currentStatus = $svc.Status
            $startType = $svc.StartType

            if ($isAdmin -and -not $modoAuditoria) {
                if ($startType -eq "Disabled") {
                    try {
                        Set-Service -Name $svcName -StartupType $s.DesiredMode -ErrorAction SilentlyContinue
                        Write-Host "[*] $($svcName): Modo de inicio cambiado de Disabled a $($s.DesiredMode)." -ForegroundColor Gray
                    } catch {}
                }

                if ($currentStatus -ne "Running" -and ($s.Required -or $svcName -eq "RemoteRegistry")) {
                    try {
                        Write-Host "[*] Iniciando servicio $($svcName)..." -ForegroundColor Gray
                        Start-Service -Name $svcName -ErrorAction Stop
                        $currentStatus = "Running"
                        Write-Host "[OK] $($svcDisp): INICIADO correctamente." -ForegroundColor Green
                    } catch {
                        Write-Host "[-] No se pudo iniciar $($svcName): $($_.Exception.Message)" -ForegroundColor Yellow
                    }
                } else {
                    $color = if ($currentStatus -eq "Running") { "Green" } else { "Gray" }
                    Write-Host "[OK] $($svcDisp): $currentStatus (Inicio: $startType)" -ForegroundColor $color
                }
            } else {
                $color = if ($currentStatus -eq "Running") { "Green" } else { "Yellow" }
                Write-Host "    $($svcDisp): $currentStatus (Inicio: $startType)" -ForegroundColor $color
            }
        }

        # -------------------------------------------------------------------------
        # FASE 3: WINRM (PSREMOTING) Y TRUSTEDHOSTS
        # -------------------------------------------------------------------------
        Write-Host "`n--- [3/5] WINRM (PSREMOTING) Y TRUSTEDHOSTS ---" -ForegroundColor Yellow
        if ($isAdmin -and -not $modoAuditoria) {
            try {
                Write-Host "[*] Verificando y habilitando WinRM (Enable-PSRemoting)..." -ForegroundColor Gray
                Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction Stop
                Write-Host "[OK] PSRemoting habilitado localmente." -ForegroundColor Green
            } catch {
                Write-Host "[-] Aviso en Enable-PSRemoting: $($_.Exception.Message)" -ForegroundColor Yellow
            }

            try {
                $thVal = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
                if ([string]::IsNullOrWhiteSpace($thVal) -or $thVal -ne "*") {
                    Set-Item WSMan:\localhost\Client\TrustedHosts -Value "*" -Force -ErrorAction SilentlyContinue
                    Write-Host "[OK] TrustedHosts configurado a '*' (Permite gestion remota en cualquier host)." -ForegroundColor Green
                } else {
                    Write-Host "[OK] TrustedHosts ya configurado a '*'." -ForegroundColor Green
                }
            } catch {
                Write-Host "[-] Aviso al configurar TrustedHosts: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        } else {
            $thVal = (Get-Item WSMan:\localhost\Client\TrustedHosts -ErrorAction SilentlyContinue).Value
            Write-Host "    TrustedHosts actual: $(if ($thVal) { $thVal } else { 'No configurado o restringido' })" -ForegroundColor Gray
        }

        # -------------------------------------------------------------------------
        # FASE 4: REGLAS DE FIREWALL PARA ADMINISTRACION
        # -------------------------------------------------------------------------
        Write-Host "`n--- [4/5] REGLAS DE FIREWALL DE WINDOWS ---" -ForegroundColor Yellow
        if ($isAdmin -and -not $modoAuditoria) {
            $fwGroups = @(
                "Windows Remote Management",
                "Administracion remota de Windows",
                "Windows Management Instrumentation (WMI)",
                "Instrumentacion de administracion de Windows (WMI)",
                "File and Printer Sharing",
                "Compartir archivos e impresoras"
            )
            foreach ($grp in $fwGroups) {
                try {
                    netsh advfirewall firewall set rule group="$grp" new enable=yes 2>$null | Out-Null
                } catch {}
            }
            Write-Host "[OK] Reglas de Firewall habilitadas para WinRM, WMI y Comparticion de archivos." -ForegroundColor Green
        } else {
            Write-Host "[*] Modo diagnostico: No se modificaron reglas de firewall (requiere permisos de administrador)." -ForegroundColor Gray
        }

        # -------------------------------------------------------------------------
        # FASE 5: AUDITORIA DE COMPONENTES Y MODULOS RSAT LOCALES
        # -------------------------------------------------------------------------
        Write-Host "`n--- [5/5] AUDITORIA DE HERRAMIENTAS RSAT EN ESTA PC ---" -ForegroundColor Yellow

        $rsatModulos = @(
            @{ Modulo = "ActiveDirectory"; Desc = "Active Directory (Usuarios, Equipos, PowerShell)"; MSC = "dsa.msc" },
            @{ Modulo = "DnsServer"; Desc = "Herramientas de Servidor DNS"; MSC = "dnsmgmt.msc" },
            @{ Modulo = "DhcpServer"; Desc = "Herramientas de Servidor DHCP"; MSC = "dhcpmgmt.msc" },
            @{ Modulo = "GroupPolicy"; Desc = "Administracion de Directivas de Grupo (GPMC)"; MSC = "gpmc.msc" },
            @{ Modulo = "ServerManager"; Desc = "Administrador del Servidor (Server Manager)"; MSC = "ServerManager.exe" }
        )

        $hayFaltantes = $false
        Write-Host ("{0,-20} {1,-14} {2,-35}" -f "COMPONENTE", "ESTADO", "DESCRIPCION") -ForegroundColor DarkGray
        Write-Host ("{0,-20} {1,-14} {2,-35}" -f "----------", "------", "-----------") -ForegroundColor DarkGray

        foreach ($rm in $rsatModulos) {
            $modAvailable = [bool](Get-Module -ListAvailable -Name $rm.Modulo -ErrorAction SilentlyContinue)
            $mscAvailable = Test-Path "$env:SystemRoot\System32\$($rm.MSC)"
            $instalado = ($modAvailable -or $mscAvailable)

            if ($instalado) {
                Write-Host ("{0,-20} " -f $rm.Modulo) -NoNewline
                Write-Host "[INSTALADO]   " -ForegroundColor Green -NoNewline
                Write-Host $rm.Desc -ForegroundColor Gray
            } else {
                $hayFaltantes = $true
                Write-Host ("{0,-20} " -f $rm.Modulo) -NoNewline
                Write-Host "[NO PRESENTE] " -ForegroundColor Yellow -NoNewline
                Write-Host $rm.Desc -ForegroundColor Gray
            }
        }

        Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor Cyan
        if ($hayFaltantes) {
            Write-Host "[AVISO] Se detectaron herramientas RSAT pendientes de instalacion en esta PC." -ForegroundColor Yellow
            Write-Host "Puede instalarlas utilizando la opcion 11.3 de este mismo submenu." -ForegroundColor Cyan
            $instDirecta = Read-Host "¿Desea iniciar la instalacion de los componentes RSAT ahora? (S/N) [N]"
            if ($instDirecta -and $instDirecta.Trim().ToUpper() -eq "S") {
                if (-not $isAdmin) {
                    Write-Host "[-] La instalacion de RSAT requiere privilegios de Administrador. Ejecute la opcion como Administrador." -ForegroundColor Red
                } else {
                    Write-Host "`n[*] Redirigiendo a la instalacion de componentes RSAT (Opcion 11.3)..." -ForegroundColor Cyan
                    Invoke-InstalarRSATLocal
                }
            }
        } else {
            Write-Host "[TODO OK] Todos los componentes RSAT principales y servicios se encuentran activos." -ForegroundColor Green
        }
        Write-Host "==========================================================================" -ForegroundColor Cyan
    }

    function Invoke-HabilitarServiciosRSATRemoto {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 12.1"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "       HABILITACION Y CONFIGURACION DE SERVICIOS RSAT (PC REMOTA)         " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $targetInput = Get-StandardIPPrompt -Mensaje "Ingrese la IP completa (ej: 192.168.176.50) o los 2 ultimos octetos"
        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-Host "Operacion cancelada." -ForegroundColor Red
            return
        }

        # 1. Resolver Hostname y evaluar conectividad
        $targetMachine = $targetInput
        $ipRemota = $targetInput
        Write-Host "`n[*] Verificando enlace de red con $targetInput (Ping)..." -ForegroundColor Yellow
        $pingOk = Test-Connection -ComputerName $targetInput -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($pingOk) {
            Write-Host "[+] Ping respondido por $targetInput." -ForegroundColor Green
        } else {
            Write-Host "[-] El equipo no responde a Ping (posible firewall o equipo apagado)." -ForegroundColor Yellow
        }

        try {
            $dns = [System.Net.Dns]::GetHostEntry($targetInput)
            if ($dns -and $dns.HostName) {
                $targetMachine = $dns.HostName.Split('.')[0]
                Write-Host "[+] Hostname resuelto via DNS: $targetMachine" -ForegroundColor Green
            }
        } catch {
            try {
                $nbt = nbtstat -a $targetInput
                $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                    $targetMachine = $Matches[1].Trim()
                    Write-Host "[+] Hostname resuelto via NetBIOS: $targetMachine" -ForegroundColor Green
                }
            } catch {}
        }

        # 2. Selección de Credenciales Administrativas
        Write-Host "`n--- AUTENTICACION ADMINISTRATIVA REMOTA ---" -ForegroundColor Yellow
        Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Integrado)"
        Write-Host " [2] Usuario de Dominio (ej: DOMINIO\Usuario)"
        Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador)"
        $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($authOpt)) { $authOpt = "1" }

        $cred = $null
        $usu = ""
        $claTexto = ""
        if ($authOpt -eq "2") {
            $domDefecto = $env:USERDOMAIN
            $dom = Read-Host "Ingrese Dominio [Presione Enter para '$domDefecto']"
            if ([string]::IsNullOrWhiteSpace($dom)) { $dom = $domDefecto }
            $uName = Read-Host "Ingrese nombre de usuario de Dominio"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = "$dom\$uName"
                $cla = Read-Host "Ingrese contrasena" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        } elseif ($authOpt -eq "3") {
            $uName = Read-Host "Ingrese nombre de usuario local (ej: Administrador)"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = if ($uName -match "\\|\@") { $uName } else { ".\$uName" }
                $cla = Read-Host "Ingrese contrasena local" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        }

        # 3. Comprobación de puertos de administración
        $port445 = $false
        $port5985 = $false
        try {
            $tSMB = New-Object System.Net.Sockets.TcpClient
            $cSMB = $tSMB.BeginConnect($targetMachine, 445, $null, $null)
            if ($cSMB.AsyncWaitHandle.WaitOne(1000, $false)) { $tSMB.EndConnect($cSMB); $port445 = $true }
            $tSMB.Close()
        } catch {}
        try {
            $tRM = New-Object System.Net.Sockets.TcpClient
            $cRM = $tRM.BeginConnect($targetMachine, 5985, $null, $null)
            if ($cRM.AsyncWaitHandle.WaitOne(1000, $false)) { $tRM.EndConnect($cRM); $port5985 = $true }
            $tRM.Close()
        } catch {}

        Write-Host "  Puerto 445 (SMB)   : $(if ($port445) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port445) { 'Green' } else { 'Yellow' })
        Write-Host "  Puerto 5985 (WinRM): $(if ($port5985) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port5985) { 'Green' } else { 'Yellow' })

        # 4. Script de configuración integral en la PC Remota
        $setupRemoteScript = @'
try {
    # A. Habilitar WinRM y PSRemoting
    try {
        Enable-PSRemoting -SkipNetworkProfileCheck -Force -ErrorAction SilentlyContinue
    } catch {}

    # B. Configurar servicios requeridos para RSAT
    $svcs = @(
        @{ Name = "WinRM"; Mode = "Automatic" },
        @{ Name = "RemoteRegistry"; Mode = "Manual" },
        @{ Name = "wuauserv"; Mode = "Manual" },
        @{ Name = "bits"; Mode = "Manual" },
        @{ Name = "cryptsvc"; Mode = "Automatic" },
        @{ Name = "TrustedInstaller"; Mode = "Manual" },
        @{ Name = "LanmanWorkstation"; Mode = "Automatic" },
        @{ Name = "LanmanServer"; Mode = "Automatic" },
        @{ Name = "RpcSs"; Mode = "Automatic" }
    )
    foreach ($item in $svcs) {
        $n = $item.Name
        try {
            $svc = Get-Service -Name $n -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.StartType -eq "Disabled") {
                    Set-Service -Name $n -StartupType $item.Mode -ErrorAction SilentlyContinue
                }
                if ($svc.Status -ne "Running" -and $n -in @("WinRM","RemoteRegistry","wuauserv","bits","cryptsvc","LanmanWorkstation","LanmanServer","RpcSs")) {
                    Start-Service -Name $n -ErrorAction SilentlyContinue
                }
            }
        } catch {}
    }

    # C. Reglas de Firewall
    $groups = @(
        "Windows Remote Management",
        "Administracion remota de Windows",
        "Windows Management Instrumentation (WMI)",
        "Instrumentacion de administracion de Windows (WMI)",
        "File and Printer Sharing",
        "Compartir archivos e impresoras",
        "Remote Administration",
        "Administracion remota"
    )
    foreach ($g in $groups) {
        netsh advfirewall firewall set rule group="$g" new enable=yes 2>$null | Out-Null
    }

    # D. Directiva de Servicing para Windows Update (Bypass WSUS para FOD)
    $servReg = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\Servicing"
    if (-not (Test-Path $servReg)) { New-Item -Path $servReg -Force | Out-Null }
    Set-ItemProperty -Path $servReg -Name "RepairContentServerSource" -Value 2 -Force -ErrorAction SilentlyContinue
    Set-ItemProperty -Path $servReg -Name "UseWindowsUpdate" -Value 1 -Force -ErrorAction SilentlyContinue

    reg add "HKLM\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System" /v LocalAccountTokenFilterPolicy /t REG_DWORD /d 1 /f 2>$null | Out-Null

    # E. ExecutionPolicy
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine -Force -ErrorAction SilentlyContinue
    } catch {}

    return "OK"
} catch {
    return $_.Exception.Message
}
'@

        Write-Host "`n[*] Aplicando configuracion de servicios RSAT en $targetMachine..." -ForegroundColor Cyan
        $metodoExitoso = ""

        # Método A: WinRM
        if ($port5985) {
            try {
                Write-Host "[*] Intentando configuracion via WinRM..." -ForegroundColor Gray
                $sb = [ScriptBlock]::Create($setupRemoteScript)
                $res = if ($cred) {
                    Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sb -ErrorAction Stop
                } else {
                    Invoke-Command -ComputerName $targetMachine -ScriptBlock $sb -ErrorAction Stop
                }
                if ($res -eq "OK") { $metodoExitoso = "WinRM" }
            } catch {
                Write-Host "[-] WinRM aviso: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # Método B: WMI
        if (-not $metodoExitoso) {
            try {
                Write-Host "[*] Intentando configuracion via WMI..." -ForegroundColor Gray
                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupRemoteScript))
                $cmdLine = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                $procClass = if ($cred) {
                    Get-WmiObject -List -ComputerName $targetMachine -Credential $cred -Class Win32_Process -ErrorAction Stop
                } else {
                    Get-WmiObject -List -ComputerName $targetMachine -Class Win32_Process -ErrorAction Stop
                }
                if ($procClass) {
                    $r = $procClass.Create($cmdLine)
                    if ($r.ReturnValue -eq 0) {
                        $metodoExitoso = "WMI"
                        Write-Host "[OK] Proceso iniciado via WMI. Esperando 5 segundos..." -ForegroundColor Green
                        Start-Sleep -Seconds 5
                    }
                }
            } catch {
                Write-Host "[-] WMI aviso: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        # Método C: PsExec
        if (-not $metodoExitoso -and $port445) {
            $psexecPath = "C:\PSTools\PsExec.exe"
            if (-not (Test-Path $psexecPath)) {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) { $psexecPath = $where.Definition }
            }
            if (Test-Path $psexecPath) {
                Write-Host "[*] Intentando configuracion via PsExec..." -ForegroundColor Gray
                $encoded = [Convert]::ToBase64String([System.Text.Encoding]::Unicode.GetBytes($setupRemoteScript))
                $argBase = "-accepteula -s -h powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $encoded"
                $argExec = if ($usu -ne "") { "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argBase" } else { "\\$targetMachine $argBase" }
                $p = Start-Process -FilePath $psexecPath -ArgumentList $argExec -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                if ($p -and $p.ExitCode -eq 0) {
                    $metodoExitoso = "PsExec"
                }
            }
        }

        Write-Host "`n--------------------------------------------------------------------------" -ForegroundColor Cyan
        if ($metodoExitoso) {
            Write-Host "[EXITO] Servicios y entorno RSAT habilitados en $targetMachine (Via $metodoExitoso)." -ForegroundColor Green
            Write-Host "  * WinRM y PSRemoting activos" -ForegroundColor Gray
            Write-Host "  * Servicios Windows Update, BITS, CryptSvc y TrustedInstaller configurados" -ForegroundColor Gray
            Write-Host "  * Reglas de Firewall habilitadas para administracion" -ForegroundColor Gray
            Write-Host "  * Directiva Servicing configurada para descarga directa de FOD" -ForegroundColor Gray
            Write-Host "`nEl equipo $targetMachine se encuentra PREPARADO para la instalacion (Opcion 12.3)." -ForegroundColor Green
        } else {
            Write-Host "[ERROR] No se pudo completar la habilitacion en $targetMachine." -ForegroundColor Red
            Write-Host "Verifique conectividad, puertos de firewall y credenciales de administrador." -ForegroundColor Yellow
        }
        Write-Host "==========================================================================" -ForegroundColor Cyan
        Write-Host " "
        Read-Host "Presione ENTER para continuar..."
    }

    function Invoke-InstalarRSATRemoto {
        cabecera
        menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: 12.3"
        Write-Host "`n==========================================================================" -ForegroundColor Cyan
        Write-Host "        INSTALACION DE COMPONENTES RSAT EN PC REMOTA                      " -ForegroundColor White -BackgroundColor DarkBlue
        Write-Host "==========================================================================" -ForegroundColor Cyan

        $targetInput = Get-StandardIPPrompt -Mensaje "Ingrese la IP completa (ej: 192.168.176.131) o Nombre de Equipo"
        if ([string]::IsNullOrWhiteSpace($targetInput)) {
            Write-Host "Operacion cancelada." -ForegroundColor Red
            return
        }

        # 1. Enlace y Resolucion Canonica de Nombre de Equipo (WMI -> DNS -> NetBIOS)
        $targetMachine = $targetInput.Trim()
        $ipRemota = $targetInput.Trim()
        Write-Host "`n[*] Verificando enlace de red con $targetInput (Ping)..." -ForegroundColor Yellow
        $pingOk = Test-Connection -ComputerName $targetInput -Count 1 -Quiet -ErrorAction SilentlyContinue
        if ($pingOk) {
            Write-Host "[+] Ping respondido por $targetInput." -ForegroundColor Green
        } else {
            Write-Host "[-] El equipo no responde a Ping (posible cortafuegos o equipo apagado)." -ForegroundColor Yellow
        }

        Write-Host "[*] Resolviendo identidad y CSName de $targetInput..." -ForegroundColor Gray
        try {
            $sys = Get-WmiObject -Class Win32_OperatingSystem -ComputerName $targetInput -ErrorAction Stop
            if ($sys -and $sys.CSName) {
                $targetMachine = $sys.CSName.Trim()
                Write-Host "[+] Nombre canonico resuelto via WMI: $targetMachine" -ForegroundColor Green
            }
        } catch {
            try {
                $dns = [System.Net.Dns]::GetHostEntry($targetInput)
                if ($dns -and $dns.HostName) {
                    $targetMachine = $dns.HostName.Split('.')[0]
                    Write-Host "[+] Hostname resuelto via DNS: $targetMachine" -ForegroundColor Green
                }
            } catch {
                try {
                    $nbt = nbtstat -a $targetInput
                    $linea = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                    if ($linea -and $linea -match "^\s*([A-Za-z0-9\-]+)") {
                        $targetMachine = $Matches[1].Trim()
                        Write-Host "[+] Hostname resuelto via NetBIOS: $targetMachine" -ForegroundColor Green
                    }
                } catch {}
            }
        }

        # 2. Diagnostico de Puertos
        $port445 = $false
        $port5985 = $false
        try {
            $tSMB = New-Object System.Net.Sockets.TcpClient
            $cSMB = $tSMB.BeginConnect($targetMachine, 445, $null, $null)
            if ($cSMB.AsyncWaitHandle.WaitOne(1000, $false)) { $tSMB.EndConnect($cSMB); $port445 = $true }
            $tSMB.Close()
        } catch {}
        try {
            $tRM = New-Object System.Net.Sockets.TcpClient
            $cRM = $tRM.BeginConnect($targetMachine, 5985, $null, $null)
            if ($cRM.AsyncWaitHandle.WaitOne(1000, $false)) { $tRM.EndConnect($cRM); $port5985 = $true }
            $tRM.Close()
        } catch {}

        Write-Host "  Puerto 445 (SMB)   : $(if ($port445) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port445) { 'Green' } else { 'Yellow' })
        Write-Host "  Puerto 5985 (WinRM): $(if ($port5985) { '[ABIERTO]' } else { '[CERRADO]' })" -ForegroundColor $(if ($port5985) { 'Green' } else { 'Yellow' })

        # 3. Autenticacion
        Write-Host "`n--- OPCIONES DE AUTENTICACION ---" -ForegroundColor Yellow
        Write-Host " [1] Usuario actual de Windows (Inicio de sesion unico / Integrado)"
        Write-Host " [2] Usuario de Dominio (ej: DOMINIO\Usuario)"
        Write-Host " [3] Usuario Local de la PC Remota (ej: .\Administrador)"
        $authOpt = Read-Host "Seleccione una opcion [1-3] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($authOpt)) { $authOpt = "1" }

        $cred = $null
        $usu = ""
        $claTexto = ""
        if ($authOpt -eq "2") {
            $domDefecto = $env:USERDOMAIN
            $dom = Read-Host "Ingrese Dominio [Presione Enter para '$domDefecto']"
            if ([string]::IsNullOrWhiteSpace($dom)) { $dom = $domDefecto }
            $uName = Read-Host "Ingrese usuario de Dominio"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = "$dom\$uName"
                $cla = Read-Host "Ingrese contrasena" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        } elseif ($authOpt -eq "3") {
            $uName = Read-Host "Ingrese Administrador Local (ej: Administrador)"
            if (-not [string]::IsNullOrWhiteSpace($uName)) {
                $usu = if ($uName -match "\\|\@") { $uName } else { ".\$uName" }
                $cla = Read-Host "Ingrese contrasena local" -AsSecureString
                $cred = New-Object System.Management.Automation.PSCredential ($usu, $cla)
                $claTexto = [System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToBSTR($cla))
            }
        }

        # Conectar sesion de red administrativa IPC$ localmente si hay credenciales explicitas
        if ($usu -ne "" -and $claTexto -ne "") {
            cmd.exe /c "net use \\$targetMachine\IPC$ /user:`"$usu`" `"$claTexto`"" 2>&1 | Out-Null
        }

        # 4. FASE DE AUDITORIA PREVIA EN VIVO (Verificar que tiene descargado/instalado)
        Write-Host "`n[*] Consultando catalogo e inventario de herramientas RSAT en $targetMachine..." -ForegroundColor Cyan
        $remoteCaps = $null
        if ($port5985) {
            try {
                $sbAudit = {
                    Get-WindowsCapability -Online -ErrorAction SilentlyContinue | Where-Object { $_.Name -like "Rsat.*" } | Select-Object Name, State
                }
                if ($cred -ne $null) {
                    $remoteCaps = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $sbAudit -ErrorAction Stop
                } else {
                    $remoteCaps = Invoke-Command -ComputerName $targetMachine -ScriptBlock $sbAudit -ErrorAction Stop
                }
            } catch {
                Write-Host "[-] Aviso en consulta WinRM: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        $rsatCatalog = @(
            @{ Key = "Rsat.ActiveDirectory.DS-LDS.Tools"; Display = "Herramientas de Active Directory DS y LDS (ADUC)" },
            @{ Key = "Rsat.Dns.Tools"; Display = "Herramientas del Servidor DNS" },
            @{ Key = "Rsat.DHCP.Tools"; Display = "Herramientas de Administracion de DHCP" },
            @{ Key = "Rsat.GroupPolicy.Management.Tools"; Display = "Consola de Administracion de Directivas de Grupo (GPMC)" },
            @{ Key = "Rsat.ServerManager.Tools"; Display = "Consola Administrador del Servidor (Server Manager)" },
            @{ Key = "Rsat.FileServices.Tools"; Display = "Herramientas de Servicios de Archivos y Almacenamiento" },
            @{ Key = "Rsat.CertificateServices.Tools"; Display = "Herramientas de Servicios de Certificados (AD CS)" },
            @{ Key = "Rsat.BitLocker.Recovery.Tools"; Display = "Visor de Recuperacion de Contrasenas de BitLocker" },
            @{ Key = "Rsat.FailoverCluster.Management.Tools"; Display = "Administrador de Clustered de Conmutacion por Error" },
            @{ Key = "Rsat.RemoteAccess.Management.Tools"; Display = "Herramientas de Administracion de Acceso Remoto" },
            @{ Key = "Rsat.RemoteDesktop.Services.Tools"; Display = "Herramientas de Servicios de Escritorio Remoto (RDS)" },
            @{ Key = "Rsat.VolumeActivation.Tools"; Display = "Herramientas de Activacion por Volumen" },
            @{ Key = "Rsat.WSUS.Tools"; Display = "Herramientas de Windows Server Update Services (WSUS)" },
            @{ Key = "Rsat.IPAM.Client.Tools"; Display = "Cliente de Administracion de Direcciones IP (IPAM)" },
            @{ Key = "Rsat.StorageReplica.Tools"; Display = "Modulo de Replica de Almacenamiento" },
            @{ Key = "Rsat.Shielded.VM.Tools"; Display = "Herramientas para Maquinas Virtuales Blindadas" }
        )

        $installedCount = 0
        $pendingCount = 0
        $pendingCapsList = @()

        if ($remoteCaps) {
            Write-Host "`n==========================================================================" -ForegroundColor Cyan
            Write-Host "       ESTADO ACTUAL DE COMPONENTES RSAT EN: $targetMachine               " -ForegroundColor White -BackgroundColor DarkBlue
            Write-Host "==========================================================================" -ForegroundColor Cyan
            foreach ($item in $rsatCatalog) {
                $capObj = $remoteCaps | Where-Object { $_.Name -like "$($item.Key)*" } | Select-Object -First 1
                $dispName = $item.Display.PadRight(58)
                if ($capObj -and ($capObj.State -eq "Installed" -or $capObj.State -eq 4 -or "$($capObj.State)" -match "Installed|4")) {
                    $installedCount++
                    Write-Host " [OK] $dispName : " -NoNewline -ForegroundColor Gray
                    Write-Host "INSTALADO" -ForegroundColor Green
                } else {
                    $pendingCount++
                    $capFullName = if ($capObj) { $capObj.Name } else { "$($item.Key)~~~~0.0.1.0" }
                    $pendingCapsList += $capFullName
                    Write-Host " [!]  $dispName : " -NoNewline -ForegroundColor Gray
                    Write-Host "NO INSTALADO" -ForegroundColor Yellow
                }
            }
            Write-Host "--------------------------------------------------------------------------" -ForegroundColor Cyan
            Write-Host "  Resumen: $installedCount instaladas | $pendingCount pendientes (Total catalogo: $($remoteCaps.Count))" -ForegroundColor White
            Write-Host "==========================================================================" -ForegroundColor Cyan

            if ($pendingCount -eq 0) {
                Write-Host "`n[TODO OK] ¡Todos los componentes de RSAT ya se encuentran instalados en $targetMachine!" -ForegroundColor Green
                Write-Host "El equipo remoto ya cuenta con el paquete completo de herramientas administrativas." -ForegroundColor Gray
                Write-Host "`nOpciones disponibles:" -ForegroundColor Yellow
                Write-Host " [1] Volver al menu principal (Recomendado - No requiere ninguna instalacion)" -ForegroundColor Cyan
                Write-Host " [2] Forzar reinstalacion / reparacion de componentes RSAT" -ForegroundColor White
                $optYaInst = Read-Host "Seleccione una opcion [1-2] (Por defecto: 1)"
                if ([string]::IsNullOrWhiteSpace($optYaInst) -or $optYaInst.Trim() -eq "1") {
                    Write-Host "`nOperacion finalizada. Regresando al menu principal..." -ForegroundColor Green
                    Write-Host " "
                    Read-Host "Presione ENTER para continuar..."
                    return
                }
            }
        } else {
            Write-Host "[!] No se pudo obtener el inventario previo en vivo via WinRM. Se continuara con el asistente." -ForegroundColor Yellow
        }

        # 5. Seleccion de Componentes a Instalar
        Write-Host "`n--- SELECCION DE COMPONENTES RSAT A INSTALAR ---" -ForegroundColor Yellow
        if ($pendingCount -gt 0) {
            Write-Host " [1] Instalar unicamente los $pendingCount componentes PENDIENTES detectados [Recomendado]" -ForegroundColor Cyan
        } else {
            Write-Host " [1] Paquete Esencial (Active Directory DS/LDS, DNS, DHCP, GPMC) [Recomendado - Rapido]" -ForegroundColor Cyan
        }
        Write-Host " [2] Paquete Esencial de Administracion (AD, DNS, DHCP, GPMC)" -ForegroundColor White
        Write-Host " [3] Todos los componentes RSAT disponibles (~21)" -ForegroundColor White
        Write-Host " [4] Personalizado (Ingresar patron, ej: Rsat.ActiveDirectory* o Rsat.Dns*)" -ForegroundColor White
        $compOpt = Read-Host "Seleccione una opcion [1-4] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($compOpt)) { $compOpt = "1" }

        $targetPatterns = @()
        $criterioLabel = ""
        if ($compOpt -eq "1" -and $pendingCount -gt 0) {
            $targetPatterns = $pendingCapsList
            $criterioLabel = "Componentes Pendientes ($pendingCount)"
        } elseif ($compOpt -eq "3") {
            $targetPatterns = @("Rsat.*")
            $criterioLabel = "Todos los componentes RSAT"
        } elseif ($compOpt -eq "4") {
            $customPat = Read-Host "Ingrese el patron a buscar (ej: Rsat.ActiveDirectory*)"
            $targetPatterns = if ([string]::IsNullOrWhiteSpace($customPat)) { @("Rsat.*") } else { @($customPat.Trim()) }
            $criterioLabel = "Personalizado ($($targetPatterns -join ', '))"
        } else {
            $targetPatterns = @(
                "Rsat.ActiveDirectory.DS-LDS.Tools*",
                "Rsat.Dns.Tools*",
                "Rsat.DHCP.Tools*",
                "Rsat.GroupPolicy.Management.Tools*"
            )
            $criterioLabel = "Paquete Esencial de Administracion"
        }
        Write-Host "[*] Criterio de instalacion: $criterioLabel" -ForegroundColor Cyan

        # 6. Seleccion del Origen de Instalacion (Internet / Archivos Locales / Red)
        Write-Host "`n--- ORIGEN DE ARCHIVOS DE INSTALACION (FOD / RSAT) ---" -ForegroundColor Yellow
        Write-Host " [1] Microsoft Update por Internet (Descarga directa automatica) [Por defecto]" -ForegroundColor Cyan
        Write-Host " [2] Carpeta local en la PC remota (ej: C:\FOD o C:\Instaladores\RSAT)" -ForegroundColor White
        Write-Host " [3] Carpeta compartida en la red UNC (ej: \\SERVIDOR\Software\RSAT_FOD)" -ForegroundColor White
        Write-Host " [4] Copiar paquetes FOD desde esta PC hacia la PC remota" -ForegroundColor White
        $origOpt = Read-Host "Seleccione origen [1-4] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($origOpt)) { $origOpt = "1" }

        $sourcePath = ""
        if ($origOpt -eq "2") {
            $pLocal = Read-Host "Ingrese la ruta de la carpeta FOD en la PC remota (ej: C:\FOD)"
            $sourcePath = if ([string]::IsNullOrWhiteSpace($pLocal)) { "" } else { $pLocal.Trim() }
        } elseif ($origOpt -eq "3") {
            $pUNC = Read-Host "Ingrese la ruta UNC compartida de red (ej: \\SERVIDOR\Share\FOD)"
            $sourcePath = if ([string]::IsNullOrWhiteSpace($pUNC)) { "" } else { $pUNC.Trim() }
        } elseif ($origOpt -eq "4") {
            $pMyPC = Read-Host "Ingrese la ruta de la carpeta FOD en ESTA PC local (ej: D:\FOD)"
            if (Test-Path $pMyPC) {
                $destRemote = "\\$targetMachine\C$\Windows\Temp\FOD"
                Write-Host "[*] Copiando archivos FOD desde $pMyPC hacia $destRemote..." -ForegroundColor Cyan
                if (-not (Test-Path $destRemote)) { New-Item -Path $destRemote -ItemType Directory -Force | Out-Null }
                Copy-Item -Path "$pMyPC\*" -Destination $destRemote -Recurse -Force -ErrorAction SilentlyContinue
                Write-Host "[+] Archivos FOD transferidos con exito a la PC remota." -ForegroundColor Green
                $sourcePath = "C:\Windows\Temp\FOD"
            } else {
                Write-Host "[-] Ruta local $pMyPC no encontrada. Se continuara con Microsoft Update." -ForegroundColor Yellow
            }
        }

        # 7. Worker Script Remoto (Contexto SYSTEM)
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
    "IN_PROGRESS|0|0" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    Write-WorkerLog ("Iniciando instalacion remota de RSAT en contexto SYSTEM (" + $env:USERNAME + ")...") "INFO"

    # A. Verificacion y configuracion de servicios criticos
    $services = @("wuauserv", "bits", "cryptsvc", "TrustedInstaller")
    foreach ($s in $services) {
        try {
            $svc = Get-Service -Name $s -ErrorAction SilentlyContinue
            if ($svc) {
                if ($svc.StartType -eq "Disabled") {
                    Set-Service -Name $s -StartupType Manual -ErrorAction SilentlyContinue
                    Write-WorkerLog ("Servicio " + $s + " cambiado de Disabled a Manual.") "INFO"
                }
                if ($svc.Status -ne "Running") {
                    Start-Service -Name $s -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
                    Write-WorkerLog ("Servicio " + $s + " iniciado.") "INFO"
                } else {
                    Write-WorkerLog ("Servicio " + $s + " verificado y activo.") "INFO"
                }
            }
        } catch {
            Write-WorkerLog ("Aviso en servicio " + $s + ": " + $_.Exception.Message) "WARN"
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

            Stop-Service -Name "wuauserv" -Force -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Start-Sleep -Seconds 2
            Start-Service -Name "wuauserv" -WarningAction SilentlyContinue -ErrorAction SilentlyContinue
            Write-WorkerLog "Servicio Windows Update reiniciado correctamente." "INFO"
        } catch {
            Write-WorkerLog ("Aviso en directivas de Windows Update: " + $_.Exception.Message) "WARN"
        }
    } else {
        Write-WorkerLog ("Utilizando repositorio de archivos FOD local/red: " + $offlineSource) "INFO"
    }

    # C. Escaneo de Componentes RSAT a instalar
    Import-Module Dism -ErrorAction SilentlyContinue
    Write-WorkerLog "Consultando catalogo de capacidades DISM en Windows..." "INFO"
    $allCaps = Get-WindowsCapability -Online -ErrorAction Stop | Where-Object { $_.Name -like "Rsat.*" }
    
    $toInstall = @()
    foreach ($cap in $allCaps) {
        if ($cap.State -ne "Installed") {
            foreach ($pat in $targetPatterns) {
                if ($cap.Name -like $pat) {
                    $toInstall += $cap
                    break
                }
            }
        }
    }

    $successCount = 0
    $failCount = 0

    if ($toInstall.Count -eq 0) {
        Write-WorkerLog "Todos los componentes solicitados ya se encuentran instalados en el equipo." "INFO"
        "COMPLETED_NOTHING_TODO" | Out-File -FilePath $statFile -Encoding UTF8 -Force
    }
    else {
        Write-WorkerLog ("Se encontraron " + $toInstall.Count + " componentes para instalar.") "INFO"
        $idx = 0
        foreach ($cap in $toInstall) {
            $idx++
            ("INSTALLING:" + $cap.Name + "|" + $idx + "|" + $toInstall.Count) | Out-File -FilePath $statFile -Encoding UTF8 -Force
            Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Iniciando descarga e instalacion de " + $cap.Name + "...") "START"
            try {
                if (-not [string]::IsNullOrEmpty($offlineSource)) {
                    Add-WindowsCapability -Online -Name $cap.Name -Source $offlineSource -LimitAccess -ErrorAction Stop | Out-Null
                } else {
                    Add-WindowsCapability -Online -Name $cap.Name -ErrorAction Stop | Out-Null
                }

                $chk = Get-WindowsCapability -Online -Name $cap.Name -ErrorAction SilentlyContinue
                if ($chk -and $chk.State -eq "Installed") {
                    Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Instalado con EXITO: " + $cap.Name) "SUCCESS"
                    $successCount++
                } else {
                    Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] Estado no confirmado para: " + $cap.Name) "FAIL"
                    $failCount++
                }
            } catch {
                Write-WorkerLog ("[" + $idx + "/" + $toInstall.Count + "] ERROR al instalar " + $cap.Name + ": " + $_.Exception.Message) "FAIL"
                $failCount++
            }
        }

        if ($failCount -eq 0 -and $successCount -gt 0) {
            ("COMPLETED_SUCCESS:" + $successCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } elseif ($successCount -gt 0 -and $failCount -gt 0) {
            ("COMPLETED_PARTIAL:OK=" + $successCount + ",FAIL=" + $failCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        } else {
            ("COMPLETED_FAILED:" + $failCount) | Out-File -FilePath $statFile -Encoding UTF8 -Force
        }
    }
} catch {
    Write-WorkerLog ("Error critico general: " + $_.Exception.Message) "ERROR"
    ("COMPLETED_FATAL:" + $_.Exception.Message) | Out-File -FilePath $statFile -Encoding UTF8 -Force
} finally {
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

        $patternsFormatted = ($targetPatterns | ForEach-Object { "`"$_`"" }) -join ", "
        $workerHeader = "`$targetPatterns = @($patternsFormatted)`n`$offlineSource = `"$sourcePath`"`n"
        $fullWorkerScript = $workerHeader + $workerBody

        # 8. Despliegue e Inicio de Tarea Programada en la PC Remota
        Write-Host "`n[*] Desplegando tarea programada bajo NT AUTHORITY\SYSTEM en $targetMachine..." -ForegroundColor Yellow
        $initScriptBlock = {
            param($scriptContent)
            if (-not (Test-Path "C:\Windows\Temp")) {
                New-Item -Path "C:\Windows\Temp" -ItemType Directory -Force | Out-Null
            }
            Remove-Item "C:\Windows\Temp\Install-RSAT.log" -Force -ErrorAction SilentlyContinue
            Remove-Item "C:\Windows\Temp\Install-RSAT.status" -Force -ErrorAction SilentlyContinue
            Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue

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
            } catch {
                $cmdCreate = "schtasks.exe /create /f /tn `"$taskName`" /ru `"SYSTEM`" /rl HIGHEST /tr `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1`" /sc ONCE /st 00:00"
                cmd.exe /c $cmdCreate 2>&1 | Out-Null
                cmd.exe /c "schtasks.exe /run /tn `"$taskName`"" 2>&1 | Out-Null
                $registered = $true
            }
            return $registered
        }

        $lanzado = $false
        if ($port5985) {
            try {
                if ($cred -ne $null) {
                    $lanzado = Invoke-Command -ComputerName $targetMachine -Credential $cred -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                } else {
                    $lanzado = Invoke-Command -ComputerName $targetMachine -ScriptBlock $initScriptBlock -ArgumentList $fullWorkerScript -ErrorAction Stop
                }
            } catch {
                Write-Host "[-] WinRM error al desplegar: $($_.Exception.Message)" -ForegroundColor Yellow
            }
        }

        if (-not $lanzado -and $port445) {
            $psexecPath = "C:\PSTools\PsExec.exe"
            if (-not (Test-Path $psexecPath)) {
                $where = Get-Command psexec -ErrorAction SilentlyContinue
                if ($where) { $psexecPath = $where.Definition }
            }
            if (Test-Path $psexecPath) {
                Write-Host "[*] Intentando despliegue de tarea via PsExec..." -ForegroundColor Gray
                try {
                    $remoteTemp = "\\$targetMachine\C$\Windows\Temp"
                    if (Test-Path $remoteTemp) {
                        [System.IO.File]::WriteAllText("$remoteTemp\Install-RSAT-Worker.ps1", $fullWorkerScript, [System.Text.Encoding]::UTF8)
                        $cmdTask = "schtasks.exe /create /f /tn `"Install-RSAT-Task`" /ru `"SYSTEM`" /rl HIGHEST /tr `"powershell.exe -NoProfile -ExecutionPolicy Bypass -File C:\Windows\Temp\Install-RSAT-Worker.ps1`" /sc ONCE /st 00:00 & schtasks.exe /run /tn `"Install-RSAT-Task`""
                        $argBase = "-accepteula -s cmd.exe /c `"$cmdTask`""
                        $argExec = if ($usu -ne "") { "\\$targetMachine -u `"$usu`" -p `"$claTexto`" $argBase" } else { "\\$targetMachine $argBase" }
                        $p = Start-Process -FilePath $psexecPath -ArgumentList $argExec -Wait -NoNewWindow -PassThru -ErrorAction SilentlyContinue
                        if ($p -and $p.ExitCode -eq 0) { $lanzado = $true }
                    }
                } catch {}
            }
        }

        if (-not $lanzado) {
            Write-Host "[ERROR] No se pudo desplegar ni iniciar la tarea en $targetMachine." -ForegroundColor Red
            Write-Host "Verifique conectividad, cortafuegos o credenciales de administrador." -ForegroundColor Yellow
            Write-Host " "
            Read-Host "Presione ENTER para continuar..."
            return
        }

        Write-Host "[+] Tarea iniciada con exito en $targetMachine." -ForegroundColor Green

        # 9. Seleccion de Modalidad de Monitoreo
        Write-Host "`n--- MODALIDAD DE MONITOREO DEL PROGRESO ---" -ForegroundColor Yellow
        Write-Host " [1] Monitorear en NUEVA VENTANA (Recomendado - Libera esta consola de inmediato)" -ForegroundColor Cyan
        Write-Host " [2] Monitorear en ESTA CONSOLA (En linea - Bloqueante)" -ForegroundColor White
        $monOpt = Read-Host "Seleccione una modalidad [1-2] (Por defecto: 1)"
        if ([string]::IsNullOrWhiteSpace($monOpt)) { $monOpt = "1" }

        # Script de Monitoreo Detallado (en nueva ventana o en consola)
        $monitorScriptCode = @"
`$Host.UI.RawUI.WindowTitle = "MONITOR RSAT: $targetMachine | shellWil"
try {
    if (`$Host.UI.RawUI.BufferSize.Width -lt 115) {
        `$Host.UI.RawUI.BufferSize = New-Object Management.Automation.Host.Size(115, 3000)
        `$Host.UI.RawUI.WindowSize = New-Object Management.Automation.Host.Size(115, 42)
    }
} catch {}

Clear-Host
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "                MONITOR DE INSTALACION DE COMPONENTES RSAT REMOTO                         " -ForegroundColor White -BackgroundColor DarkBlue
Write-Host "==========================================================================================" -ForegroundColor Cyan
Write-Host "  Equipo Destino : $targetMachine" -ForegroundColor Yellow
Write-Host "  Criterio       : $criterioLabel" -ForegroundColor White
Write-Host "  Hora de Inicio : `$((Get-Date).ToString('HH:mm:ss'))" -ForegroundColor Gray
Write-Host "==========================================================================================`n" -ForegroundColor Cyan

# Autenticacion IPC si hay credenciales explicitas
if ("$usu" -ne "" -and "$claTexto" -ne "") {
    cmd.exe /c "net use \\$targetMachine\IPC$ /user:`"$usu`" `"$claTexto`"" 2>&1 | Out-Null
}

Write-Host "[*] Conectando con $targetMachine y transmitiendo progreso en tiempo real...`n" -ForegroundColor Gray

`$startTime = Get-Date
`$lastLine = 0
`$terminado = `$false
`$maxMinutes = 35
`$lastActivityTime = Get-Date
`$finalStatus = ""
`$ultimoComponente = ""

while (-not `$terminado) {
    Start-Sleep -Seconds 3
    `$elapsed = "{0:mm\:ss}" -f ((Get-Date) - `$startTime)

    `$newLines = @()
    `$status = "RUNNING"

    # 1. Lectura directa via SMB
    `$logSMB = "\\$targetMachine\C$\Windows\Temp\Install-RSAT.log"
    `$statSMB = "\\$targetMachine\C$\Windows\Temp\Install-RSAT.status"
    `$smbOk = `$false

    if (Test-Path `$logSMB) {
        try {
            `$all = Get-Content `$logSMB -Encoding UTF8 -ErrorAction SilentlyContinue
            if (`$all) {
                `$total = `$all.Count
                if (`$total -gt `$lastLine) {
                    `$newLines = `$all[`$lastLine..(`$total - 1)]
                    `$lastLine = `$total
                    `$lastActivityTime = Get-Date
                }
            }
            `$smbOk = `$true
        } catch {}
    }
    if (Test-Path `$statSMB) {
        try {
            `$stVal = (Get-Content `$statSMB -Raw -ErrorAction SilentlyContinue).Trim()
            if (-not [string]::IsNullOrWhiteSpace(`$stVal)) { `$status = `$stVal }
        } catch {}
    }

    # 2. Fallback WinRM si SMB no estuvo accesible
    if (-not `$smbOk) {
        try {
            `$pollRes = Invoke-Command -ComputerName "$targetMachine" -ScriptBlock {
                param(`$from)
                `$l = "C:\Windows\Temp\Install-RSAT.log"
                `$s = "C:\Windows\Temp\Install-RSAT.status"
                `$lines = @()
                `$tot = 0
                if (Test-Path `$l) {
                    try {
                        `$a = Get-Content `$l -Encoding UTF8 -ErrorAction SilentlyContinue
                        if (`$a) {
                            `$tot = `$a.Count
                            if (`$tot -gt `$from) { `$lines = `$a[`$from..(`$tot - 1)] }
                        }
                    } catch {}
                }
                `$st = "RUNNING"
                if (Test-Path `$s) {
                    try { `$st = (Get-Content `$s -Raw -ErrorAction SilentlyContinue).Trim() } catch {}
                }
                return @{ Lines = `$lines; Total = `$tot; Status = `$st }
            } -ArgumentList `$lastLine -ErrorAction SilentlyContinue

            if (`$pollRes) {
                if (`$pollRes.Total -gt `$lastLine) {
                    `$newLines = `$pollRes.Lines
                    `$lastLine = `$pollRes.Total
                    `$lastActivityTime = Get-Date
                }
                if (`$pollRes.Status) { `$status = `$pollRes.Status }
            }
        } catch {}
    }

    # 3. Procesar y colorear lineas de log
    if (`$newLines -and `$newLines.Count -gt 0) {
        foreach (`$l in `$newLines) {
            if (`$l -match "\[SUCCESS\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Green
            } elseif (`$l -match "\[FAIL\]|\[ERROR\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Red
            } elseif (`$l -match "\[START\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Cyan
            } elseif (`$l -match "\[WARN\]") {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Yellow
            } else {
                Write-Host "  [`$elapsed] `$l" -ForegroundColor Gray
            }
        }
    } else {
        # Latido dinamico con detalle del componente actual
        `$inactiveSec = ((Get-Date) - `$lastActivityTime).TotalSeconds
        if (`$inactiveSec -ge 10) {
            if (`$status -match "^INSTALLING:(.+?)\|(\d+)\|(\d+)") {
                `$cName = `$Matches[1]
                `$cIdx = `$Matches[2]
                `$cTot = `$Matches[3]
                Write-Host "   >>> [`$elapsed] [DESCARGANDO/INSTALANDO] `$cName (Progreso: `$cIdx de `$cTot)..." -ForegroundColor DarkCyan
            } elseif (`$status -like "IN_PROGRESS*") {
                Write-Host "   >>> [`$elapsed] [INICIALIZANDO] Preparando servicios del sistema y catalogo DISM en $targetMachine..." -ForegroundColor DarkCyan
            } else {
                Write-Host "   >>> [`$elapsed] [EN PROGRESO] Operacion activa en PC remota..." -ForegroundColor DarkCyan
            }
            `$lastActivityTime = Get-Date
        }
    }

    # 4. Evaluacion de fin de proceso
    if (`$status -like "COMPLETED_*") {
        `$terminado = `$true
        `$finalStatus = `$status
    }

    # 5. Deteccion de fallo prematuro de la tarea programada
    if (-not `$terminado -and ((Get-Date) - `$startTime).TotalSeconds -gt 15) {
        try {
            `$tChk = schtasks.exe /query /s "$targetMachine" /tn "Install-RSAT-Task" /fo CSV -ErrorAction SilentlyContinue 2>`$null | ConvertFrom-Csv
            if (`$tChk) {
                `$stTask = `$tChk.Status -or `$tChk.Estado
                if (`$stTask -and `$stTask -notmatch "Running|Ejecutando" -and `$status -notlike "COMPLETED_*") {
                    # Tarea finalizo inesperadamente
                    `$terminado = `$true
                    `$finalStatus = "TASK_STOPPED_UNEXPECTEDLY"
                }
            }
        } catch {}
    }

    if (((Get-Date) - `$startTime).TotalMinutes -gt `$maxMinutes) {
        Write-Host "`n[-] Se supero el tiempo limite de `$maxMinutes minutos." -ForegroundColor Red
        break
    }
}

Write-Host "`n==========================================================================================" -ForegroundColor Cyan
if (`$finalStatus -like "COMPLETED_SUCCESS*" -or `$finalStatus -eq "COMPLETED_NOTHING_TODO") {
    Write-Host "[EXITO] Instalacion de RSAT completada correctamente en $targetMachine." -ForegroundColor Green
} elseif (`$finalStatus -like "COMPLETED_PARTIAL*") {
    Write-Host "[AVISO] Instalacion finalizada con algunos componentes instalados y otros con advertencia." -ForegroundColor Yellow
} elseif (`$finalStatus -eq "TASK_STOPPED_UNEXPECTEDLY") {
    Write-Host "[-] La tarea remota se detuvo de forma imprevista." -ForegroundColor Red
    Write-Host "Revise el registro en la PC remota: C:\Windows\Temp\Install-RSAT.log" -ForegroundColor Yellow
} else {
    Write-Host "[-] Instalacion finalizada con estado: `$finalStatus." -ForegroundColor Red
    Write-Host "Revise el registro en la PC remota: C:\Windows\Temp\Install-RSAT.log" -ForegroundColor Yellow
}
Write-Host "Tiempo total transcurrido: `$elapsed" -ForegroundColor Gray
Write-Host "==========================================================================================" -ForegroundColor Cyan

# Limpieza remota
try {
    Invoke-Command -ComputerName "$targetMachine" -ScriptBlock {
        Unregister-ScheduledTask -TaskName "Install-RSAT-Task" -Confirm:`$false -ErrorAction SilentlyContinue | Out-Null
        Remove-Item "C:\Windows\Temp\Install-RSAT-Worker.ps1" -Force -ErrorAction SilentlyContinue
    } -ErrorAction SilentlyContinue | Out-Null
} catch {}

Write-Host "`nPresione cualquier tecla para continuar..." -ForegroundColor Gray
try { [void][System.Console]::ReadKey(`$true) } catch {}
"@

        if ($monOpt.Trim() -eq "1") {
            # Modalidad 1: Nueva Ventana Independiente (Consola Libre)
            $monitorFile = Join-Path $env:TEMP "shellWil_MonitorRSAT_${targetMachine}.ps1"
            [System.IO.File]::WriteAllText($monitorFile, $monitorScriptCode, [System.Text.Encoding]::UTF8)

            Write-Host "`n[*] Abriendo monitor de progreso en una NUEVA VENTANA..." -ForegroundColor Green
            Start-Process powershell.exe -ArgumentList "-NoExit", "-ExecutionPolicy", "Bypass", "-File", "`"$monitorFile`""

            Write-Host "`n==========================================================================" -ForegroundColor Cyan
            Write-Host "  [OK] PROCESO DESPLEGADO Y MONITOR INICIADO EN NUEVA VENTANA INDEPENDIENTE" -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host "  Equipo Destino : $targetMachine" -ForegroundColor White
            Write-Host "  Componentes    : $criterioLabel" -ForegroundColor White
            Write-Host "  Estado         : Tarea programada iniciada en contexto SYSTEM" -ForegroundColor Gray
            Write-Host "  Monitoreo      : Se abrio una ventana secundaria para seguir el avance en vivo." -ForegroundColor Gray
            Write-Host "                   Esta consola queda completamente LIBRE para su uso." -ForegroundColor Green
            Write-Host "==========================================================================" -ForegroundColor Cyan
            Write-Host " "
            Read-Host "Presione ENTER para continuar..."
        } else {
            # Modalidad 2: Monitoreo en Esta Misma Consola (Bloqueante)
            Write-Host "`n[*] Iniciando monitoreo en esta consola..." -ForegroundColor Cyan
            $sbExec = [ScriptBlock]::Create($monitorScriptCode)
            & $sbExec
        }
    }


    function Get-NativeSnmpSummary {
        param(
            [string]$TargetIP,
            [string]$Community = "public",
            [int]$TimeoutMs = 400
        )
        $resObj = [PSCustomObject]@{
            SysDescr = $null
            SysName  = $null
            IsActive = $false
        }

        $fnOidToBytes = {
            param([string]$oid)
            $parts = $oid.Split('.') | ForEach-Object { [int]$_ }
            $bytes = New-Object 'System.Collections.Generic.List[byte]'
            $bytes.Add([byte](40 * $parts[0] + $parts[1]))
            for ($i = 2; $i -lt $parts.Count; $i++) {
                $val = $parts[$i]
                $temp = New-Object 'System.Collections.Generic.List[byte]'
                $temp.Add([byte]($val -band 0x7f))
                $val = $val -shr 7
                while ($val -gt 0) {
                    $temp.Insert(0, [byte](($val -band 0x7f) -bor 0x80))
                    $val = $val -shr 7
                }
                $bytes.AddRange($temp)
            }
            return $bytes.ToArray()
        }

        $fnBuildSnmp = {
            param([string]$comm, [string]$oid)
            $oidBytes = & $fnOidToBytes $oid
            $varbind = New-Object 'System.Collections.Generic.List[byte]'
            $varbind.Add(0x06); $varbind.Add([byte]$oidBytes.Length); $varbind.AddRange($oidBytes)
            $varbind.Add(0x05); $varbind.Add(0x00)

            $varbindList = New-Object 'System.Collections.Generic.List[byte]'
            $varbindList.Add(0x30); $varbindList.Add([byte]$varbind.Count); $varbindList.AddRange($varbind)

            $pdu = New-Object 'System.Collections.Generic.List[byte]'
            $pdu.Add(0x02); $pdu.Add(0x04); $pdu.AddRange(@(0x00, 0x00, 0x00, 0x01))
            $pdu.Add(0x02); $pdu.Add(0x01); $pdu.Add(0x00)
            $pdu.Add(0x02); $pdu.Add(0x01); $pdu.Add(0x00)
            $pdu.AddRange($varbindList)

            $commBytes = [System.Text.Encoding]::ASCII.GetBytes($comm)
            $msg = New-Object 'System.Collections.Generic.List[byte]'
            $msg.Add(0x02); $msg.Add(0x01); $msg.Add(0x01)
            $msg.Add(0x04); $msg.Add([byte]$commBytes.Length); $msg.AddRange($commBytes)

            $env = New-Object 'System.Collections.Generic.List[byte]'
            $env.Add(0xa0); $env.Add([byte]$pdu.Count); $env.AddRange($pdu)
            $msg.AddRange($env)

            $pkt = New-Object 'System.Collections.Generic.List[byte]'
            $pkt.Add(0x30); $pkt.Add([byte]$msg.Count); $pkt.AddRange($msg)
            return $pkt.ToArray()
        }

        $fnQueryOid = {
            param([string]$oid)
            $sock = $null
            try {
                $sock = New-Object System.Net.Sockets.UdpClient
                $sock.Client.ReceiveTimeout = $TimeoutMs
                $pkt = & $fnBuildSnmp $Community $oid
                $sock.Connect($TargetIP, 161)
                $sock.Send($pkt, $pkt.Length) | Out-Null
                $ep = New-Object System.Net.IPEndPoint([System.Net.IPAddress]::Any, 0)
                $resp = $sock.Receive([ref]$ep)

                $oidB = & $fnOidToBytes $oid
                $oidIdx = -1
                for ($i = 0; $i -le ($resp.Length - $oidB.Length); $i++) {
                    $m = $true
                    for ($j = 0; $j -lt $oidB.Length; $j++) {
                        if ($resp[$i + $j] -ne $oidB[$j]) { $m = $false; break }
                    }
                    if ($m) { $oidIdx = $i; break }
                }
                if ($oidIdx -eq -1) { return $null }
                $vIdx = $oidIdx + $oidB.Length
                if ($vIdx -ge $resp.Length) { return $null }
                $vTag = $resp[$vIdx]
                $lByte = $resp[$vIdx + 1]
                $dIdx = $vIdx + 2
                $vLen = $lByte
                if ($lByte -band 0x80) {
                    $nBytes = $lByte -band 0x7f
                    $vLen = 0
                    for ($k = 0; $k -lt $nBytes; $k++) { $vLen = ($vLen -shl 8) + $resp[$dIdx + $k] }
                    $dIdx += $nBytes
                }
                if (($dIdx + $vLen) -gt $resp.Length) { return $null }
                if ($vTag -eq 0x04) {
                    return [System.Text.Encoding]::ASCII.GetString($resp, $dIdx, $vLen)
                }
                return $null
            } catch {
                return $null
            } finally {
                if ($sock) { $sock.Close() }
            }
        }

        $d = & $fnQueryOid "1.3.6.1.2.1.1.1.0"
        if ($d) {
            $resObj.SysDescr = $d.Trim()
            $resObj.IsActive = $true
        }
        $n = & $fnQueryOid "1.3.6.1.2.1.1.5.0"
        if ($n) {
            $resObj.SysName = $n.Trim()
            $resObj.IsActive = $true
        }
        return $resObj
    }

    function Get-NetworkDeviceProfile {
        param(
            [string]$TargetIP,
            [string]$HostName,
            [string]$MACAddress
        )

        $ouiDB = @{
            '00:17:61' = 'ZKTeco (Biometrico)'; '6C:DF:FB' = 'ZKTeco (Biometrico)'; 'E0:69:95' = 'ZKTeco (Biometrico)'
            'C4:2F:90' = 'ZKTeco (Biometrico)'; '00:0B:82' = 'Grandstream (Biometrico/VoIP)'; '2C:26:17' = 'Anviz (Biometrico)'
            '50:13:95' = 'Suprema (Biometrico)'
            '00:26:73' = 'Ricoh (Fotocopiadora)'; '00:00:85' = 'Canon (Fotocopiadora/Impresora)'; '00:20:6B' = 'Konica Minolta (Fotocopiadora)'
            '00:04:F2' = 'Polycom/Ricoh'; '00:17:C8' = 'Kyocera (Fotocopiadora)'; '00:C0:EE' = 'Kyocera (Fotocopiadora)'
            '00:00:AA' = 'Xerox (Fotocopiadora)'; '00:80:77' = 'Brother (Fotocopiadora/Impresora)'; '00:1B:A9' = 'Toshiba (Fotocopiadora)'
            '78:8C:77' = 'Sharp (Fotocopiadora)'; '00:00:07' = 'Xerox (Fotocopiadora)'
            '00:1E:0B' = 'HP (Impresora)'; '00:25:B3' = 'HP (Impresora)'; '3C:D9:2B' = 'HP (Impresora)'
            '70:5A:0F' = 'HP (Impresora)'; 'A4:5D:36' = 'HP (Impresora)'; '00:00:48' = 'Epson (Impresora)'
            '00:26:AB' = 'Epson (Impresora)'; '00:01:E6' = 'Hewlett Packard (Impresora)'; '00:05:9A' = 'Zebra (Impresora)'
            '58:38:79' = 'Hikvision (CCTV)'; '44:19:B6' = 'Hikvision (CCTV)'; 'C0:56:E3' = 'Hikvision (CCTV)'
            'B4:A3:82' = 'Hikvision (CCTV)'; '28:57:BE' = 'Hikvision (CCTV)'; '54:C4:15' = 'Dahua (CCTV)'
            'E0:50:8B' = 'Dahua (CCTV)'; '38:AF:29' = 'Dahua (CCTV)'; 'B0:C5:54' = 'Dahua (CCTV)'
            '00:40:8C' = 'Axis (CCTV)'; '48:EA:63' = 'Uniview (CCTV)'
            '00:00:0C' = 'Cisco Systems'; '00:01:42' = 'Cisco Systems'; '00:1C:7F' = 'Cisco Systems'
            '00:1A:A1' = 'Cisco Systems'; '48:8F:5A' = 'HPE Aruba'; '6C:3B:6B' = 'HPE Aruba'
            'CC:2D:E0' = 'HPE ProCurve'; 'D4:CA:6D' = 'MikroTik'; 'D4:F5:EF' = 'Huawei'
            'C0:06:C3' = 'D-Link'; '50:D4:F7' = 'TP-Link'
            '24:A4:3C' = 'Ubiquiti Networks'; 'F0:9F:C2' = 'Ubiquiti Networks'
            '50:C7:BF' = 'TP-Link WiFi'; 'E8:48:B8' = 'TP-Link WiFi'
            'F8:BC:12' = 'Dell (Computadora)'; '7C:57:58' = 'Dell (Computadora)'; '00:14:22' = 'Dell (Computadora)'
            '18:66:DA' = 'Dell (Computadora)'; 'B8:CA:3A' = 'Dell (Computadora)'; 'AC:16:2D' = 'Hewlett Packard (PC)'
            'B0:4F:13' = 'Hewlett Packard (PC)'; 'A0:B3:CC' = 'Lenovo (Computadora)'; 'E4:54:E8' = 'Lenovo (Computadora)'
            '00:59:07' = 'Lenovo (Computadora)'
        }

        # 1. Prospeccion rapida de puertos Windows
        $p135 = Test-PortQuick $TargetIP 135 100
        $p445 = Test-PortQuick $TargetIP 445 100
        $p3389 = $false
        $p5985 = $false
        if ($p135 -or $p445) {
            $p3389 = Test-PortQuick $TargetIP 3389 100
            $p5985 = Test-PortQuick $TargetIP 5985 100
        }

        $fabricanteOUI = "No identificado"
        if ($MACAddress -and $MACAddress.Length -ge 8) {
            $pref = $MACAddress.Substring(0, 8).ToUpper()
            if ($ouiDB.ContainsKey($pref)) {
                $fabricanteOUI = $ouiDB[$pref]
            }
        }

        # Si responde puertos Windows (135 o 445), se clasifica como Computadora
        if ($p135 -or $p445) {
            return [PSCustomObject]@{
                IsComputer    = $true
                DeviceType    = "Computadora (Windows PC / Servidor)"
                Port135       = $p135
                Port445       = $p445
                Port3389      = $p3389
                Port5985      = $p5985
                OpenPorts     = @()
                Manufacturer  = $fabricanteOUI
                SnmpData      = $null
                EffectiveHost = $HostName
            }
        }

        # Sondeo de puertos para dispositivos de red no-PC
        $p9100 = Test-PortQuick $TargetIP 9100 120
        $p515  = Test-PortQuick $TargetIP 515 100
        $p631  = Test-PortQuick $TargetIP 631 100
        $p4370 = Test-PortQuick $TargetIP 4370 120
        $p5005 = Test-PortQuick $TargetIP 5005 100
        $p554  = Test-PortQuick $TargetIP 554 100
        $p8000 = Test-PortQuick $TargetIP 8000 100
        $p37777= Test-PortQuick $TargetIP 37777 100
        $p34567= Test-PortQuick $TargetIP 34567 100
        $p8291 = Test-PortQuick $TargetIP 8291 100
        $p22   = Test-PortQuick $TargetIP 22 100
        $p23   = Test-PortQuick $TargetIP 23 100
        $p80   = Test-PortQuick $TargetIP 80 100
        $p443  = Test-PortQuick $TargetIP 443 100
        $p8080 = Test-PortQuick $TargetIP 8080 100

        # Sondeo SNMP
        $snmpInfo = Get-NativeSnmpSummary $TargetIP "public" 400

        $openPortsList = @()
        if ($p9100) { $openPortsList += "9100 (RAW Print)" }
        if ($p515)  { $openPortsList += "515 (LPD Print)" }
        if ($p631)  { $openPortsList += "631 (IPP Print)" }
        if ($p4370) { $openPortsList += "4370 (ZKTeco Biometric)" }
        if ($p5005) { $openPortsList += "5005 (Suprema Biometric)" }
        if ($p554)  { $openPortsList += "554 (RTSP Video)" }
        if ($p8000) { $openPortsList += "8000 (Hikvision SDK)" }
        if ($p37777){ $openPortsList += "37777 (Dahua SDK)" }
        if ($p34567){ $openPortsList += "34567 (XM DVR)" }
        if ($p8291) { $openPortsList += "8291 (MikroTik Winbox)" }
        if ($p22)   { $openPortsList += "22 (SSH)" }
        if ($p23)   { $openPortsList += "23 (Telnet)" }
        if ($p80)   { $openPortsList += "80 (HTTP Web)" }
        if ($p443)  { $openPortsList += "443 (HTTPS Web)" }
        if ($p8080) { $openPortsList += "8080 (HTTP Alt)" }
        if ($snmpInfo.IsActive) { $openPortsList += "161 (SNMP UDP)" }

        # Si SNMP trajo un sysName mas preciso, actualizar HostName
        $effectiveHost = $HostName
        if ([string]::IsNullOrWhiteSpace($effectiveHost) -or $effectiveHost -eq $TargetIP) {
            if ($snmpInfo.SysName) {
                $effectiveHost = $snmpInfo.SysName
            }
        }

        # Logica de clasificacion
        $hUpper = "$effectiveHost $($snmpInfo.SysDescr) $fabricanteOUI".ToUpper()
        $tipo = "Dispositivo de Red (Generico)"

        if ($p4370 -or $p5005 -or ($hUpper -match "ZK|BIO|RELOJ|ANVIZ|TIMESTATION|CONTROL-ASISTENCIA|SUPREMA") -or ($fabricanteOUI -match "ZKTeco|Anviz|Suprema")) {
            $tipo = "Reloj biometrico / Control de Asistencia"
        }
        elseif (($hUpper -match "DVR|NVR|XVR|HIK-NVR|DAHUA-NVR|GRABADOR|HIKVISION-NVR") -or 
                (($p8000 -or $p37777 -or $p34567) -and ($hUpper -notmatch "CAM|IPC") -and $p554)) {
            $tipo = "DVR / NVR (Grabador de Video de Seguridad)"
        }
        elseif ($p554 -or ($hUpper -match "CAM|IPC|CAMERA|DOMO|TUBO|BULLET|CCTV|HIK-CAM|DAHUA-CAM|HIKVISION|DAHUA|UNIVIEW|AXIS") -or ($fabricanteOUI -match "Hikvision|Dahua|Axis|Uniview")) {
            $tipo = "Camara CCTV / Seguridad IP"
        }
        elseif (($hUpper -match "RICOH|AFICIO|KONICA|BIZHUB|KYOCERA|TASKALFA|XEROX|WORKCENTRE|ALTALINK|VERSALINK|TOSHIBA|ESTUDIO|SHARP|MX-|DEVELOP|IMAGERUNNER|IR-ADV|COPIADORA|FOTOCOPIADORA") -or
                ($p9100 -and ($p80 -or $p443) -and ($fabricanteOUI -match "Ricoh|Canon|Konica|Kyocera|Xerox|Toshiba|Sharp"))) {
            $tipo = "Fotocopiadora (Multifuncional Corporativa)"
        }
        elseif ($p9100 -or $p515 -or $p631 -or ($hUpper -match "PRN|PRINT|EPSON|BROTHER|HP-PRINT|LASERJET|DESKJET|PAGEWIDE|ZEBRA|SATO|IMPRESORA|HEWLETT PACKARD") -or ($fabricanteOUI -match "HP|Epson|Brother|Zebra")) {
            $tipo = "Impresora de red"
        }
        elseif ($p8291 -or ($hUpper -match "ROUTER|GW|GATEWAY|MIKROTIK|FORTINET|CISCO-ROUTER|PFSENSE|OPNSENSE|EDGEROUTER|FIREWALL") -or ($fabricanteOUI -match "MikroTik")) {
            $tipo = "Router / Gateway / Firewall"
        }
        elseif ($p8080 -or ($hUpper -match "WIFI|AP-|AP_|WIRELESS|ACCESSPOINT|UNIFI|UAP|AIRMAX|TENDA|MERCUSYS") -or ($fabricanteOUI -match "Ubiquiti")) {
            $tipo = "Router inalambrico / Access Point"
        }
        elseif ($p22 -or $p23 -or ($snmpInfo.IsActive) -or ($hUpper -match "SW|SWITCH|SW-|CATALYST|PROCURVE|ARUBA|EDGESWITCH|CISCO") -or ($fabricanteOUI -match "Cisco|Aruba|ProCurve|Huawei")) {
            $tipo = "Switch de datos / Red"
        }
        elseif ($hUpper -match "SCANNER|ESCANER|AVISION|FUJITSU") {
            $tipo = "Escaner de red"
        }
        elseif ($p22 -and -not $p135 -and -not $p445) {
            $tipo = "Servidor Linux / Unix"
        }

        $isComputerGuess = $false
        if ($openPortsList.Count -eq 0 -and ($hUpper -match "DESKTOP|LAPTOP|PC|WIN|SRV|SERVER|WS-|HMP")) {
            $isComputerGuess = $true
            $tipo = "Computadora (Windows PC - Firewall Activo / Puertos Filtrados)"
        }

        return [PSCustomObject]@{
            IsComputer    = $isComputerGuess
            DeviceType    = $tipo
            Port135       = $false
            Port445       = $false
            Port3389      = $false
            Port5985      = $false
            OpenPorts     = $openPortsList
            Manufacturer  = $fabricanteOUI
            SnmpData      = $snmpInfo
            EffectiveHost = $effectiveHost
        }
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

        # Visualizar inmediatamente la tarjeta del usuario activo como primera salida tras digitar la IP
        psMostrarInformacionUsuarioActivo -TargetIP $target

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
            Write-Host "    11.1 Habilitar servicios RSAT y ejecucion remota (Local)" -ForegroundColor Cyan
            Write-Host "    11.2 Denegar/Deshabilitar ejecucion remota (Local)" -ForegroundColor Yellow
            Write-Host "    11.3 Instalar todos los componentes de RSAT (Local)" -ForegroundColor Green
            Write-Host "  ----------------------------------------"
            Write-Host "  12. Habilitacion de RSAT - REMOTO"
            Write-Host "    12.1 Habilitar servicios RSAT y ejecucion remota (Remoto)" -ForegroundColor Cyan
            Write-Host "    12.2 Denegar/Deshabilitar ejecucion de scripts (Remoto)" -ForegroundColor Yellow
            Write-Host "    12.3 Instalar componentes de RSAT (Remoto)" -ForegroundColor Green
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

                    Write-Host "`n--- Consultando informacion de red para $ipRemota... ---" -ForegroundColor Yellow

                    # A. Ping rapido (.NET Ping con timeout 800ms)
                    $pingOk = $false
                    try {
                        $pObj = New-Object System.Net.NetworkInformation.Ping
                        $r = $pObj.Send($ipRemota, 800)
                        if ($r.Status -eq [System.Net.NetworkInformation.IPStatus]::Success) {
                            $pingOk = $true
                        }
                    } catch {}
                    if (-not $pingOk) {
                        Write-Warning "El equipo $ipRemota no respondio a ping (Timeout 800ms). Es posible que este apagado o tenga firewall activo."
                    }

                    # B. Resolucion de MAC via ARP / Get-NetNeighbor
                    $macRemota = ""
                    try {
                        $neighbor = Get-NetNeighbor -IPAddress $ipRemota -AddressFamily IPv4 -ErrorAction SilentlyContinue | Select-Object -First 1
                        if ($neighbor -and $neighbor.LinkLayerAddress) {
                            $macRemota = $neighbor.LinkLayerAddress.ToUpper().Replace("-", ":")
                        }
                    } catch {}
                    if ([string]::IsNullOrEmpty($macRemota)) {
                        try {
                            $arpLines = arp -a $ipRemota
                            foreach ($al in $arpLines) {
                                if ($al -match '([0-9a-fA-F]{2}[:-]){5}[0-9a-fA-F]{2}') {
                                    $macRemota = $Matches[0].ToUpper().Replace("-", ":")
                                    break
                                }
                            }
                        } catch {}
                    }
                    if ([string]::IsNullOrEmpty($macRemota)) { $macRemota = "No disponible" }

                    # C. Resolucion de Hostname (DNS Asincrono no bloqueante + Fallback NetBIOS)
                    $computerTarget = $ipRemota
                    $resolvedHost = ""
                    Write-Host "[*] Resolviendo Hostname de $ipRemota..." -ForegroundColor Gray
                    try {
                        $asyncDns = [System.Net.Dns]::BeginGetHostEntry($ipRemota, $null, $null)
                        if ($asyncDns.AsyncWaitHandle.WaitOne(400, $false)) {
                            $entry = [System.Net.Dns]::EndGetHostEntry($asyncDns)
                            if ($entry -and $entry.HostName) {
                                $resolvedHost = $entry.HostName.Split('.')[0]
                                $computerTarget = $resolvedHost
                                Write-Host "[+] Hostname resuelto via DNS: $computerTarget (Kerberos habilitado)" -ForegroundColor Green
                            }
                        }
                    } catch {}

                    if ([string]::IsNullOrEmpty($resolvedHost)) {
                        try {
                            $nbt = nbtstat -a $ipRemota 2>$null
                            $lineaName = $nbt | Where-Object { $_ -match "<\x00>.*UNIQUE" } | Select-Object -First 1
                            if ($lineaName -and $lineaName -match "^\s*([A-Za-z0-9\-]+)") {
                                $resolvedHost = $Matches[1].Trim()
                                $computerTarget = $resolvedHost
                                Write-Host "[+] Hostname resuelto via NetBIOS: $computerTarget" -ForegroundColor Green
                            }
                        } catch {}
                    }

                    if ([string]::IsNullOrEmpty($resolvedHost)) {
                        Write-Host "[-] No se pudo resolver Hostname. Usando IP directamente ($ipRemota)." -ForegroundColor Yellow
                    }

                    # D. Sondeo Rapido de Dispositivo y Clasificacion (< 800 ms)
                    Write-Host "[*] Identificando perfil y servicios del equipo..." -ForegroundColor Gray
                    $devProfile = Get-NetworkDeviceProfile -TargetIP $ipRemota -HostName $computerTarget -MACAddress $macRemota
                    if ($devProfile.EffectiveHost -and $devProfile.EffectiveHost -ne $ipRemota) {
                        $computerTarget = $devProfile.EffectiveHost
                    }

                    # =========================================================================
                    # CASO A: EL EQUIPO NO ES UNA COMPUTADORA (Impresora, Switch, Camara, etc.)
                    # =========================================================================
                    if (-not $devProfile.IsComputer) {
                        Write-Host "`n===========================================================" -ForegroundColor Cyan
                        Write-Host "        DISPOSITIVO DE RED DETECTADO (NO ES UNA PC)        " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Tipo de Dispositivo:  " -NoNewline
                        Write-Host "$($devProfile.DeviceType)" -ForegroundColor Green
                        Write-Host "  Direccion IP:         " -NoNewline
                        Write-Host "$ipRemota" -ForegroundColor Yellow
                        Write-Host "  Nombre de Host:       " -NoNewline
                        $hDisplay = if ($computerTarget -and $computerTarget -ne $ipRemota) { $computerTarget } else { "(Sin Hostname registrado)" }
                        Write-Host "$hDisplay" -ForegroundColor Yellow
                        Write-Host "  Direccion MAC:        " -NoNewline
                        Write-Host "$macRemota" -ForegroundColor Yellow
                        Write-Host "  Fabricante (OUI):     " -NoNewline
                        Write-Host "$($devProfile.Manufacturer)" -ForegroundColor Cyan
                        
                        $portsStr = if ($devProfile.OpenPorts.Count -gt 0) { $devProfile.OpenPorts -join ", " } else { "Ningun puerto estandar responde (Posible bloqueo o filtrado)" }
                        Write-Host "  Servicios / Puertos:  " -NoNewline
                        Write-Host "$portsStr" -ForegroundColor Gray

                        if ($devProfile.SnmpData -and $devProfile.SnmpData.SysDescr) {
                            Write-Host "  Descripcion SNMP:     " -NoNewline
                            Write-Host "$($devProfile.SnmpData.SysDescr)" -ForegroundColor White
                        }
                        if ($devProfile.SnmpData -and $devProfile.SnmpData.SysName) {
                            Write-Host "  Nombre SNMP (sysName):" -NoNewline
                            Write-Host "$($devProfile.SnmpData.SysName)" -ForegroundColor White
                        }

                        $estadoEnlace = if ($pingOk -or $devProfile.OpenPorts.Count -gt 0 -or $macRemota -ne "No disponible") { "En linea / Activo en la red" } else { "Inaccesible / Desconectado" }
                        Write-Host "  Estado de Conexion:   " -NoNewline
                        Write-Host "$estadoEnlace" -ForegroundColor Green
                        Write-Host "===========================================================`n" -ForegroundColor Cyan

                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # =========================================================================
                    # CASO B: EL EQUIPO ES UNA COMPUTADORA (Windows PC / Servidor / Workgroup)
                    # =========================================================================
                    Write-Host "[+] Computadora detectada ($($devProfile.DeviceType)). Iniciando conexion WMI..." -ForegroundColor Cyan

                    # Gestion de Credenciales y reintentos para Dominio / Grupo de Trabajo
                    $sys = $null
                    $cred = $null
                    $targetWmi = if ($resolvedHost) { $resolvedHost } else { $ipRemota }
                    $reintentarConCred = $true
                    $credProporcionada = $null

                    if ($global:RemoteTargetIP -eq $ipRemota -and $global:RemoteTargetCred -ne $null) {
                        $credProporcionada = $global:RemoteTargetCred
                    }

                    while ($reintentarConCred) {
                        $reintentarConCred = $false
                        try {
                            if ($cred) {
                                $sys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $targetWmi -Credential $cred -ErrorAction Stop
                            } else {
                                $sys = Get-WmiObject -Class Win32_ComputerSystem -ComputerName $targetWmi -ErrorAction Stop
                            }
                        }
                        catch {
                            $errMsg = $_.Exception.Message
                            $esAccesoDenegado = ($errMsg -match "Acceso denegado" -or $errMsg -match "Access is denied" -or $errMsg -match "0x80070005")
                            $esRpcNoDisponible = ($errMsg -match "RPC" -or $errMsg -match "0x800706BA" -or $errMsg -match "no disponible")

                            if ($esAccesoDenegado) {
                                Write-Host "`n[!] ERROR DE AUTENTICACION: Acceso denegado (0x80070005)" -ForegroundColor Red
                                Write-Host "    El equipo $ipRemota ($computerTarget) rechazo las credenciales actuales." -ForegroundColor Yellow
                                Write-Host "    Causa habitual: El equipo se encuentra en un GRUPO DE TRABAJO (Workgroup)" -ForegroundColor Yellow
                                Write-Host "    o requiere una cuenta de administrador local especifica (ej: .\Administrador).`n" -ForegroundColor Yellow

                                if ($credProporcionada) {
                                    $resp = Read-Host "¿Desea reintentar usando las credenciales guardadas para $ipRemota? (S/N) [S]"
                                    if ($resp -eq "" -or $resp.ToUpper() -eq "S") {
                                        $cred = $credProporcionada
                                        $reintentarConCred = $true
                                        $credProporcionada = $null
                                        $targetWmi = $ipRemota
                                        Enable-LocalTrustedHostsConfig
                                        Write-Host "[*] Reintentando conexion con credenciales guardadas..." -ForegroundColor Cyan
                                        continue
                                    }
                                }

                                $respIngresar = Read-Host "¿Desea ingresar credenciales para autenticar en $ipRemota? (S/N) [S]"
                                if ($respIngresar -eq "" -or $respIngresar.ToUpper() -eq "S") {
                                    Write-Host "Ingrese credenciales para $ipRemota (ej: .\Administrador o DOMINIO\Usuario):" -ForegroundColor Cyan
                                    $rawCred = Get-Credential
                                    if ($rawCred) {
                                        $uName = $rawCred.UserName
                                        if ($uName -notmatch '\\' -and $uName -notmatch '@') {
                                            $fixedUser = ".\$uName"
                                            $cred = New-Object System.Management.Automation.PSCredential($fixedUser, $rawCred.Password)
                                        } else {
                                            $cred = $rawCred
                                        }
                                        $global:RemoteTargetIP = $ipRemota
                                        $global:RemoteTargetCred = $cred
                                        $targetWmi = $ipRemota
                                        $reintentarConCred = $true
                                        Enable-LocalTrustedHostsConfig
                                        Write-Host "[*] Reintentando conexion con credenciales suministradas..." -ForegroundColor Cyan
                                        continue
                                    }
                                }
                            }
                            elseif ($esRpcNoDisponible) {
                                Write-Host "`n[!] ERROR DE COMUNICACION: Servidor RPC no disponible (0x800706BA)" -ForegroundColor Red
                                Write-Host "    El equipo remoto tiene bloqueado WMI/RPC en el Firewall de Windows" -ForegroundColor Yellow
                                Write-Host "    o los servicios de administracion remota estan detenidos.`n" -ForegroundColor Yellow

                                $respHab = Read-Host "¿Desea intentar HABILITAR WMI, RPC y Firewall en $ipRemota ahora? (S/N) [S]"
                                if ($respHab -eq "" -or $respHab.ToUpper() -eq "S") {
                                    if ($cred) {
                                        $usu = $cred.UserName
                                        $pass = $cred.GetNetworkCredential().Password
                                        psHabilitarAdministracionRemota -targetInput $ipRemota -username $usu -passwordText $pass
                                    } else {
                                        psHabilitarAdministracionRemota -targetInput $ipRemota
                                    }
                                    Write-Host "[*] Esperando 3 segundos y reintentando conexion..." -ForegroundColor Cyan
                                    Start-Sleep -Seconds 3
                                    $reintentarConCred = $true
                                    continue
                                }
                            }
                            else {
                                Write-Host "ERROR: No se pudo establecer conexion con $ipRemota ($computerTarget)." -ForegroundColor Red
                                Write-Host "Detalle: $($errMsg)" -ForegroundColor Gray
                            }
                        }
                    }

                    if (-not $sys) {
                        Write-Host "`nNo fue posible recuperar los datos del equipo remoto." -ForegroundColor Red
                        Read-Host "Presione ENTER para continuar..."
                        break
                    }

                    # Funcion de consulta WMI segura utilizando credenciales si estan disponibles
                    function Get-SubMenuWmiSafe {
                        param(
                            [string]$Class,
                            [string]$Filter = $null,
                            [switch]$SilentlyContinue
                        )
                        $p = @{
                            Class        = $Class
                            ComputerName = $targetWmi
                        }
                        if ($cred) { $p["Credential"] = $cred }
                        if ($Filter) { $p["Filter"] = $Filter }
                        if ($SilentlyContinue) {
                            $p["ErrorAction"] = "SilentlyContinue"
                        } else {
                            $p["ErrorAction"] = "Stop"
                        }
                        return (Get-WmiObject @p)
                    }

                    try {
                        $marca = if ($sys.Manufacturer) { $sys.Manufacturer.Trim() } else { "Desconocido" }
                        $modelo = if ($sys.Model) { $sys.Model.Trim() } else { "Desconocido" }

                        # Dominio / Grupo de trabajo
                        $redGrupo = ""
                        if ($sys.PartOfDomain) {
                            $redGrupo = "Dominio: $($sys.Domain)"
                        } else {
                            $redGrupo = "Grupo de Trabajo: $($sys.Domain)"
                        }

                        $os = Get-SubMenuWmiSafe -Class Win32_OperatingSystem -SilentlyContinue
                        $osName = if ($os -and $os.Caption) { $os.Caption.Trim() } else { "Windows (Desconocido)" }
                        $osVer = if ($os -and $os.Version) { $os.Version.Trim() } else { "" }
                        $osArch = if ($os -and $os.OSArchitecture) { $os.OSArchitecture.Trim() } else { "" }
                        $osDisplay = $osName
                        if ($osVer) { $osDisplay += " ($osVer)" }
                        if ($osArch) { $osDisplay += " $osArch" }

                        # Microprocesador (CPU)
                        $cpu = Get-SubMenuWmiSafe -Class Win32_Processor -SilentlyContinue | Select-Object -First 1
                        $cpuName = if ($cpu -and $cpu.Name) { $cpu.Name.Trim() } else { "Desconocido" }

                        # Memoria RAM
                        $ramSum = (Get-SubMenuWmiSafe -Class Win32_PhysicalMemory -SilentlyContinue | Measure-Object -Property Capacity -Sum).Sum
                        if (-not $ramSum) {
                            $ramSum = $sys.TotalPhysicalMemory
                        }
                        $ramGB = if ($ramSum) { [Math]::Round($ramSum / 1GB, 2) } else { 0 }

                        # Almacenamiento Total (Discos Fisicos)
                        $disks = Get-SubMenuWmiSafe -Class Win32_DiskDrive -SilentlyContinue
                        $totalStorageBytes = 0
                        $diskDetails = @()
                        if ($disks) {
                            foreach ($disk in $disks) {
                                if ($disk.Size) {
                                    $totalStorageBytes += $disk.Size
                                    $sizeGB = [Math]::Round($disk.Size / 1GB, 2)
                                    $diskDetails += "      - $($disk.Model): $sizeGB GB"
                                }
                            }
                        }
                        $totalStorageGB = [Math]::Round($totalStorageBytes / 1GB, 2)

                        # --- MOSTRAR INFORMACION DEL EQUIPO ---
                        Write-Host "`n===========================================================" -ForegroundColor Cyan
                        Write-Host "            CARACTERISTICAS Y ESPECIFICACIONES             " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  Nombre del Equipo (Hostname): " -NoNewline
                        Write-Host "$($sys.Name)" -ForegroundColor Green
                        Write-Host "  Red / Grupo:                  " -NoNewline
                        if ($sys.PartOfDomain) {
                            Write-Host "$redGrupo" -ForegroundColor Green
                        } else {
                            Write-Host "$redGrupo" -ForegroundColor Yellow
                        }
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

                        # (La informacion del usuario activo ya fue visualizada como primer paso tras digitar la IP)

                        # --- OBTENER ADAPTADORES DE RED REMOTOS ---
                        $nicConfigs = Get-SubMenuWmiSafe -Class Win32_NetworkAdapterConfiguration -Filter "IPEnabled = TRUE" -SilentlyContinue
                        
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host "             CONFIGURACION DE RED Y CONECTIVIDAD           " -ForegroundColor Cyan
                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                        Write-Host "  --- Adaptadores de Red Activos ---" -ForegroundColor Yellow
                        Write-Host ""

                        $hayAdaptadorActivo = $false

                        if ($nicConfigs) {
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
                                $adapterInfo = Get-SubMenuWmiSafe -Class Win32_NetworkAdapter -Filter "Index = $($config.Index)" -SilentlyContinue
                                
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

                                $gateways = @()
                                if ($config.DefaultIPGateway) {
                                    foreach ($gw in $config.DefaultIPGateway) {
                                        if ($gw -match "^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$") {
                                            $gateways += $gw
                                        }
                                    }
                                }

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
                        }

                        if (-not $hayAdaptadorActivo) {
                            Write-Host "  No se detectaron adaptadores de red activos con IPv4 configurada en el equipo remoto." -ForegroundColor Red
                        }

                        Write-Host "===========================================================" -ForegroundColor Cyan
                        Write-Host ""
                    }
                    catch {
                        Write-Host "ERROR al consultar especificaciones de $ipRemota ($computerTarget)." -ForegroundColor Red
                        Write-Host "Detalle: $($_.Exception.Message)" -ForegroundColor Gray
                    }

                    [System.GC]::Collect()
                    Read-Host "Presione ENTER para continuar..."
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
                    $credOpt = $null
                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                    }
                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
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
                    $credOpt = $null
                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                    }
                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
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
                    Invoke-HabilitarServiciosRSATLocal
                }

                "11.2" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Deshabilitando ejecucion remota y de scripts localmente..." -ForegroundColor Cyan
                    
                    $isAdmin = Test-IsProcessAdmin
                    if (-not $isAdmin) {
                        Write-Host "`n[ERROR] Esta accion requiere privilegios de Administrador (Token Elevado)." -ForegroundColor Red
                        Write-Host "Por favor ejecute la consola como Administrador." -ForegroundColor Yellow
                    } else {
                        # 1. Deshabilitar PSRemoting
                        try {
                            Write-Host "Deteniendo y deshabilitando servicio WinRM..." -ForegroundColor Gray
                            Disable-PSRemoting -Force -ErrorAction Stop
                            Write-Host "[OK] PSRemoting deshabilitado localmente." -ForegroundColor Green
                        }
                        catch {
                            Write-Host "ADVERTENCIA: No se pudo deshabilitar PSRemoting localmente: $($_.Exception.Message)" -ForegroundColor Yellow
                        }

                        # 2. Configurar ExecutionPolicy con deteccion de GPO
                        try {
                            $polList = Get-ExecutionPolicy -List
                            $mPol = ($polList | Where-Object { $_.Scope -eq 'MachinePolicy' }).ExecutionPolicy
                            $uPol = ($polList | Where-Object { $_.Scope -eq 'UserPolicy' }).ExecutionPolicy
                            if ($mPol -ne 'Undefined' -or $uPol -ne 'Undefined') {
                                Write-Host "[INFO] Directiva de Dominio (GPO) presente. No se modifican directivas corporativas persistentes." -ForegroundColor Cyan
                            } else {
                                Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope LocalMachine -Force -ErrorAction Stop
                                Write-Host "[OK] Politica establecida a Restricted para LocalMachine." -ForegroundColor Green
                            }
                        }
                        catch {
                            try {
                                Set-ExecutionPolicy -ExecutionPolicy Restricted -Scope CurrentUser -Force -ErrorAction Stop
                                Write-Host "[OK] Politica establecida a Restricted para CurrentUser." -ForegroundColor Green
                            }
                            catch {
                                Write-Host "[-] Aviso al restringir directiva: $($_.Exception.Message)" -ForegroundColor Yellow
                            }
                        }
                    }
                }

                "11.3" {
                    Invoke-InstalarRSATLocal
                }

                "12" { 
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op25"
                    Write-Host "Por favor seleccione una sub-opcion especifica (12.1, 12.2 o 12.3)" -ForegroundColor Yellow
                }

                "12.1" {
                    Invoke-HabilitarServiciosRSATRemoto
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
                    Invoke-InstalarRSATRemoto
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
                                    $credOpt = $null
                                    if (-not [string]::IsNullOrWhiteSpace($usu) -and $null -ne $cla) {
                                        $credOpt = New-Object System.Management.Automation.PSCredential("gmsantacruz\$usu", $cla)
                                    }
                                    $IPFinal = Get-StandardIPPrompt -Credential $credOpt
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

                "101" {
                    $salirSub101 = $false
                    do {
                        try {
                            cabecera
                            Write-Header " 101. CREDENCIALES NAVEGADORES (ADMINISTRACION Y AUDITORIA) "
                            Write-Host "  1. Auditoria de navegadores (Perfiles, Sitios Web y Cuentas guardadas)." -ForegroundColor Green
                            Write-Host "  2. Generar reporte consolidado de dominios para Listas Blancas/Negras." -ForegroundColor Cyan
                            Write-Host "  3. Ver historial de accesos y registros de auditoria del Grupo 101." -ForegroundColor Yellow
                            Write-Host "  ----------------------------------------------------------------------"
                            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R"
                            Write-Header "==============================================================="
                            
                            $op101 = Read-Host "Seleccione la tarea a realizar"
                            
                            switch ($op101) {
                                "1" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Auditoria de Navegadores)"
                                    
                                    Write-Host "`n--- AUDITORIA DE NAVEGADORES Y CREDENCIALES GUARDADAS (EQUIPO REMOTO) ---" -ForegroundColor Cyan
                                    Write-Host "[POLITICA DE SEGURIDAD]: Esta herramienta audita unicamente nombres de usuario y URLs asociadas." -ForegroundColor Gray
                                    Write-Host "                         No extrae, descifra ni expone contraseñas, tokens ni cookies." -ForegroundColor Gray

                                    # 1. Control de Acceso: Verificar token de Administrador
                                    $isAdmin = Test-IsProcessAdmin
                                    if (-not $isAdmin) {
                                        Write-Host "`n[ERROR DE SEGURIDAD] Esta funcionalidad requiere una consola con privilegios elevados de Administrador." -ForegroundColor Red
                                        Write-AuditAccess101 -Target "N/A" -Action "Auditoria de Navegadores" -Status "DENEGADO_TOKEN_NO_ELEVADO"
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    # 2. Solicitar Target aplicando lineamientos de subMenu25
                                    $IPFinal = Get-StandardIPPrompt
                                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                                        Write-Host "Operacion cancelada." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    # 3. Resolución de Hostname prioritario para Kerberos y procesos internos
                                    $computerTarget = $IPFinal
                                    Write-Host "`n[*] Resolviendo Hostname de $IPFinal para sesion administrativa..." -ForegroundColor Gray
                                    try {
                                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                                        $computerTarget = $entry.HostName.Split('.')[0]
                                        Write-Host "[+] Hostname resuelto: $computerTarget (Kerberos / SMB habilitado)" -ForegroundColor Green
                                    }
                                    catch {
                                        try {
                                            $sys = Get-CimInstance Win32_OperatingSystem -ComputerName $IPFinal -OperationTimeoutSec 3 -ErrorAction Stop
                                            $computerTarget = $sys.CSName
                                            Write-Host "[+] Hostname resuelto via WMI: $computerTarget" -ForegroundColor Green
                                        }
                                        catch {
                                            Write-Host "[-] No se pudo resolver Hostname. Usando identificador: $IPFinal" -ForegroundColor Yellow
                                        }
                                    }

                                    # Asentar en registro de auditoría el acceso autorizado
                                    Write-AuditAccess101 -Target "$computerTarget ($IPFinal)" -Action "Auditoria de Navegadores" -Status "AUTORIZADO"

                                    # 4. Validar acceso al recurso administrativo
                                    $remoteC = "\\$computerTarget\C$"
                                    if (-not (Test-Path $remoteC)) {
                                        Write-Host "`n[-] ERROR: No se puede acceder al recurso compartido administrativo en $remoteC" -ForegroundColor Red
                                        Write-Host "    Verifique conectividad de red, firewall y permisos de administrador en el destino." -ForegroundColor Yellow
                                        Read-Host "`nPresione ENTER para continuar..."
                                        break
                                    }

                                    # Inicializar motor SQLite
                                    Initialize-WinSqliteHelper

                                    # 5. Detección de navegadores instalados en la máquina remota
                                    Write-Host "`n[*] Detectando navegadores instalados en $computerTarget..." -ForegroundColor Yellow
                                    
                                    $chromePaths = @(
                                        "\\$computerTarget\C$\Program Files\Google\Chrome\Application\chrome.exe",
                                        "\\$computerTarget\C$\Program Files (x86)\Google\Chrome\Application\chrome.exe"
                                    )
                                    $edgePaths = @(
                                        "\\$computerTarget\C$\Program Files (x86)\Microsoft\Edge\Application\msedge.exe",
                                        "\\$computerTarget\C$\Program Files\Microsoft\Edge\Application\msedge.exe"
                                    )
                                    $firefoxPaths = @(
                                        "\\$computerTarget\C$\Program Files\Mozilla Firefox\firefox.exe",
                                        "\\$computerTarget\C$\Program Files (x86)\Mozilla Firefox\firefox.exe"
                                    )
                                    $bravePaths = @(
                                        "\\$computerTarget\C$\Program Files\BraveSoftware\Brave-Browser\Application\brave.exe",
                                        "\\$computerTarget\C$\Program Files (x86)\BraveSoftware\Brave-Browser\Application\brave.exe"
                                    )
                                    $operaPaths = @(
                                        "\\$computerTarget\C$\Program Files\Opera\launcher.exe",
                                        "\\$computerTarget\C$\Program Files (x86)\Opera\launcher.exe"
                                    )

                                    $hasChrome = [bool]($chromePaths | Where-Object { Test-Path $_ })
                                    $hasEdge = [bool]($edgePaths | Where-Object { Test-Path $_ })
                                    $hasFirefox = [bool]($firefoxPaths | Where-Object { Test-Path $_ })
                                    $hasBrave = [bool]($bravePaths | Where-Object { Test-Path $_ })
                                    $hasOpera = [bool]($operaPaths | Where-Object { Test-Path $_ })

                                    Write-Host "    - Google Chrome:   $([char]0x2022) $(if ($hasChrome) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasChrome) { 'Green' } else { 'DarkGray' })
                                    Write-Host "    - Microsoft Edge:  $([char]0x2022) $(if ($hasEdge) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasEdge) { 'Green' } else { 'DarkGray' })
                                    Write-Host "    - Mozilla Firefox: $([char]0x2022) $(if ($hasFirefox) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasFirefox) { 'Green' } else { 'DarkGray' })
                                    Write-Host "    - Brave Browser:   $([char]0x2022) $(if ($hasBrave) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasBrave) { 'Green' } else { 'DarkGray' })
                                    Write-Host "    - Opera:           $([char]0x2022) $(if ($hasOpera) { 'INSTALADO' } else { 'No detectado' })" -ForegroundColor $(if ($hasOpera) { 'Green' } else { 'DarkGray' })

                                    # 6. Escaneo de perfiles de usuario en el equipo remoto
                                    Write-Host "`n[*] Analizando perfiles de usuario en el equipo remoto..." -ForegroundColor Yellow
                                    $usersDir = "\\$computerTarget\C$\Users"
                                    $userFolders = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue | 
                                        Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }

                                    if (-not $userFolders -or $userFolders.Count -eq 0) {
                                        Write-Host "[-] No se pudieron listar carpetas de usuario en $usersDir." -ForegroundColor Yellow
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    $auditGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                                    $localAuditTemp = Join-Path $env:TEMP "ShellSW_Audit_$auditGuid"
                                    New-Item -ItemType Directory -Path $localAuditTemp -Force -ErrorAction SilentlyContinue | Out-Null

                                    $loginResults = [System.Collections.Generic.List[PSCustomObject]]::new()

                                    try {
                                        foreach ($uFolder in $userFolders) {
                                            $uName = $uFolder.Name
                                            Write-Host "  -> Inspeccionando perfil: $uName..." -ForegroundColor Gray

                                            # --- CHROME ---
                                            $chromeUserData = Join-Path $uFolder.FullName "AppData\Local\Google\Chrome\User Data"
                                            if (Test-Path $chromeUserData) {
                                                $profileDirs = Get-ChildItem -Path $chromeUserData -Directory -ErrorAction SilentlyContinue | 
                                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                                foreach ($pDir in $profileDirs) {
                                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                                    if (Test-Path $loginDataFile) {
                                                        $tmpDb = Join-Path $localAuditTemp "Chrome_${uName}_$($pDir.Name)_LoginData"
                                                        try {
                                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                            foreach ($e in $entries) {
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Google Chrome"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
                                                                        Categoria        = $classif.Category
                                                                        Color            = $classif.Color
                                                                        Sugerencia       = $classif.ActionSuggestion
                                                                    })
                                                                }
                                                            }
                                                        } catch {}
                                                        finally {
                                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                                        }
                                                    }
                                                }
                                            }

                                            # --- MICROSOFT EDGE ---
                                            $edgeUserData = Join-Path $uFolder.FullName "AppData\Local\Microsoft\Edge\User Data"
                                            if (Test-Path $edgeUserData) {
                                                $profileDirs = Get-ChildItem -Path $edgeUserData -Directory -ErrorAction SilentlyContinue | 
                                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                                foreach ($pDir in $profileDirs) {
                                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                                    if (Test-Path $loginDataFile) {
                                                        $tmpDb = Join-Path $localAuditTemp "Edge_${uName}_$($pDir.Name)_LoginData"
                                                        try {
                                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                            foreach ($e in $entries) {
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Microsoft Edge"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
                                                                        Categoria        = $classif.Category
                                                                        Color            = $classif.Color
                                                                        Sugerencia       = $classif.ActionSuggestion
                                                                    })
                                                                }
                                                            }
                                                        } catch {}
                                                        finally {
                                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                                        }
                                                    }
                                                }
                                            }

                                            # --- BRAVE ---
                                            $braveUserData = Join-Path $uFolder.FullName "AppData\Local\BraveSoftware\Brave-Browser\User Data"
                                            if (Test-Path $braveUserData) {
                                                $profileDirs = Get-ChildItem -Path $braveUserData -Directory -ErrorAction SilentlyContinue | 
                                                    Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                                foreach ($pDir in $profileDirs) {
                                                    $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                                    if (Test-Path $loginDataFile) {
                                                        $tmpDb = Join-Path $localAuditTemp "Brave_${uName}_$($pDir.Name)_LoginData"
                                                        try {
                                                            [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                            $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                            foreach ($e in $entries) {
                                                                if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                    $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                    $loginResults.Add([PSCustomObject]@{
                                                                        UsuarioLocal     = $uName
                                                                        Navegador        = "Brave Browser"
                                                                        Perfil           = $pDir.Name
                                                                        UrlOrigen        = $e.OriginUrl
                                                                        Dominio          = $classif.Domain
                                                                        UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
                                                                        Categoria        = $classif.Category
                                                                        Color            = $classif.Color
                                                                        Sugerencia       = $classif.ActionSuggestion
                                                                    })
                                                                }
                                                            }
                                                        } catch {}
                                                        finally {
                                                            if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                                        }
                                                    }
                                                }
                                            }

                                            # --- OPERA ---
                                            $operaUserData = Join-Path $uFolder.FullName "AppData\Roaming\Opera Software\Opera Stable"
                                            if (Test-Path $operaUserData) {
                                                $loginDataFile = Join-Path $operaUserData "Login Data"
                                                if (Test-Path $loginDataFile) {
                                                    $tmpDb = Join-Path $localAuditTemp "Opera_${uName}_LoginData"
                                                    try {
                                                        [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                        $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                        foreach ($e in $entries) {
                                                            if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                $classif = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                $loginResults.Add([PSCustomObject]@{
                                                                    UsuarioLocal     = $uName
                                                                    Navegador        = "Opera"
                                                                    Perfil           = "Default"
                                                                    UrlOrigen        = $e.OriginUrl
                                                                    Dominio          = $classif.Domain
                                                                    UsuarioGuardado  = if ([string]::IsNullOrWhiteSpace($e.Username)) { "(Sin usuario / Acceso guardado)" } else { $e.Username }
                                                                    Categoria        = $classif.Category
                                                                    Color            = $classif.Color
                                                                    Sugerencia       = $classif.ActionSuggestion
                                                                })
                                                            }
                                                        }
                                                    } catch {}
                                                    finally {
                                                        if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                                    }
                                                }
                                            }

                                            # --- MOZILLA FIREFOX ---
                                            $firefoxProfiles = Join-Path $uFolder.FullName "AppData\Roaming\Mozilla\Firefox\Profiles"
                                            if (Test-Path $firefoxProfiles) {
                                                $ffDirs = Get-ChildItem -Path $firefoxProfiles -Directory -ErrorAction SilentlyContinue
                                                foreach ($ffDir in $ffDirs) {
                                                    $loginsJson = Join-Path $ffDir.FullName "logins.json"
                                                    if (Test-Path $loginsJson) {
                                                        try {
                                                            $jsonRaw = Get-Content -LiteralPath $loginsJson -Raw -Encoding UTF8 -ErrorAction Stop
                                                            $ffObj = $jsonRaw | ConvertFrom-Json
                                                            if ($ffObj -and $ffObj.logins) {
                                                                foreach ($lg in $ffObj.logins) {
                                                                    $targetUrl = if ($lg.hostname) { $lg.hostname } else { $lg.formSubmitURL }
                                                                    if (-not [string]::IsNullOrWhiteSpace($targetUrl)) {
                                                                        $classif = Get-DomainClassification -UrlOrDomain $targetUrl
                                                                        $userDisplay = if ($lg.encryptedUsername) { "[Protegido por Firefox / NSS]" } else { "(Formulario guardado)" }
                                                                        $loginResults.Add([PSCustomObject]@{
                                                                            UsuarioLocal     = $uName
                                                                            Navegador        = "Mozilla Firefox"
                                                                            Perfil           = $ffDir.Name
                                                                            UrlOrigen        = $targetUrl
                                                                            Dominio          = $classif.Domain
                                                                            UsuarioGuardado  = $userDisplay
                                                                            Categoria        = $classif.Category
                                                                            Color            = $classif.Color
                                                                            Sugerencia       = $classif.ActionSuggestion
                                                                        })
                                                                    }
                                                                }
                                                            }
                                                        } catch {}
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    finally {
                                        # Purga absoluta de archivos temporales
                                        if (Test-Path $localAuditTemp) {
                                            Remove-Item -Path $localAuditTemp -Recurse -Force -ErrorAction SilentlyContinue
                                        }
                                    }

                                    # 7. Presentación de Resultados en Consola
                                    Write-Host "`n==========================================================================================================" -ForegroundColor Cyan
                                    Write-Host "                     RESULTADOS DE AUDITORIA DE NAVEGADORES - EQUIPO: $computerTarget" -ForegroundColor Cyan
                                    Write-Host "==========================================================================================================" -ForegroundColor Cyan

                                    if ($loginResults.Count -eq 0) {
                                        Write-Host "`n[i] No se encontraron credenciales ni accesos guardados en los perfiles examinados de $computerTarget." -ForegroundColor Green
                                    }
                                    else {
                                        Write-Host ("`n{0,-15} {1,-16} {2,-38} {3,-28} {4,-24}" -f "USUARIO PC", "NAVEGADOR", "DOMINIO / SITIO", "USUARIO ASOCIADO", "CATEGORIA SUGERIDA") -ForegroundColor Yellow
                                        Write-Host ("-" * 125) -ForegroundColor Gray

                                        foreach ($item in $loginResults) {
                                            $dispUser = if ($item.UsuarioGuardado.Length -gt 26) { $item.UsuarioGuardado.Substring(0, 23) + "..." } else { $item.UsuarioGuardado }
                                            $dispDomain = if ($item.Dominio.Length -gt 36) { $item.Dominio.Substring(0, 33) + "..." } else { $item.Dominio }
                                            
                                            Write-Host ("{0,-15} {1,-16} {2,-38} " -f $item.UsuarioLocal, $item.Navegador, $dispDomain) -NoNewline
                                            Write-Host ("{0,-28} " -f $dispUser) -ForegroundColor Cyan -NoNewline
                                            Write-Host ("{0,-24}" -f $item.Categoria) -ForegroundColor $item.Color
                                        }

                                        # Resumen consolidado
                                        $totalSitios = $loginResults.Count
                                        $blancasCount = ($loginResults | Where-Object { $_.Categoria -like "*BLANCA*" }).Count
                                        $negrasCount = ($loginResults | Where-Object { $_.Categoria -like "*NEGRA*" }).Count
                                        $sensiblesCount = ($loginResults | Where-Object { $_.Categoria -like "*SENSIBLE*" -or $_.Categoria -like "*RIESGO*" }).Count

                                        Write-Host "`n--- RESUMEN DE SEGURIDAD Y CONTROL DE RED ---" -ForegroundColor Cyan
                                        Write-Host "  Total de Accesos Guardados Identificados: $totalSitios" -ForegroundColor White
                                        Write-Host "  Sitios en Lista Blanca sugerida (Institucionales/Productivos): $blancasCount" -ForegroundColor Green
                                        Write-Host "  Sitios en Lista Negra sugerida (Ocio/Redes Sociales):         $negrasCount" -ForegroundColor Red
                                        Write-Host "  Sitios Financieros o de Riesgo de Exfiltracion:              $sensiblesCount" -ForegroundColor Magenta

                                        # 8. Opciones de Exportación
                                        Write-Host "`n¿Desea exportar este reporte para administracion de red? (S/N) [N]: " -NoNewline -ForegroundColor Yellow
                                        $respExport = Read-Host
                                        if ($respExport -match '^[sS]$') {
                                            $repDir = "C:\shellWil\reportes"
                                            if (-not (Test-Path $repDir)) {
                                                New-Item -ItemType Directory -Path $repDir -Force -ErrorAction SilentlyContinue | Out-Null
                                            }
                                            $timestampStr = Get-Date -Format 'yyyyMMdd_HHmmss'
                                            $csvPath = Join-Path $repDir "Auditoria_Navegadores_${computerTarget}_${timestampStr}.csv"
                                            $txtDominios = Join-Path $repDir "Listas_Dominios_${computerTarget}_${timestampStr}.txt"

                                            # Exportar CSV
                                            $loginResults | Export-Csv -Path $csvPath -NoTypeInformation -Encoding UTF8 -Force
                                            Write-Host "[+] Reporte CSV guardado exitosamente en:" -ForegroundColor Green
                                            Write-Host "    $csvPath" -ForegroundColor White

                                            # Exportar listado de dominios clasificados para reglas de Firewall/Proxy
                                            $dominiosUnicos = $loginResults | Select-Object -ExpandProperty Dominio -Unique | Sort-Object
                                            $dominiosTexto = @"
# ==============================================================================
#   REPORTE DE DOMINIOS PARA REGLAS DE FIREWALL / PROXY (LISTAS BLANCAS / NEGRAS)
#   Equipo Auditado: $computerTarget ($IPFinal) | Fecha: $(Get-Date -Format 'dd/MM/yyyy HH:mm:ss')
#   Generado por: ShellSW - Grupo 101 Credenciales Navegadores
# ==============================================================================

[DOMINIOS - SUGERENCIA LISTA BLANCA (PERMITIR)]
$($loginResults | Where-Object { $_.Categoria -like "*BLANCA*" -or $_.Categoria -like "*PRODUCTIVIDAD*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[DOMINIOS - SUGERENCIA LISTA NEGRA (BLOQUEAR / RESTRINGIR)]
$($loginResults | Where-Object { $_.Categoria -like "*NEGRA*" -or $_.Categoria -like "*RESTRINGIDO*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[DOMINIOS - AUDITORIA FINANCIERA Y RIESGO DE EXFILTRACION]
$($loginResults | Where-Object { $_.Categoria -like "*SENSIBLE*" -or $_.Categoria -like "*RIESGO*" } | Select-Object -ExpandProperty Dominio -Unique | Out-String)

[TODOS LOS DOMINIOS UNICOS IDENTIFICADOS]
$($dominiosUnicos | Out-String)
"@
                                            $dominiosTexto | Out-File -FilePath $txtDominios -Encoding UTF8 -Force
                                            Write-Host "[+] Archivo de reglas de red guardado en:" -ForegroundColor Green
                                            Write-Host "    $txtDominios" -ForegroundColor White
                                        }
                                    }

                                    Read-Host "`nPresione ENTER para continuar..."
                                }

                                "2" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Reporte Consolidado Listas Blancas/Negras)"
                                    Write-Host "`n--- GENERADOR CONSOLIDADO DE REGLAS DE RED PARA FIREWALL / PROXY ---" -ForegroundColor Cyan
                                    Write-Host "Esta opcion permite procesar el equipo remoto y generar directamente las directivas" -ForegroundColor Gray
                                    Write-Host "en formatos compatibles con FortiGate, Squid, RouterOS (MikroTik) o Pi-hole." -ForegroundColor Gray
                                    
                                    $IPFinal = Get-StandardIPPrompt
                                    if ([string]::IsNullOrWhiteSpace($IPFinal)) {
                                        Write-Host "Operacion cancelada." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    $computerTarget = $IPFinal
                                    try {
                                        $entry = [System.Net.Dns]::GetHostEntry($IPFinal)
                                        $computerTarget = $entry.HostName.Split('.')[0]
                                    } catch {}

                                    Write-Host "`n[*] Extrayendo inventario de dominios desde perfiles remotos de $computerTarget..." -ForegroundColor Yellow
                                    
                                    Initialize-WinSqliteHelper
                                    $usersDir = "\\$computerTarget\C$\Users"
                                    if (-not (Test-Path $usersDir)) {
                                        Write-Host "[-] No se pudo conectar a $usersDir. Verifique permisos y red." -ForegroundColor Red
                                        Read-Host "Presione ENTER para continuar..."
                                        break
                                    }

                                    $userFolders = Get-ChildItem -Path $usersDir -Directory -ErrorAction SilentlyContinue | 
                                        Where-Object { $_.Name -notmatch '^(Public|Default|Default User|All Users)$' }

                                    $dominiosDetectados = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::OrdinalIgnoreCase)
                                    $auditGuid = [System.Guid]::NewGuid().ToString("N").Substring(0, 8)
                                    $localAuditTemp = Join-Path $env:TEMP "ShellSW_Audit_$auditGuid"
                                    New-Item -ItemType Directory -Path $localAuditTemp -Force -ErrorAction SilentlyContinue | Out-Null

                                    try {
                                        foreach ($uFolder in $userFolders) {
                                            $browserUserDatas = @(
                                                (Join-Path $uFolder.FullName "AppData\Local\Google\Chrome\User Data"),
                                                (Join-Path $uFolder.FullName "AppData\Local\Microsoft\Edge\User Data"),
                                                (Join-Path $uFolder.FullName "AppData\Local\BraveSoftware\Brave-Browser\User Data")
                                            )
                                            foreach ($bData in $browserUserDatas) {
                                                if (Test-Path $bData) {
                                                    $profileDirs = Get-ChildItem -Path $bData -Directory -ErrorAction SilentlyContinue | 
                                                        Where-Object { $_.Name -eq "Default" -or $_.Name -like "Profile *" }
                                                    foreach ($pDir in $profileDirs) {
                                                        $loginDataFile = Join-Path $pDir.FullName "Login Data"
                                                        if (Test-Path $loginDataFile) {
                                                            $tmpDb = Join-Path $localAuditTemp "tmp_$([System.Guid]::NewGuid().ToString('N').Substring(0,6))"
                                                            try {
                                                                [System.IO.File]::Copy($loginDataFile, $tmpDb, $true)
                                                                $entries = [WinSqliteReader]::ReadLogins($tmpDb)
                                                                foreach ($e in $entries) {
                                                                    if (-not [string]::IsNullOrWhiteSpace($e.OriginUrl)) {
                                                                        $c = Get-DomainClassification -UrlOrDomain $e.OriginUrl
                                                                        if ($c.Domain) { $dominiosDetectados.Add($c.Domain) | Out-Null }
                                                                    }
                                                                }
                                                            } catch {}
                                                            finally {
                                                                if (Test-Path $tmpDb) { Remove-Item $tmpDb -Force -ErrorAction SilentlyContinue }
                                                            }
                                                        }
                                                    }
                                                }
                                            }
                                        }
                                    }
                                    finally {
                                        if (Test-Path $localAuditTemp) { Remove-Item $localAuditTemp -Recurse -Force -ErrorAction SilentlyContinue }
                                    }

                                    Write-Host "`n[+] Total de dominios unicos extraidos: $($dominiosDetectados.Count)" -ForegroundColor Green
                                    Write-Host "`n--- LISTA BLANCA SUGERIDA (Dominios Institucionales / Gubernamentales / Productivos) ---" -ForegroundColor Green
                                    $lb = $dominiosDetectados | Where-Object { (Get-DomainClassification $_).Category -like "*BLANCA*" -or (Get-DomainClassification $_).Category -like "*PRODUCTIVIDAD*" }
                                    if ($lb) { $lb | ForEach-Object { Write-Host "  + $_" -ForegroundColor Green } } else { Write-Host "  (Ninguno detectado)" -ForegroundColor Gray }

                                    Write-Host "`n--- LISTA NEGRA SUGERIDA (Ocio / Redes Sociales / Streaming) ---" -ForegroundColor Red
                                    $ln = $dominiosDetectados | Where-Object { (Get-DomainClassification $_).Category -like "*NEGRA*" -or (Get-DomainClassification $_).Category -like "*RESTRINGIDO*" }
                                    if ($ln) { $ln | ForEach-Object { Write-Host "  - $_" -ForegroundColor Red } } else { Write-Host "  (Ninguno detectado)" -ForegroundColor Gray }

                                    Read-Host "`nPresione ENTER para continuar..."
                                }

                                "3" {
                                    cabecera
                                    menuOpcion "Se encuentra en el SUB_MENU: 101 ;;; Opcion: $op101 (Registro de Auditoria de Accesos)"
                                    Write-Host "`n--- HISTORIAL DE ACCESOS Y REGISTROS DE AUDITORIA (GRUPO 101) ---" -ForegroundColor Yellow
                                    
                                    $logFile = "C:\shellWil\logs\audit_101.log"
                                    if (Test-Path $logFile) {
                                        Write-Host "`n[Bitacora Local: $logFile]" -ForegroundColor Cyan
                                        Get-Content -Path $logFile -Tail 30 | ForEach-Object {
                                            if ($_ -like "*DENEGADO*") {
                                                Write-Host $_ -ForegroundColor Red
                                            } elseif ($_ -like "*AUTORIZADO*") {
                                                Write-Host $_ -ForegroundColor Green
                                            } else {
                                                Write-Host $_ -ForegroundColor Gray
                                            }
                                        }
                                    } else {
                                        Write-Host "`n[i] Aun no se ha generado la bitacora local $logFile." -ForegroundColor Gray
                                    }

                                    Write-Host "`n--- Eventos Recientes en Visor de Sucesos (Application / ShellSW) ---" -ForegroundColor Cyan
                                    try {
                                        $evs = Get-EventLog -LogName Application -Source "ShellSW" -Newest 15 -ErrorAction SilentlyContinue
                                        if ($evs) {
                                            foreach ($ev in $evs) {
                                                $colorEv = if ($ev.EntryType -eq "Warning") { "Red" } else { "Green" }
                                                Write-Host "  [$($ev.TimeGenerated.ToString('yyyy-MM-dd HH:mm:ss'))] EventID: $($ev.InstanceId) | $($ev.Message)" -ForegroundColor $colorEv
                                            }
                                        } else {
                                            Write-Host "  (No se encontraron eventos previos de ShellSW en el Visor de Sucesos)" -ForegroundColor Gray
                                        }
                                    } catch {
                                        Write-Host "  [!] No se pudieron leer eventos del registro de Windows: $_" -ForegroundColor DarkGray
                                    }

                                    Read-Host "`nPresione ENTER para continuar..."
                                }

                                "0" {
                                    $salirSub101 = $true
                                }

                                Default {
                                    Write-Host "Opcion invalida." -ForegroundColor Red
                                    Start-Sleep -Seconds 1
                                }
                            }
                        }
                        catch {
                            Write-Host "[-] ERROR: Ocurrio un fallo en el submenu de credenciales navegadores: $_" -ForegroundColor Red
                            Read-Host "Presione ENTER para continuar..."
                        }
                    } while (-not $salirSub101)
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
