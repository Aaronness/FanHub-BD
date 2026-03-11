
--Consulta 1: Clasificación de Ganancias

SELECT u.nickname AS Nickname, ct.nombre AS Categoria, COUNT(DISTINCT s.idUsuario) AS [Total Suscriptores Activos], SUM(f.monto_total) AS [Monto Facturado], dbo.fn_clasificar_ingreso(SUM(f.monto_total)) AS [Clasificacion]
FROM Creador c
    JOIN Usuario u ON (c.idUsuario  = u.id)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
    JOIN NivelSuscripcion ns ON (c.idUsuario = ns.idCreador)
    JOIN Suscripcion s ON (ns.id = s.idNivel)
    JOIN Factura f ON (s.id = f.idSuscripcion)
WHERE s.estado = 'Activa' AND f.fecha_emision >= DATEADD(MONTH, -1, CAST(GETDATE() AS DATE)) AND f.fecha_emision <  CAST(GETDATE() AS DATE)
GROUP BY u.nickname, ct.nombre


-- Consulta 2: Viralidad por Categoría

WITH puntajes AS (
    SELECT p.id AS idPublicacion, p.titulo, p.idCreador, ct.id AS idCategoria, ct.nombre AS nombreCategoria, (COUNT(DISTINCT urp.idUsuario) * 1.5) + (COUNT(DISTINCT cm.id) * 3) AS puntaje
    FROM Publicacion p
        JOIN Creador c ON (p.idCreador = c.idUsuario)
        JOIN Categoria ct ON (c.idCategoria = ct.id)
        LEFT JOIN UsuarioReaccionPublicacion urp ON (p.id = urp.idPublicacion)
        LEFT JOIN Comentario cm ON (p.id = cm.idPublicacion)
    GROUP BY p.id, p.titulo, p.idCreador, ct.id, ct.nombre
)
SELECT p.nombreCategoria AS [Nombre Categoría], p.titulo AS [Título Publicacion], u.nickname AS Creador, p.puntaje AS [Puntaje Maximo]
FROM puntajes p JOIN Usuario u ON (p.idCreador = u.id)
WHERE p.puntaje = (
    SELECT MAX(pt.puntaje)
    FROM puntajes pt
    WHERE pt.idCategoria = p.idCategoria)


-- Consulta 3: Análisis de Dominios de Correo

SELECT SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, LEN(u.email)) AS Dominio, COUNT(*) AS [Cantidad Usuarios]
FROM Usuario u
GROUP BY SUBSTRING(u.email, CHARINDEX('@', u.email) + 1, LEN(u.email))
HAVING COUNT(*) > 10


-- Consulta 4: Promedio de Retención

SELECT u.nickname AS [Nickname Creador], ns.nombre AS [Nombre Nivel], AVG(DATEDIFF(DAY, s.fecha_inicio, s.fecha_fin)) AS [Promedio Dias]
FROM Suscripcion s
    JOIN NivelSuscripcion ns ON (s.idNivel = ns.id)
    JOIN Creador c ON (ns.idCreador = c.idUsuario)
    JOIN Usuario u ON (c.idUsuario = u.id)
WHERE s.estado = 'Cancelada' AND s.fecha_fin IS NOT NULL
GROUP BY u.nickname, ns.nombre, ns.orden
ORDER BY ns.orden ASC;


-- Consulta 5: Tiempo y Peso de Contenido (Gaming)

SELECT u.nickname AS Nickname, CAST(SUM(v.duracion_seg) / 3600 AS VARCHAR) + 'h ' + CAST((SUM(v.duracion_seg) % 3600) / 60 AS VARCHAR) + 'm' AS [Tiempo Total Formateado],
       CAST(SUM(
           CASE v.resolucion
               WHEN '4K'    THEN (v.duracion_seg / 60.0) * 0.5
               WHEN '1080p' THEN (v.duracion_seg / 60.0) * 0.1
               ELSE              (v.duracion_seg / 60.0) * 0.05
           END
       ) AS DECIMAL(10,2)) AS [Estimacion GB]
FROM Video v
    JOIN Publicacion p ON (v.idPublicacion = p.id)
    JOIN Creador c ON (p.idCreador = c.idUsuario)
    JOIN Usuario u ON (c.idUsuario = u.id)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
WHERE ct.nombre = 'Gaming'
GROUP BY u.nickname


-- Consulta 6: Mapa de Calor Financiero

WITH total_global AS (
    SELECT SUM(monto_total) AS total
    FROM Factura
)
SELECT u.pais AS País, SUM(f.monto_total) AS [Total Facturado], CAST(SUM(f.monto_total) * 100.0 / tg.total AS DECIMAL(10,2)) AS [Share %]
FROM Factura f
    JOIN Suscripcion s ON (f.idSuscripcion = s.id)
    JOIN Usuario u ON (s.idUsuario = u.id)
    JOIN total_global tg ON (1 = 1)
