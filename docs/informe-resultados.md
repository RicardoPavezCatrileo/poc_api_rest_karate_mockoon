# Informe de resultados de pruebas

**Sistema bajo prueba:** API REST y servicio SOAP de usuarios, simulados con Mockoon 9.10.0 (`mocks/usuarios-api.json`).
**Fecha de las ejecuciones:** 2026-11-11.
**Rama:** `feature/performance-metrics` (commit `283da16`).

Todas las cifras de este informe salen de ejecuciones reales de esa fecha. Lo que no se pudo verificar se indica como tal.

## Resumen

| Ámbito | Resultado |
|---|---|
| Pruebas funcionales (Karate) | 228 de 228 escenarios aprobados, en 15 features |
| Colección de Postman (Newman) | 14 solicitudes y 45 de 45 aserciones aprobadas |
| Carga (Gatling) | Se cumplieron los 7 umbrales del SLA: 48,75 TPS, p95 de 30 ms, p99 de 32 ms y 0 errores |
| Estrés (Gatling) | 9.570 solicitudes sin errores, hasta unas 275 por segundo en el último escalón |
| CI (GitHub Actions) | Runs en verde en `main` y en `feature/performance-metrics` |
| Defectos de la API | Ninguno registrado (ver [Defectos](#defectos)) |

**Conclusión:** el servicio cumple el contrato y el SLA definido para la carga esperada. El principal riesgo no es funcional: la carga y el servicio se midieron en la misma máquina y contra un mock, así que los tiempos no representan producción.

## Alcance

**Incluido:** CRUD de usuarios, autenticación (login, Bearer, API Key, 401 y 403), errores HTTP y timeouts, contratos OpenAPI y WSDL/XSD, servicio SOAP, datos con SQL (H2), colección de Postman, carga y estrés con Gatling, y ejecución en CI.

**Excluido:** un backend real con base de datos real, pruebas de seguridad de penetración, pruebas de resistencia (soak) y de pico (spike), y el monitoreo con un APM (Instana no está disponible en local; ver `docs/monitoreo-instana.md`).

## Entorno

| Elemento | Local | CI |
|---|---|---|
| Sistema | Windows 11, 20 núcleos, 16 GB | GitHub Actions, `ubuntu-latest` |
| Java | 21 | 21 (Temurin) |
| Node.js | 26.13.0 | 26 |
| Mock | Mockoon CLI 9.10.0 en el puerto 3001 | Mockoon CLI 9.10.0 |
| Herramientas | Karate 1.5.2, Gatling 3.11.5 (karate-gatling), H2 2.5.252, Newman 6.2.3 | Las mismas |

## Resultados funcionales

`.\mvnw.cmd test`: 228 escenarios aprobados, 0 fallidos. El runner tardó 42,4 s (incluye los escenarios `@timeout`, que esperan una ruta de 15 s). Sin `@timeout`: 223 escenarios en 22,5 s.

| Tag | Escenarios | Contenido |
|---|---:|---|
| `@regression` | 228 | Suite completa |
| `@negative` | 117 | Entradas inválidas y respuestas de error |
| `@contract` | 71 | Estructura, OpenAPI y WSDL/XSD |
| `@security` | 37 | Autenticación y autorización |
| `@smoke` | 18 | Camino crítico |
| `@soap` | 16 | Servicio SOAP |
| `@sql` | 15 | Datos con SQL |
| `@timeout` | 5 | Timeouts del cliente y del servidor |

Los escenarios pueden tener varios tags, así que la suma supera el total.

**Newman:** 14 solicitudes, 28 scripts de prueba, 45 aserciones aprobadas y tiempo medio de respuesta de 35 ms (mínimo 18, máximo 64).

**CI:** el run de `feature/performance-metrics` pasó sus 12 pasos en 2 min 17 s: Karate en 58 s, Newman en 5 s y Gatling en 48 s.

## Resultados de performance

### Carga: tráfico esperado

Rampa de 10 s y 30 s sostenidos a 20 consultas, 5 logins y 5 SOAP por segundo (55 solicitudes por segundo en régimen).

| Solicitud | Total | KO | TPS | p50 | p95 | p99 | Máx |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Global** | 1.950 | 0 | 48,75 | 20 | 30 | 32 | 35 |
| GET /api/usuarios/{id} | 705 | 0 | 17,63 | 21 | 31 | 32 | 33 |
| GET /api/secure/usuarios | 180 | 0 | 4,5 | 17 | 31 | 34 | 35 |
| GET /api/usuarios | 705 | 0 | 17,63 | 25 | 30 | 31 | 35 |
| POST /soap/usuarios | 180 | 0 | 4,5 | 11 | 29 | 32 | 33 |
| POST /api/auth/login | 180 | 0 | 4,5 | 12 | 27 | 29 | 31 |

Tiempos en ms. Umbrales: p95 global < 500 ms, p99 < 800 ms, máximo < 2 s, errores < 1 %, TPS ≥ 45, y p95 de login y de SOAP < 500 ms. **Se cumplieron los 7.**

| Recurso | Promedio | Máximo |
|---|---:|---:|
| CPU host (%) | 12,8 | 31,7 |
| CPU inyector Gatling (% del host) | 4,1 | 9,9 |
| CPU mock (% de un núcleo) | 19,4 | 60,9 |
| Memoria mock (MB) | 228,7 | 262,8 |

### Estrés: buscar el límite

Cinco escalones de 10 s, de 20 a 100 consultas por segundo, con login y SOAP proporcionales.

| Solicitud | Total | KO | TPS | p50 | p95 | p99 | Máx |
|---|---:|---:|---:|---:|---:|---:|---:|
| **Global** | 9.570 | 0 | 162,2 | 13 | 22 | 29 | 35 |
| GET /api/usuarios | 3.480 | 0 | 58,98 | 14 | 26 | 29 | 35 |
| GET /api/usuarios/{id} | 3.480 | 0 | 58,98 | 13 | 22 | 29 | 34 |
| GET /api/secure/usuarios | 870 | 0 | 14,75 | 14 | 22 | 29 | 33 |
| POST /soap/usuarios | 870 | 0 | 14,75 | 9 | 20 | 25 | 28 |
| POST /api/auth/login | 870 | 0 | 14,75 | 12 | 18 | 27 | 30 |

| Recurso | Promedio | Máximo |
|---|---:|---:|
| CPU host (%) | 15,9 | 32,2 |
| CPU inyector Gatling (% del host) | 6,7 | 17,4 |
| CPU mock (% de un núcleo) | 36,5 | 88,1 |
| Memoria mock (MB) | 262,5 | 283,7 |

## Hallazgos

| # | Hallazgo | Evidencia | Impacto |
|---|---|---|---|
| H1 | El CPU del mock crece con cada escalón de estrés: 21,5 %, 24,4 %, 40,6 %, 47,6 % y 51,0 % de un núcleo (promedios por tramos de 12 s), mientras el host no pasa de 32 %. | Muestras por segundo de `MonitorRecursos` en la corrida de `estres` (el CSV se sobrescribe en cada ejecución) | Con más carga, el hilo de eventos de Node sería el primer recurso en saturarse. Las latencias todavía no lo reflejan. |
| H2 | En una ejecución anterior, con escalones de 50 a 250 consultas por segundo, el 25,8 % de las solicitudes falló con `BindException` mientras el p99 del servidor seguía en 28 ms. | Comentario de `UsuariosSimulation.estres()` | El límite fue el generador de carga (puertos efímeros de Windows), no el servicio. Por eso el perfil actual llega hasta 100 consultas por segundo. |
| H3 | `header X = null` en Karate envía el texto `null`; no omite la cabecera. | `target/karate.log` | Los casos de cabecera ausente se escribieron como escenarios propios. Sin esa verificación habrían pasado probando otra cosa. |
| H4 | El mock solo entiende los prefijos SOAP `soapenv` y `usu`. | README, sección Servicio SOAP | Un cliente SOAP real con otros prefijos para el mismo namespace fallaría contra el mock. Es una limitación del mock, no del contrato. |
| H5 | En Windows, la CPU de un proceso se acumula en intervalos de unos 15 ms: una muestra aislada puede marcar 0 % o un pico. | `recursos.csv` | Los hallazgos de recursos se basan en la tendencia, no en muestras sueltas. |
| H6 | Mientras se construía la transferencia, un error de sintaxis en la plantilla hizo que Mockoon respondiera **201 con un texto de error en el cuerpo y sin mover ningún saldo**. | Prueba manual con curl antes de escribir los escenarios | Una prueba que solo revisara el status habría pasado. Los escenarios de transferencia validan el esquema de la respuesta y los saldos por `GET /api/cuentas/{id}`. |

## Actualización: dominio bancario

Ejecución del 2026-11-11, después de agregar cuentas y transferencias (rama `feature/banca-transferencias`):

| Ámbito | Resultado |
|---|---|
| Suite completa | 266 de 266 escenarios aprobados en 16 features; runner en 50,2 s |
| `transferencias/transferencias.feature` (`@banca`) | 38 de 38: 7 reglas de negocio, 14 datos inválidos, 4 payloads malformados, 401, 403, conservación del dinero, redondeo a centavos, contrato OpenAPI y 3 escenarios de consistencia con SQL |
| Newman con la carpeta 06 Banca | 17 solicitudes, 55 de 55 aserciones |

Comprobaciones clave: ningún rechazo mueve dinero; tras tres transferencias el total sigue en 4950,50; 0.1 + 0.2 suman exactamente 0.3; y en la base, una transferencia a una cuenta cerrada revierte el descuento ya hecho al origen (rollback).

## Defectos

No se registraron defectos de la API. El sistema bajo prueba es un mock que se construyó junto con su contrato, y los escenarios de control comprueban que los validadores **rechazan** respuestas incorrectas (campo de más, tipo incorrecto, status no documentado). Es decir, las pruebas detectarían un defecto si existiera. En un backend real, un fallo se registraría como Bug con la plantilla de `docs/azure-boards.md`.

## Riesgos

| # | Riesgo | Probabilidad | Mitigación |
|---|---|---|---|
| R1 | El mock no se comporta igual que el backend real (latencia, concurrencia, persistencia). | Alta | Ejecutar la misma suite contra un ambiente real con `-DbaseUrl`; los contratos sirven de puente. |
| R2 | Los tiempos de performance están medidos con el inyector y el mock en la misma máquina. | Alta | Inyector en otra máquina o agente; validar del lado del servidor con un APM (Instana). |
| R3 | En CI, los agentes compartidos varían en capacidad: los umbrales de Gatling podrían fallar sin un cambio real. | Media | Umbrales con margen (p95 500 ms frente a 30 ms medidos); si se vuelve inestable, separar la carga en un pipeline programado. |
| R4 | La suite corre en un hilo por el estado compartido del mock; el tiempo crece con cada escenario. | Media | Aislar datos (ids únicos por escenario) para paralelizar. |
| R5 | Los contratos (`openapi.yaml`, `usuarios.wsdl`) se escribieron para el mock y pueden desfasarse. | Media | En un proyecto real, el contrato lo entrega desarrollo y se versiona con el servicio. |
| R6 | La detección del PID del mock en Linux (`ss`) no está verificada: los logs del run requieren sesión. | Baja | Revisar el resumen del job en GitHub Actions; si no aparece el PID, pasar `-DmockPid`. |

## Recomendaciones

1. Ejecutar la suite contra un ambiente real antes de usar estos tiempos como referencia (R1, R2).
2. Separar la prueba de carga en un pipeline programado si los umbrales se vuelven inestables en CI (R3).
3. Incorporar un APM (Instana) para correlacionar los tiempos de Gatling con la latencia del servidor y sus trazas.
4. Agregar pruebas de pico y de resistencia cuando exista un ambiente dedicado.

## Evidencia

| Evidencia | Ubicación |
|---|---|
| Reporte de Karate | `target/karate-reports/karate-summary.html` |
| Solicitudes y respuestas HTTP | `target/karate.log` |
| Reporte de Gatling | `target/gatling/<ejecución>/index.html` |
| Recursos y resumen de performance | `target/gatling-recursos/` |
| Resultados en CI | Artefacto `reporte-pruebas` de cada run de GitHub Actions |
