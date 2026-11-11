# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Contexto

POC de pruebas de API REST con Karate DSL contra un mock de Mockoon (`http://localhost:3001`). Es la contraparte de `C:\Users\ricar\2026\poc_api_rest_playwright_mockoon` (Python, Playwright y Pytest): ambas prueban el mismo mock y deben poder compararse caso por caso. El README de esa POC documenta el contrato completo de la API (campos, reglas de validación y mensajes de error).

La especificación completa está en `C:\Users\ricar\2026\especificacion-karate.md`. Se trabaja por fases: al terminar cada fase, detenerse, mostrar archivos, comandos y resultados reales, y esperar confirmación.

## Comandos

Requieren Mockoon en marcha, Desktop o CLI, nunca ambos en el mismo puerto.

```powershell
npx.cmd @mockoon/cli@9.10.0 validate --data .\mocks\usuarios-api.json
npx.cmd @mockoon/cli@9.10.0 start --data .\mocks\usuarios-api.json --disable-log-to-file --log-transaction   # Terminal aparte
.\mvnw.cmd test
.\mvnw.cmd test "-Dkarate.options=--tags @smoke"       # También: @regression, @negative, @security, @contract, @timeout
.\mvnw.cmd test "-Dkarate.options=--tags ~@timeout"    # Omite las pruebas lentas
.\mvnw.cmd test "-Dkarate.options=classpath:usuarios/get-usuarios.feature"   # Un solo feature
.\mvnw.cmd test "-Dkarate.env=ci"
.\mvnw.cmd test "-DbaseUrl=http://localhost:3002"
```

En PowerShell el argumento `-D...` completo va entre comillas dobles. Reporte HTML: `target/karate-reports/karate-summary.html`; log HTTP: `target/karate.log`.

## Arquitectura

- `ApiTestRunner.java` es el único punto de entrada (surefire solo incluye esa clase). Ejecuta `classpath:` con `parallel(1)` y falla si hay escenarios fallidos. `-Dkarate.options` sobrescribe tags y rutas del Runner.
- Un solo hilo es obligatorio: el mock guarda los usuarios en un único data bucket compartido y los escenarios lo restablecen con `POST /api/test/reset`.
- Los `.feature`, `karate-config.js` y `logback-test.xml` viven en `src/test/java` (el `pom.xml` los copia como recursos de prueba). Los datos de prueba van en `src/test/resources/data`, fuera de los `.feature`.
- `health/health.feature` no está en la estructura de la especificación: se agregó porque el health check no pertenece a `usuarios/` ni a `contratos/`.
- `common/` contiene features reutilizables (`reset.feature`, `login.feature`) y esquemas (`common/schemas/`). Llevan `@ignore` para que el Runner no los ejecute solos; se invocan con `call` o `callonce`.
- `karate-config.js` centraliza `baseUrl`, timeouts y `maxResponseTimeMs`. Acepta `karate.env` `local` (por defecto) o `ci`; cualquier otro valor falla.

## Restricciones

- Karate 1.5.2 con `karate-junit5`, por decisión del usuario: Karate 2.x solo publica `karate-junit6`. No actualizar a 2.x sin consultarlo.
- Todas las solicitudes HTTP se hacen con Karate. No usar REST Assured, Postman/Newman ni otros clientes.
- Todo escenario lleva `@regression` además de sus tags específicos.
- El objetivo de la POC es demostrar los requisitos de una oferta de QA Automation backend (REST y SOAP, OpenAPI, SQL, Gatling, CI/CD con Azure DevOps, Git, Postman y curl). `mocks/usuarios-api.json` partió como copia del mock de Playwright, pero puede extenderse libremente para cubrir esos requisitos; solo debe seguir siendo compatible con Mockoon 9.10.0 y validarse con `mockoon-cli validate`. En la comparativa del README, indicar qué casos son exclusivos de esta POC.
- No usar esperas fijas (`Thread.sleep`, `karate.pause`).
- No inventar versiones, resultados de ejecución ni métricas en la documentación.
- Sin `git push`, repositorios ni ramas remotas sin autorización explícita.

## Detalles de Karate que no son evidentes

- Los features que modifican datos hacen `* call read('classpath:common/reset.feature')` como primer paso del `Background`, antes de `* url baseUrl`.
- `common/schemas/` guarda tanto esquemas con marcadores difusos (`usuario.json`) como cuerpos de error esperados (`datos-invalidos.json`, `payload-malformado.json`). `usuario-no-encontrado.json` usa la expresión embebida `#(...usuarioId...)`: léelo con `read()` en el momento del `match`, con `usuarioId` ya definido.
- Los `Scenario Outline` toman sus filas de `src/test/resources/data` con `Examples: | read('classpath:data/...') |` (JSON o CSV). En tablas inline, el sufijo `!` en la columna (`usuarioId!`) evalúa el valor como número u objeto en vez de texto.
- Payloads malformados: se envían como cadena con `header Content-Type = 'application/json'`. Karate los manda tal cual (verificado en `target/karate.log`); el cuerpo vacío sale con `Content-Length: 0`.
- `header X = null` no omite la cabecera: envía el texto `null`. Los casos de cabecera ausente van en un escenario propio, sin el paso `header`. Con `''` sí se envía vacía.
- `common/login.feature` devuelve `token`. Se usa con `callonce` en el `Background` (un login por feature) o con `call ... { credencialesLogin: ... }` para otro usuario. El parámetro no se llama `credenciales` para no chocar con variables del llamador, que el feature llamado hereda.
- Para comprobar que una aserción puede fallar, `karate.match('actual each contains esperado')` devuelve `{ pass, message }` sin cortar el escenario.
- Timeout del cliente: `errores/timeouts.feature` llama a `common/get-lento.feature` con `karate.call` dentro de un `try/catch` de JS. El escenario pasa, pero Karate deja una línea `ERROR` en el log (`get-lento.feature:12`); es esperada.
- Campos sensibles: usar `common/campos-sensibles.js` (`match camposSensibles(response) == []`), que no distingue mayúsculas y recorre objetos anidados. Un esquema con `#notpresent` no lo hace.
- `match` no acepta una función JS en línea con `!=` en el lado izquierdo: asigna el resultado con `def` y compara la variable.

## Detalles del mock que no son evidentes

- Las rutas se evalúan en orden: `lento`, `999` y DELETE van antes de la ruta CRUD `api/usuarios`.
- DELETE responde 204 sin cuerpo ni `Content-Type`.
- `/api/usuarios/lento` tarda 15 s (`latency` y `retardo_ms` en el mock); debe coincidir con `timeouts.slowDelayMs` de `karate-config.js`.
- 401 incluye `WWW-Authenticate: Bearer`; 403 es token válido sin permisos (`qa_sin_permisos`). Los tokens son cadenas fijas, no JWT.
- 524 es un código específico de Cloudflare; Mockoon solo simula la respuesta.
