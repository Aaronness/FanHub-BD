-- ==============================================================================================
-- Universidad Central de Venezuela
-- Proyecto Fase 2: FanHub
-- Archivo: Lookups.sql
-- Descripción: Script de inicialización de datos maestros (Catálogos).
-- Instrucciones: Ejecutar este script DESPUÉS de crear las tablas y ANTES de insertar 
--                usuarios, creadores o publicaciones.
-- ==============================================================================================

USE [NombreDeSuBaseDeDatos]; -- Reemplace con el nombre real de su BD
GO

PRINT 'Iniciando carga de datos de Catálogos...';

-- ==========================================
-- 1. Inserción de CATEGORÍAS
-- ==========================================
-- Nota: Se desactiva la propiedad IDENTITY temporalmente para forzar los IDs exactos.
-- Esto es importante para mantener la integridad referencial con otras tablas que usarán estos IDs como FK.
-- No necesitan hacer esto si no les importa el orden específico de los IDs, pero es una buena práctica para datos maestros como estos.
IF OBJECT_ID('Categoria', 'U') IS NOT NULL
BEGIN
    -- Intentar encender el IDENTITY_INSERT (fallará silenciosamente si la columna no es identity, lo cual está bien)
    BEGIN TRY SET IDENTITY_INSERT Categoria ON; END TRY BEGIN CATCH END CATCH;

    INSERT INTO Categoria (id, nombre, descripcion) VALUES
    (1, 'Gaming', 'Transmisiones en vivo de videojuegos, eSports y speedruns.'),
    (2, 'Fitness', 'Rutinas de ejercicio, nutrición, dietas y bienestar físico.'),
    (3, 'Tecnología', 'Reseñas de gadgets, tutoriales de programación y software.'),
    (4, 'Arte Digital', 'Ilustraciones, diseño gráfico, modelado 3D y animación.'),
    (5, 'Música', 'Covers, composiciones originales, partituras y clases de instrumentos.'),
    (6, 'Cocina', 'Recetas paso a paso, técnicas culinarias y repostería.'),
    (7, 'Vlogs', 'Blogs en video sobre estilo de vida, moda y viajes alrededor del mundo.'),
    (8, 'Educación', 'Cursos, apoyo académico, idiomas y divulgación científica.'),
    (9, 'ASMR', 'Contenido auditivo y visual relajante (respuestas meridianas sensoriales).'),
    (10, 'Comedia', 'Sketches, stand-up, parodias y contenido humorístico en general.'),
    (11, 'Moda y Belleza', 'Maquillaje, cuidado de la piel, outfits y reseñas de productos.'),
    (12, 'Viajes', 'Turismo, guías de ciudades, mochileros y reseñas de hoteles.'),
    (13, 'Finanzas Personales', 'Inversiones, criptomonedas, ahorro y educación financiera.'),
    (14, 'Deportes', 'Análisis de partidos, noticias deportivas y entrevistas a atletas.'),
    (15, 'Cine y TV', 'Reseñas de películas, análisis de series y noticias de Hollywood.'),
    (16, 'Literatura', 'Reseñas de libros, clubes de lectura y consejos de escritura.'),
    (17, 'Manualidades', 'DIY, costura, carpintería y proyectos para el hogar.'),
    (18, 'Política y Noticias', 'Análisis de actualidad, debates y reportajes de investigación.'),
    (19, 'Mascotas', 'Adiestramiento canino, cuidados, acuarios y veterinaria básica.'),
    (20, 'Astrología y Esoterismo', 'Horóscopos, tarot, espiritualidad y meditación.'),
    (21, 'Cosplay', 'Creación de trajes, props, maquillaje FX y sesiones fotográficas temáticas.'),
    (22, 'Fotografía y Modelaje', 'Sesiones de fotos profesionales, detrás de cámaras y poses.'),
    (23, 'Anime y Manga', 'Reseñas, teorías, fan-fiction y discusión sobre cultura otaku.'),
    (24, 'Podcasts', 'Programas de audio, entrevistas, storytelling y charlas en formato episódico.');

    BEGIN TRY SET IDENTITY_INSERT Categoria OFF; END TRY BEGIN CATCH END CATCH;
    PRINT 'Catálogo [Categoria] insertado correctamente (24 registros).';
END
ELSE
BEGIN
    PRINT 'ERROR: La tabla Categoria no existe. Verifique su DDL.';
END
GO

-- ==========================================
-- 2. Inserción de TIPOS DE REACCIÓN
-- ==========================================
IF OBJECT_ID('TipoReaccion', 'U') IS NOT NULL
BEGIN
    BEGIN TRY SET IDENTITY_INSERT TipoReaccion ON; END TRY BEGIN CATCH END CATCH;

    INSERT INTO TipoReaccion (id, nombre, emoji_code) VALUES
    (1, 'Me gusta', '👍'),
    (2, 'Me encanta', '❤️'),
    (3, 'Me divierte', '😂'),
    (4, 'Fuego', '🔥'),
    (5, 'Me entristece', '😢'),
    (6, 'Me asombra', '😲'),
    (7, 'Me enfurece', '😡');

    BEGIN TRY SET IDENTITY_INSERT TipoReaccion OFF; END TRY BEGIN CATCH END CATCH;
    PRINT 'Catálogo [TipoReaccion] insertado correctamente (7 registros).';
END
ELSE
BEGIN
    PRINT 'ERROR: La tabla TipoReaccion no existe. Verifique su DDL.';
END
GO

PRINT 'Carga de Catálogos finalizada exitosamente.';
GO