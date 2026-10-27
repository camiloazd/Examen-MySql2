-- Eventos Premier S.A.S. | Módulo 1: esquema relacional
-- Compatible con MySQL 8.0+. Ejecutar primero este archivo.

CREATE DATABASE IF NOT EXISTS eventos_premier_db
  CHARACTER SET utf8mb4
  COLLATE utf8mb4_0900_ai_ci;

USE eventos_premier_db;

CREATE TABLE IF NOT EXISTS salones (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    capacidad INT UNSIGNED NOT NULL,
    precio_hora DECIMAL(10,2) NOT NULL,
    estado ENUM('Disponible', 'En mantenimiento', 'Ocupado')
        NOT NULL DEFAULT 'Disponible',
    encargado_responsable VARCHAR(150) NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    actualizado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP
        ON UPDATE CURRENT_TIMESTAMP,
    CONSTRAINT chk_salones_capacidad CHECK (capacidad > 0),
    CONSTRAINT chk_salones_precio CHECK (precio_hora >= 0),
    INDEX idx_salones_estado_capacidad (estado, capacidad)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS clientes (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    nombre_completo VARCHAR(150) NOT NULL,
    identificacion VARCHAR(50) NOT NULL UNIQUE,
    telefono VARCHAR(30) NOT NULL,
    correo_electronico VARCHAR(100) NOT NULL,
    tipo_cliente ENUM('Individual', 'Corporativo') NOT NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_clientes_tipo_nombre (tipo_cliente, nombre_completo)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS reservas (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    salon_id INT UNSIGNED NOT NULL,
    cliente_id INT UNSIGNED NOT NULL,
    fecha_hora_inicio DATETIME NOT NULL,
    fecha_hora_fin DATETIME NOT NULL,
    total_horas DECIMAL(5,2) NOT NULL,
    valor_total DECIMAL(12,2) NOT NULL,
    estado_reserva ENUM('Confirmada', 'Cancelada', 'Finalizada')
        NOT NULL DEFAULT 'Confirmada',
    observaciones VARCHAR(500) NULL,
    creado_en DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    CONSTRAINT fk_reservas_salon
        FOREIGN KEY (salon_id) REFERENCES salones(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT fk_reservas_cliente
        FOREIGN KEY (cliente_id) REFERENCES clientes(id)
        ON DELETE RESTRICT ON UPDATE CASCADE,
    CONSTRAINT chk_fechas CHECK (fecha_hora_fin > fecha_hora_inicio),
    CONSTRAINT chk_total_horas CHECK (total_horas > 0),
    CONSTRAINT chk_valor_total CHECK (valor_total >= 0),
    INDEX idx_reservas_salon_fechas (salon_id, fecha_hora_inicio, fecha_hora_fin),
    INDEX idx_reservas_cliente_estado (cliente_id, estado_reserva),
    INDEX idx_reservas_inicio_estado (fecha_hora_inicio, estado_reserva)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS pagos (
    id INT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reserva_id INT UNSIGNED NOT NULL,
    fecha_pago DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    monto_pagado DECIMAL(12,2) NOT NULL,
    metodo_pago ENUM('Efectivo', 'Tarjeta', 'Transferencia') NOT NULL,
    referencia VARCHAR(100) NULL,
    observaciones VARCHAR(250) NULL,
    CONSTRAINT fk_pagos_reserva
        FOREIGN KEY (reserva_id) REFERENCES reservas(id)
        ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT chk_monto_pago CHECK (monto_pagado > 0),
    INDEX idx_pagos_reserva_fecha (reserva_id, fecha_pago)
) ENGINE=InnoDB;

CREATE TABLE IF NOT EXISTS auditoria_precios (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    salon_id INT UNSIGNED NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    precio_anterior DECIMAL(10,2) NOT NULL,
    precio_nuevo DECIMAL(10,2) NOT NULL,
    INDEX idx_auditoria_salon_fecha (salon_id, fecha_cambio)
    -- Sin FK intencionalmente: se conserva la auditoría aunque el salón se archive.
) ENGINE=InnoDB;

-- Historial de cambios de estado de reservas para trazabilidad.
CREATE TABLE IF NOT EXISTS auditoria_reservas (
    id BIGINT UNSIGNED AUTO_INCREMENT PRIMARY KEY,
    reserva_id INT UNSIGNED NOT NULL,
    estado_anterior VARCHAR(20) NOT NULL,
    estado_nuevo VARCHAR(20) NOT NULL,
    usuario VARCHAR(100) NOT NULL,
    fecha_cambio DATETIME NOT NULL DEFAULT CURRENT_TIMESTAMP,
    INDEX idx_auditoria_reserva_fecha (reserva_id, fecha_cambio)
) ENGINE=InnoDB;
