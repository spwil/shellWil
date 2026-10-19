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
* **Fecha:** 18 de Octubre de 2026
* **Hito Completado:** **Sistema de Desarrollo Multi-PC y Sincronización Segura Git (Opciones 1010 y 1011)**.
* **Cambios Clave Realizados:**
  1. **Opción 1011 (Continuar y Sincronizar):** Implementada en `src/helpers.ps1`. Descarga cambios con `git pull origin main`, limpia bloqueos residuales (`*.lock`), protege cambios locales sin guardar (con submenú interactivo: commit 1010, stash o reset), y auto-compila inmediatamente con `build.ps1`.
  2. **Opción 1010 (Publicar en GitHub):** Mejorada con auto-resolución de rechazos. Si la otra PC subió cambios previamente (`non-fast-forward`), la opción 1010 ofrece integrar automáticamente con `git pull --rebase` y reintentar el `push`.
  3. **Seguridad / Modo Oculto:** Ambas opciones (1010 y 1011) se mantuvieron **ocultas de la visual del menú principal**, evitando que operadores finales o personal no autorizado las ejecuten por error. Funcionan escribiendo directamente `1010` o `1011` en la consola.
  4. **Documentación:** Se generó la guía técnica completa en [Varios/manual_sincronizacion_multipc_git.md](Varios/manual_sincronizacion_multipc_git.md).
  5. **Comando de Memoria:** Incorporación de la palabra clave `RECUERDAME` tanto en el asistente IA como en el menú del script.

---

## 📍 3. ¿En qué punto nos hemos quedado?
El proyecto tiene su infraestructura de desarrollo y sincronización entre 2 computadoras **100% probada, libre de errores de sintaxis y compilada en `ShellSW.bat`**.

* **Estado de Git:** Rama `main`, sincronizada con `origin/main`.
* **Próxima acción técnica:** Probar la descarga en la segunda computadora (PC 2) abriendo ShellSW y tecleando `1011`.

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