GROUP BY u.pais, tg.total


-- Consulta 7: Intereses Cruzados

SELECT u.nickname AS Nickname, SUM(f.monto_total) AS [Gasto Total Histórico]
FROM Usuario u
    JOIN Suscripcion s ON (u.id = s.idUsuario)
    JOIN NivelSuscripcion ns ON (s.idNivel = ns.id)
    JOIN Creador c ON (ns.idCreador = c.idUsuario)
    JOIN Categoria ct ON (c.idCategoria = ct.id)
    JOIN Factura f ON (s.id = f.idSuscripcion)
WHERE u.id IN (
    SELECT s2.idUsuario
    FROM Suscripcion s2
        JOIN NivelSuscripcion ns2 ON (s2.idNivel = ns2.id)
        JOIN Creador c2 ON (ns2.idCreador = c2.idUsuario)
        JOIN Categoria ct2 ON (c2.idCategoria = ct2.id)
    WHERE ct2.nombre = 'Tecnología'
    INTERSECT
    SELECT s3.idUsuario
    FROM Suscripcion s3
        JOIN NivelSuscripcion ns3 ON (s3.idNivel = ns3.id)
        JOIN Creador c3 ON (ns3.idCreador = c3.idUsuario)
        JOIN Categoria ct3 ON (c3.idCategoria = ct3.id)
    WHERE ct3.nombre = 'Fitness'
)
GROUP BY u.nickname
HAVING SUM(f.monto_total) > 140


-- Consulta 8: Generaciones

