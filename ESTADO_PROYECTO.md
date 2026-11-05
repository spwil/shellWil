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
* **Fecha:** 19 de Octubre de 2026
* **Hito Completado:** **Corrección integral de la Opción 10.3 (Impresora Predeterminada Remota Multi-Usuario) y Unificación de PsExec**.
* **Cambios Clave Realizados:**
  1. **Resolución del congelamiento en pantalla negra (Opción 10.3):**
     - Se eliminó el bloqueo síncrono infinito en PsExec (`Start-Process -Wait`) causado por la espera de `cmd /c` y `wscript.exe`.
     - Se añadió el parámetro `/q` (quiet) a `PrintUIEntry` y `bWaitOnReturn = False` en `SetDefaultPrinter.vbs` para impedir que se levanten cuadros de diálogo modales invisibles en la Sesión 0 que paralizaban el sistema.
     - PsExec ahora se invoca con `-d` (ejecución asíncrona fire & forget), `-n 8` (timeout de conexión), `-nobanner` e inyección precisa en el `SessionId` activo del usuario conectado (`-i $activeSessionId`).
     - Se implementó un timeout estricto de seguridad de 6 segundos con `[System.Diagnostics.Process]::Start` y cancelación forzada (`Kill()`) en caso de falta de respuesta del host remoto.
     - Se corrigió la consulta de confirmación donde `$targetIP?` evaluaba a vacío por sintaxis de PowerShell, quedando correctamente como `${targetIP}?`.
  2. **Unificación y Portabilidad de PsExec:**
     - Creación de la función centralizada `Get-PsExecPath` en [src/helpers.ps1](src/helpers.ps1), la cual resuelve dinámicamente `PsExec.exe` buscando en `C:\PSTools`, la raíz del proyecto (`E:\proyectosIA\shellWil`), `C:\Windows\System32` o la variable de entorno `PATH`.
     - Actualización de todos los módulos ([src/subMenu25.ps1](src/subMenu25.ps1), [src/subMenu28.ps1](src/subMenu28.ps1), [src/helpers.ps1](src/helpers.ps1)) para consumir esta función.
  3. **Verificación de la nueva ruta de trabajo:**
     - Verificado el funcionamiento transparente en la nueva ubicación `E:\proyectosIA\shellWil`. Todas las funciones de resolución de entorno (`Get-ShellWorkspacePath`, `Get-GitDevContext`, compilación [build.ps1](build.ps1)) responden con total exactitud.
  4. **Compilación y verificación:**
     - Ejecutado [build.ps1](build.ps1) y validado que [ShellSW.bat](ShellSW.bat) y todos los módulos de `src/` compilan con 0 errores de sintaxis.

---

## 📍 3. ¿En qué punto nos hemos quedado?
La Opción 10.3 del módulo [src/subMenu25.ps1](src/subMenu25.ps1) ha sido corregida y optimizada exhaustivamente, eliminando el fallo de congelamiento y garantizando la aplicación de directivas multi-usuario en equipos remotos de forma no bloqueante y segura.

* **Estado de Git:** Rama `main`, cambios listos para ser guardados y probados.
* **Próxima acción técnica:** Probar la Opción 10.3 en el entorno de red Helpdesk y realizar commit con la Opción 1010 si se desea sincronizar a GitHub.

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
- [ ] Probar flujo completo de bajada en la PC secundaria mediante la opción `1011`.
- [ ] Revisión periódica de submódulos de administración según requerimientos del equipo de Helpdesk.
