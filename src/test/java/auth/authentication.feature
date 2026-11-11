@regression @security
Feature: POST /api/auth/login

  Background:
    * url baseUrl
    * def auth = read('classpath:data/auth.json')
    * def credencialesIncorrectas = { codigo: 401, error: 'Unauthorized', mensaje: 'Credenciales incorrectas.' }

  @smoke
  Scenario: Login correcto entrega el token
    Given path 'api', 'auth', 'login'
    And request auth.credencialesValidas
    When method post
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == { access_token: '#(auth.tokenValido)', token_type: 'Bearer' }

  Scenario: Login del usuario sin permisos entrega otro token
    Given path 'api', 'auth', 'login'
    And request auth.credencialesSinPermisos
    When method post
    Then status 200
    And match response.access_token == auth.tokenSinPermisos

  Scenario: El feature de login reutilizable obtiene el token de qa_user
    * def sesion = call read('classpath:common/login.feature')
    * match sesion.token == auth.tokenValido

  @negative
  Scenario Outline: Login incorrecto responde 401: <caso>
    Given path 'api', 'auth', 'login'
    And request credenciales
    When method post
    Then status 401
    And match header Content-Type contains 'application/json'
    And match response == credencialesIncorrectas
    And match response.access_token == '#notpresent'

    Examples:
      | read('classpath:data/credenciales-incorrectas.json') |

  @negative
  Scenario Outline: Login con cuerpo malformado responde 401: <caso>
    Given path 'api', 'auth', 'login'
    And header Content-Type = 'application/json'
    And request cuerpo
    When method post
    Then status 401
    And match response == credencialesIncorrectas

    Examples:
      | read('classpath:data/payloads-malformados.json') |

  @negative
  Scenario: Un login incorrecto no revela la password enviada
    * def password = 'password-que-no-debe-aparecer'
    Given path 'api', 'auth', 'login'
    And request { username: 'qa_user', password: '#(password)' }
    When method post
    Then status 401
    * string cuerpo = response
    And match cuerpo !contains password
