# Estrategia de ramas

Esta guía simula la colaboración entre tres QA Automation Engineers. Los roles son didácticos: cada commit debe llevar la identidad real de quien lo hace, sin usar nombres ni correos ajenos.

## Ramas

| Rama | Responsable | Alcance |
|---|---|---|
| `main` | Todo el equipo | Código revisado, con el workflow en verde |
| `feature/api-crud` | QA 1 | `usuarios/*.feature`, `common/reset.feature` y esquemas de usuario |
| `feature/api-auth` | QA 2 | `auth/*.feature` y `common/login.feature`: login, Bearer Token, API Key, 401 y 403 |
| `feature/api-errors` | QA 3 | `errores/*.feature`: errores HTTP y timeouts |

```text
main ───●──────────────●──────────●──────────●───
         \            /          /          /
          ├─ feature/api-crud ──┘          /
          ├─ feature/api-auth ────────────┘
          └─ feature/api-errors ──────────┘
```

## Crear una rama

Parta siempre de un `main` actualizado:

```powershell
git switch main
git pull
git switch -c feature/api-crud
```

## Commits

Use commits pequeños con un solo propósito y el formato `tipo: descripción`:

| Tipo | Uso | Ejemplo |
|---|---|---|
| `feat` | Funcionalidad o escenarios nuevos | `feat: add API key scenarios` |
| `fix` | Corrección | `fix: send absent header instead of literal null` |
| `test` | Cambios en escenarios existentes | `test: validate 422 error messages` |
| `docs` | Documentación | `docs: describe timeout scenarios` |
| `ci` | Workflow | `ci: publish karate reports as artifact` |
| `chore` | Mantenimiento | `chore: update Maven Wrapper` |

Antes de cada commit, con Mockoon en marcha:

```powershell
git status
git diff
.\mvnw.cmd test
```

No versione `target/` (reportes y logs generados) ni credenciales reales.

## Pull requests

1. Publique la rama: `git push -u origin feature/api-crud`.
2. Abra el pull request hacia `main`. La plantilla está en `.github/pull_request_template.md`.
3. Espere a que el workflow `API Tests` termine en verde.
4. Pida la revisión de otro integrante.

Mantenga cada pull request acotado a su rama. Un cambio ajeno a su alcance va en otro pull request.

## Code review

Quien revisa comprueba que:

- Los escenarios validan el comportamiento y fallarían si este se rompe. En caso de duda, revise en `target/karate.log` qué se envió realmente (por ejemplo, `header X = null` envía el texto `null`).
- Los casos negativos comprueban el código, el cuerpo y el mensaje de error.
- Los datos están en `src/test/resources/data` y los esquemas en `common/schemas`.
- Las solicitudes usan Karate, sin otros clientes HTTP ni esperas fijas.
- Todo escenario lleva `@regression` y los tags que le correspondan.
- El README coincide con el cambio y solo muestra resultados reales.

Quien hace la revisión comenta con un motivo concreto. Quien abrió el pull request responde a cada comentario y no aprueba su propio trabajo.

## Conflictos

Los conflictos más probables están en los archivos compartidos: `karate-config.js`, `common/`, `src/test/resources/data/usuarios.json` y `mocks/usuarios-api.json`.

Actualice su rama con `main` y resuélvalos en local:

```powershell
git switch feature/api-auth
git fetch origin
git merge origin/main
# Edite los archivos en conflicto y conserve los cambios de ambas ramas que correspondan
git add src/test/java/karate-config.js
git commit
```

Después valide el resultado:

```powershell
npx.cmd @mockoon/cli@9.10.0 validate --data .\mocks\usuarios-api.json
.\mvnw.cmd test
git push
```

En `mocks/usuarios-api.json`, compruebe además que `lento`, `999` y DELETE sigan antes de la ruta CRUD, y que `rootChildren` contenga cada ruta. Si el conflicto es grande, puede ser más seguro aplicar los cambios de nuevo desde Mockoon Desktop.

No use `git push --force` sobre una rama compartida.

## Merge

Se hace cuando el workflow está en verde, hay una aprobación y no quedan conversaciones abiertas.

Se recomienda **Squash and merge**, para dejar en `main` un commit por pull request con un mensaje en el formato anterior. Después, borre la rama y actualice su copia:

```powershell
git switch main
git pull
git branch -d feature/api-crud
```

## Protección de main

Esto se configura en GitHub, en **Settings > Branches > Add branch protection rule**, para el patrón `main`:

- **Require a pull request before merging**, con al menos una aprobación.
- **Dismiss stale pull request approvals when new commits are pushed**.
- **Require status checks to pass before merging**, con el check `api-tests`.
- **Require branches to be up to date before merging**.
- **Require conversation resolution before merging**.
- **Do not allow bypassing the above settings**.
- Mantener desactivados los force push y el borrado de la rama.

Con una sola persona en el repositorio, exigir una aprobación impide hacer el merge, porque GitHub no permite aprobar un pull request propio. En ese caso, exija solo el pull request y el check.

Según el plan de GitHub y la visibilidad del repositorio, algunas opciones pueden no estar disponibles.
