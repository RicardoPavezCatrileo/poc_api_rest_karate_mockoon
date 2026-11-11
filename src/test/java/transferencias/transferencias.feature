@regression @banca
Feature: Cuentas y transferencias bancarias

  POST /api/transferencias mueve un monto entre dos cuentas activas. Las reglas, en el orden en que el mock las evalúa:
  token válido (401) y con permisos (403), JSON válido (400), esquema y máximo 2 decimales (422), cuentas distintas (422),
  cuentas existentes (404), cuentas activas (422) y saldo suficiente (422). Una transferencia rechazada no mueve dinero.

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def cuentas = read('classpath:data/cuentas.json')
    * def auth = read('classpath:data/auth.json')
    * def esquemaCuenta = read('classpath:common/schemas/cuenta.json')
    * def esquemaTransferencia = read('classpath:common/schemas/transferencia.json')
    * def sesion = callonce read('classpath:common/login.feature')
    * def saldosIniciales = karate.map(cuentas.iniciales, function(c){ return c.saldo })
    * def saldoDe = function(id){ return karate.call('classpath:common/cuenta.feature', { cuentaId: id, token: sesion.token }).saldo }
    * def saldosActuales = function(){ return karate.map(cuentas.iniciales, function(c){ return saldoDe(c.id) }) }
    * def transferir = function(origen, destino, monto){ return karate.call('classpath:common/transferir.feature', { cuentaOrigen: origen, cuentaDestino: destino, monto: monto, token: sesion.token }) }
    * def sumar = function(lista){ var s = 0; for (var i = 0; i < lista.length; i++) { s += lista[i] } return Math.round(s * 100) / 100 }

  # ───────────── Cuentas ─────────────

  @smoke
  Scenario: Consultar una cuenta
    Given path 'api', 'cuentas', 10
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then status 200
    And match header Content-Type contains 'application/json'
    And match response == esquemaCuenta
    And match response == cuentas.iniciales[0]

  @negative
  Scenario: Una cuenta inexistente responde 404
    Given path 'api', 'cuentas', 99
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then status 404
    And match response == { codigo: 404, error: 'Not Found', mensaje: 'La cuenta 99 no existe.' }

  @security @negative
  Scenario: Consultar una cuenta sin token responde 401
    Given path 'api', 'cuentas', 10
    When method get
    Then status 401
    And match header WWW-Authenticate == 'Bearer'
    And match response.codigo == 401

  # ───────────── Transferencias aceptadas ─────────────

  @smoke
  Scenario: Una transferencia válida mueve el monto y queda en el historial
    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And request cuentas.transferenciaValida
    When method post
    Then status 201
    And match header Content-Type contains 'application/json'
    And match response == esquemaTransferencia
    And match response contains { id: 1, cuentaOrigen: 10, cuentaDestino: 20, monto: 125.75, saldoOrigen: 1374.25, saldoDestino: 375.75 }
    And match saldoDe(10) == 1374.25
    And match saldoDe(20) == 375.75

    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then status 200
    And match response == [{ id: 1, cuentaOrigen: 10, cuentaDestino: 20, monto: 125.75, estado: 'completada' }]

  Scenario: El dinero total se conserva después de varias transferencias
    * def totalAntes = sumar(saldosActuales())
    * match transferir(10, 20, 100.10).responseStatus == 201
    * match transferir(20, 11, 50.05).responseStatus == 201
    * match transferir(11, 10, 0.99).responseStatus == 201
    * match sumar(saldosActuales()) == totalAntes
    * match saldosActuales() == [1400.89, 3249.56, 300.05, 0]

  Scenario: Los centavos se redondean: 0.1 + 0.2 suman exactamente 0.3
    * match transferir(11, 20, 0.1).responseStatus == 201
    * def segunda = transferir(11, 20, 0.2)
    * match segunda.response.saldoDestino == 250.3
    * match segunda.response.saldoOrigen == 3200.2

  Scenario: Se puede transferir el saldo completo, pero no un centavo más
    * def completa = transferir(20, 10, 250)
    * match completa.responseStatus == 201
    * match completa.response.saldoOrigen == 0
    * def otra = transferir(20, 10, 0.01)
    * match otra.responseStatus == 422
    * match otra.response.mensaje == 'Saldo insuficiente en la cuenta 20: disponible 0, solicitado 0.01.'

  # ───────────── Transferencias rechazadas ─────────────

  @negative
  Scenario Outline: Una transferencia rechazada por regla de negocio no mueve dinero: <caso>
    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And request { cuentaOrigen: '#(cuentaOrigen)', cuentaDestino: '#(cuentaDestino)', monto: '#(monto)' }
    When method post
    Then match responseStatus == codigo
    And match response == { codigo: '#(codigo)', error: '#(error)', mensaje: '#(mensaje)' }
    And match saldosActuales() == saldosIniciales

    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then match response == []

    Examples:
      | read('classpath:data/transferencias-rechazadas.json') |

  @negative
  Scenario Outline: Datos inválidos responden 422 y no mueven dinero: <caso>
    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And request payload
    When method post
    Then status 422
    And match response == read('classpath:common/schemas/datos-invalidos.json')
    And match saldosActuales() == saldosIniciales

    Examples:
      | read('classpath:data/transferencias-invalidas.json') |

  @negative
  Scenario Outline: Un payload malformado responde 400: <caso>
    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And header Content-Type = 'application/json'
    And request cuerpo
    When method post
    Then status 400
    And match response == read('classpath:common/schemas/payload-malformado.json')
    And match saldosActuales() == saldosIniciales

    Examples:
      | read('classpath:data/payloads-malformados.json') |

  @security @negative
  Scenario: Transferir sin token responde 401 y no mueve dinero
    Given path 'api', 'transferencias'
    And request cuentas.transferenciaValida
    When method post
    Then status 401
    And match header WWW-Authenticate == 'Bearer'
    And match saldosActuales() == saldosIniciales

  @security @negative
  Scenario: Transferir con un token sin permisos responde 403 y no mueve dinero
    * def sinPermisos = call read('classpath:common/login.feature') { credencialesLogin: '#(auth.credencialesSinPermisos)' }
    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sinPermisos.token
    And request cuentas.transferenciaValida
    When method post
    Then status 403
    And match response.mensaje == 'El token es válido, pero no tiene permisos sobre este recurso.'
    And match saldosActuales() == saldosIniciales

  # ───────────── Contrato ─────────────

  @contract
  Scenario: Las respuestas de cuentas y transferencias cumplen el contrato OpenAPI
    * def OpenApi = Java.type('soporte.OpenApiContrato')
    * def erroresDeContrato = function(metodo, ruta){ return OpenApi.validarRespuesta(metodo, ruta, karate.get('responseStatus'), karate.get('responseHeaders'), karate.get('responseBytes')) }

    Given path 'api', 'cuentas', 10
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then match erroresDeContrato('get', '/api/cuentas/10') == []

    Given path 'api', 'cuentas', 99
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then match erroresDeContrato('get', '/api/cuentas/99') == []

    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And request cuentas.transferenciaValida
    When method post
    Then match responseStatus == 201
    And match erroresDeContrato('post', '/api/transferencias') == []

    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    And request { cuentaOrigen: 20, cuentaDestino: 10, monto: 9999 }
    When method post
    Then match responseStatus == 422
    And match erroresDeContrato('post', '/api/transferencias') == []

    Given path 'api', 'transferencias'
    And request cuentas.transferenciaValida
    When method post
    Then match responseStatus == 401
    And match erroresDeContrato('post', '/api/transferencias') == []

    Given path 'api', 'transferencias'
    And header Authorization = 'Bearer ' + sesion.token
    When method get
    Then match erroresDeContrato('get', '/api/transferencias') == []

  # ───────────── Consistencia con la base de datos ─────────────

  @sql
  Scenario: Los saldos de la API coinciden con la tabla cuentas
    * def db = Java.type('soporte.BaseDeDatos')
    * db.inicializar()
    * def filas = db.consultar('SELECT id, usuario_id AS "usuarioId", tipo, estado, CAST(saldo AS DOUBLE PRECISION) AS saldo FROM cuentas ORDER BY id')
    * match filas == cuentas.iniciales
    * match saldosActuales() == karate.map(filas, function(f){ return f.saldo })

  @sql
  Scenario: La misma transferencia en la API y en una transacción SQL deja los mismos saldos
    * def db = Java.type('soporte.BaseDeDatos')
    * db.inicializar()
    * def t = cuentas.transferenciaValida
    * match transferir(t.cuentaOrigen, t.cuentaDestino, t.monto).responseStatus == 201
    * match db.transferir(t.cuentaOrigen, t.cuentaDestino, t.monto) == null
    * def saldosBase = karate.map(db.consultar('SELECT CAST(saldo AS DOUBLE PRECISION) AS saldo FROM cuentas ORDER BY id'), function(f){ return f.saldo })
    * match saldosActuales() == saldosBase
    # La transacción registró un retiro y un depósito, así que la conciliación se mantiene
    * match db.valor('SELECT COUNT(*) FROM movimientos') == 8
    * text descuadradas =
      """
      SELECT COUNT(*) FROM cuentas c
      WHERE c.saldo <> c.saldo_inicial
        + COALESCE((SELECT SUM(m.monto) FROM movimientos m WHERE m.cuenta_id = c.id AND m.tipo = 'deposito'), 0)
        - COALESCE((SELECT SUM(m.monto) FROM movimientos m WHERE m.cuenta_id = c.id AND m.tipo = 'retiro'), 0)
      """
    * match db.valor(descuadradas) == 0

  @sql @negative
  Scenario: Una transferencia SQL que falla hace rollback completo
    * def db = Java.type('soporte.BaseDeDatos')
    * db.inicializar()
    * def saldosBase = function(){ return karate.map(db.consultar('SELECT CAST(saldo AS DOUBLE PRECISION) AS saldo FROM cuentas ORDER BY id'), function(f){ return f.saldo }) }
    # Saldo insuficiente: el UPDATE del origen viola CHECK (saldo >= 0)
    * match db.transferir(20, 10, 250.01) == '#regex 23.*'
    # Destino cerrado: el origen ya se había descontado dentro de la transacción y el rollback lo revierte
    * match db.transferir(10, 30, 1) == '02000'
    * match saldosBase() == saldosIniciales
    * match db.valor('SELECT COUNT(*) FROM movimientos') == 6
