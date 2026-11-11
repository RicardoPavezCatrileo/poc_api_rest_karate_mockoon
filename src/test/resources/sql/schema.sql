-- Esquema de laboratorio: usuarios (los mismos de la API), sus cuentas y los movimientos de cada cuenta.
DROP TABLE IF EXISTS movimientos;
DROP TABLE IF EXISTS cuentas;
DROP TABLE IF EXISTS usuarios;

CREATE TABLE usuarios (
    id      INTEGER      PRIMARY KEY,
    nombre  VARCHAR(100) NOT NULL,
    email   VARCHAR(150) NOT NULL UNIQUE,
    rol     VARCHAR(20)  NOT NULL CHECK (rol IN ('admin', 'supervisor', 'usuario')),
    activo  BOOLEAN      NOT NULL
);

CREATE TABLE cuentas (
    id             INTEGER       PRIMARY KEY,
    usuario_id     INTEGER       NOT NULL REFERENCES usuarios (id),
    tipo           VARCHAR(20)   NOT NULL CHECK (tipo IN ('corriente', 'ahorro')),
    estado         VARCHAR(20)   NOT NULL CHECK (estado IN ('activa', 'cerrada')),
    saldo_inicial  NUMERIC(12, 2) NOT NULL,
    saldo          NUMERIC(12, 2) NOT NULL CHECK (saldo >= 0)
);

CREATE TABLE movimientos (
    id         INTEGER        PRIMARY KEY,
    cuenta_id  INTEGER        NOT NULL REFERENCES cuentas (id),
    tipo       VARCHAR(20)    NOT NULL CHECK (tipo IN ('deposito', 'retiro')),
    monto      NUMERIC(12, 2) NOT NULL CHECK (monto > 0),
    fecha      DATE           NOT NULL
);
