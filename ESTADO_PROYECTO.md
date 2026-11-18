# ESTADO_PROYECTO.md — Memoria y Bitácora de Continuidad

> **Propósito:** Este archivo es la memoria central del proyecto `shellWil`. Permite que cualquier miembro del equipo o el asistente de Inteligencia Artificial (Antigravity) conozca exactamente en qué estado se encuentra el desarrollo, qué fue lo último que se hizo y cómo retomar el trabajo sin perder tiempo al escribir **`RECUERDAME`**.

---

## 📌 1. Ficha del Proyecto
* **Proyecto:** `shellWil` ([repositorio GitHub](https://github.com/spwil/shellWil.git))
* **Autor / Responsable:** Ing. Wilson Yucra Juan (`wyucra@gmsantacruz.gov.bo`)
* **Objetivo:** Suite integral y portable de administración, soporte técnico, auditoría y mantenimiento del Sistema Operativo Windows para Helpdesk.
* **Arquitectura:**
  - Código fuente modular en `src/` ([helpers.ps1](src/helpers.ps1), [menuPrincipal.ps1](src/menuPrincipal.ps1), [subMenu20.ps1](src/subMenu20.ps1) a [subMenu28.ps1](src/subMenu28.ps1)).
  - Script de ensamblado automático: [build.ps1](build.ps1).
  - Binario ejecutable compilado: [ShellSW.bat](ShellSW.bat).

---

## 🕒 2. Última Sesión de Trabajo
* **Fecha:** 18 de Noviembre de 2026
* **Hito Completado:** **Modularización, Compatibilidad Multi-OS (Win 7 a 11), Soporte Workgroup y Resiliencia de Servicios en la Opción 100 (`src/subMenu25.ps1`)**.
* **Cambios Clave Realizados:**
  1. **Motor Centralizado de Preparación Remota (`Initialize-RemoteScreenEnvironment`):**
     - Modularización integral de las opciones 1, 2 y 3 bajo una sola función resiliente.
     - **Activación Interna y Automática de Servicios:** En las opciones 2 (GIF) y 3 (RDP Shadowing) ahora se auto-inician y configuran en cascada los servicios requeridos (`LanmanServer`, `RpcSs`, `winmgmt`, `RemoteRegistry` y para Shadowing `SessionEnv`, `UmRdpService`, `TermService`).
  2. **Control Estricto de Tiempos (Anti-Congelamiento):**
     - Comprobación previa de sockets en puertos 445 (SMB) y 135 (RPC) con timeout de **1000 ms** antes de invocar herramientas pesadas.
     - PsExec configurado con parámetro de timeout `-n 4` / `-n 6` para evitar que la consola quede estancada ante equipos apagados o no receptivos.
     - Detección de sesión interactiva limitada a 2 intentos con remediación automática entre intentos.
  3. **Compatibilidad Total desde Windows 7 hasta Windows 11:**
     - Fallback automático de `Get-CimInstance` (PS 3.0+) a `Get-WmiObject` (compatible con PS 2.0 y Windows 7).
     - **Detección inteligente de versión de Windows:** Si el equipo remoto es Windows 7 / 8.0 (kernel NT < 6.3), la opción 3 advierte que el parámetro nativo `/shadow` no existe en Windows 7 y ofrece la alternativa oficial de Microsoft: **Asistencia Remota (`msra.exe /offerRA`)**.
  4. **Soporte Avanzado para Equipos Fuera de Dominio (Workgroup):**
     - Detección automática de usuarios locales o fuera de dominio (`.\admin`).
     - Creación de túnel SMB autenticado (`net use \\Target\IPC$`) para prevenir errores de acceso denegado (Error 5) bajo NTLM.
     - Inyección de directiva de bypass de Remote UAC (`LocalAccountTokenFilterPolicy = 1`) y `AutoShareWks = 1`.
     - Apertura de reglas de firewall aplicadas a todos los perfiles (`profile=any`).
     - Saneamiento en `src/helpers.ps1` (`psHabilitarAdministracionRemota`) eliminando el prefijo de dominio corporativo forzado.
     - Configuración de `TrustedHosts = *` en el cliente local para permitir conexiones WinRM a cualquier IP.
  5. **Mejoras Agregadas en el Menú 100:**
     - **Captura Multi-Monitor:** Se sustituyó `PrimaryScreen` por `VirtualScreen` tanto en captura PNG como en ráfagas GIF, capturando todos los monitores si el usuario tiene 2 o más pantallas.
     - **Opción 4:** Acceso directo a Asistencia Remota interactiva oficial (`msra.exe /offerRA`).
     - **Opción 5:** Acceso directo para abrir el directorio local de capturas (`C:\spscreen`).
  6. **Compilación y verificación:**
     - Análisis sintáctico AST Parser ejecutado con 0 errores en todos los archivos modificados.
     - Binario compilado y verificado con `build.ps1` -> [ShellSW.bat](ShellSW.bat).

---

## 📍 3. ¿En qué punto nos hemos quedado?
La **Opción 100 (Captura y Monitoreo Remoto)** está completamente modularizada, robustecida contra congelamientos, compatible con Windows 7/8/10/11 y equipos en Workgroup/Dominio. Compilado y listo en [ShellSW.bat](ShellSW.bat).

* **Estado de Git:** Rama `main`, cambios listos en `ShellSW.bat`, `src/helpers.ps1`, `src/subMenu25.ps1` y `ESTADO_PROYECTO.md`.
* **Próxima acción técnica:** Probar las opciones en `ShellSW.bat` -> opción `25` -> opción `100`:
  * `1`: Captura instantánea PNG (Multi-Monitor).
  * `2`: Clip de 15 segundos GIF animado (con auto-habilitación interna de servicios).
  * `3`: Visualización en vivo RDP Shadowing (con auto-inicio de TermService y fallback para Win 7).
  * `4`: Asistencia Remota interactiva (MSRA).
  * `5`: Abrir carpeta local de capturas `C:\spscreen`.
* **Publicación:** Cuando desees sincronizar a GitHub, usa la opción oculta `1010` en el menú principal.

---

## 🚀 4. Guía para Continuar (Paso a Paso)

### Si estás en la PC 2 (o en una máquina distinta a donde se programó):
1. Abre `ShellSW.bat` (o tu terminal).
2. En el menú, escribe **`1011`** y presiona Enter.
3. El sistema descargará todo lo nuevo desde GitHub, auto-compilará [ShellSW.bat](ShellSW.bat) y te preguntará si deseas reiniciar para cargar los cambios.
4. *(Solo la primera vez en PC 2)* Si te pide credenciales de GitHub, ejecuta:
   ```powershell
   git config --global credential.helper manager
   ```

### Si vas a continuar programando o agregando módulos:
1. Edita los módulos en la carpeta `src/`.
2. Para probar tus cambios en caliente o recompilar, ejecuta:
   ```powershell
   .\build.ps1
   ```
3. Al terminar la sesión, escribe **`1010`** en el menú de ShellSW (o ejecuta commit y push) para que la otra PC reciba tus avances.

---

## 📋 5. Tareas Pendientes y Roadmap Sugerido
- [x] Sincronización multi-PC automatizada (Opciones 1010 y 1011).
- [x] Ocultamiento de opciones de desarrollo en el menú por seguridad.
- [x] Documentación de sincronización y bitácora de memoria (`RECUERDAME`).
- [x] Opción 6: Gestión de Símbolos SIAF-SICE multi-capa en Submenú 28.
- [x] Opción 7: Consola Remota PowerShell Interactiva (WinRM + WMI auto-enable + PsExec fallback).
- [x] Optimización Opción 100: Captura de pantalla remota con SSO por defecto y caché de credenciales en Submenú 25.
- [x] Suite Completa de Monitoreo Remoto: Clip continuo de 15 segundos (GIF nativo .NET) y RDP Shadowing en tiempo real (mstsc /shadow).
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
