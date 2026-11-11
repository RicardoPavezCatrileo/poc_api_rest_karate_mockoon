Feature: Login y recurso protegido bajo carga

  Lo ejecuta Gatling (performance.UsuariosSimulation); ApiTestRunner no lo incluye.

  Background:
    * url baseUrl
    * def auth = read('classpath:data/auth.json')

  Scenario: Iniciar sesión y consultar con token Bearer
    Given path 'api', 'auth', 'login'
    And request auth.credencialesValidas
    When method post
    Then status 200
    * def token = response.access_token

    Given path 'api', 'secure', 'usuarios'
    And header Authorization = 'Bearer ' + token
    When method get
    Then status 200
