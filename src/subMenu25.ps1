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
                    $entrada = Read-Host "Ingrese IP completa, los 2 ultimos octetos (ej. 13.15), el ultimo octeto (ej. 15) o el Hostname"
                    $entrada = $entrada.Trim()

                    $ipRemota = ""
                    if ($entrada -match "^[a-zA-Z]") {
                        # Es un Hostname
                        $ipRemota = $entrada
                    }
                    elseif ($entrada -split "\." -and ($entrada -split "\.").Count -eq 2) {
                        # Si ingreso exactamente 2 octetos (ej: 13.15)
                        $ipRemota = "192.168." + $entrada
                    }
                    elseif ($entrada -split "\." -and ($entrada -split "\.").Count -eq 1 -and $entrada -match "^\d+$") {
                        # Si ingreso exactamente 1 octeto (ej: 15)
                        $ipRemota = "192.168.176." + $entrada
                    }
                    else {
                        # IP Completa u otros formatos
                        $ipRemota = $entrada
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
                                    
                                    $ipInput = Read-Host "Introduzca los 2 ultimos segmentos IP (ej. 176.80) o la IP completa"
                                    if ($ipInput -match '^\d{1,3}\.\d{1,3}\.\d{1,3}\.\d{1,3}$') {
                                        $IPFinal = $ipInput
                                    } else {
                                        $IPFinal = "192.168.$ipInput"
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
