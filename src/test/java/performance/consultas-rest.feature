Feature: Consultas REST bajo carga

  Lo ejecuta Gatling (performance.UsuariosSimulation); ApiTestRunner no lo incluye.
  Solo lee datos, así que varios usuarios virtuales pueden ejecutarlo a la vez sin interferir.

  Background:
    * url baseUrl

  Scenario: Listar y obtener usuarios
    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And match response == '#[_ > 0]'

    * def usuarioId = 1 + Math.floor(Math.random() * 3)
    Given path 'api', 'usuarios', usuarioId
    When method get
    Then status 200
    And match response.id == usuarioId
