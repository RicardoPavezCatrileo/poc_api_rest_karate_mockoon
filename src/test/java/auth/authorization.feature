@regression @security
Feature: GET /api/secure/usuarios con token Bearer

  401: no se sabe quién llama (incluye WWW-Authenticate: Bearer).
  403: se sabe quién llama, pero no tiene permisos sobre el recurso.

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def auth = read('classpath:data/auth.json')
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')
    * def camposSensibles = read('classpath:common/campos-sensibles.js')
    * def noAutenticado = { codigo: 401, error: 'Unauthorized', mensaje: 'Token ausente, incorrecto o con formato inválido.' }
    # El token se obtiene una sola vez por feature con un login real
    * def sesion = callonce read('classpath:common/login.feature')

  @smoke
  Scenario: Un token válido accede al recurso
    Given path 'api', 'secure', 'usuarios'
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match each response == esquemaUsuario
    And match camposSensibles(response) == []
    And match response[*].id == datos.existentes

  Scenario: El recurso seguro refleja los datos actuales
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    Given path 'api', 'secure', 'usuarios'
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then status 200
    And match response[*].id == [2, 3]

  @negative
  Scenario: Sin token responde 401 con WWW-Authenticate
    Given path 'api', 'secure', 'usuarios'
    When method get
    Then status 401
    And match header Content-Type contains 'application/json'
    And match header WWW-Authenticate == 'Bearer'
    And match response == noAutenticado

  @negative
  Scenario Outline: Un token incorrecto o con formato inválido responde 401: <caso>
    Given path 'api', 'secure', 'usuarios'
    And header Authorization = authorization
    When method get
    Then status 401
    And match header WWW-Authenticate == 'Bearer'
    And match response == noAutenticado

    Examples:
      | read('classpath:data/autorizaciones-rechazadas.json') |

  @negative
  Scenario: Un token válido sin permisos responde 403 sin WWW-Authenticate
    * def sesionSinPermisos = call read('classpath:common/login.feature') { credencialesLogin: '#(auth.credencialesSinPermisos)' }
    * match sesionSinPermisos.token == auth.tokenSinPermisos

    Given path 'api', 'secure', 'usuarios'
    And header Authorization = 'Bearer ' + sesionSinPermisos.token
    When method get
    Then status 403
    And match header Content-Type contains 'application/json'
    And match response == { codigo: 403, error: 'Forbidden', mensaje: '#regex .*no tiene permisos.*' }
    And match karate.response.header('WWW-Authenticate') == null
