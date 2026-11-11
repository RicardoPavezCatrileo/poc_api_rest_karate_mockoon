@regression @sql
Feature: Preparar y validar datos de prueba con SQL

  soporte.BaseDeDatos recrea una base H2 en memoria (modo PostgreSQL) con src/test/resources/sql
  antes de cada escenario. Todas las consultas usan parámetros (?), nunca concatenación.

  Background:
    * call read('classpath:common/reset.feature')
    * url baseUrl
    * def db = Java.type('soporte.BaseDeDatos')
    * db.inicializar()

  @smoke
  Scenario: Los usuarios de la API coinciden con la tabla usuarios
    * def filas = db.consultar('SELECT id, nombre, email, rol, activo FROM usuarios ORDER BY id')
    Given path 'api', 'usuarios'
    When method get
    Then status 200
    And match response == filas

  Scenario: Preparar datos con SQL: el usuario activo con mayor saldo total se consulta en la API
    * text consulta =
      """
      SELECT u.id, u.nombre, SUM(c.saldo) AS saldo_total
      FROM usuarios u
      JOIN cuentas c ON c.usuario_id = u.id
      WHERE u.activo = TRUE AND c.estado = 'activa'
      GROUP BY u.id, u.nombre
      ORDER BY saldo_total DESC
      LIMIT 1
      """
    * def elegido = db.consultar(consulta)[0]
    * match elegido.saldo_total == 4700.50

    Given path 'api', 'usuarios', elegido.id
    When method get
    Then status 200
    And match response.nombre == elegido.nombre

  Scenario: JOIN: cuentas activas con su titular
    * text consulta =
      """
      SELECT c.id AS cuenta, u.nombre AS titular, c.tipo, c.saldo
      FROM cuentas c
      JOIN usuarios u ON u.id = c.usuario_id
      WHERE c.estado = ?
      ORDER BY c.id
      """
    * def filas = db.consultar(consulta, 'activa')
    * match filas ==
      """
      [
        { cuenta: 10, titular: 'Ana Torres', tipo: 'corriente', saldo: 1500.00 },
        { cuenta: 11, titular: 'Ana Torres', tipo: 'ahorro',    saldo: 3200.50 },
        { cuenta: 20, titular: 'Bruno Díaz', tipo: 'corriente', saldo: 250.00 }
      ]
      """

  Scenario: LEFT JOIN: usuarios sin ninguna cuenta activa
    * text consulta =
      """
      SELECT u.id, u.nombre
      FROM usuarios u
      LEFT JOIN cuentas c ON c.usuario_id = u.id AND c.estado = 'activa'
      WHERE c.id IS NULL
      ORDER BY u.id
      """
    * match db.consultar(consulta) == [{ id: 3, nombre: 'Carla Muñoz' }]

  Scenario: Agregaciones: cantidad de cuentas y saldo por usuario, con HAVING
    * text consulta =
      """
      SELECT u.nombre, COUNT(c.id) AS cuentas, SUM(c.saldo) AS saldo_total, AVG(c.saldo) AS saldo_promedio
      FROM usuarios u
      JOIN cuentas c ON c.usuario_id = u.id
      GROUP BY u.nombre
      HAVING COUNT(c.id) > 1
      """
    * def filas = db.consultar(consulta)
    * match filas == '#[1]'
    * match filas[0].nombre == 'Ana Torres'
    * match filas[0].cuentas == 2
    * match filas[0].saldo_total == 4700.50
    * match filas[0].saldo_promedio == 2350.25

  Scenario: Agregaciones: totales de movimientos por tipo
    * text consulta =
      """
      SELECT tipo, COUNT(*) AS cantidad, SUM(monto) AS total
      FROM movimientos
      GROUP BY tipo
      ORDER BY tipo
      """
    * match db.consultar(consulta) ==
      """
      [
        { tipo: 'deposito', cantidad: 2, total: 1000.50 },
        { tipo: 'retiro',   cantidad: 4, total: 650.00 }
      ]
      """

  Scenario: Conciliación: el saldo de cada cuenta coincide con saldo inicial + depósitos - retiros
    * text consulta =
      """
      SELECT c.id, c.saldo,
             c.saldo_inicial + COALESCE(SUM(CASE WHEN m.tipo = 'deposito' THEN m.monto ELSE -m.monto END), 0) AS saldo_calculado
      FROM cuentas c
      LEFT JOIN movimientos m ON m.cuenta_id = c.id
      GROUP BY c.id, c.saldo, c.saldo_inicial
      HAVING c.saldo <> c.saldo_inicial + COALESCE(SUM(CASE WHEN m.tipo = 'deposito' THEN m.monto ELSE -m.monto END), 0)
      """
    * match db.consultar(consulta) == []

  Scenario: La conciliación detecta un saldo alterado
    * match db.ejecutar('UPDATE cuentas SET saldo = saldo + ? WHERE id = ?', 1, 20) == 1
    * text consulta =
      """
      SELECT c.id
      FROM cuentas c
      LEFT JOIN movimientos m ON m.cuenta_id = c.id
      GROUP BY c.id, c.saldo, c.saldo_inicial
      HAVING c.saldo <> c.saldo_inicial + COALESCE(SUM(CASE WHEN m.tipo = 'deposito' THEN m.monto ELSE -m.monto END), 0)
      """
    * match db.consultar(consulta) == [{ id: 20 }]

  Scenario: Un usuario creado por la API se registra y se valida en la base
    Given path 'api', 'usuarios'
    And request read('classpath:data/usuarios.json').nuevo
    When method post
    Then status 201
    * def creado = response

    * def insertadas = db.ejecutar('INSERT INTO usuarios (id, nombre, email, rol, activo) VALUES (?, ?, ?, ?, ?)', creado.id, creado.nombre, creado.email, creado.rol, creado.activo)
    * match insertadas == 1
    * match db.valor('SELECT COUNT(*) FROM usuarios') == 4
    * def filas = db.consultar('SELECT id, nombre, email, rol, activo FROM usuarios WHERE id = ?', creado.id)
    * match filas == '#[1]'
    * match filas[0] == creado

  @negative
  Scenario Outline: La base rechaza datos que violan su integridad: <caso>
    * def sqlState = db.sqlStateDelError(sentencia)
    * match sqlState == '#regex 23.*'

    Examples:
      | caso                    | sentencia                                                                                          |
      | cuenta-inexistente      | INSERT INTO movimientos (id, cuenta_id, tipo, monto, fecha) VALUES (999, 77, 'deposito', 10, CURRENT_DATE) |
      | saldo-negativo          | UPDATE cuentas SET saldo = -1 WHERE id = 10                                                        |
      | email-duplicado         | INSERT INTO usuarios (id, nombre, email, rol, activo) VALUES (9, 'Otra', 'ana.torres@example.com', 'admin', TRUE) |
      | rol-desconocido         | INSERT INTO usuarios (id, nombre, email, rol, activo) VALUES (9, 'Otra', 'otra@example.com', 'root', TRUE) |
      | monto-cero              | INSERT INTO movimientos (id, cuenta_id, tipo, monto, fecha) VALUES (999, 10, 'deposito', 0, CURRENT_DATE) |

  @negative @security
  Scenario: Un intento de inyección SQL en un parámetro no altera la consulta
    * def filas = db.consultar('SELECT id FROM usuarios WHERE email = ?', "x' OR '1'='1")
    * match filas == []
    * match db.valor('SELECT COUNT(*) FROM usuarios') == 3
