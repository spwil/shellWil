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
            Write-Host "    5.4. Actualizacion y Diagnostico de Politicas (gpupdate)." -ForegroundColor Yellow
            Write-Host "  6. OPTIMIZACION Y LIMPIEZA DE SISTEMA:" -ForegroundColor Green
            Write-Host "    6.1. Eliminar Archivos TEMPORALES CARPETAS" -ForegroundColor DarkCyan
            Write-Host "    6.2. Eliminar Archivos Temporales ProgramData." -ForegroundColor DarkCyan
            Write-Host "    6.3. Liberar RAM." -ForegroundColor DarkCyan
            Write-Host "    6.4. Liberar Procesador." -ForegroundColor DarkCyan
            Write-Host "    6.5. Vaciar Papelera de Reciclaje" -ForegroundColor DarkCyan
            Write-Host "    6.6. Eliminacion avanzada de temporales (Todos los usuarios)" -ForegroundColor Yellow
            Write-Host "  12. Revisiones Instaladas de Windows."
            Write-Host "  20 ---)) HERRAMIENTAS PC y PORTATIL (Laptops)." -ForegroundColor Green
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
                "6.1" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                        
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
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                        
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
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"
                    psLimpiarRAM

                    Write-Host "Presione Enter para volver..." -ForegroundColor Green
                }
                "6.4" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

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
                    Write-Host "`nProceso finalizado..." -ForegroundColor Yellow
                    Write-Host ""
                }
                "6.5" { 

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

                    # Abrir la ventana de la Papelera de Reciclaje para verificación visual
                    Write-Host "`nAbriendo la papelera de reciclaje para verificacion..." -ForegroundColor Yellow
                    try {
                        Start-Process "explorer.exe" "shell:RecycleBinFolder"
                    }
                    catch {
                        # Fallback de seguridad mediante .NET en caso de que Start-Process falle
                        [System.Diagnostics.Process]::Start("explorer.exe", "shell:RecycleBinFolder") | Out-Null
                    }

                    Write-Host "-------------------------------------------------------"
                    Write-Host " "

                }
                "6.6" {
                    cabecera
                    menuOpcion "Se encuentra en el SUB_MENU: $opcion ;;; Opcion: $op23"

                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "   ELIMINACION DE TEMPORALES PARA TODOS LOS USUARIOS       " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Obtener perfiles de usuario locales y de dominio
                    $profiles = $null
                    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                        $profiles = Get-CimInstance -ClassName Win32_UserProfile -ErrorAction SilentlyContinue
                    }
                    else {
                        $profiles = Get-WmiObject -Class Win32_UserProfile -ErrorAction SilentlyContinue
                    }

                    $profilePaths = @()
                    if ($profiles) {
                        foreach ($p in $profiles) {
                            # Evitar carpetas de sistema (SYSTEM, LocalService, NetworkService) y Default
                            if ($p.Special -eq $false -and $p.LocalPath -and (Test-Path $p.LocalPath)) {
                                $profilePaths += $p.LocalPath
                            }
                        }
                    }

                    # Fallback si WMI falla
                    if ($profilePaths.Count -eq 0) {
                        $profilePaths = Get-ChildItem -Path "C:\Users" -Directory -ErrorAction SilentlyContinue | 
                        Where-Object { $_.Name -notin "Default", "Default User", "All Users", "Public" } | 
                        Select-Object -ExpandProperty FullName
                    }

                    Write-Host "Perfiles de usuario detectados a procesar: $($profilePaths.Count)" -ForegroundColor Yellow
                    Write-Host ""

                    $totalArchivosEliminados = 0
                    $totalCarpetasEliminadas = 0
                    $totalEspacioLiberado = 0

                    foreach ($path in $profilePaths) {
                        $tempPath = Join-Path $path "AppData\Local\Temp"
                        $userName = Split-Path $path -Leaf
                        
                        Write-Host "Procesando perfil: $userName ($path)..." -ForegroundColor Cyan

                        if (Test-Path $tempPath) {
                            Write-Host "  Ruta Temp: $tempPath" -ForegroundColor Gray
                            
                            # Obtener elementos en la carpeta Temp
                            $items = Get-ChildItem -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue
                            
                            $eliminadosUser = 0
                            $fallidosUser = 0
                            $espacioUser = 0

                            # Eliminar archivos individualmente
                            foreach ($item in $items) {
                                if (-not $item.PSIsContainer) {
                                    $size = $item.Length
                                    try {
                                        Remove-Item -Path $item.FullName -Force -Recurse -ErrorAction Stop
                                        $totalEspacioLiberado += $size
                                        $espacioUser += $size
                                        $eliminadosUser++
                                        $totalArchivosEliminados++
                                    }
                                    catch {
                                        # Archivo en uso por el usuario/sistema o sin permisos
                                        $fallidosUser++
                                    }
                                }
                            }

                            # Eliminar directorios vacíos recursivamente
                            $dirs = Get-ChildItem -Path "$tempPath\*" -Recurse -Force -ErrorAction SilentlyContinue | 
                            Where-Object { $_.PSIsContainer } | 
                            Sort-Object FullName -Descending
                            foreach ($dir in $dirs) {
                                try {
                                    Remove-Item -Path $dir.FullName -Force -ErrorAction Stop
                                    $totalCarpetasEliminadas++
                                }
                                catch {
                                    # Directorio no está vacío o en uso
                                }
                            }

                            $mbLiberados = [Math]::Round($espacioUser / 1MB, 2)
                            Write-Host "  -> Archivos eliminados: $eliminadosUser | Bloqueados/En uso: $fallidosUser" -ForegroundColor Green
                            Write-Host "  -> Espacio liberado: $mbLiberados MB" -ForegroundColor Green
                        }
                        else {
                            Write-Host "  -> Directorio Temp no inicializado para este usuario." -ForegroundColor Yellow
                        }
                        Write-Host ""
                    }

                    $totalMBLiberados = [Math]::Round($totalEspacioLiberado / 1MB, 2)
                    Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    Write-Host "RESUMEN GLOBAL DE LIMPIEZA MULTI-USUARIO:" -ForegroundColor Cyan
                    Write-Host "Total archivos eliminados: $totalArchivosEliminados" -ForegroundColor White
                    Write-Host "Total carpetas eliminadas: $totalCarpetasEliminadas" -ForegroundColor White
                    Write-Host "Total espacio liberado:    $totalMBLiberados MB" -ForegroundColor Green
                    Write-Host "-----------------------------------------------------------" -ForegroundColor Gray
                    Write-Host ""
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
                    psSubMenuPortatil
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