SELECT
    CASE
        WHEN YEAR(u.fecha_nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(u.fecha_nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'X'
    END AS Generación,
    COUNT(DISTINCT u.id) AS [Cantidad Usuarios Activos], CAST(SUM(f.monto_total) / COUNT(DISTINCT MONTH(f.fecha_emision)) AS DECIMAL(10,2)) AS [Gasto Promedio Mensual]
FROM Usuario u
    JOIN Suscripcion s ON (u.id = s.idUsuario)
    JOIN Factura f ON (s.id = f.idSuscripcion)
WHERE u.esta_activo = 1
GROUP BY
    CASE
        WHEN YEAR(u.fecha_nacimiento) > 2000 THEN 'Gen Z'
        WHEN YEAR(u.fecha_nacimiento) BETWEEN 1981 AND 2000 THEN 'Millennials'
        ELSE 'X'
    END
-- Consulta 9: Creadores Polémicos
-- Listar Creadores con un promedio de ratio (Comentarios / Reacciones) > 2.0.
-- Columnas a mostrar: Nickname, Cantidad Posts Evaluados, Ratio Promedio. 

WITH EstadisticasPorPost AS (
    SELECT 
        p.id AS idPublicacion,
        p.idCreador,
        CAST(COUNT(DISTINCT c.id) AS DECIMAL(10,2)) AS TotalComentarios,
        CAST(COUNT(DISTINCT urp.idUsuario) AS DECIMAL(10,2)) AS TotalReacciones
    FROM Publicacion p
    LEFT JOIN Comentario c ON p.id = c.idPublicacion
    LEFT JOIN UsuarioReaccionPublicacion urp ON p.id = urp.idPublicacion
    GROUP BY p.id, p.idCreador
),
RatiosPorPost AS (
    SELECT idCreador,idPublicacion,
        -- Si no hay reacciones, el ratio se asume como el total de comentarios 
        -- para evitar división por cero, o 0 si no hay ninguno.
        CASE 
            WHEN TotalReacciones = 0 THEN TotalComentarios 
            ELSE (TotalComentarios / TotalReacciones) 
        END AS Ratio
    FROM EstadisticasPorPost
)
SELECT 
    u.nickname AS Nickname,
    COUNT(r.idPublicacion) AS [Cantidad Posts Evaluados],
    CAST(AVG(r.Ratio) AS DECIMAL(10,2)) AS [Ratio Promedio]

FROM RatiosPorPost r JOIN Usuario u ON r.idCreador = u.id
GROUP BY u.id, u.nickname
HAVING AVG(r.Ratio) > 2.0
ORDER BY [Ratio Promedio] DESC;

-- Consulta 10: Ranking de Creadores (Reputación)
-- Se listan los creadores multimedia (video/imagen) que nunca han publicado contenido nsfw
-- Ordenado descendientemente por reputacion y en caso de empate por cantidad de suscriptores

-- CTE para calcular el total de suscriptores por creador multimedia (video/imagen)
WITH ConteoSuscriptores AS (
    SELECT ns.idCreador, COUNT(DISTINCT s.idUsuario) AS TotalSuscriptores
    FROM NivelSuscripcion AS ns JOIN Suscripcion AS s ON ns.id = s.idNivel
    WHERE s.estado = 'Activa'
    GROUP BY ns.idCreador
)
SELECT u.nickname AS Nickname, ISNULL(cs.TotalSuscriptores, 0) AS TotalSuscriptores, 
       dbo.fn_calcular_reputacion(c.idUsuario) AS Reputacion
FROM Creador AS c JOIN Usuario AS u ON c.idUsuario = u.id
     LEFT JOIN ConteoSuscriptores AS cs ON c.idUsuario = cs.idCreador
WHERE c.es_nsfw = 0 AND c.idUsuario IN (SELECT idCreador FROM Publicacion WHERE tipo_contenido IN ('VIDEO', 'IMAGEN'))
ORDER BY Reputacion DESC, TotalSuscriptores DESC -- Se ordena por suscriptores como criterio de desempate

-- Consulta 11: Usuarios "Lurkers": Usuarios con suscripción activa pero sin ninguna interacción (comentario/reacción).
-- Columnas a mostrar: Nickname, Fecha Última Suscripción, Monto Gastado (Estimado).

SELECT u.nickname AS Nickname, MAX(s.fecha_inicio) AS FechaUltimaSuscripcion, ISNULL(SUM(f.monto_total), 0) AS MontoGastado
FROM Usuario AS u JOIN Suscripcion AS s ON u.id = s.idUsuario JOIN Factura AS f ON s.id = f.idSuscripcion
WHERE s.estado = 'Activa' AND NOT EXISTS (
      SELECT 1 
      FROM UsuarioReaccionPublicacion urp 
      WHERE urp.idUsuario = u.id
  )
  AND NOT EXISTS (
      SELECT 1 
      FROM Comentario cm 
      WHERE cm.idUsuario = u.id
  )
GROUP BY u.nickname;

-- Consulta 12: Tendencias (Tags)
-- Top 3 etiquetas más usadas el último mes.
-- Columnas a mostrar: Nombre Etiqueta, Cantidad Publicaciones.

SELECT TOP 3 e.nombre AS [Nombre Etiqueta], COUNT(pe.idPublicacion) AS [Cantidad Publicaciones]
FROM Etiqueta e
JOIN PublicacionEtiqueta pe ON e.id = pe.idEtiqueta
JOIN Publicacion p ON pe.idPublicacion = p.id
-- Filtro para el último mes (30 días)
WHERE p.fecha_publicacion >= DATEADD(MONTH, -1, GETDATE())
GROUP BY e.nombre
ORDER BY [Cantidad Publicaciones] DESC;

-- Consulta 13: Cobertura Total de Reacciones
-- Usuarios que han usado todos los tipos de reacción del catálogo.
-- Columnas a mostrar: Nickname, Total Reacciones Realizadas.

SELECT u.nickname AS Nickname, COUNT(urp.idTipoReaccion) AS [Total Reacciones Realizadas]

FROM Usuario u JOIN UsuarioReaccionPublicacion urp ON u.id = urp.idUsuario

GROUP BY u.id, u.nickname
HAVING COUNT(DISTINCT urp.idTipoReaccion) = (SELECT COUNT(*) FROM TipoReaccion)
ORDER BY [Total Reacciones Realizadas] DESC;


-- Consulta 14: Reporte de Nómina (Liquidación): 
-- Generar el listado de pagos a realizar a los creadores correspondiente al mes actual. 
-- La plataforma cobra una comisión del 20% sobre el total facturado.
-- Columnas a mostrar: Nombre Banco, Cuenta Bancaria, Beneficiario (Nickname), 
-- Total Facturado (Bruto), Comisión FanHub, Monto a Transferir (Neto).

SELECT c.banco_nombre AS NombreBanco, c.banco_cuenta AS CuentaBancaria, u.nickname AS Beneficiario, SUM(f.monto_total) AS TotalFacturadoBruto,
       CAST(SUM(f.monto_total) * 0.20 AS DECIMAL(10,2)) AS ComisionFanHub, 
       CAST(SUM(f.monto_total) * 0.80 AS DECIMAL(10,2)) AS MontoTransferirNeto
FROM Usuario AS u JOIN Creador AS c ON u.id = c.idUsuario JOIN NivelSuscripcion AS ns ON c.idUsuario = ns.idCreador
     JOIN Suscripcion AS s ON ns.id = s.idNivel JOIN Factura AS f ON s.id = f.idSuscripcion
WHERE s.estado = 'Activa' AND f.fecha_emision >=DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1) -- inicio mes actual
      AND f.fecha_emision <  DATEADD(MONTH, 1, DATEFROMPARTS(YEAR(GETDATE()), MONTH(GETDATE()), 1)) -- inicio próximo mes
GROUP BY c.banco_nombre, c.banco_cuenta, u.nickname
ORDER BY u.nickname;