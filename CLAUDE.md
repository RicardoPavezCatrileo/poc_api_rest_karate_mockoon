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
.\mvnw.cmd test "-Dkarate.options=--tags @smoke"       # También: @regression, @negative, @security, @contract, @soap, @sql, @banca, @timeout
.\mvnw.cmd test "-Dkarate.options=--tags ~@timeout"    # Omite las pruebas lentas
.\mvnw.cmd test "-Dkarate.options=classpath:usuarios/get-usuarios.feature"   # Un solo feature
.\mvnw.cmd test "-Dkarate.env=ci"
.\mvnw.cmd test "-DbaseUrl=http://localhost:3002"
.\mvnw.cmd test-compile gatling:test "-Dperfil=carga"   # O estres; reporte en target/gatling
node scripts\resumen-performance.mjs                     # TPS, latencias, recursos y hallazgos de la última ejecución
npx.cmd newman@6.2.3 run .\postman\usuarios-api.postman_collection.json -e .\postman\local.postman_environment.json
```

En PowerShell el argumento `-D...` completo va entre comillas dobles. Reporte HTML: `target/karate-reports/karate-summary.html`; log HTTP: `target/karate.log`.

## Arquitectura

- `ApiTestRunner.java` es el único punto de entrada (surefire solo incluye esa clase). Ejecuta una lista explícita de carpetas (`FEATURES_FUNCIONALES`) con `parallel(1)` y falla si hay escenarios fallidos: una carpeta nueva de features debe agregarse a esa lista o no se ejecuta. `-Dkarate.options` sobrescribe tags y rutas del Runner.
- `performance/` queda fuera del Runner: sus features los ejecuta Gatling desde `performance/UsuariosSimulation.java` (perfiles `carga` y `estres` con `-Dperfil`). Antes de la carga corre `preparar-datos.feature`; los demás solo leen, porque varios usuarios virtuales comparten el mock. Gatling corre en otra JVM: `perfil`, `baseUrl` y `karate.env` se le pasan mediante propiedades del `pom.xml` (`jvmArgs`), y con log `WARN`.
- `performance/MonitorRecursos` corre en los hooks `before()`/`after()` de la simulación y escribe `target/gatling-recursos/` (CSV por segundo y `resumen.json`). Busca el PID del mock por el puerto de `baseUrl` (`netstat` en Windows, `ss` en Linux) o lo toma de `-DmockPid`. En Windows `ProcessHandle` no expone la línea de comandos ni la memoria de otro proceso: la memoria se lee con `tasklist`. `scripts/resumen-performance.mjs` combina eso con `target/gatling/<lastRun>/js/stats.json` (`percentiles1..4` = p50, p75, p95, p99) y no decide si la prueba pasa; eso lo hacen las aserciones de Gatling. `TPS_MINIMO_CARGA` se deriva de la inyección del perfil `carga`: al cambiar la inyección, recalcularlo. `docs/monitoreo-instana.md` relaciona estas métricas con Instana, que no se puede ejecutar localmente.
- Un solo hilo es obligatorio: el mock guarda los usuarios en un único data bucket compartido y los escenarios lo restablecen con `POST /api/test/reset`.
- Los `.feature`, `karate-config.js` y `logback-test.xml` viven en `src/test/java` (el `pom.xml` los copia como recursos de prueba). Los datos de prueba van en `src/test/resources/data`, fuera de los `.feature`.
- `health/health.feature` no está en la estructura de la especificación: se agregó porque el health check no pertenece a `usuarios/` ni a `contratos/`.
- `common/` contiene features reutilizables (`reset.feature`, `login.feature`) y esquemas (`common/schemas/`). Llevan `@ignore` para que el Runner no los ejecute solos; se invocan con `call` o `callonce`.
- `soporte/` (Java) valida contratos sin hacer solicitudes: `OpenApiContrato` contra `src/test/resources/contracts/openapi.yaml` (librería `openapi-request-validator-core`) y `XmlContrato` contra el XSD incluido en `contracts/usuarios.wsdl` (APIs XML del JDK). Ambos devuelven una lista de errores; en Karate se usa `match ... == []`. Al cambiar el mock, actualizar también estos contratos.
- `soporte/BaseDeDatos` da acceso JDBC a un H2 en memoria (modo PostgreSQL) que `sql/datos-sql.feature` recrea en cada escenario desde `src/test/resources/sql` (`schema.sql`, `datos.sql`). Solo `PreparedStatement` con `?`, nunca SQL concatenado. `-Ddb.url`, `-Ddb.usuario` y `-Ddb.clave` apuntan a otra base. Los datos semilla deben coincidir con los usuarios iniciales del mock.
- Documentos con resultados reales: `README.md`, `docs/informe-resultados.md`, `guia_qa_poc_api_rest_karate_mockoon.html` y `arquitectura.html` (tabla de cobertura del aviso, con lo parcial y lo pendiente). Al cambiar escenarios, umbrales o resultados, actualizarlos con cifras de una ejecución real. Los conteos por tag salen de los JSON de `target/karate-reports/` de una ejecución completa.
- CI: `.github/workflows/api-tests.yml` y `azure-pipelines.yml` son equivalentes (validar mock, iniciar Mockoon CLI, Karate, Newman, Gatling, publicar reportes). Un cambio en uno se replica en el otro. `postman/` es una colección independiente ejecutada con Newman; no la usan los features.
- `karate-config.js` centraliza `baseUrl`, timeouts y `maxResponseTimeMs`. Acepta `karate.env` `local` (por defecto) o `ci`; cualquier otro valor falla.

## Restricciones

- Karate 1.5.2 con `karate-junit5`, por decisión del usuario: Karate 2.x solo publica `karate-junit6`. No actualizar a 2.x sin consultarlo.
- Todas las solicitudes HTTP de las pruebas automatizadas se hacen con Karate. No usar REST Assured ni otros clientes en el código Java ni en los features. La colección de Postman/Newman es un entregable aparte que demuestra ese requisito, no un reemplazo de Karate.
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
- Banca: `POST /api/transferencias` tiene una respuesta por regla, en orden (401, 403, 400, 422 esquema, 422 decimales, 422 misma cuenta, 404 origen, 404 destino, 422 origen no activa, 422 destino no activa, 422 saldo) y la 201 por defecto. Las reglas de negocio son reglas `templating` con `#each (dataRaw 'cuentas')` y regex `^si$` o `^existe$`. Las cuentas del data bucket `cuentas` deben coincidir con `sql/datos.sql` y con `data/cuentas.json`; el reset restaura `cuentas` desde `cuentas-iniciales` y vacía `transferencias`.
- Plantillas de Mockoon: `setVar` dentro de un `#each` solo vale para esa iteración, así que la 201 vuelve a recorrer las cuentas para mostrar los saldos. El helper `float` genera números aleatorios (faker), no convierte; para redondear a centavos se usa `divide (round (multiply x 100)) 100`. `eq` compara con `===`.
- DELETE responde 204 sin cuerpo ni `Content-Type`.
- `/api/usuarios/lento` tarda 15 s (`latency` y `retardo_ms` en el mock); debe coincidir con `timeouts.slowDelayMs` de `karate-config.js`.
- 401 incluye `WWW-Authenticate: Bearer`; 403 es token válido sin permisos (`qa_sin_permisos`). Los tokens son cadenas fijas, no JWT.
- 524 es un código específico de Cloudflare; Mockoon solo simula la respuesta.
- SOAP (`POST /soap/usuarios`): Mockoon convierte el XML en un objeto con los prefijos en las claves y el texto en `_text`, así que las reglas y plantillas usan `soapenv:Envelope.soapenv:Body.usu:ObtenerUsuario.usu:id._text`. Solo funcionan los prefijos `soapenv` y `usu`. Comparte el data bucket `usuarios` con REST. Los errores son SOAP Fault con HTTP 500.
- `GET /soap/usuarios?wsdl` sirve una copia inline de `contracts/usuarios.wsdl`; un escenario comprueba que coinciden. Si se edita el WSDL, actualizar también el cuerpo de esa ruta en el mock.
- En Karate, XPath ignora los prefijos de namespace (`/Envelope/Body/...`); con prefijos devuelve `#notpresent`. `count()` en XPath devolvió 0: contar con el largo de la lista.
