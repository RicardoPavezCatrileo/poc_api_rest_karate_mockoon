@regression @contract
Feature: Contrato de las respuestas de usuarios

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')
    * def camposSensibles = read('classpath:common/campos-sensibles.js')

  @smoke
  Scenario: Contrato de la lista de usuarios
    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == '#[_ > 0]'
    And match each response == esquemaUsuario
    * def ids = $response[*].id
    And match ids == karate.distinct(ids)

  Scenario: Valores esperados del usuario 1
    Given path 'api', 'usuarios', 1
    When method get
    Then status 200
    And match response == esquemaUsuario
    And match response == datos.usuario1

  Scenario Outline: La respuesta de <recurso> no expone campos sensibles
    Given path ruta
    When method get
    Then status 200
    And match camposSensibles(response) == []

    Examples:
      | recurso   | ruta              |
      | la lista  | api/usuarios      |
      | usuario 1 | api/usuarios/1    |

  Scenario: El tiempo de respuesta está dentro del umbral
    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And assert responseTime < maxResponseTimeMs

  Scenario: DELETE no declara Content-Type
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204
    And match karate.response.header('Content-Type') == null

  # Las siguientes comprueban que los esquemas rechazan datos incorrectos:
  # sin esto, un esquema demasiado permisivo dejaría pasar todas las pruebas anteriores.

  Scenario Outline: El esquema de usuario rechaza datos incorrectos: <caso>
    * def muestra = karate.merge(datos.usuario1, cambios)
    * remove muestra.<quitar>
    * def resultado = karate.match('muestra == esquemaUsuario')
    * match resultado.pass == false

    Examples:
      | caso            | cambios!            | quitar  |
      | campo-faltante  | {}                  | email   |
      | tipo-incorrecto | { id: '1' }         | sinUso  |
      | bool-como-int   | { id: true }        | sinUso  |
      | campo-de-mas    | { password: 'x' }   | sinUso  |
      | rol-desconocido | { rol: 'root' }     | sinUso  |

  Scenario Outline: El cuerpo de error esperado rechaza el error genérico <codigo>
    Given path 'api', 'errores', codigo
    When method get
    Then match responseStatus == codigo
    * def esperado = read('classpath:common/schemas/' + esquema)
    * def resultado = karate.match('response == esperado')
    * match resultado.pass == false

    Examples:
      | codigo! | esquema                  |
      | 422     | datos-invalidos.json     |
      | 400     | payload-malformado.json  |

  Scenario Outline: La búsqueda de campos sensibles los detecta: <caso>
    * match camposSensibles(muestra) == esperado

    Examples:
      | caso       | muestra!                                | esperado!                    |
      | directo    | { password: 'x' }                       | ['$.password']               |
      | mayusculas | { Token: 'x' }                          | ['$.Token']                  |
      | anidado    | [{ perfil: { api_key: 'x' } }]          | ['$[0].perfil.api_key']      |
      | limpio     | [{ id: 1, nombre: 'Ana' }]              | []                           |