function psSubMenuPortatil {
    $salirSubPortatil = $false
    do {
        try {
            # cabecera con informacion del autor
            cabecera
            Write-Header " 23.20. ---)) LOCAL: HERRAMIENTAS PC PORTATIL."
            Write-Host "  1. BitLocker - Dell - HP - Lenovo" -ForegroundColor Green
            Write-Host "    1.1. Desactivar BitLocker (Deshabilitar protectores C: - Mantenimiento)"
            Write-Host "    1.2. Activar BitLocker (Habilitar protectores C: - Fin Mantenimiento)"
            Write-Host "    1.3. Verificar Estado de BitLocker"
            Write-Host "    1.4. Desactivar BitLocker de forma Permanente"
            Write-Host "    1.5. Mostrar Progreso de Desactivacion (Descifrado)"
            Write-Host "  2. Estado de bateria Laptop (Diagnostico de Salud y Desgaste)." -ForegroundColor Green
            Write-Host ""
            Write-Host "  0. V O L V E R   A L   M E N U   A N T E R I O R   (SUB-MENU 23)"
            Write-Header "===================================================================="
            
            $opPortatil = Read-Host "Seleccione la tarea a realizar"

            switch ($opPortatil) {
                "1" {
                    Write-Host "Por favor seleccione una opcion valida (1.1 - 1.5) para gestionar BitLocker." -ForegroundColor Yellow
                }
                "1.1" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Activar BitLocker (Mantenimiento)"
                    Write-Host "Consultando estado actual de BitLocker..." -ForegroundColor Cyan
                    manage-bde -status C:
                    Write-Host "`nEjecutando: manage-bde -protectors -disable C:" -ForegroundColor Yellow
                    manage-bde -protectors -disable C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.2" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Desactivar BitLocker"
                    Write-Host "Ejecutando: manage-bde -protectors -enable C:" -ForegroundColor Yellow
                    manage-bde -protectors -enable C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.3" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Verificar estado de BitLocker"
                    Write-Host "Consultando estado actual de BitLocker en la unidad C:..." -ForegroundColor Cyan
                    manage-bde -status C:
                    Write-Host "`nProceso ejecutado."
                }
                "1.4" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Desactivar BitLocker permanentemente"
                    Write-Host "¡ATENCION! Esta opcion desactivara y descifrara BitLocker permanentemente en C:." -ForegroundColor Red
                    $confirm = Read-Host "¿Esta seguro de que desea continuar? (S/N)"
                    if ($confirm -eq "S" -or $confirm -eq "s") {
                        Write-Host "Iniciando descifrado permanente de BitLocker en la unidad C:..." -ForegroundColor Yellow
                        manage-bde -off C:
                        Write-Host "`nProceso iniciado con exito. Puede monitorear el progreso usando la opcion 1.5." -ForegroundColor Green
                    }
                    else {
                        Write-Host "Operacion cancelada." -ForegroundColor Cyan
                    }
                }
                "1.5" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Progreso de desactivacion de BitLocker"
                    Write-Host "Consultando el estado de progreso en la unidad C:..." -ForegroundColor Cyan
                    $status = manage-bde -status C:
                    $status | Out-String | Write-Host
                    
                    # Intentar extraer porcentaje cifrado y estado de conversion
                    $statusText = $status -join "`n"
                    $porcentajeMatch = [regex]::Match($statusText, '(Percentage Encrypted|Porcentaje cifrado)\s*:\s*([\d,.]+%)', 'IgnoreCase')
                    $estadoMatch = [regex]::Match($statusText, '(Conversion Status|Estado de conversi.n)\s*:\s*([^\r\n]+)', 'IgnoreCase')
                    
                    if ($porcentajeMatch.Success -or $estadoMatch.Success) {
                        Write-Host "`n--- RESUMEN DE PROGRESO DE DESCIFRADO ---" -ForegroundColor Yellow
                        if ($estadoMatch.Success) {
                            Write-Host "Estado actual: $($estadoMatch.Groups[2].Value.Trim())" -ForegroundColor Green
                        }
                        if ($porcentajeMatch.Success) {
                            $pctStr = $porcentajeMatch.Groups[2].Value.Trim()
                            Write-Host "Porcentaje Cifrado: $pctStr" -ForegroundColor Cyan
                            # Mostrar el inverso para indicar progreso de descifrado
                            $numPart = $pctStr -replace '[^\d,.]', ''
                            # Cambiar coma por punto si es necesario para convertir a double en PowerShell
                            $numPart = $numPart -replace ',', '.'
                            if ([double]::TryParse($numPart, [ref]$val)) {
                                $progresoDescifrado = 100 - $val
                                Write-Host "Progreso de Descifrado: $progresoDescifrado%" -ForegroundColor Green
                                
                                # Dibujar barra de progreso simple en consola
                                $barLength = 20
                                $filled = [Math]::Round(($progresoDescifrado / 100) * $barLength)
                                $empty = $barLength - $filled
                                $bar = "[" + ("#" * $filled) + ("." * $empty) + "]"
                                Write-Host "Progreso: $bar" -ForegroundColor Green
                            }
                        }
                        Write-Host "----------------------------------------"
                    }
                }
                "2" {
                    cabecera
                    menuOpcion "HERRAMIENTAS PC PORTATIL -> Estado de bateria Laptop"
                    
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host "      ANALISIS DE SALUD Y DESGASTE DE LA BATERIA           " -ForegroundColor Cyan
                    Write-Host "===========================================================" -ForegroundColor Cyan
                    Write-Host ""

                    # 1. Determinar si el equipo es Laptop o PC de Escritorio
                    $isLaptop = $false
                    $baterias = $null
                    if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                        $baterias = Get-CimInstance -ClassName Win32_Battery -ErrorAction SilentlyContinue
                    }
                    else {
                        $baterias = Get-WmiObject -Class Win32_Battery -ErrorAction SilentlyContinue
                    }
                    
                    if ($baterias) {
                        $isLaptop = $true
                    }
                    else {
                        $chassisTypes = @()
                        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                            $chassisTypes = (Get-CimInstance -ClassName Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
                        }
                        else {
                            $chassisTypes = (Get-WmiObject -Class Win32_SystemEnclosure -ErrorAction SilentlyContinue).ChassisTypes
                        }
                        
                        foreach ($t in $chassisTypes) {
                            # Códigos de chasis portátiles comunes
                            if ($t -in 8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32) {
                                $isLaptop = $true
                                break
                            }
                        }
                    }

                    # Mostrar detección
                    if ($isLaptop) {
                        Write-Host "Tipo de equipo detectado: PC Portatil (Laptop)" -ForegroundColor Green
                        Write-Host "Detected System Type: Laptop" -ForegroundColor Green
                    }
                    else {
                        Write-Host "Tipo de equipo detectado: PC de Escritorio (Desktop)" -ForegroundColor Yellow
                        Write-Host "Detected System Type: Desktop" -ForegroundColor Yellow
                    }
                    Write-Host ""

                    # 2. Mostrar Fórmulas
                    Write-Host "Formula para calcular la salud / Battery health formula:" -ForegroundColor Cyan
                    Write-Host "  Espanol: Porcentaje de Vida Util = (Capacidad de Carga Completa / Capacidad de Diseno) * 100" -ForegroundColor Gray
                    Write-Host "  English: Battery Health Percentage = (Full Charge Capacity / Design Capacity) * 100" -ForegroundColor Gray
                    Write-Host ""

                    # 3. Generar reporte HTML en C:\bateriaReporte.html
                    $rutaHTML = "C:\bateriaReporte.html"
                    Write-Host "Generando reporte de bateria en C:\bateriaReporte.html... / Generating battery report..." -ForegroundColor Gray
                    
                    try {
                        $pOutput = powercfg /batteryreport /output $rutaHTML 2>&1
                        if (Test-Path $rutaHTML) {
                            Write-Host "Reporte generado en: $rutaHTML" -ForegroundColor Green
                        }
                        else {
                            Write-Host "No se pudo generar el reporte. Asegurese de ejecutar el script como Administrador." -ForegroundColor Red
                            Write-Host "Detalle del sistema: $pOutput" -ForegroundColor Gray
                        }
                    }
                    catch {
                        Write-Host "No se pudo generar el reporte mediante powercfg: $($_.Exception.Message)" -ForegroundColor Red
                    }
                    Write-Host ""

                    # 4. Obtener y mostrar datos reales de batería si es una Laptop
                    if ($isLaptop) {
                        $designedCapacityVal = 0
                        $fullChargeCapacityVal = 0
                        $cycleCountVal = $null
                        $manufacturer = "Desconocido"
                        $chemistry = "Desconocido"
                        $parsedOK = $false

                        # Intentar obtener datos a través de WMI/CIM en root/wmi
                        if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                            $staticData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryStaticData" -ErrorAction SilentlyContinue
                            $fullChargeData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
                            $cycleData = Get-CimInstance -Namespace "root\wmi" -ClassName "BatteryCycleCount" -ErrorAction SilentlyContinue
                            
                            if ($staticData) {
                                $designedCapacityVal = $staticData[0].DesignedCapacity
                                $chemistry = $staticData[0].Chemistry
                                $manufacturer = $staticData[0].ManufacturerName
                            }
                            if ($fullChargeData) {
                                $fullChargeCapacityVal = $fullChargeData[0].FullChargedCapacity
                            }
                            if ($cycleData) {
                                $cycleCountVal = $cycleData[0].CycleCount
                            }
                        }
                        
                        if ($designedCapacityVal -eq 0 -and (Get-Command Get-WmiObject -ErrorAction SilentlyContinue)) {
                            $staticData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryStaticData" -ErrorAction SilentlyContinue
                            $fullChargeData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryFullChargedCapacity" -ErrorAction SilentlyContinue
                            $cycleData = Get-WmiObject -Namespace "root\wmi" -Class "BatteryCycleCount" -ErrorAction SilentlyContinue
                            
                            if ($staticData) {
                                $designedCapacityVal = $staticData[0].DesignedCapacity
                                $chemistry = $staticData[0].Chemistry
                                $manufacturer = $staticData[0].ManufacturerName
                            }
                            if ($fullChargeData) {
                                $fullChargeCapacityVal = $fullChargeData[0].FullChargedCapacity
                            }
                            if ($cycleData) {
                                $cycleCountVal = $cycleData[0].CycleCount
                            }
                        }

                        # Fallback a Win32_Battery
                        if ($designedCapacityVal -eq 0) {
                            $win32Battery = $null
                            if (Get-Command Get-CimInstance -ErrorAction SilentlyContinue) {
                                $win32Battery = Get-CimInstance -ClassName "Win32_Battery" -ErrorAction SilentlyContinue
                            }
                            else {
                                $win32Battery = Get-WmiObject -Class "Win32_Battery" -ErrorAction SilentlyContinue
                            }
                            
                            if ($win32Battery) {
                                $designedCapacityVal = $win32Battery[0].DesignCapacity
                                $fullChargeCapacityVal = $win32Battery[0].FullChargeCapacity
                                $manufacturer = $win32Battery[0].Manufacturer
                                $chemistry = $win32Battery[0].Chemistry
                            }
                        }

                        if ($designedCapacityVal -gt 0 -and $fullChargeCapacityVal -gt 0) {
                            $parsedOK = $true
                        }

                        if ($parsedOK) {
                            $porcentajeVida = [Math]::Round(($fullChargeCapacityVal / $designedCapacityVal) * 100, 1)
                            $porcentajeDesgaste = [Math]::Round(100 - $porcentajeVida, 1)
                            
                            Write-Host "--- DATOS GENERALES DE LA BATERIA ---" -ForegroundColor Cyan
                            Write-Host "Fabricante:        $manufacturer"
                            Write-Host "Quimica:           $chemistry"
                            Write-Host "Capacidad Diseno:  $designedCapacityVal mWh"
                            Write-Host "Capacidad Actual:  $fullChargeCapacityVal mWh"
                            if ($null -ne $cycleCountVal) {
                                Write-Host "Ciclos de Carga:   $cycleCountVal"
                            }
                            
                            Write-Host "`n--- REPORTE DE SALUD Y DESGASTE ---" -ForegroundColor Yellow
                            Write-Host "Porcentaje de Salud (Vida Util): " -NoNewline
                            if ($porcentajeVida -ge 90) {
                                Write-Host "$porcentajeVida%" -ForegroundColor Green
                            }
                            elseif ($porcentajeVida -ge 75) {
                                Write-Host "$porcentajeVida%" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "$porcentajeVida%" -ForegroundColor Red
                            }
                            
                            Write-Host "Porcentaje de Desgaste:          " -NoNewline
                            if ($porcentajeDesgaste -le 10) {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Green
                            }
                            elseif ($porcentajeDesgaste -le 25) {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Yellow
                            }
                            else {
                                Write-Host "$porcentajeDesgaste%" -ForegroundColor Red
                            }
                            
                            Write-Host "`n--- INTERPRETACION TECNICA ---" -ForegroundColor Cyan
                            if ($porcentajeVida -ge 90) {
                                Write-Host "ESTADO: EXCELENTE" -ForegroundColor Green
                                Write-Host "La bateria esta en optimas condiciones and retiene la mayor parte de su capacidad original."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Evite descargar la bateria por completo por debajo del 20%; las descargas profundas estresan las celdas de Ion-Litio."
                                Write-Host "2. No mantenga la laptop cargando permanentemente al 100% en ambientes de alta temperatura (esto acelera el desgaste quimico)."
                                Write-Host "3. Si la marca de su laptop posee herramientas de gestion (Dell Power Manager, HP Support Assistant, Lenovo Vantage), configure un limite de carga al 80% si planea utilizarla conectada a la corriente la mayor parte del tiempo."
                            }
                            elseif ($porcentajeVida -ge 75) {
                                Write-Host "ESTADO: BUENO / NORMAL" -ForegroundColor Yellow
                                Write-Host "La bateria presenta un nivel de desgaste normal debido al uso transcurrido. La autonomia es adecuada."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Mantenga habitos de carga estables, evitando descargas completas recurrentes."
                                Write-Host "2. Realice una calibracion de bateria cada 3 meses: carguela al 100%, dejela descargar completamente hasta que el equipo se apague solo, y vuelva a cargarla al 100% de manera ininterrumpida con el equipo apagado. Esto recalibra el chip indicador."
                                Write-Host "3. Asegurese de que las rejillas de ventilacion del portatil esten limpias, ya que el calor excesivo es el peor enemigo de la vida util de la bateria."
                            }
                            elseif ($porcentajeVida -ge 50) {
                                Write-Host "ESTADO: REGULAR / DESGASTADO" -ForegroundColor Red
                                Write-Host "La bateria tiene un desgaste considerable. La duracion de la carga es menor y el rendimiento movil se vera reducido."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Evite ejecutar aplicaciones de alto rendimiento (juegos, edicion de video) operando unicamente con bateria, ya que la alta demanda de corriente incrementa el estres termico."
                                Write-Host "2. Desactive servicios en segundo plano y reduzca el brillo de pantalla para maximizar los periodos de uso portatil."
                                Write-Host "3. Vaya planificando el reemplazo de la bateria si su ritmo de trabajo requiere movilidad constante."
                            }
                            else {
                                Write-Host "ESTADO: CRITICO / REEMPLAZAR" -ForegroundColor Red -BackgroundColor Black
                                Write-Host "La bateria ha cumplido su ciclo de vida util y la retencion de carga es minima o nula."
                                Write-Host "`nRECOMENDACIONES DE EXPERTO:" -ForegroundColor Yellow
                                Write-Host "1. Se aconseja encarecidamente cambiar la bateria por una original o compatible certificada para restaurar la portabilidad."
                                Write-Host "2. PRECAUCION: Examine visualmente si la bateria se encuentra inflada (esto se nota si el touchpad o el teclado se sienten duros o levantados). Si detecta hinchazon, retire la bateria de inmediato, ya que representa un peligro fisico (riesgo de incendio o explosion)."
                                Write-Host "3. Si utiliza la laptop fija conectada permanentemente, puede optar por remover la bateria (si es extraible) para evitar calor innecesario, o bien limitar estrictamente la carga via software."
                            }
                        }
                        else {
                            Write-Host "No se pudieron extraer los datos detallados de la bateria a traves de WMI/CIM." -ForegroundColor Yellow
                            Write-Host "Por favor, revise el reporte detallado generado en la ruta indicada." -ForegroundColor Yellow
                        }
                    }
                    else {
                        # Recomendaciones para PC de Escritorio
                        Write-Host "RECOMENDACIONES DE EXPERTO (PC DE ESCRITORIO O SERVIDOR):" -ForegroundColor Yellow
                        Write-Host "1. Al tratarse de un equipo de escritorio, se recomienda encarecidamente el uso de un UPS (No-Break) o Sistema de Alimentacion Ininterrumpida."
                        Write-Host "2. Un UPS protegera su PC contra apagones repentinos (que pueden causar corrupcion de archivos y danos en el sistema operativo o SSD/HDD) y contra sobretensiones electricas."
                        Write-Host "3. Realice mantenimientos preventivos de limpieza de polvo interno de la PC y renovacion de pasta termica cada 12 o 18 meses para asegurar temperaturas optimas en el procesador."
                    }

                    # 5. Preguntar si se desea abrir el reporte generado
                    if (Test-Path $rutaHTML) {
                        Write-Host ""
                        $openBrowser = Read-Host "¿Desea abrir el reporte HTML detallado en el navegador? (S/N)"
                        if ($openBrowser -eq "S" -or $openBrowser -eq "s") {
                            Write-Host "Abriendo el reporte en el navegador..." -ForegroundColor Gray
                            try {
                                Start-Process $rutaHTML
                            }
                            catch {
                                Write-Host "No se pudo abrir automaticamente. Puede encontrar el archivo en: $rutaHTML" -ForegroundColor Red
                            }
                        }
                    }
                }
                "0" {
                    $salirSubPortatil = $true
                }
                Default {
                    Write-Host "Opcion invalida." -ForegroundColor Red
                }
            }
            if (-not $salirSubPortatil) { Read-Host "HERRAMIENTAS PC PORTATIL: Presione ENTER para continuar..." }
        }
        catch {
            Write-Host "`n[ERROR NO ESPERADO]: $($_.Exception.Message)" -ForegroundColor Red
            Read-Host "Presione Enter para continuar..."
        }
    } while (-not $salirSubPortatil)
}

#************************************************* FIN SUB MENU.23*****************************************************************
#**********************************************************************************************************************************

#******************************************************** INICIO SUB MENU.24 ******************************************************
#**********************************************************************************************************************************
