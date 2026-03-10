-- =================================================
--                  STORE PROCEDURES
-- =================================================

-- Store Procedure para crear una suscripción y factura inicial
CREATE PROCEDURE sp_crear_suscripcion
    @idUsuario INT,
    @idNivel INT,
    @idMetodoPago INT
AS
BEGIN
    SET NOCOUNT ON; -- Esto evita que SQL muestre cuántas filas se afectan tras cada consulta

    BEGIN TRY
        BEGIN TRAN; -- Todo lo que hice desde aquí puede ser deshecho si ocurre un error

        -- Obtener el id del creador relacionado al nivel
        DECLARE @idCreador INT;
        SELECT @idCreador = idCreador
        FROM NivelSuscripcion
        WHERE id = @idNivel;

        -- Validar que no exista una suscripción activa para este usuario y creador
        IF EXISTS (
            SELECT N.id
            FROM Suscripcion S
            INNER JOIN NivelSuscripcion N ON S.idNivel = N.id
            WHERE S.idUsuario = @idUsuario
                  AND N.idCreador = @idCreador
                  AND S.estado = 'Activa'
        )
        BEGIN
            -- Abortamos, ya existe una suscripción activa
            RAISERROR('El usuario ya tiene una suscripción activa a este creador.', 16, 1);
            ROLLBACK TRAN; -- Se deshace todo lo hecho con bluetooth
            RETURN; -- Aquí termina el procedimiento si salió mal
        END

        -- Obtener el precio actual del nivel
        DECLARE @precio_actual DECIMAL(10,2);
        SELECT @precio_actual = precio_actual
        FROM NivelSuscripcion
        WHERE id = @idNivel;

        -- Insertar la nueva suscripción
        INSERT INTO Suscripcion (
            idUsuario, idNivel, fecha_inicio, fecha_renovacion,
            fecha_fin, estado, precio_pactado
        ) VALUES (
            @idUsuario, @idNivel, GETDATE(), NULL, NULL, 'Activa', @precio_actual
        );

        -- Obtener el ID de la suscripción creada (función para obtener el último id insertado)
        DECLARE @idSuscripcion INT = SCOPE_IDENTITY();

        -- Generar la primera factura asociada
        -- El impuesto es del 16%
        DECLARE @sub_total DECIMAL(10,2) = @precio_actual;
        DECLARE @monto_impuesto DECIMAL(10,2) = @sub_total * 0.16;
        DECLARE @monto_total DECIMAL(10,2) = @sub_total + @monto_impuesto;
        DECLARE @codigo_transaccion VARCHAR(30) = CONVERT(VARCHAR(30), NEWID()); -- Genera un código único para la transacción

        -- Inserta la factura
        INSERT INTO Factura (
            idSuscripcion, codigo_transaccion, fecha_emision,
            sub_total, monto_impuesto, monto_total
        ) VALUES (
            @idSuscripcion, @codigo_transaccion, GETDATE(),
            @sub_total, @monto_impuesto, @monto_total
        );

        COMMIT TRAN; -- Si todo salió bien, guarda los cambios en la base de datos.
    END TRY
    BEGIN CATCH
        IF @@TRANCOUNT > 0
            ROLLBACK TRAN; -- Si hubo error, regresa la base de datos a su estado previo.

        -- Captura el mensaje de error actual
        DECLARE @error NVARCHAR(4000) = ERROR_MESSAGE();
        -- Muestra el error para saber que la transacción no se pudo hacer
        THROW 51000, @error, 1;
    END CATCH
END
GO

-- =================================================
--                  FUNCIONES
-- =================================================

CREATE FUNCTION fn_calcular_impuesto(@monto DECIMAL(10,2))
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @impuesto DECIMAL(10,2);
	SET @impuesto = (16*@monto)/100;
	RETURN @impuesto;
END
GO

CREATE FUNCTION fn_clasificar_ingreso(@monto DECIMAL(10,2))
RETURNS NVARCHAR(20)
AS
BEGIN
	DECLARE @calificacion NVARCHAR(20);
	IF @monto > 1000
		SET @calificacion = 'Diamante';
	ELSE IF @monto >=500
		SET @calificacion = 'Oro';
	ELSE
		SET @calificacion = 'Plata';
	RETURN @calificacion;
END
GO

CREATE FUNCTION fn_calcular_reputacion(@idCreador INT)
RETURNS DECIMAL(10,2)
AS
BEGIN
	DECLARE @totalSuscriptores INT = 0;
	DECLARE @totalReacciones INT = 0;
	DECLARE @antiguedad INT = 0;
	DECLARE @reputacion DECIMAL(10,2);

	SELECT @totalSuscriptores = COUNT(DISTINCT(s.idUsuario))
	FROM NivelSuscripcion as n JOIN Suscripcion as s ON(n.id = s.idNivel)
	WHERE @idCreador = n.idCreador;

	SELECT @totalReacciones = COUNT(*)
	FROM UsuarioReaccionPublicacion as urp JOIN Publicacion as p ON(urp.idPublicacion = p.id)
	WHERE @idCreador = p.idCreador AND urp.fecha_reaccion >= DATEADD(MONTH, -1, GETDATE());

	SELECT @antiguedad = DATEDIFF(MONTH, u.fecha_registro, GETDATE())
	FROM Creador as c JOIN Usuario as u ON(c.idUsuario = u.id)
	WHERE @idCreador = c.idUsuario;

	SET @reputacion = (@totalSuscriptores * 0.5) + (@totalReacciones * 0.1) + (@antiguedad * 2);
	IF @reputacion > 100
		SET @reputacion = 100
	RETURN @reputacion;
END
GO

--TRUGGERS

-- Trigger 1: Auditoría de Precios (Safety)

CREATE TRIGGER tr_auditar_precio_nivel
ON NivelSuscripcion
AFTER UPDATE
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
            JOIN deleted d ON (i.id = d.id)
        WHERE ABS(i.precio_actual - d.precio_actual) > (d.precio_actual * 0.50)
    )
    BEGIN
        RAISERROR('El cambio de precio supera el 50% del precio anterior. Operación cancelada.', 16, 1);
        ROLLBACK TRAN;
    END
END
GO


-- Trigger 2: Protección de Menores (NSFW)

CREATE TRIGGER tr_proteger_menores_nsfw
ON Suscripcion
AFTER INSERT
AS
BEGIN
    SET NOCOUNT ON;

    IF EXISTS (
        SELECT 1
        FROM inserted i
            JOIN NivelSuscripcion ns ON (i.idNivel = ns.id)
            JOIN Creador c ON (ns.idCreador = c.idUsuario)
            JOIN Usuario u ON (i.idUsuario = u.id)
        WHERE c.es_nsfw = 1
          AND DATEADD(YEAR, 18, u.fecha_nacimiento) > CAST(GETDATE() AS DATE)
    )
    BEGIN
        RAISERROR('Contenido restringido por edad.', 16, 1);
        ROLLBACK TRAN;
    END
END
GO
