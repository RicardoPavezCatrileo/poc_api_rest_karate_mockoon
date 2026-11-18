# Azure DevOps: Boards, Repos y Pipelines

Cómo se gestionaría esta POC en Azure DevOps: el trabajo en **Boards**, el código en **Repos** y la ejecución en **Pipelines** (`azure-pipelines.yml`). El repositorio real está en GitHub; esta guía describe el flujo equivalente y lo que cambia si el código vive en Azure Repos.

## Estructura del trabajo en Boards

El proyecto usaría el proceso **Agile**, cuya jerarquía es Epic → Feature → User Story → Task, con Bug al nivel de las historias. En el proceso **Scrum** la historia se llama Product Backlog Item; en **Basic**, Issue.

| Nivel | Ejemplo en esta POC |
|---|---|
| Epic | Automatización de pruebas backend de la API de usuarios |
| Feature | CRUD REST · Autenticación y autorización · Errores y timeouts · Servicio SOAP · Contratos · Datos con SQL · Performance · CI/CD · Colección Postman |
| User Story | Ver ejemplos abajo |
| Task | Escribir el feature, agregar los datos, ajustar el mock, actualizar el contrato, ejecutar en CI |
| Bug | Un defecto encontrado por una prueba (plantilla abajo) |

Las **Area Paths** separan por componente (`POC\API REST`, `POC\SOAP`, `POC\Performance`) y las **Iterations** por sprint. Cada fase de la POC equivale a un sprint.

## Historias con criterios de aceptación

Los criterios de aceptación se escriben de forma que cada uno sea un escenario de Karate. Así, la trazabilidad va de la historia al `.feature` y del `.feature` al resultado del pipeline.

**User Story: Consultar usuarios**
> Como consumidor de la API, quiero listar y obtener usuarios, para mostrarlos en mi aplicación.

| Criterio de aceptación | Escenario |
|---|---|
| `GET /api/usuarios` responde 200 con la lista y cada usuario cumple el esquema | `get-usuarios.feature`: «Listar los usuarios iniciales» |
| `GET /api/usuarios/{id}` de un usuario existente responde 200 con ese usuario | «Obtener el usuario existente» |
| Un id inexistente responde 404 con el mensaje «El usuario {id} no existe.» | «Obtener el usuario inexistente responde 404» |

**User Story: Proteger el recurso de usuarios**
> Como responsable de seguridad, quiero que `/api/secure/usuarios` exija un token válido con permisos, para que solo accedan usuarios autorizados.

| Criterio de aceptación | Escenario |
|---|---|
| Con un token válido responde 200 y no expone campos sensibles | `authorization.feature`: «Un token válido accede al recurso» |
| Sin token responde 401 con `WWW-Authenticate: Bearer` | «Sin token responde 401 con WWW-Authenticate» |
| Con un token válido sin permisos responde 403 | «Un token válido sin permisos responde 403 sin WWW-Authenticate» |

**User Story: Conciliar saldos**
> Como analista de operaciones, quiero verificar que el saldo de cada cuenta coincide con sus movimientos, para detectar inconsistencias.

| Criterio de aceptación | Escenario |
|---|---|
| Saldo = saldo inicial + depósitos − retiros en todas las cuentas | `datos-sql.feature`: «Conciliación: el saldo de cada cuenta coincide con saldo inicial + depósitos - retiros» |
| Un saldo alterado se detecta | «La conciliación detecta un saldo alterado» |

**User Story: Rendimiento del servicio**
> Como dueño del producto, quiero que la API soporte el tráfico esperado dentro del SLA, para no degradar la experiencia.

| Criterio de aceptación | Evidencia |
|---|---|
| Con 55 solicitudes por segundo sostenidas, p95 < 500 ms, p99 < 800 ms y errores < 1 % | Aserciones del perfil `carga` en `UsuariosSimulation` |
| Se identifica el primer recurso en saturarse | Hallazgo del perfil `estres` en `docs/informe-resultados.md` |

## Plantilla de Bug para un defecto de API

| Campo | Contenido |
|---|---|
| Title | `[API] POST /api/usuarios con email duplicado responde 201 en vez de 422` |
| Repro Steps | La solicitud exacta con `curl.exe` (método, URL, cabeceras y cuerpo) y el escenario de Karate que falla |
| Expected / Actual | Status y cuerpo esperados según el contrato frente a los recibidos |
| System Info | Entorno (`local` o `ci`), versión del servicio y run del pipeline (**Found in Build**) |
| Severity | 1 - Critical a 4 - Low, según el impacto; el **Priority** lo fija el equipo |
| Attachments | Extracto de `target/karate.log` y el reporte del run |
| Links | La User Story afectada y el commit o PR que lo corrige |

El ejemplo del título es ilustrativo: en la POC no se registraron defectos, porque el sistema bajo prueba es un mock que se ajustó al contrato.

## Vincular commits y pull requests con work items

| Dónde está el código | Cómo se vincula |
|---|---|
| Azure Repos | Mencionar `#123` en el mensaje del commit o en el PR. Al completar el PR, la opción de completar los work items vinculados los cierra |
| GitHub (como esta POC) | Instalar la app **Azure Boards** en el repositorio y mencionar `AB#123` en el commit o el PR; `Fixes AB#123` cambia el estado al hacer merge |

Ejemplo de commit con el formato de `docs/branching-strategy.md`:

```text
feat: add resource monitor and TPS thresholds AB#123
```

## Azure Repos: políticas de rama

Si el código viviera en Azure Repos, `main` se protegería con **Branch policies**, el equivalente a la protección de ramas de GitHub:

| Política | Configuración propuesta |
|---|---|
| Require a minimum number of reviewers | 1 revisor; quien abre el PR no aprueba su propio cambio |
| Check for linked work items | Obligatorio: todo PR se vincula a una historia, una tarea o un bug |
| Check for comment resolution | Obligatorio |
| Limit merge types | Solo squash merge, como en `docs/branching-strategy.md` |
| Build validation | El pipeline de `azure-pipelines.yml`; el PR no se completa si las pruebas fallan |

**Detalle importante:** la sección `pr:` de `azure-pipelines.yml` solo aplica a repositorios en GitHub o Bitbucket. Con Azure Repos, la validación de los PR se configura con la política **Build validation**, no en el YAML.

## Consultas y dashboard

Una consulta guardada para los bugs abiertos del área de la API (WIQL):

```sql
SELECT [System.Id], [System.Title], [Microsoft.VSTS.Common.Severity], [System.State]
FROM WorkItems
WHERE [System.TeamProject] = @project
  AND [System.WorkItemType] = 'Bug'
  AND [System.State] <> 'Closed'
  AND [System.AreaPath] UNDER 'POC\API REST'
ORDER BY [Microsoft.VSTS.Common.Severity]
```

Un dashboard del equipo de QA reuniría: la consulta anterior, el avance del sprint, el historial del pipeline y la tendencia de resultados de pruebas. Los resultados vienen de `PublishTestResults` (JUnit de Karate y Newman).

## Flujo completo de un cambio

1. Se toma una User Story del sprint y se crean sus Tasks.
2. Se crea la rama `feature/<tema>` desde `main`.
3. Cada commit menciona el work item (`#123` en Azure Repos o `AB#123` desde GitHub).
4. Se abre el PR hacia `main`. Las políticas exigen el work item vinculado, la revisión y el pipeline en verde.
5. Si una prueba encuentra un defecto, se crea un Bug con la plantilla y se vincula a la historia.
6. Al completar el PR con squash merge, los work items vinculados pasan a cerrados y el run queda como evidencia.
