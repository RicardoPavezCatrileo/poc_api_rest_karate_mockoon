@regression
Feature: GET /api/usuarios

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')

  @smoke
  Scenario: Listar los usuarios iniciales
    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match each response == esquemaUsuario
    And match response[*].id == datos.existentes

  @smoke
  Scenario Outline: Obtener el usuario existente <usuarioId>
    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == esquemaUsuario
    And match response.id == usuarioId

    Examples:
      | usuarioId! |
      | 1          |
      | 2          |
      | 3          |

  @negative
  Scenario Outline: Obtener el usuario inexistente <usuarioId> responde 404
    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 404
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Examples:
      | usuarioId! |
      | 999        |
      | 12345      |
