-- Datos semilla ficticios. Los usuarios coinciden con los iniciales de la API (data bucket usuarios-iniciales).
INSERT INTO usuarios (id, nombre, email, rol, activo) VALUES
    (1, 'Ana Torres',  'ana.torres@example.com',  'admin',   TRUE),
    (2, 'Bruno Díaz',  'bruno.diaz@example.com',  'usuario', TRUE),
    (3, 'Carla Muñoz', 'carla.munoz@example.com', 'usuario', FALSE);

-- saldo = saldo_inicial + depósitos - retiros
INSERT INTO cuentas (id, usuario_id, tipo, estado, saldo_inicial, saldo) VALUES
    (10, 1, 'corriente', 'activa',  1000.00, 1500.00),
    (11, 1, 'ahorro',    'activa',  3000.00, 3200.50),
    (20, 2, 'corriente', 'activa',   500.00,  250.00),
    (30, 3, 'ahorro',    'cerrada',  100.00,    0.00);

INSERT INTO movimientos (id, cuenta_id, tipo, monto, fecha) VALUES
    (100, 10, 'deposito', 800.00, DATE '2026-10-01'),
    (101, 10, 'retiro',   300.00, DATE '2026-10-05'),
    (110, 11, 'deposito', 200.50, DATE '2026-10-02'),
    (200, 20, 'retiro',   150.00, DATE '2026-10-03'),
    (201, 20, 'retiro',   100.00, DATE '2026-10-07'),
    (300, 30, 'retiro',   100.00, DATE '2026-09-30');
