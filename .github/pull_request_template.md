## Qué cambia y por qué

<!-- Describa el cambio y el motivo. -->

## Tipo de cambio

- [ ] Escenarios nuevos o modificados (`.feature`)
- [ ] Datos de prueba o esquemas (`src/test/resources/data`, `common/schemas`)
- [ ] Mock (`mocks/usuarios-api.json`)
- [ ] Configuración (`pom.xml`, `karate-config.js`, runner)
- [ ] Workflow de CI
- [ ] Documentación

## Cómo se probó

<!-- Pegue solo resultados reales. Indique con qué servidor se ejecutó: Mockoon Desktop o CLI. -->

```text
.\mvnw.cmd test
```

## Lista de comprobación

- [ ] La suite pasa en local y el workflow `API Tests` está en verde.
- [ ] Las solicitudes usan Karate, sin REST Assured, Postman ni esperas fijas.
- [ ] Todo escenario nuevo lleva `@regression` y sus tags específicos.
- [ ] Los datos de prueba están en JSON o CSV, fuera de los `.feature`.
- [ ] Si cambió el mock, `mockoon-cli validate` no da errores y el orden de las rutas sigue siendo correcto.
- [ ] No se incluyen reportes generados (`target/`) ni credenciales reales.
- [ ] El README y `docs/` reflejan el cambio.

## Notas para la revisión

<!-- Decisiones, riesgos o partes que conviene revisar con más atención. -->
