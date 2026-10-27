-- Eventos Premier S.A.S. | Módulo 3: triggers y auditoría
USE eventos_premier_db;

DROP TRIGGER IF EXISTS actualizar_estado_salon_trigger;
DROP TRIGGER IF EXISTS liberar_salon_trigger;
DROP TRIGGER IF EXISTS auditoria_precios_trigger;
DROP TRIGGER IF EXISTS auditoria_estado_reserva_trigger;

DELIMITER //

CREATE TRIGGER actualizar_estado_salon_trigger
AFTER INSERT ON reservas
FOR EACH ROW
BEGIN
    -- Cumple el requisito del ejercicio: una reserva nueva marca el salón ocupado.
    UPDATE salones
       SET estado = 'Ocupado'
     WHERE id = NEW.salon_id
       AND estado <> 'En mantenimiento';
END//

CREATE TRIGGER liberar_salon_trigger
AFTER DELETE ON reservas
FOR EACH ROW
BEGIN
    -- Solo libera el salón si no quedan reservas confirmadas asociadas.
    IF NOT EXISTS (
        SELECT 1
          FROM reservas
         WHERE salon_id = OLD.salon_id
           AND estado_reserva = 'Confirmada'
    ) THEN
        UPDATE salones
           SET estado = 'Disponible'
         WHERE id = OLD.salon_id
           AND estado <> 'En mantenimiento';
    END IF;
END//

CREATE TRIGGER auditoria_precios_trigger
BEFORE UPDATE ON salones
FOR EACH ROW
BEGIN
    IF OLD.precio_hora <> NEW.precio_hora THEN
        INSERT INTO auditoria_precios
            (salon_id, usuario, fecha_cambio, precio_anterior, precio_nuevo)
        VALUES
            (OLD.id, USER(), CURRENT_TIMESTAMP, OLD.precio_hora, NEW.precio_hora);
    END IF;
END//

CREATE TRIGGER auditoria_estado_reserva_trigger
AFTER UPDATE ON reservas
FOR EACH ROW
BEGIN
    IF OLD.estado_reserva <> NEW.estado_reserva THEN
        INSERT INTO auditoria_reservas
            (reserva_id, estado_anterior, estado_nuevo, usuario, fecha_cambio)
        VALUES
            (OLD.id, OLD.estado_reserva, NEW.estado_reserva, USER(), CURRENT_TIMESTAMP);
    END IF;
END//

DELIMITER ;
