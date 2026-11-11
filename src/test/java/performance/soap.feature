Feature: Servicio SOAP bajo carga

  Lo ejecuta Gatling (performance.UsuariosSimulation); ApiTestRunner no lo incluye.

  Background:
    * url baseUrl

  Scenario: ObtenerUsuario por SOAP
    * def usuarioId = 1 + Math.floor(Math.random() * 3)
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/obtener-usuario.xml')
    When soap action 'http://poc.qa/usuarios/ObtenerUsuario'
    Then status 200
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/id == '' + usuarioId
