@regression @contract
Feature: Las respuestas REST cumplen el contrato OpenAPI (contracts/openapi.yaml)

  Karate hace la solicitud y soporte.OpenApiContrato valida status, cabeceras y cuerpo recibidos
  contra la especificación. Un status no documentado, un tipo incorrecto, un campo de más o una
  cabecera requerida ausente se informan como error.

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def auth = read('classpath:data/auth.json')
    * def OpenApi = Java.type('soporte.OpenApiContrato')
    * def erroresDeContrato = function(metodo, ruta){ return OpenApi.validarRespuesta(metodo, ruta, karate.get('responseStatus'), karate.get('responseHeaders'), karate.get('responseBytes')) }

  @smoke
  Scenario: La especificación OpenAPI es válida
    * match OpenApi.erroresDeLaEspecificacion() == []

  Scenario Outline: <metodo> <ruta> responde <status> según el contrato
    Given path ruta
    When method metodo
    Then match responseStatus == status
    And match erroresDeContrato(metodo, '/' + ruta) == []

    Examples:
      | metodo | ruta                  | status! |
      | get    | api/health            | 200     |
      | post   | api/test/reset        | 200     |
      | get    | api/usuarios          | 200     |
      | get    | api/usuarios/1        | 200     |
      | get    | api/usuarios/999      | 404     |
      | get    | api/usuarios/12345    | 404     |
      | delete | api/usuarios/2        | 204     |
      | delete | api/usuarios/999      | 404     |
      | get    | api/secure/usuarios   | 401     |
      | get    | api/apikey/usuarios   | 401     |

  Scenario Outline: <metodo> <ruta> con cuerpo responde <status> según el contrato: <caso>
    Given path ruta
    And request cuerpo
    When method metodo
    Then match responseStatus == status
    And match erroresDeContrato(metodo, '/' + ruta) == []

    Examples:
      | caso                  | metodo | ruta            | cuerpo!                                                                          | status! |
      | crear                 | post   | api/usuarios    | { nombre: 'Diego Rojas', email: 'diego@example.com', rol: 'usuario', activo: true } | 201     |
      | crear-invalido        | post   | api/usuarios    | { nombre: '', email: 'diego@example.com', rol: 'usuario', activo: true }            | 422     |
      | reemplazar            | put    | api/usuarios/1  | { nombre: 'Ana', email: 'ana@example.com', rol: 'admin', activo: false }            | 200     |
      | reemplazar-inexistente| put    | api/usuarios/999| { nombre: 'Ana', email: 'ana@example.com', rol: 'admin', activo: false }            | 404     |
      | actualizar            | patch  | api/usuarios/1  | { activo: false }                                                                | 200     |
      | actualizar-vacio      | patch  | api/usuarios/1  | {}                                                                               | 422     |
      | login                 | post   | api/auth/login  | { username: 'qa_user', password: 'demo123' }                                     | 200     |
      | login-incorrecto      | post   | api/auth/login  | { username: 'qa_user', password: 'otra' }                                        | 401     |

  Scenario Outline: <metodo> con payload malformado responde 400 según el contrato
    Given path 'api', 'usuarios', 1
    And header Content-Type = 'application/json'
    And request 'esto no es json'
    When method metodo
    Then status 400
    And match erroresDeContrato(metodo, '/api/usuarios/1') == []

    Examples:
      | metodo |
      | put    |
      | patch  |

  Scenario Outline: El error <codigo> cumple el contrato
    Given path 'api', 'errores', codigo
    When method get
    Then match responseStatus == codigo
    And match erroresDeContrato('get', '/api/errores/' + codigo) == []

    Examples:
      | read('classpath:data/errores-http.json') |

  @security
  Scenario Outline: Los recursos protegidos responden <status> según el contrato: <caso>
    Given path ruta
    And header <cabecera> = valor
    When method get
    Then match responseStatus == status
    And match erroresDeContrato('get', '/' + ruta) == []

    Examples:
      | caso              | ruta                | cabecera      | valor                                | status! |
      | token-valido      | api/secure/usuarios | Authorization | Bearer token-demo-12345              | 200     |
      | token-sin-permiso | api/secure/usuarios | Authorization | Bearer token-sin-permisos-67890      | 403     |
      | api-key-valida    | api/apikey/usuarios | X-API-Key     | demo-api-key-123                     | 200     |

  # Comprueban que el validador detecta incumplimientos: sin esto, un validador que no valida
  # dejaría pasar todas las pruebas anteriores.

  Scenario Outline: El validador OpenAPI detecta una respuesta que no cumple el contrato: <caso>
    * def errores = OpenApi.validarEjemplo(metodo, ruta, status, 'application/json', cuerpo)
    * match errores == '#[_ > 0]'

    Examples:
      | caso                   | metodo | ruta               | status! | cuerpo                                                                                      |
      | id-texto               | GET    | /api/usuarios/1    | 200     | {"id":"1","nombre":"Ana","email":"ana@example.com","rol":"admin","activo":true}             |
      | campo-de-mas           | GET    | /api/usuarios/1    | 200     | {"id":1,"nombre":"Ana","email":"ana@example.com","rol":"admin","activo":true,"password":"x"} |
      | campo-faltante         | GET    | /api/usuarios/1    | 200     | {"id":1,"nombre":"Ana","rol":"admin","activo":true}                                         |
      | rol-desconocido        | GET    | /api/usuarios/1    | 200     | {"id":1,"nombre":"Ana","email":"ana@example.com","rol":"root","activo":true}                |
      | status-no-documentado  | GET    | /api/usuarios/1    | 418     | {"codigo":418,"error":"Teapot","mensaje":"x"}                                               |
      | error-sin-mensaje      | GET    | /api/usuarios/999  | 404     | {"codigo":404,"error":"Not Found"}                                                          |
      | lista-no-es-arreglo    | GET    | /api/usuarios      | 200     | {"id":1}                                                                                    |

  Scenario: El validador OpenAPI acepta una respuesta que cumple el contrato
    * def cuerpo = '{"id":1,"nombre":"Ana","email":"ana@example.com","rol":"admin","activo":true}'
    * match OpenApi.validarEjemplo('GET', '/api/usuarios/1', 200, 'application/json', cuerpo) == []

  Scenario: El validador OpenAPI exige WWW-Authenticate en el 401
    * def cuerpo = '{"codigo":401,"error":"Unauthorized","mensaje":"x"}'
    * match OpenApi.validarEjemplo('GET', '/api/secure/usuarios', 401, 'application/json', cuerpo) == '#[_ > 0]'
