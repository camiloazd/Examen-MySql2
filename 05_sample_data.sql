-- Datos de demostración. Ejecutar después de los módulos 01, 02 y 03.
USE eventos_premier_db;

INSERT INTO salones (nombre, capacidad, precio_hora, estado, encargado_responsable)
VALUES
('Gran Salón Premier', 180, 250000.00, 'Disponible', 'Laura Méndez'),
('Salón Jardín', 80, 160000.00, 'Disponible', 'Carlos Rojas'),
('Sala Ejecutiva', 30, 95000.00, 'Disponible', 'Diana Torres')
ON DUPLICATE KEY UPDATE nombre = VALUES(nombre);

INSERT INTO clientes
(nombre_completo, identificacion, telefono, correo_electronico, tipo_cliente)
VALUES
('María Fernanda Gómez', 'CC-DEMO-1001', '3001112233', 'maria.demo@example.com', 'Individual'),
('Corporación Andina Demo', 'NIT-DEMO-9001', '6015550101', 'eventos@example.com', 'Corporativo'),
('Servicios del Oriente Demo', 'NIT-DEMO-9002', '6075550101', 'reservas@example.com', 'Corporativo')
ON DUPLICATE KEY UPDATE nombre_completo = VALUES(nombre_completo);

-- Ejemplo de función:
SELECT calcular_total_reserva(160000.00, 3.00) AS total_con_iva;

-- Ejemplo de disponibilidad:
SELECT verificar_disponibilidad(1, '2026-12-10 09:00:00', '2026-12-10 12:00:00')
       AS salon_disponible;
