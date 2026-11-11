@regression @soap
Feature: Servicio SOAP 1.1 de usuarios (POST /soap/usuarios)

  El servicio comparte el data bucket usuarios con la API REST: lo que se crea o elimina por REST
  se refleja en SOAP. Los errores se informan con SOAP Fault y HTTP 500, como define SOAP 1.1.
  Karate ignora los prefijos de namespace en XPath: /Envelope/Body/... selecciona soapenv:Envelope/soapenv:Body/...

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def datos = read('classpath:data/usuarios.json')
    * def XmlContrato = Java.type('soporte.XmlContrato')
    * def accion = 'http://poc.qa/usuarios/'

  @smoke @contract
  Scenario: ObtenerUsuario devuelve el usuario y cumple el contrato del WSDL
    * def usuarioId = 1
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/obtener-usuario.xml')
    When soap action accion + 'ObtenerUsuario'
    Then status 200
    And match header Content-Type contains 'text/xml'
    And match XmlContrato.validar(responseBytes) == []
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/id == '1'
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/nombre == datos.usuario1.nombre
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/email == datos.usuario1.email
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/rol == datos.usuario1.rol
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/activo == 'true'
    And match /Envelope/Body/Fault == '#notpresent'

  @smoke @contract
  Scenario: ListarUsuarios devuelve los usuarios iniciales y cumple el contrato del WSDL
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/listar-usuarios.xml')
    When soap action accion + 'ListarUsuarios'
    Then status 200
    And match XmlContrato.validar(responseBytes) == []
    And match /Envelope/Body/ListarUsuariosResponse/usuario/id == ['1', '2', '3']
    And match /Envelope/Body/ListarUsuariosResponse/usuario[3]/nombre == 'Carla Muñoz'

  Scenario: Un usuario creado por REST se obtiene por SOAP
    Given path 'api', 'usuarios'
    And request datos.nuevo
    When method post
    Then status 201
    * def usuarioId = response.id

    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/obtener-usuario.xml')
    When soap action accion + 'ObtenerUsuario'
    Then status 200
    And match XmlContrato.validar(responseBytes) == []
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/id == '' + usuarioId
    And match /Envelope/Body/ObtenerUsuarioResponse/usuario/nombre == datos.nuevo.nombre

  @negative
  Scenario: Un usuario eliminado por REST responde SOAP Fault
    Given path 'api', 'usuarios', 1
    When method delete
    Then status 204

    * def usuarioId = 1
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/obtener-usuario.xml')
    When soap action accion + 'ObtenerUsuario'
    Then status 500
    And match /Envelope/Body/Fault/faultstring == 'El usuario 1 no existe.'

  @negative
  Scenario Outline: ObtenerUsuario con el id <usuarioId> responde SOAP Fault de cliente
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/obtener-usuario.xml')
    When soap action accion + 'ObtenerUsuario'
    Then status 500
    And match header Content-Type contains 'text/xml'
    And match /Envelope/Body/Fault/faultcode == 'soapenv:Client'
    And match /Envelope/Body/Fault/faultstring == 'El usuario ' + usuarioId + ' no existe.'
    And match /Envelope/Body/ObtenerUsuarioResponse == '#notpresent'

    Examples:
      | usuarioId |
      | 999       |
      | 12345     |
      | abc       |

  @negative
  Scenario: Una operación desconocida responde SOAP Fault de cliente
    Given path 'soap', 'usuarios'
    And request read('classpath:data/soap/operacion-desconocida.xml')
    When soap action accion + 'EliminarTodo'
    Then status 500
    And match /Envelope/Body/Fault/faultcode == 'soapenv:Client'
    And match /Envelope/Body/Fault/faultstring contains 'operación desconocida'

  @negative
  Scenario: Un XML mal formado responde SOAP Fault de cliente
    Given path 'soap', 'usuarios'
    And header Content-Type = 'text/xml; charset=utf-8'
    And header SOAPAction = accion + 'ObtenerUsuario'
    And request '<soapenv:Envelope><soapenv:Body><roto'
    When method post
    Then status 500
    And match /Envelope/Body/Fault/faultcode == 'soapenv:Client'
    And match /Envelope/Body/Fault/faultstring contains 'XML mal formado'

  @contract
  Scenario: El WSDL publicado coincide con el contrato del repositorio
    Given path 'soap', 'usuarios'
    And param wsdl = ''
    When method get
    Then status 200
    And match header Content-Type contains 'text/xml'
    And match /definitions/@name == 'UsuariosService'
    And match /definitions/portType/operation/@name == ['ObtenerUsuario', 'ListarUsuarios']
    And match /definitions/binding/operation/operation/@soapAction == ['http://poc.qa/usuarios/ObtenerUsuario', 'http://poc.qa/usuarios/ListarUsuarios']
    * def normalizar = function(texto){ return texto.replace(/\r/g, '').trim() }
    * def publicado = normalizar(new java.lang.String(responseBytes, 'UTF-8'))
    * def contrato = normalizar(karate.readAsString('classpath:contracts/usuarios.wsdl'))
    * match publicado == contrato

  @contract
  Scenario Outline: El validador del WSDL rechaza una respuesta que no cumple el contrato: <caso>
    * def errores = XmlContrato.validar(xml)
    * match errores == '#[_ > 0]'

    Examples:
      | read('classpath:data/soap/respuestas-invalidas.json') |
