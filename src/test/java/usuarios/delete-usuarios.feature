@regression
Feature: DELETE /api/usuarios/{id}

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def esquemaUsuario = read('classpath:common/schemas/usuario.json')

  @smoke
  Scenario: Eliminar un usuario responde 204 sin cuerpo ni Content-Type
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204
    And match responseBytes.length == 0
    And match karate.response.header('Content-Type') == null

  Scenario: El usuario eliminado deja de existir
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * def usuarioId = 1
    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 404
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id !contains 1

  Scenario: Eliminar solo afecta al usuario indicado
    Given path 'api', 'usuarios', 2
    When method delete
    Then status 204

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == [1, 3]

  @negative
  Scenario Outline: Eliminar el usuario inexistente <usuarioId> responde 404 y no altera los datos
    Given path 'api', 'usuarios', usuarioId
    When method delete
    Then status 404
    And match header Content-Type contains 'application/json'
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == datos.existentes

    Examples:
      | usuarioId! |
      | 999        |
      | 12345      |

  @negative
  Scenario: Eliminar dos veces el mismo usuario responde 404
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * def usuarioId = 1
    Given path 'api', 'usuarios', usuarioId
    When method delete
    Then status 404
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

  @smoke
  Scenario: Ciclo de vida completo de un usuario
    Given path 'api', 'usuarios'
    And request datos.nuevo
    When method post
    Then status 201
    And match response == esquemaUsuario
    And match response.id == datos.siguienteId
    * def usuarioId = response.id
    * def creado = response

    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 200
    And match response == creado

    * def esperado = karate.merge(datos.actualizado, { id: usuarioId })
    Given path 'api', 'usuarios', usuarioId
    And request datos.actualizado
    When method put
    Then status 200
    And match response == esperado

    * def esperado = karate.merge(esperado, { activo: true })
    Given path 'api', 'usuarios', usuarioId
    And request { activo: true }
    When method patch
    Then status 200
    And match response == esperado

    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 200
    And match response == esperado

    Given path 'api', 'usuarios', usuarioId
    When method delete
    Then status 204

    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 404
    And match response == read('classpath:common/schemas/usuario-no-encontrado.json')

    Given path 'api', 'usuarios'
    When method get
    Then match response[*].id == datos.existentes

  Scenario: Restablecer recupera los datos iniciales
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * call read('classpath:common/reset.feature')

    Given path 'api', 'usuarios', 1
    When method get
    Then status 200
    And match response == datos.usuario1

  Scenario: Restablecer no altera la copia inicial
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * call read('classpath:common/reset.feature')

    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * call read('classpath:common/reset.feature')

    Given path 'api', 'usuarios', 1
    When method get
    Then status 200
    And match response == datos.usuario1
