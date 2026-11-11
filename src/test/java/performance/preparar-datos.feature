Feature: Preparación de datos antes de la carga

  Lo ejecuta UsuariosSimulation una sola vez antes de inyectar usuarios virtuales.

  Scenario: Restablecer los usuarios y comprobar que el servicio responde
    * call read('classpath:common/reset.feature')
    Given url baseUrl
    And path 'api', 'health'
    When method get
    Then status 200
