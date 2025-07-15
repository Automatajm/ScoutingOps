--
-- PostgreSQL database dump
--

-- Dumped from database version 17.5
-- Dumped by pg_dump version 17.5

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: public; Type: SCHEMA; Schema: -; Owner: pestuser
--

-- *not* creating schema, since initdb creates it


ALTER SCHEMA public OWNER TO pestuser;

--
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: pestuser
--

COMMENT ON SCHEMA public IS '';


--
-- Name: sp_check_rol_in_use(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_check_rol_in_use(rol_id integer) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    usuario_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO usuario_count
    FROM pm_usuarios
    WHERE pmus_funcion = rol_id
    LIMIT 1;
    
    RETURN usuario_count > 0;
END;
$$;


ALTER FUNCTION public.sp_check_rol_in_use(rol_id integer) OWNER TO pestuser;

--
-- Name: sp_create_lote(character varying, character varying, integer, integer, integer, character varying, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_lote(p_codigo character varying, p_canteros character varying DEFAULT NULL::character varying, p_cantidad integer DEFAULT 0, p_estatus integer DEFAULT 1, p_idvariedad integer DEFAULT NULL::integer, p_contenedor character varying DEFAULT NULL::character varying, p_grower character varying DEFAULT NULL::character varying, p_variedad character varying DEFAULT NULL::character varying, p_casa character varying DEFAULT NULL::character varying, p_creadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message text, lote_data json)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_code_exists BOOLEAN;
    v_nuevo_lote pm_lotes%ROWTYPE;
BEGIN
    -- Validar campos obligatorios
    IF p_codigo IS NULL OR p_codigo = '' THEN
        RETURN QUERY
        SELECT false, 'El código del lote es obligatorio', NULL::JSON;
        RETURN;
    END IF;
    
    -- Verificar si ya existe un lote con el mismo código
    SELECT EXISTS(
        SELECT 1 FROM pm_lotes WHERE pmlt_codigo = p_codigo
    ) INTO v_code_exists;
    
    IF v_code_exists THEN
        RETURN QUERY
        SELECT false, 'Ya existe un lote con ese código', NULL::JSON;
        RETURN;
    END IF;
    
    -- Insertar nuevo lote
    INSERT INTO pm_lotes (
        pmlt_codigo,
        pmlt_canteros,
        pmlt_cantidad,
        pmlt_estatus,
        pmlt_idvariedad,
        pmlt_contenedor,
        pmlt_grower,
        pmlt_variedad,
        pmlt_casa,
        pmlt_creadopor,
        pmlt_fechacreacion
    ) VALUES (
        p_codigo,
        p_canteros,
        p_cantidad,
        p_estatus,
        p_idvariedad,
        p_contenedor,
        p_grower,
        p_variedad,
        p_casa,
        p_creadopor,
        NOW()
    ) RETURNING * INTO v_nuevo_lote;
    
    -- Retornar éxito con objeto JSON del lote creado
    RETURN QUERY
    SELECT 
        true, 
        'Lote creado exitosamente', 
        row_to_json(v_nuevo_lote)::JSON;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM, NULL::JSON;
END;
$$;


ALTER FUNCTION public.sp_create_lote(p_codigo character varying, p_canteros character varying, p_cantidad integer, p_estatus integer, p_idvariedad integer, p_contenedor character varying, p_grower character varying, p_variedad character varying, p_casa character varying, p_creadopor integer) OWNER TO pestuser;

--
-- Name: sp_create_monitoreo(character varying, character varying, character varying, character varying, character varying, integer, character varying, character varying, character varying, integer, text, timestamp without time zone, boolean, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_monitoreo(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_canteros character varying DEFAULT NULL::character varying, p_pmmo_idvariedad character varying DEFAULT NULL::character varying, p_pmmo_grower character varying DEFAULT NULL::character varying, p_pmmo_cant_botada integer DEFAULT NULL::integer, p_pmmo_comentarios text DEFAULT NULL::text, p_pmmo_fecha timestamp without time zone DEFAULT NULL::timestamp without time zone, p_pmmo_automatico boolean DEFAULT true, p_pmmo_estatus integer DEFAULT 1, p_pmmo_creadopor integer DEFAULT 1, p_pmmo_nivmuestram1 integer DEFAULT NULL::integer, p_pmmo_nivmuestram2 integer DEFAULT NULL::integer, p_pmmo_nivmuestram3 integer DEFAULT NULL::integer, p_pmmo_nivmuestraa1 integer DEFAULT NULL::integer, p_pmmo_nivmuestraa2 integer DEFAULT NULL::integer, p_pmmo_nivmuestraa3 integer DEFAULT NULL::integer, p_pmmo_muestra1 integer DEFAULT NULL::integer, p_pmmo_muestra2 integer DEFAULT NULL::integer, p_pmmo_muestra3 integer DEFAULT NULL::integer, p_pmmo_contenedor character varying DEFAULT 'CONT_GENERAL'::character varying) RETURNS TABLE(success boolean, message character varying, monitoreo_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_plaga_id INT;
  v_monitoreo_id INT;
  v_exists BOOLEAN;
BEGIN
  -- Validar campos obligatorios
  IF p_pmlt_codigo IS NULL OR p_pmmo_casa IS NULL OR p_pmmo_cantero IS NULL OR 
     p_pmmo_variedad IS NULL OR p_pmni_nombrecomun IS NULL OR p_pmmo_cantidad IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Los campos código de lote, casa, cantero, variedad, plaga y cantidad son obligatorios'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar que el lote exista
  SELECT EXISTS (
    SELECT 1 FROM pm_lotes WHERE pmlt_codigo = p_pmlt_codigo
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'El lote con código ' || p_pmlt_codigo || ' no existe'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Obtener ID de la plaga
  SELECT pmpl_id INTO v_plaga_id
  FROM pm_plagas
  WHERE pmpl_nombrecomun = p_pmni_nombrecomun;
  
  IF v_plaga_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'No se encontró la plaga con nombre: ' || p_pmni_nombrecomun::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Insertar el nuevo monitoreo
  INSERT INTO pm_monitoreos (
    pmlt_codigo,
    pmmo_casa,
    pmmo_cantero,
    pmmo_canteros,
    pmmo_variedad,
    pmmo_idvariedad,
    pmmo_grower,
    pmni_id,
    pmmo_cantidad,
    pmmo_cant_botada,
    pmmo_comentarios,
    pmmo_fecha,
    pmmo_automatico,
    pmmo_estatus,
    pmmo_creadopor,
    pmmo_fechacreacion,
    pmmo_nivmuestram1,
    pmmo_nivmuestram2,
    pmmo_nivmuestram3,
    pmmo_nivmuestraa1,
    pmmo_nivmuestraa2,
    pmmo_nivmuestraa3,
    pmmo_muestra1,
    pmmo_muestra2,
    pmmo_muestra3,
    pmmo_contenedor
  ) VALUES (
    p_pmlt_codigo,
    p_pmmo_casa,
    p_pmmo_cantero,
    COALESCE(p_pmmo_canteros, p_pmmo_cantero),
    p_pmmo_variedad,
    COALESCE(p_pmmo_idvariedad, p_pmmo_variedad),
    p_pmmo_grower,
    v_plaga_id,
    p_pmmo_cantidad,
    p_pmmo_cant_botada,
    p_pmmo_comentarios,
    COALESCE(p_pmmo_fecha, NOW()),
    p_pmmo_automatico,
    p_pmmo_estatus,
    p_pmmo_creadopor,
    NOW(),
    p_pmmo_nivmuestram1,
    p_pmmo_nivmuestram2,
    p_pmmo_nivmuestram3,
    p_pmmo_nivmuestraa1,
    p_pmmo_nivmuestraa2,
    p_pmmo_nivmuestraa3,
    p_pmmo_muestra1,
    p_pmmo_muestra2,
    p_pmmo_muestra3,
    COALESCE(p_pmmo_contenedor, 'CONT_GENERAL')
  ) RETURNING pmmo_secuencia INTO v_monitoreo_id;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Monitoreo creado exitosamente'::VARCHAR, v_monitoreo_id;
END;
$$;


ALTER FUNCTION public.sp_create_monitoreo(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_estatus integer, p_pmmo_creadopor integer, p_pmmo_nivmuestram1 integer, p_pmmo_nivmuestram2 integer, p_pmmo_nivmuestram3 integer, p_pmmo_nivmuestraa1 integer, p_pmmo_nivmuestraa2 integer, p_pmmo_nivmuestraa3 integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_contenedor character varying) OWNER TO pestuser;

--
-- Name: FUNCTION sp_create_monitoreo(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_estatus integer, p_pmmo_creadopor integer, p_pmmo_nivmuestram1 integer, p_pmmo_nivmuestram2 integer, p_pmmo_nivmuestram3 integer, p_pmmo_nivmuestraa1 integer, p_pmmo_nivmuestraa2 integer, p_pmmo_nivmuestraa3 integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_contenedor character varying); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_create_monitoreo(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_estatus integer, p_pmmo_creadopor integer, p_pmmo_nivmuestram1 integer, p_pmmo_nivmuestram2 integer, p_pmmo_nivmuestram3 integer, p_pmmo_nivmuestraa1 integer, p_pmmo_nivmuestraa2 integer, p_pmmo_nivmuestraa3 integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_contenedor character varying) IS 'Función para crear un nuevo monitoreo.';


--
-- Name: sp_create_monitoreo_con_niveles(character varying, character varying, character varying, character varying, character varying, integer, integer, integer, integer, character varying, character varying, character varying, integer, text, timestamp without time zone, boolean, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_monitoreo_con_niveles(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_canteros character varying DEFAULT NULL::character varying, p_pmmo_idvariedad character varying DEFAULT NULL::character varying, p_pmmo_grower character varying DEFAULT NULL::character varying, p_pmmo_cant_botada integer DEFAULT NULL::integer, p_pmmo_comentarios text DEFAULT NULL::text, p_pmmo_fecha timestamp without time zone DEFAULT NULL::timestamp without time zone, p_pmmo_automatico boolean DEFAULT true, p_pmmo_creadopor integer DEFAULT 1, p_pmmo_contenedor character varying DEFAULT 'CONT_GENERAL'::character varying) RETURNS TABLE(success boolean, message character varying, monitoreo_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_plaga_id INT;
  v_monitoreo_id INT;
  v_exists BOOLEAN;
  v_nivel1 INT := NULL;
  v_nivel2 INT := NULL;
  v_nivel3 INT := NULL;
BEGIN
  -- Validar campos obligatorios
  IF p_pmlt_codigo IS NULL OR p_pmmo_casa IS NULL OR p_pmmo_cantero IS NULL OR 
     p_pmmo_variedad IS NULL OR p_pmni_nombrecomun IS NULL OR p_pmmo_cantidad IS NULL OR
     p_pmmo_muestra1 IS NULL OR p_pmmo_muestra2 IS NULL OR p_pmmo_muestra3 IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Faltan campos obligatorios para el cálculo automático de niveles'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar que el lote exista
  SELECT EXISTS (
    SELECT 1 FROM pm_lotes WHERE pmlt_codigo = p_pmlt_codigo
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'El lote con código ' || p_pmlt_codigo || ' no existe'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Obtener ID de la plaga
  SELECT pmpl_id INTO v_plaga_id
  FROM pm_plagas
  WHERE pmpl_nombrecomun = p_pmni_nombrecomun;
  
  IF v_plaga_id IS NULL THEN
    RETURN QUERY SELECT FALSE, 'No se encontró la plaga con nombre: ' || p_pmni_nombrecomun::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Determinar el nivel para cada muestra según los límites
  -- Nivel 1
  SELECT 
    CASE 
      WHEN p_pmmo_muestra1 <= MAX(pmni_lmsuperior) THEN 1
      ELSE NULL
    END INTO v_nivel1
  FROM pm_nivelesinfestacion
  WHERE pmni_plaga = v_plaga_id AND pmni_nivel = 1;
  
  -- Nivel 2
  SELECT 
    CASE 
      WHEN p_pmmo_muestra1 > MAX(n1.pmni_lmsuperior) AND p_pmmo_muestra1 <= MAX(n2.pmni_lmsuperior) THEN 2
      ELSE NULL
    END INTO v_nivel2
  FROM pm_nivelesinfestacion n1, pm_nivelesinfestacion n2
  WHERE n1.pmni_plaga = v_plaga_id AND n1.pmni_nivel = 1
    AND n2.pmni_plaga = v_plaga_id AND n2.pmni_nivel = 2;
  
  -- Nivel 3
  SELECT 
    CASE 
      WHEN p_pmmo_muestra1 > MAX(pmni_lmsuperior) THEN 3
      ELSE NULL
    END INTO v_nivel3
  FROM pm_nivelesinfestacion
  WHERE pmni_plaga = v_plaga_id AND pmni_nivel = 2;
  
  -- Si no se pudo determinar ningún nivel, usar el más alto
  IF v_nivel1 IS NULL AND v_nivel2 IS NULL AND v_nivel3 IS NULL THEN
    v_nivel1 := 3;
    v_nivel2 := 3;
    v_nivel3 := 3;
  ELSE
    -- Si algún nivel no se pudo determinar, usar valores calculados o valores por defecto
    v_nivel1 := COALESCE(v_nivel1, 
                 CASE WHEN p_pmmo_muestra1 <= p_pmmo_muestra2 AND p_pmmo_muestra1 <= p_pmmo_muestra3 THEN 1
                      WHEN p_pmmo_muestra1 >= p_pmmo_muestra2 AND p_pmmo_muestra1 >= p_pmmo_muestra3 THEN 3
                      ELSE 2 END);
    
    v_nivel2 := COALESCE(v_nivel2, 
                 CASE WHEN p_pmmo_muestra2 <= p_pmmo_muestra1 AND p_pmmo_muestra2 <= p_pmmo_muestra3 THEN 1
                      WHEN p_pmmo_muestra2 >= p_pmmo_muestra1 AND p_pmmo_muestra2 >= p_pmmo_muestra3 THEN 3
                      ELSE 2 END);
    
    v_nivel3 := COALESCE(v_nivel3, 
                 CASE WHEN p_pmmo_muestra3 <= p_pmmo_muestra1 AND p_pmmo_muestra3 <= p_pmmo_muestra2 THEN 1
                      WHEN p_pmmo_muestra3 >= p_pmmo_muestra1 AND p_pmmo_muestra3 >= p_pmmo_muestra2 THEN 3
                      ELSE 2 END);
  END IF;
  
  -- Insertar el monitoreo con los niveles calculados
  INSERT INTO pm_monitoreos (
    pmlt_codigo,
    pmmo_casa,
    pmmo_cantero,
    pmmo_canteros,
    pmmo_variedad,
    pmmo_idvariedad,
    pmmo_grower,
    pmni_id,
    pmmo_cantidad,
    pmmo_cant_botada,
    pmmo_comentarios,
    pmmo_fecha,
    pmmo_automatico,
    pmmo_estatus,
    pmmo_creadopor,
    pmmo_fechacreacion,
    pmmo_nivmuestram1,
    pmmo_nivmuestram2,
    pmmo_nivmuestram3,
    pmmo_nivmuestraa1,
    pmmo_nivmuestraa2,
    pmmo_nivmuestraa3,
    pmmo_muestra1,
    pmmo_muestra2,
    pmmo_muestra3,
    pmmo_contenedor
  ) VALUES (
    p_pmlt_codigo,
    p_pmmo_casa,
    p_pmmo_cantero,
    COALESCE(p_pmmo_canteros, p_pmmo_cantero),
    p_pmmo_variedad,
    COALESCE(p_pmmo_idvariedad, p_pmmo_variedad),
    p_pmmo_grower,
    v_plaga_id,
    p_pmmo_cantidad,
    p_pmmo_cant_botada,
    p_pmmo_comentarios,
    COALESCE(p_pmmo_fecha, NOW()),
    p_pmmo_automatico,
    1, -- estatus activo
    p_pmmo_creadopor,
    NOW(),
    v_nivel1,
    v_nivel2,
    v_nivel3,
    v_nivel1,
    v_nivel2,
    v_nivel3,
    p_pmmo_muestra1,
    p_pmmo_muestra2,
    p_pmmo_muestra3,
    COALESCE(p_pmmo_contenedor, 'CONT_GENERAL')
  ) RETURNING pmmo_secuencia INTO v_monitoreo_id;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Monitoreo con niveles automáticos creado exitosamente'::VARCHAR, v_monitoreo_id;
END;
$$;


ALTER FUNCTION public.sp_create_monitoreo_con_niveles(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_creadopor integer, p_pmmo_contenedor character varying) OWNER TO pestuser;

--
-- Name: FUNCTION sp_create_monitoreo_con_niveles(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_creadopor integer, p_pmmo_contenedor character varying); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_create_monitoreo_con_niveles(p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_variedad character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_canteros character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_creadopor integer, p_pmmo_contenedor character varying) IS 'Función para crear un monitoreo con cálculo automático de niveles.';


--
-- Name: sp_create_nivel(integer, integer, character varying, character varying, integer, integer, character varying, text, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_nivel(p_nivel integer, p_plaga integer, p_nombrecomun character varying, p_rango character varying, p_lminferior integer DEFAULT 0, p_lmsuperior integer DEFAULT 0, p_tipoobservacion character varying DEFAULT NULL::character varying, p_observacion text DEFAULT NULL::text, p_cintaidentificadora character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT 1, p_creadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, nivel_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_secuencia INT;
  v_exists BOOLEAN;
BEGIN
  -- Validaciones básicas
  IF p_nivel IS NULL OR p_plaga IS NULL OR p_nombrecomun IS NULL OR p_rango IS NULL THEN
    RETURN QUERY SELECT FALSE, 'Nivel, plaga, nombre común y rango son obligatorios'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar si la plaga existe
  SELECT EXISTS (
    SELECT 1 FROM pm_plagas WHERE pmpl_id = p_plaga
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'La plaga especificada no existe'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar si ya existe un nivel similar para esta plaga
  SELECT EXISTS (
    SELECT 1 
    FROM pm_nivelesinfestacion 
    WHERE pmni_plaga = p_plaga AND pmni_nivel = p_nivel AND pmni_estatus = 1
  ) INTO v_exists;
  
  IF v_exists THEN
    RETURN QUERY SELECT FALSE, 'Ya existe un nivel ' || p_nivel || ' para esta plaga'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Insertar nuevo nivel de infestación
  INSERT INTO pm_nivelesinfestacion(
    pmni_nivel,
    pmni_plaga,
    pmni_nombrecomun,
    pmni_rango,
    pmni_lminferior,
    pmni_lmsuperior,
    pmni_tipoobservacion,
    pmni_observacion,
    pmni_cintaidentificadora,
    pmni_estatus,
    pmni_creadopor,
    pmni_fechacreacion
  ) VALUES (
    p_nivel,
    p_plaga,
    p_nombrecomun,
    p_rango,
    p_lminferior,
    p_lmsuperior,
    p_tipoobservacion,
    p_observacion,
    p_cintaidentificadora,
    p_estatus,
    p_creadopor,
    NOW()
  ) RETURNING pmni_secuencia INTO v_secuencia;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Nivel de infestación creado correctamente'::VARCHAR, v_secuencia;
END;
$$;


ALTER FUNCTION public.sp_create_nivel(p_nivel integer, p_plaga integer, p_nombrecomun character varying, p_rango character varying, p_lminferior integer, p_lmsuperior integer, p_tipoobservacion character varying, p_observacion text, p_cintaidentificadora character varying, p_estatus integer, p_creadopor integer) OWNER TO pestuser;

--
-- Name: sp_create_plaga(character varying, character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_plaga(p_nombrecomun character varying, p_genero character varying DEFAULT NULL::character varying, p_familia character varying DEFAULT NULL::character varying, p_tipo character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT 1, p_creadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, plaga_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_plaga_id INT;
  v_exists BOOLEAN;
BEGIN
  -- Validaciones básicas
  IF p_nombrecomun IS NULL OR p_nombrecomun = '' THEN
    RETURN QUERY SELECT FALSE, 'El nombre común de la plaga es obligatorio'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar si ya existe una plaga con el mismo nombre
  SELECT EXISTS (
    SELECT 1 FROM pm_plagas WHERE pmpl_nombrecomun = p_nombrecomun
  ) INTO v_exists;
  
  IF v_exists THEN
    RETURN QUERY SELECT FALSE, 'Ya existe una plaga con ese nombre común'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Insertar nueva plaga
  INSERT INTO pm_plagas(
    pmpl_nombrecomun, 
    pmpl_genero, 
    pmpl_familia, 
    pmpl_tipo, 
    pmpl_estatus, 
    pmpl_creadopor, 
    pmpl_fechacreacion
  ) VALUES (
    p_nombrecomun, 
    p_genero, 
    p_familia, 
    p_tipo, 
    p_estatus, 
    p_creadopor, 
    NOW()
  ) RETURNING pmpl_id INTO v_plaga_id;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Plaga creada correctamente'::VARCHAR, v_plaga_id;
END;
$$;


ALTER FUNCTION public.sp_create_plaga(p_nombrecomun character varying, p_genero character varying, p_familia character varying, p_tipo character varying, p_estatus integer, p_creadopor integer) OWNER TO pestuser;

--
-- Name: sp_create_rol(character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_rol(descripcion_param character varying, estatus_param integer DEFAULT 1, creador_param integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, rol_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuevo_id INTEGER;
    existe_rol BOOLEAN;
BEGIN
    -- Verificar si ya existe un rol con el mismo nombre
    SELECT EXISTS(
        SELECT 1 FROM pm_rol WHERE pmrl_descripcion = descripcion_param
    ) INTO existe_rol;
    
    IF existe_rol THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Ya existe un rol con esa descripción'::VARCHAR(255) AS message, 
            NULL::INTEGER AS rol_id;
        RETURN;
    END IF;
    
    -- Insertar nuevo rol
    INSERT INTO pm_rol(
        pmrl_descripcion,
        pmrl_estatus,
        pmrl_creadopor,
        pmrl_fechacreacion
    ) VALUES (
        descripcion_param,
        estatus_param,
        creador_param,
        NOW()
    ) RETURNING pmrl_id INTO nuevo_id;
    
    -- Retornar resultado exitoso
    RETURN QUERY SELECT 
        TRUE::BOOLEAN AS success, 
        'Rol creado correctamente'::VARCHAR(255) AS message, 
        nuevo_id::INTEGER AS rol_id;
END;
$$;


ALTER FUNCTION public.sp_create_rol(descripcion_param character varying, estatus_param integer, creador_param integer) OWNER TO pestuser;

--
-- Name: sp_create_unidad_cultivo(character varying, character varying, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_unidad_cultivo(p_codigo character varying, p_cantero character varying, p_id integer DEFAULT 0, p_estatus integer DEFAULT 1, p_creadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message text, unidad_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_secuencia INT;
  v_existe INT;
BEGIN
  -- Verificar parámetros requeridos
  IF p_codigo IS NULL OR trim(p_codigo) = '' THEN
    RETURN QUERY SELECT FALSE, 'El código es obligatorio', 0;
    RETURN;
  END IF;
  
  IF p_cantero IS NULL OR trim(p_cantero) = '' THEN
    RETURN QUERY SELECT FALSE, 'El cantero es obligatorio', 0;
    RETURN;
  END IF;
  
  -- Verificar si ya existe una unidad con el mismo código
  SELECT COUNT(*) INTO v_existe FROM pm_unidadescultivo WHERE pmuc_codigo = p_codigo;
  IF v_existe > 0 THEN
    RETURN QUERY SELECT FALSE, 'Ya existe una unidad de cultivo con ese código', 0;
    RETURN;
  END IF;
  
  -- Insertar nueva unidad de cultivo
  -- Nota: Dejamos que PostgreSQL use la secuencia predeterminada
  INSERT INTO pm_unidadescultivo(
    pmuc_codigo, 
    pmuc_cantero, 
    pmuc_id, 
    pmuc_estatus, 
    pmuc_creadopor, 
    pmuc_fechacreacion
  ) VALUES (
    p_codigo, 
    p_cantero, 
    COALESCE(p_id, 0), 
    COALESCE(p_estatus, 1), 
    COALESCE(p_creadopor, 1), 
    NOW()
  ) RETURNING pmuc_secuencia INTO v_secuencia;
  
  RETURN QUERY SELECT TRUE, 'Unidad de cultivo creada correctamente', v_secuencia;
END;
$$;


ALTER FUNCTION public.sp_create_unidad_cultivo(p_codigo character varying, p_cantero character varying, p_id integer, p_estatus integer, p_creadopor integer) OWNER TO pestuser;

--
-- Name: sp_create_usuario(character varying, integer, character varying, integer, integer, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_usuario(usuario_param character varying, funcion_param integer, password_param character varying, codigo_param integer DEFAULT 0, estatus_param integer DEFAULT 1, correo_param character varying DEFAULT NULL::character varying, telefono_param character varying DEFAULT NULL::character varying, creador_param integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, usuario_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    nuevo_id INTEGER;
    existe_usuario BOOLEAN;
BEGIN
    -- Verificar si ya existe un usuario con el mismo nombre
    SELECT EXISTS(
        SELECT 1 FROM pm_usuarios WHERE pmus_usuario = usuario_param
    ) INTO existe_usuario;
    
    IF existe_usuario THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Ya existe un usuario con ese nombre'::VARCHAR(255) AS message, 
            NULL::INTEGER AS usuario_id;
        RETURN;
    END IF;
    
    -- Insertar nuevo usuario
    INSERT INTO pm_usuarios(
        pmus_codigo, 
        pmus_usuario, 
        pmus_funcion, 
        pmus_estatus, 
        pmus_creadopor, 
        pmus_fechacreacion,
        pmus_password,
        pmus_correo,
        pmus_telefono
    ) VALUES (
        codigo_param, 
        usuario_param, 
        funcion_param, 
        estatus_param, 
        creador_param, 
        NOW(),
        password_param,
        correo_param,
        telefono_param
    ) RETURNING pmus_id INTO nuevo_id;
    
    -- Retornar resultado exitoso con conversión explícita de tipos
    RETURN QUERY SELECT 
        TRUE::BOOLEAN AS success, 
        'Usuario creado correctamente'::VARCHAR(255) AS message, 
        nuevo_id::INTEGER AS usuario_id;
END;
$$;


ALTER FUNCTION public.sp_create_usuario(usuario_param character varying, funcion_param integer, password_param character varying, codigo_param integer, estatus_param integer, correo_param character varying, telefono_param character varying, creador_param integer) OWNER TO pestuser;

--
-- Name: sp_create_variedad(character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_create_variedad(p_codigo character varying, p_descripcion character varying, p_responsable character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT 1, p_creado_por integer DEFAULT 1) RETURNS TABLE(success boolean, message text, variedad_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_code_exists BOOLEAN;
    v_id INTEGER;
BEGIN
    -- Validar campos obligatorios
    IF p_codigo IS NULL OR p_codigo = '' THEN
        RETURN QUERY
        SELECT false, 'El código es obligatorio', 0::INTEGER;
        RETURN;
    END IF;
    
    IF p_descripcion IS NULL OR p_descripcion = '' THEN
        RETURN QUERY
        SELECT false, 'La descripción es obligatoria', 0::INTEGER;
        RETURN;
    END IF;
    
    -- Verificar si ya existe una variedad con el mismo código
    SELECT EXISTS(
        SELECT 1 FROM pm_variedades WHERE pmva_codigo = p_codigo
    ) INTO v_code_exists;
    
    IF v_code_exists THEN
        RETURN QUERY
        SELECT false, 'Ya existe una variedad con ese código', 0::INTEGER;
        RETURN;
    END IF;
    
    -- Insertar nueva variedad
    INSERT INTO pm_variedades (
        pmva_codigo,
        pmva_descripcion,
        pmva_responsable,
        pmva_estatus,
        pmva_creadopor,
        pmva_fechacreacion
    ) VALUES (
        p_codigo,
        p_descripcion,
        p_responsable,
        p_estatus,
        p_creado_por,
        NOW()
    ) RETURNING pmva_id INTO v_id;
    
    -- Retornar éxito
    RETURN QUERY
    SELECT true, 'Variedad creada exitosamente', v_id;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM, 0::INTEGER;
END;
$$;


ALTER FUNCTION public.sp_create_variedad(p_codigo character varying, p_descripcion character varying, p_responsable character varying, p_estatus integer, p_creado_por integer) OWNER TO pestuser;

--
-- Name: sp_delete_lote(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_lote(p_id integer) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_exists BOOLEAN;
BEGIN
    -- Verificar si el lote existe
    SELECT EXISTS(
        SELECT 1 FROM pm_lotes WHERE pmlt_secuencia = p_id
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RETURN QUERY
        SELECT false, 'Lote no encontrado';
        RETURN;
    END IF;
    
    -- Realizar baja lógica (actualizar estatus a 0)
    UPDATE pm_lotes SET
        pmlt_estatus = 0,
        pmlt_fechamodificacion = NOW()
    WHERE pmlt_secuencia = p_id;
    
    -- Retornar éxito
    RETURN QUERY
    SELECT true, 'Lote eliminado exitosamente';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM;
END;
$$;


ALTER FUNCTION public.sp_delete_lote(p_id integer) OWNER TO pestuser;

--
-- Name: sp_delete_monitoreo(integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_monitoreo(p_pmmo_secuencia integer, p_pmmo_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Verificar que el monitoreo exista
  SELECT EXISTS (
    SELECT 1 FROM pm_monitoreos WHERE pmmo_secuencia = p_pmmo_secuencia
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'No se encontró el monitoreo con ID '|| p_pmmo_secuencia::TEXT;
    RETURN;
  END IF;
  
  -- Realizar eliminación lógica
  UPDATE pm_monitoreos SET 
    pmmo_estatus = 0,
    pmmo_modificadopor = p_pmmo_modificadopor,
    pmmo_fechamodificacion = NOW()
  WHERE pmmo_secuencia = p_pmmo_secuencia;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Monitoreo eliminado exitosamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_delete_monitoreo(p_pmmo_secuencia integer, p_pmmo_modificadopor integer) OWNER TO pestuser;

--
-- Name: FUNCTION sp_delete_monitoreo(p_pmmo_secuencia integer, p_pmmo_modificadopor integer); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_delete_monitoreo(p_pmmo_secuencia integer, p_pmmo_modificadopor integer) IS 'Función para realizar la baja lógica de un monitoreo (cambiar estatus a 0).';


--
-- Name: sp_delete_nivel(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_nivel(p_secuencia integer) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Verificar si el nivel existe
  SELECT EXISTS (
    SELECT 1 FROM pm_nivelesinfestacion WHERE pmni_secuencia = p_secuencia
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'Nivel de infestación no encontrado'::VARCHAR;
    RETURN;
  END IF;
  
  -- Eliminar nivel (baja lógica)
  UPDATE pm_nivelesinfestacion 
  SET pmni_estatus = 0, 
      pmni_fechamodificacion = NOW() 
  WHERE pmni_secuencia = p_secuencia;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Nivel de infestación eliminado correctamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_delete_nivel(p_secuencia integer) OWNER TO pestuser;

--
-- Name: sp_delete_niveles_por_plaga(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_niveles_por_plaga(p_plaga_id integer) RETURNS TABLE(success boolean, message character varying, count integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_count INT;
BEGIN
  -- Verificar si hay niveles para esta plaga
  SELECT COUNT(*) 
  FROM pm_nivelesinfestacion 
  WHERE pmni_plaga = p_plaga_id AND pmni_estatus = 1
  INTO v_count;
  
  IF v_count = 0 THEN
    RETURN QUERY SELECT FALSE, 'No hay niveles de infestación activos para esta plaga'::VARCHAR, 0;
    RETURN;
  END IF;
  
  -- Eliminar todos los niveles (baja lógica)
  UPDATE pm_nivelesinfestacion 
  SET pmni_estatus = 0, 
      pmni_fechamodificacion = NOW() 
  WHERE pmni_plaga = p_plaga_id AND pmni_estatus = 1;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, v_count || ' niveles de infestación eliminados correctamente'::VARCHAR, v_count;
END;
$$;


ALTER FUNCTION public.sp_delete_niveles_por_plaga(p_plaga_id integer) OWNER TO pestuser;

--
-- Name: sp_delete_plaga(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_plaga(p_id integer) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_exists BOOLEAN;
  v_count INT;
BEGIN
  -- Verificar si la plaga existe
  SELECT EXISTS (
    SELECT 1 FROM pm_plagas WHERE pmpl_id = p_id
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'Plaga no encontrada'::VARCHAR;
    RETURN;
  END IF;
  
  -- Actualizar estado de la plaga (baja lógica)
  UPDATE pm_plagas 
  SET pmpl_estatus = 0, 
      pmpl_fechamodificacion = NOW() 
  WHERE pmpl_id = p_id;
  
  -- Verificar si hay niveles de infestación asociados
  SELECT COUNT(*) 
  FROM pm_nivelesinfestacion 
  WHERE pmni_plaga = p_id AND pmni_estatus = 1
  INTO v_count;
  
  -- Si hay niveles asociados, también hacerles baja lógica
  IF v_count > 0 THEN
    UPDATE pm_nivelesinfestacion 
    SET pmni_estatus = 0, 
        pmni_fechamodificacion = NOW() 
    WHERE pmni_plaga = p_id;
  END IF;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Plaga eliminada correctamente'::VARCHAR;
END;
$$;


ALTER FUNCTION public.sp_delete_plaga(p_id integer) OWNER TO pestuser;

--
-- Name: sp_delete_rol(integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_rol(rol_id integer, modificador_param integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    existe_rol BOOLEAN;
    en_uso BOOLEAN;
BEGIN
    -- Verificar si el rol existe
    SELECT EXISTS(
        SELECT 1 FROM pm_rol WHERE pmrl_id = rol_id
    ) INTO existe_rol;
    
    IF NOT existe_rol THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Rol no encontrado'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Verificar si el rol está siendo utilizado
    SELECT * FROM sp_check_rol_in_use(rol_id) INTO en_uso;
    
    IF en_uso THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'No se puede eliminar el rol porque está siendo utilizado por uno o más usuarios'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Eliminar rol (baja lógica)
    UPDATE pm_rol SET 
        pmrl_estatus = 0,
        pmrl_modificadopor = modificador_param,
        pmrl_fechamodificacion = NOW()
    WHERE pmrl_id = rol_id;
    
    -- Retornar resultado exitoso
    RETURN QUERY SELECT 
        TRUE::BOOLEAN AS success, 
        'Rol eliminado correctamente'::VARCHAR(255) AS message;
END;
$$;


ALTER FUNCTION public.sp_delete_rol(rol_id integer, modificador_param integer) OWNER TO pestuser;

--
-- Name: sp_delete_unidad_cultivo(integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_unidad_cultivo(p_secuencia integer, p_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_existe INT;
BEGIN
  -- Verificar si la unidad existe
  SELECT COUNT(*) INTO v_existe FROM pm_unidadescultivo WHERE pmuc_secuencia = p_secuencia;
  IF v_existe = 0 THEN
    RETURN QUERY SELECT FALSE, 'Unidad de cultivo no encontrada';
    RETURN;
  END IF;
  
  -- Eliminar lógicamente la unidad
  UPDATE pm_unidadescultivo SET 
    pmuc_estatus = 0, 
    pmuc_modificadopor = COALESCE(p_modificadopor, 1),
    pmuc_fechamodificacion = NOW() 
  WHERE pmuc_secuencia = p_secuencia;
  
  RETURN QUERY SELECT TRUE, 'Unidad de cultivo eliminada correctamente';
END;
$$;


ALTER FUNCTION public.sp_delete_unidad_cultivo(p_secuencia integer, p_modificadopor integer) OWNER TO pestuser;

--
-- Name: sp_delete_variedad(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_delete_variedad(p_id integer) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_exists BOOLEAN;
    v_in_use BOOLEAN;
BEGIN
    -- Verificar si la variedad existe
    SELECT EXISTS(
        SELECT 1 FROM pm_variedades WHERE pmva_id = p_id
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RETURN QUERY
        SELECT false, 'Variedad no encontrada';
        RETURN;
    END IF;
    
    -- Verificar si la variedad está siendo utilizada en algún lote
    SELECT EXISTS(
        SELECT 1 FROM pm_lotes WHERE pmlt_idvariedad = p_id LIMIT 1
    ) INTO v_in_use;
    
    IF v_in_use THEN
        RETURN QUERY
        SELECT false, 'No se puede eliminar la variedad porque está siendo utilizada en uno o más lotes';
        RETURN;
    END IF;
    
    -- Realizar baja lógica (actualizar estatus a 0)
    UPDATE pm_variedades SET
        pmva_estatus = 0,
        pmva_fechamodificacion = NOW()
    WHERE pmva_id = p_id;
    
    -- Retornar éxito
    RETURN QUERY
    SELECT true, 'Variedad eliminada exitosamente';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM;
END;
$$;


ALTER FUNCTION public.sp_delete_variedad(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_casas_canteros(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_casas_canteros() RETURNS TABLE(tipo character varying, valor character varying, cuenta bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Obtener lista de casas
  RETURN QUERY
  SELECT 'casa'::VARCHAR as tipo, pmmo_casa as valor, COUNT(*) as cuenta
  FROM pm_monitoreos
  WHERE pmmo_estatus = 1
    AND pmmo_casa IS NOT NULL
    AND pmmo_casa <> ''
  GROUP BY pmmo_casa
  
  UNION ALL
  
  -- Obtener lista de canteros
  SELECT 'cantero'::VARCHAR as tipo, pmmo_cantero as valor, COUNT(*) as cuenta
  FROM pm_monitoreos
  WHERE pmmo_estatus = 1
    AND pmmo_cantero IS NOT NULL
    AND pmmo_cantero <> ''
  GROUP BY pmmo_cantero
  
  ORDER BY tipo, valor;
END;
$$;


ALTER FUNCTION public.sp_get_casas_canteros() OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_casas_canteros(); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_casas_canteros() IS 'Función para obtener la lista de casas y canteros disponibles para filtrado.';


--
-- Name: sp_get_estadisticas_resumen(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_estadisticas_resumen(p_usuario_id integer DEFAULT NULL::integer) RETURNS TABLE(cantidadmensual bigint, plagasfrecuentes json, monitoreosvariedad json)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_cantidad_mensual BIGINT;
  v_plagas_frecuentes JSON;
  v_monitoreos_por_variedad JSON;
BEGIN
  -- Obtener cantidad de monitoreos en el último mes
  IF p_usuario_id IS NULL THEN
    SELECT COUNT(*) INTO v_cantidad_mensual
    FROM pm_monitoreos
    WHERE pmmo_fecha >= NOW() - INTERVAL '30 days'
    AND pmmo_estatus = 1;
    
    -- Top 5 plagas más frecuentes
    SELECT json_agg(t)
    INTO v_plagas_frecuentes
    FROM (
      SELECT p.pmpl_nombrecomun as plaga, COUNT(*) as cantidad
      FROM pm_monitoreos m
      JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
      WHERE m.pmmo_fecha >= NOW() - INTERVAL '90 days'
      AND m.pmmo_estatus = 1
      GROUP BY p.pmpl_id, p.pmpl_nombrecomun
      ORDER BY cantidad DESC
      LIMIT 5
    ) t;
    
    -- Monitoreos por variedad
    SELECT json_agg(t)
    INTO v_monitoreos_por_variedad
    FROM (
      SELECT pmmo_variedad as variedad, COUNT(*) as cantidad
      FROM pm_monitoreos
      WHERE pmmo_fecha >= NOW() - INTERVAL '90 days'
      AND pmmo_estatus = 1
      GROUP BY pmmo_variedad
      ORDER BY cantidad DESC
    ) t;
  ELSE
    -- Filtrar por usuario si se proporciona ID
    SELECT COUNT(*) INTO v_cantidad_mensual
    FROM pm_monitoreos
    WHERE pmmo_fecha >= NOW() - INTERVAL '30 days'
    AND pmmo_estatus = 1
    AND pmmo_creadopor = p_usuario_id;
    
    -- Top 5 plagas más frecuentes (filtradas por usuario)
    SELECT json_agg(t)
    INTO v_plagas_frecuentes
    FROM (
      SELECT p.pmpl_nombrecomun as plaga, COUNT(*) as cantidad
      FROM pm_monitoreos m
      JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
      WHERE m.pmmo_fecha >= NOW() - INTERVAL '90 days'
      AND m.pmmo_estatus = 1
      AND m.pmmo_creadopor = p_usuario_id
      GROUP BY p.pmpl_id, p.pmpl_nombrecomun
      ORDER BY cantidad DESC
      LIMIT 5
    ) t;
    
    -- Monitoreos por variedad (filtrados por usuario)
    SELECT json_agg(t)
    INTO v_monitoreos_por_variedad
    FROM (
      SELECT pmmo_variedad as variedad, COUNT(*) as cantidad
      FROM pm_monitoreos
      WHERE pmmo_fecha >= NOW() - INTERVAL '90 days'
      AND pmmo_estatus = 1
      AND pmmo_creadopor = p_usuario_id
      GROUP BY pmmo_variedad
      ORDER BY cantidad DESC
    ) t;
  END IF;
  
  -- Si no hay datos, devolver arrays vacíos
  IF v_plagas_frecuentes IS NULL THEN
    v_plagas_frecuentes := '[]'::JSON;
  END IF;
  
  IF v_monitoreos_por_variedad IS NULL THEN
    v_monitoreos_por_variedad := '[]'::JSON;
  END IF;
  
  RETURN QUERY SELECT 
    v_cantidad_mensual, 
    v_plagas_frecuentes, 
    v_monitoreos_por_variedad;
END;
$$;


ALTER FUNCTION public.sp_get_estadisticas_resumen(p_usuario_id integer) OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_estadisticas_resumen(p_usuario_id integer); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_estadisticas_resumen(p_usuario_id integer) IS 'Función para obtener estadísticas resumidas para el dashboard.';


--
-- Name: sp_get_limites_niveles(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_limites_niveles() RETURNS TABLE(lmsupniv1 integer, lmsupniv2 integer, lmsupniv3 integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    COALESCE(MAX(CASE WHEN pmni_nivel = 1 THEN pmni_lmsuperior END), 10) AS lmsupniv1,
    COALESCE(MAX(CASE WHEN pmni_nivel = 2 THEN pmni_lmsuperior END), 20) AS lmsupniv2,
    COALESCE(MAX(CASE WHEN pmni_nivel = 3 THEN pmni_lmsuperior END), 30) AS lmsupniv3
  FROM pm_nivelesinfestacion
  WHERE pmni_estatus = 1;
END;
$$;


ALTER FUNCTION public.sp_get_limites_niveles() OWNER TO pestuser;

--
-- Name: sp_get_lote_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_lote_by_id(p_id integer) RETURNS TABLE(pmlt_secuencia integer, pmlt_codigo character varying, pmlt_canteros character varying, pmlt_cantidad integer, pmlt_estatus integer, pmlt_idvariedad integer, pmlt_fechacreacion timestamp without time zone, pmlt_contenedor character varying, pmlt_fechamodificacion timestamp without time zone, pmlt_creadopor integer, pmlt_grower character varying, pmlt_variedad character varying, pmlt_casa character varying, pmlt_modificadopor integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.pmlt_secuencia,
        l.pmlt_codigo,
        l.pmlt_canteros,
        l.pmlt_cantidad,
        l.pmlt_estatus,
        l.pmlt_idvariedad,
        l.pmlt_fechacreacion,
        l.pmlt_contenedor,
        l.pmlt_fechamodificacion,
        l.pmlt_creadopor,
        l.pmlt_grower,
        l.pmlt_variedad,
        l.pmlt_casa,
        l.pmlt_modificadopor
    FROM 
        pm_lotes l
    WHERE 
        l.pmlt_secuencia = p_id;
END;
$$;


ALTER FUNCTION public.sp_get_lote_by_id(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_lote_info(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_lote_info(p_lote_codigo character varying) RETURNS TABLE(pmlt_secuencia integer, pmlt_codigo character varying, pmlt_casa character varying, pmlt_canteros character varying, pmlt_idvariedad integer, pmlt_contenedor character varying, pmlt_cantidad integer, pmlt_grower character varying, pmlt_variedad character varying, pmlt_estatus integer, pmlt_creadopor integer, pmlt_fechacreacion timestamp without time zone, pmlt_modificadopor integer, pmlt_fechamodificacion timestamp without time zone, pmva_descripcion character varying, pmva_responsable character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.pmlt_secuencia,
        l.pmlt_codigo,
        l.pmlt_casa,
        l.pmlt_canteros,
        l.pmlt_idvariedad,
        l.pmlt_contenedor,
        l.pmlt_cantidad,
        l.pmlt_grower,
        l.pmlt_variedad,
        l.pmlt_estatus,
        l.pmlt_creadopor,
        l.pmlt_fechacreacion,
        l.pmlt_modificadopor,
        l.pmlt_fechamodificacion,
        v.pmva_descripcion,
        v.pmva_responsable
    FROM pm_lotes l
    LEFT JOIN pm_variedades v ON v.pmva_codigo = l.pmlt_idvariedad::varchar
    WHERE l.pmlt_codigo = p_lote_codigo;
END;
$$;


ALTER FUNCTION public.sp_get_lote_info(p_lote_codigo character varying) OWNER TO pestuser;

--
-- Name: sp_get_lotes(character varying, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_lotes(p_codigo_variedad character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_busqueda character varying DEFAULT NULL::character varying) RETURNS TABLE(pmlt_secuencia integer, pmlt_codigo character varying, pmlt_canteros character varying, pmlt_cantidad integer, pmlt_estatus integer, pmlt_idvariedad integer, pmlt_fechacreacion timestamp without time zone, pmlt_contenedor character varying, pmlt_fechamodificacion timestamp without time zone, pmlt_creadopor integer, pmlt_grower character varying, pmlt_variedad character varying, pmlt_casa character varying, pmlt_modificadopor integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY 
    SELECT 
        l.pmlt_secuencia,
        l.pmlt_codigo,
        l.pmlt_canteros,
        l.pmlt_cantidad,
        l.pmlt_estatus,
        l.pmlt_idvariedad,
        l.pmlt_fechacreacion,
        l.pmlt_contenedor,
        l.pmlt_fechamodificacion,
        l.pmlt_creadopor,
        l.pmlt_grower,
        l.pmlt_variedad,
        l.pmlt_casa,
        l.pmlt_modificadopor
    FROM 
        pm_lotes l
    LEFT JOIN 
        pm_variedades v ON CAST(v.pmva_codigo AS VARCHAR) = CAST(l.pmlt_idvariedad AS VARCHAR)
    WHERE 
        -- Filtro por ID de variedad (lo que viene del frontend)
        (p_codigo_variedad IS NULL OR 
         v.pmva_descripcion ILIKE '%' || p_codigo_variedad || '%' OR
		 l.pmlt_variedad ILIKE '%' || p_codigo_variedad || '%')
        AND
        -- Filtro por estatus
        (p_estatus IS NULL OR l.pmlt_estatus = p_estatus)
        AND
        -- Filtro por búsqueda en múltiples campos
        (p_busqueda IS NULL OR 
            l.pmlt_codigo ILIKE '%' || p_busqueda || '%' OR 
            l.pmlt_grower ILIKE '%' || p_busqueda || '%' OR 
            l.pmlt_casa ILIKE '%' || p_busqueda || '%' OR
            l.pmlt_variedad ILIKE '%' || p_busqueda || '%' OR
            v.pmva_descripcion ILIKE '%' || p_busqueda || '%')
        AND
        -- Excluir lotes eliminados
        l.pmlt_estatus != -1
    ORDER BY 
        l.pmlt_secuencia DESC;
END;
$$;


ALTER FUNCTION public.sp_get_lotes(p_codigo_variedad character varying, p_estatus integer, p_busqueda character varying) OWNER TO pestuser;

--
-- Name: sp_get_lotes_by_codigo_variedad(character varying, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_lotes_by_codigo_variedad(p_codigo_variedad character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_busqueda character varying DEFAULT NULL::character varying) RETURNS TABLE(pmlt_secuencia integer, pmlt_codigo character varying, pmlt_canteros character varying, pmlt_cantidad integer, pmlt_estatus integer, pmlt_idvariedad integer, pmlt_fechacreacion timestamp without time zone, pmlt_contenedor character varying, pmlt_fechamodificacion timestamp without time zone, pmlt_creadopor integer, pmlt_grower character varying, pmlt_variedad character varying, pmlt_casa character varying, pmlt_modificadopor integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    query_text TEXT;
    result_count INTEGER;
BEGIN
    -- Log detallado de entrada
    RAISE NOTICE '=== SP_GET_LOTES_BY_CODIGO_VARIEDAD ===';
    RAISE NOTICE 'p_codigo_variedad: %', COALESCE(p_codigo_variedad, 'NULL');
    RAISE NOTICE 'p_estatus: %', COALESCE(p_estatus::text, 'NULL');
    RAISE NOTICE 'p_busqueda: %', COALESCE(p_busqueda, 'NULL');
    
    -- Construir query dinámicamente para debug
    query_text := 'SELECT COUNT(*) FROM pm_lotes l WHERE l.pmlt_estatus != -1';
    
    IF p_estatus IS NOT NULL THEN
        query_text := query_text || ' AND l.pmlt_estatus = ' || p_estatus;
        RAISE NOTICE 'Filtro de estado aplicado: pmlt_estatus = %', p_estatus;
    ELSE
        RAISE NOTICE 'Sin filtro de estado aplicado';
    END IF;
    
    -- Ejecutar conteo para debug
    EXECUTE query_text INTO result_count;
    RAISE NOTICE 'Registros que cumplen filtro de estado: %', result_count;

    RETURN QUERY 
    SELECT 
        l.pmlt_secuencia,
        l.pmlt_codigo,
        l.pmlt_canteros,
        l.pmlt_cantidad,
        l.pmlt_estatus,
        l.pmlt_idvariedad,
        l.pmlt_fechacreacion,
        l.pmlt_contenedor,
        l.pmlt_fechamodificacion,
        l.pmlt_creadopor,
        l.pmlt_grower,
        l.pmlt_variedad,
        l.pmlt_casa,
        l.pmlt_modificadopor
    FROM 
        pm_lotes l
    LEFT JOIN 
        pm_variedades v ON CAST(v.pmva_codigo AS VARCHAR) = CAST(l.pmlt_idvariedad AS VARCHAR)
    WHERE 
        -- Filtro por variedad
        (p_codigo_variedad IS NULL OR 
         v.pmva_descripcion ILIKE '%' || p_codigo_variedad || '%' OR
         l.pmlt_variedad ILIKE '%' || p_codigo_variedad || '%')
        AND
        -- ⚠️ FILTRO POR ESTATUS - VERIFICADO
        (p_estatus IS NULL OR l.pmlt_estatus = p_estatus)
        AND
        -- Filtro por búsqueda
        (p_busqueda IS NULL OR 
            l.pmlt_codigo ILIKE '%' || p_busqueda || '%' OR 
            l.pmlt_grower ILIKE '%' || p_busqueda || '%' OR 
            l.pmlt_casa ILIKE '%' || p_busqueda || '%' OR
            l.pmlt_variedad ILIKE '%' || p_busqueda || '%' OR
            v.pmva_descripcion ILIKE '%' || p_busqueda || '%')
        AND
        -- Excluir eliminados
        l.pmlt_estatus != -1
    ORDER BY 
        l.pmlt_secuencia DESC;
        
    -- Log final
    GET DIAGNOSTICS result_count = ROW_COUNT;
    RAISE NOTICE 'Registros devueltos finalmente: %', result_count;
    RAISE NOTICE '=== FIN SP ===';
END;
$$;


ALTER FUNCTION public.sp_get_lotes_by_codigo_variedad(p_codigo_variedad character varying, p_estatus integer, p_busqueda character varying) OWNER TO pestuser;

--
-- Name: sp_get_monitoreo_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_monitoreo_by_id(p_id integer) RETURNS TABLE(pmmo_secuencia integer, pmlt_codigo character varying, pmmo_casa character varying, pmmo_cantero character varying, pmmo_canteros character varying, pmmo_variedad character varying, pmmo_idvariedad character varying, pmmo_grower character varying, pmni_id integer, pmmo_cantidad integer, pmmo_cant_botada integer, pmmo_comentarios character varying, pmmo_fecha timestamp without time zone, pmmo_automatico boolean, pmmo_estatus integer, pmmo_creadopor integer, pmmo_fechacreacion timestamp without time zone, pmmo_modificadopor integer, pmmo_fechamodificacion timestamp without time zone, pmmo_nivmuestram1 integer, pmmo_nivmuestram2 integer, pmmo_nivmuestram3 integer, pmmo_nivmuestraa1 integer, pmmo_nivmuestraa2 integer, pmmo_nivmuestraa3 integer, pmmo_muestra1 integer, pmmo_muestra2 integer, pmmo_muestra3 integer, pmmo_contenedor character varying, pmpl_nombrecomun character varying, pmva_descripcion character varying, pmni_nombrecomun character varying, pmlt_canteros character varying, pmlt_grower character varying, pmlt_contenedor character varying, lmsupniv1 integer, lmsupniv2 integer, lmsupniv3 integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.pmmo_secuencia,
    m.pmlt_codigo,
    m.pmmo_casa,
    m.pmmo_cantero,
    m.pmmo_canteros,
    m.pmmo_variedad,
    m.pmmo_idvariedad,
    m.pmmo_grower,
    m.pmni_id,
    m.pmmo_cantidad,
    m.pmmo_cant_botada,
    m.pmmo_comentarios,
    m.pmmo_fecha,
    m.pmmo_automatico,
    m.pmmo_estatus,
    m.pmmo_creadopor,
    m.pmmo_fechacreacion,
    m.pmmo_modificadopor,
    m.pmmo_fechamodificacion,
    m.pmmo_nivmuestram1,
    m.pmmo_nivmuestram2,
    m.pmmo_nivmuestram3,
    m.pmmo_nivmuestraa1,
    m.pmmo_nivmuestraa2,
    m.pmmo_nivmuestraa3,
    m.pmmo_muestra1,
    m.pmmo_muestra2,
    m.pmmo_muestra3,
    m.pmmo_contenedor,
    p.pmpl_nombrecomun,
    v.pmva_descripcion,
    (SELECT max(ni.pmni_nombrecomun) FROM pm_nivelesinfestacion ni WHERE ni.pmni_plaga = p.pmpl_id)::VARCHAR(100) AS pmni_nombrecomun,
    l.pmlt_canteros,
    l.pmlt_grower,
    l.pmlt_contenedor,
    (SELECT MAX(n1.pmni_lmsuperior) FROM pm_nivelesinfestacion n1 WHERE n1.pmni_nivel = 1 AND n1.pmni_plaga = p.pmpl_id) AS lmsupniv1,
    (SELECT MAX(n2.pmni_lmsuperior) FROM pm_nivelesinfestacion n2 WHERE n2.pmni_nivel = 2 AND n2.pmni_plaga = p.pmpl_id) AS lmsupniv2,
    (SELECT MAX(n3.pmni_lminferior) FROM pm_nivelesinfestacion n3 WHERE n3.pmni_nivel = 3 AND n3.pmni_plaga = p.pmpl_id) AS lmsupniv3
  FROM pm_monitoreos m
  LEFT JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
  LEFT JOIN pm_lotes l ON m.pmlt_codigo = l.pmlt_codigo
  LEFT JOIN pm_variedades v ON v.pmva_codigo = l.pmlt_idvariedad::varchar
  WHERE m.pmmo_secuencia = p_id;
END;
$$;


ALTER FUNCTION public.sp_get_monitoreo_by_id(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_monitoreos(character varying, character varying, integer, timestamp without time zone, timestamp without time zone, character varying, character varying, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_monitoreos(p_lote character varying DEFAULT NULL::character varying, p_plaga character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_fecha_inicio timestamp without time zone DEFAULT NULL::timestamp without time zone, p_fecha_fin timestamp without time zone DEFAULT NULL::timestamp without time zone, p_casa character varying DEFAULT NULL::character varying, p_cantero character varying DEFAULT NULL::character varying, p_variedad character varying DEFAULT NULL::character varying) RETURNS TABLE(pmmo_secuencia integer, pmlt_codigo character varying, pmmo_casa character varying, pmmo_cantero character varying, pmmo_canteros character varying, pmmo_variedad character varying, pmmo_idvariedad character varying, pmmo_grower character varying, pmni_id integer, pmmo_cantidad integer, pmmo_cant_botada integer, pmmo_comentarios character varying, pmmo_fecha timestamp without time zone, pmmo_automatico boolean, pmmo_estatus integer, pmmo_creadopor integer, pmmo_fechacreacion timestamp without time zone, pmmo_modificadopor integer, pmmo_fechamodificacion timestamp without time zone, pmmo_nivmuestram1 integer, pmmo_nivmuestram2 integer, pmmo_nivmuestram3 integer, pmmo_nivmuestraa1 integer, pmmo_nivmuestraa2 integer, pmmo_nivmuestraa3 integer, pmmo_muestra1 integer, pmmo_muestra2 integer, pmmo_muestra3 integer, pmmo_contenedor character varying, pmpl_nombrecomun character varying, pmva_descripcion character varying, pmni_nombrecomun character varying, pmlt_canteros character varying, pmlt_grower character varying, pmlt_contenedor character varying, lmsupniv1 integer, lmsupniv2 integer, lmsupniv3 integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.pmmo_secuencia,
    m.pmlt_codigo,
    m.pmmo_casa,
    m.pmmo_cantero,
    m.pmmo_canteros,
    m.pmmo_variedad,
    m.pmmo_idvariedad,
    m.pmmo_grower,
    m.pmni_id,
    m.pmmo_cantidad,
    m.pmmo_cant_botada,
    m.pmmo_comentarios,
    m.pmmo_fecha,
    m.pmmo_automatico,
    m.pmmo_estatus,
    m.pmmo_creadopor,
    m.pmmo_fechacreacion,
    m.pmmo_modificadopor,
    m.pmmo_fechamodificacion,
    m.pmmo_nivmuestram1,
    m.pmmo_nivmuestram2,
    m.pmmo_nivmuestram3,
    m.pmmo_nivmuestraa1,
    m.pmmo_nivmuestraa2,
    m.pmmo_nivmuestraa3,
    m.pmmo_muestra1,
    m.pmmo_muestra2,
    m.pmmo_muestra3,
    m.pmmo_contenedor,
    p.pmpl_nombrecomun,
    v.pmva_descripcion,
    (SELECT DISTINCT ni.pmni_nombrecomun FROM pm_nivelesinfestacion ni WHERE ni.pmni_plaga = p.pmpl_id LIMIT 1) AS pmni_nombrecomun,
    l.pmlt_canteros,
    l.pmlt_grower,
    l.pmlt_contenedor,
    (SELECT MAX(n1.pmni_lmsuperior) FROM pm_nivelesinfestacion n1 WHERE n1.pmni_nivel = 1 AND n1.pmni_plaga = p.pmpl_id) AS lmsupniv1,
    (SELECT MAX(n2.pmni_lmsuperior) FROM pm_nivelesinfestacion n2 WHERE n2.pmni_nivel = 2 AND n2.pmni_plaga = p.pmpl_id) AS lmsupniv2,
    (SELECT MAX(n3.pmni_lminferior) FROM pm_nivelesinfestacion n3 WHERE n3.pmni_nivel = 3 AND n3.pmni_plaga = p.pmpl_id) AS lmsupniv3
  FROM pm_monitoreos m
  LEFT JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
  LEFT JOIN pm_lotes l ON m.pmlt_codigo = l.pmlt_codigo
  LEFT JOIN pm_variedades v ON v.pmva_codigo = l.pmlt_idvariedad::varchar
  WHERE (p_lote IS NULL OR m.pmlt_codigo = p_lote)
    AND (p_plaga IS NULL OR p.pmpl_nombrecomun = p_plaga)
    AND (p_estatus IS NULL OR m.pmmo_estatus = p_estatus)
    AND (p_fecha_inicio IS NULL OR m.pmmo_fecha >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR m.pmmo_fecha <= p_fecha_fin)
    AND (p_casa IS NULL OR m.pmmo_casa = p_casa)
    AND (p_cantero IS NULL OR m.pmmo_cantero = p_cantero)
    AND (p_variedad IS NULL OR m.pmmo_variedad = p_variedad OR v.pmva_descripcion = p_variedad)
  ORDER BY m.pmmo_fecha DESC, m.pmmo_secuencia DESC;
END;
$$;


ALTER FUNCTION public.sp_get_monitoreos(p_lote character varying, p_plaga character varying, p_estatus integer, p_fecha_inicio timestamp without time zone, p_fecha_fin timestamp without time zone, p_casa character varying, p_cantero character varying, p_variedad character varying) OWNER TO pestuser;

--
-- Name: sp_get_monitoreos_by_lote(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_monitoreos_by_lote(p_lote_codigo character varying) RETURNS TABLE(pmmo_secuencia integer, pmlt_codigo character varying, pmmo_casa character varying, pmmo_cantero character varying, pmmo_canteros character varying, pmmo_variedad character varying, pmmo_idvariedad character varying, pmmo_grower character varying, pmni_id integer, pmmo_cantidad integer, pmmo_cant_botada integer, pmmo_comentarios text, pmmo_fecha timestamp without time zone, pmmo_automatico boolean, pmmo_estatus integer, pmmo_creadopor integer, pmmo_fechacreacion timestamp without time zone, pmmo_modificadopor integer, pmmo_fechamodificacion timestamp without time zone, pmmo_nivmuestram1 integer, pmmo_nivmuestram2 integer, pmmo_nivmuestram3 integer, pmmo_nivmuestraa1 integer, pmmo_nivmuestraa2 integer, pmmo_nivmuestraa3 integer, pmmo_muestra1 integer, pmmo_muestra2 integer, pmmo_muestra3 integer, pmmo_contenedor character varying, pmpl_nombrecomun character varying, pmva_descripcion character varying, pmni_nombrecomun character varying, pmlt_canteros character varying, pmlt_grower character varying, lmsupniv1 integer, lmsupniv2 integer, lmsupniv3 integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.pmmo_secuencia,
    m.pmlt_codigo,
    m.pmmo_casa,
    m.pmmo_cantero,
    m.pmmo_canteros,
    m.pmmo_variedad,
    m.pmmo_idvariedad,
    m.pmmo_grower,
    m.pmni_id,
    m.pmmo_cantidad,
    m.pmmo_cant_botada,
    m.pmmo_comentarios,
    m.pmmo_fecha,
    m.pmmo_automatico,
    m.pmmo_estatus,
    m.pmmo_creadopor,
    m.pmmo_fechacreacion,
    m.pmmo_modificadopor,
    m.pmmo_fechamodificacion,
    m.pmmo_nivmuestram1,
    m.pmmo_nivmuestram2,
    m.pmmo_nivmuestram3,
    m.pmmo_nivmuestraa1,
    m.pmmo_nivmuestraa2,
    m.pmmo_nivmuestraa3,
    m.pmmo_muestra1,
    m.pmmo_muestra2,
    m.pmmo_muestra3,
    m.pmmo_contenedor,
    p.pmpl_nombrecomun,
    v.pmva_descripcion,
    (SELECT MAX(pmni_nombrecomun) FROM pm_nivelesinfestacion WHERE pmni_plaga = p.pmpl_id) AS pmni_nombrecomun,
    l.pmlt_canteros,
    l.pmlt_grower,
    (SELECT MAX(n1.pmni_lmsuperior) FROM pm_nivelesinfestacion n1 WHERE n1.pmni_nivel = 1 AND n1.pmni_plaga = p.pmpl_id) AS lmsupniv1,
    (SELECT MAX(n2.pmni_lmsuperior) FROM pm_nivelesinfestacion n2 WHERE n2.pmni_nivel = 2 AND n2.pmni_plaga = p.pmpl_id) AS lmsupniv2,
    (SELECT MAX(n3.pmni_lminferior) FROM pm_nivelesinfestacion n3 WHERE n3.pmni_nivel = 3 AND n3.pmni_plaga = p.pmpl_id) AS lmsupniv3
  FROM pm_monitoreos m
  LEFT JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
  LEFT JOIN pm_lotes l ON m.pmlt_codigo = l.pmlt_codigo
  LEFT JOIN pm_variedades v ON v.pmva_codigo = l.pmlt_idvariedad::varchar
  WHERE m.pmlt_codigo = p_lote_codigo
  ORDER BY m.pmmo_fecha DESC;
END;
$$;


ALTER FUNCTION public.sp_get_monitoreos_by_lote(p_lote_codigo character varying) OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_monitoreos_by_lote(p_lote_codigo character varying); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_monitoreos_by_lote(p_lote_codigo character varying) IS 'Función para obtener los monitoreos asociados a un lote específico.';


--
-- Name: sp_get_monitoreos_by_usuario(integer, timestamp without time zone, timestamp without time zone); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_monitoreos_by_usuario(p_usuario_id integer, p_fecha_inicio timestamp without time zone DEFAULT NULL::timestamp without time zone, p_fecha_fin timestamp without time zone DEFAULT NULL::timestamp without time zone) RETURNS TABLE(pmmo_secuencia integer, pmlt_codigo character varying, pmmo_casa character varying, pmmo_cantero character varying, pmmo_canteros character varying, pmmo_variedad character varying, pmmo_idvariedad character varying, pmmo_grower character varying, pmni_id integer, pmmo_cantidad integer, pmmo_cant_botada integer, pmmo_comentarios text, pmmo_fecha timestamp without time zone, pmmo_automatico boolean, pmmo_estatus integer, pmmo_creadopor integer, pmmo_fechacreacion timestamp without time zone, pmmo_modificadopor integer, pmmo_fechamodificacion timestamp without time zone, pmmo_nivmuestram1 integer, pmmo_nivmuestram2 integer, pmmo_nivmuestram3 integer, pmmo_nivmuestraa1 integer, pmmo_nivmuestraa2 integer, pmmo_nivmuestraa3 integer, pmmo_muestra1 integer, pmmo_muestra2 integer, pmmo_muestra3 integer, pmmo_contenedor character varying, pmpl_nombrecomun character varying, pmva_descripcion character varying, pmni_nombrecomun character varying, pmlt_canteros character varying, pmlt_grower character varying, lmsupniv1 integer, lmsupniv2 integer, lmsupniv3 integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.pmmo_secuencia,
    m.pmlt_codigo,
    m.pmmo_casa,
    m.pmmo_cantero,
    m.pmmo_canteros,
    m.pmmo_variedad,
    m.pmmo_idvariedad,
    m.pmmo_grower,
    m.pmni_id,
    m.pmmo_cantidad,
    m.pmmo_cant_botada,
    m.pmmo_comentarios,
    m.pmmo_fecha,
    m.pmmo_automatico,
    m.pmmo_estatus,
    m.pmmo_creadopor,
    m.pmmo_fechacreacion,
    m.pmmo_modificadopor,
    m.pmmo_fechamodificacion,
    m.pmmo_nivmuestram1,
    m.pmmo_nivmuestram2,
    m.pmmo_nivmuestram3,
    m.pmmo_nivmuestraa1,
    m.pmmo_nivmuestraa2,
    m.pmmo_nivmuestraa3,
    m.pmmo_muestra1,
    m.pmmo_muestra2,
    m.pmmo_muestra3,
    m.pmmo_contenedor,
    p.pmpl_nombrecomun,
    v.pmva_descripcion,
    (SELECT MAX(pmni_nombrecomun) FROM pm_nivelesinfestacion WHERE pmni_plaga = p.pmpl_id) AS pmni_nombrecomun,
    l.pmlt_canteros,
    l.pmlt_grower,
    (SELECT MAX(n1.pmni_lmsuperior) FROM pm_nivelesinfestacion n1 WHERE n1.pmni_nivel = 1 AND n1.pmni_plaga = p.pmpl_id) AS lmsupniv1,
    (SELECT MAX(n2.pmni_lmsuperior) FROM pm_nivelesinfestacion n2 WHERE n2.pmni_nivel = 2 AND n2.pmni_plaga = p.pmpl_id) AS lmsupniv2,
    (SELECT MAX(n3.pmni_lminferior) FROM pm_nivelesinfestacion n3 WHERE n3.pmni_nivel = 3 AND n3.pmni_plaga = p.pmpl_id) AS lmsupniv3
  FROM pm_monitoreos m
  LEFT JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
  LEFT JOIN pm_lotes l ON m.pmlt_codigo = l.pmlt_codigo
  LEFT JOIN pm_variedades v ON v.pmva_codigo = l.pmlt_idvariedad::varchar
  WHERE m.pmmo_creadopor = p_usuario_id
    AND m.pmmo_estatus = 1
    AND (p_fecha_inicio IS NULL OR m.pmmo_fecha >= p_fecha_inicio)
    AND (p_fecha_fin IS NULL OR m.pmmo_fecha <= p_fecha_fin)
  ORDER BY m.pmmo_fecha DESC, m.pmmo_secuencia DESC;
END;
$$;


ALTER FUNCTION public.sp_get_monitoreos_by_usuario(p_usuario_id integer, p_fecha_inicio timestamp without time zone, p_fecha_fin timestamp without time zone) OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_monitoreos_by_usuario(p_usuario_id integer, p_fecha_inicio timestamp without time zone, p_fecha_fin timestamp without time zone); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_monitoreos_by_usuario(p_usuario_id integer, p_fecha_inicio timestamp without time zone, p_fecha_fin timestamp without time zone) IS 'Función para obtener los monitoreos creados por un usuario específico.';


--
-- Name: sp_get_monitoreos_recientes(integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_monitoreos_recientes(p_dias integer DEFAULT 7, p_usuario_id integer DEFAULT NULL::integer) RETURNS TABLE(pmmo_secuencia integer, pmlt_codigo character varying, pmmo_casa character varying, pmmo_cantero character varying, pmmo_fecha timestamp without time zone, pmmo_variedad character varying, pmpl_nombrecomun character varying, pmni_id integer, pmmo_cantidad integer, pmmo_creadopor integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    m.pmmo_secuencia,
    m.pmlt_codigo,
    m.pmmo_casa,
    m.pmmo_cantero,
    m.pmmo_fecha,
    m.pmmo_variedad,
    p.pmpl_nombrecomun,
    m.pmni_id,
    m.pmmo_cantidad,
    m.pmmo_creadopor
  FROM pm_monitoreos m
  LEFT JOIN pm_plagas p ON p.pmpl_id = m.pmni_id
  WHERE m.pmmo_estatus = 1
    AND m.pmmo_fecha >= CURRENT_DATE - (p_dias || ' days')::INTERVAL
    AND (p_usuario_id IS NULL OR m.pmmo_creadopor = p_usuario_id)
  ORDER BY m.pmmo_fecha DESC
  LIMIT 50; -- Limitar a un número razonable para rendimiento
END;
$$;


ALTER FUNCTION public.sp_get_monitoreos_recientes(p_dias integer, p_usuario_id integer) OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_monitoreos_recientes(p_dias integer, p_usuario_id integer); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_monitoreos_recientes(p_dias integer, p_usuario_id integer) IS 'Función para obtener los monitoreos más recientes con filtros opcionales.';


--
-- Name: sp_get_nivel_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_nivel_by_id(p_id integer) RETURNS TABLE(pmni_secuencia integer, pmni_nivel integer, pmni_plaga integer, pmni_nombrecomun character varying, pmni_rango character varying, pmni_lminferior integer, pmni_lmsuperior integer, pmni_tipoobservacion character varying, pmni_observacion text, pmni_cintaidentificadora character varying, pmni_estatus integer, pmni_creadopor integer, pmni_fechacreacion timestamp without time zone, pmni_modificadopor integer, pmni_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ni.pmni_secuencia,
    ni.pmni_nivel,
    ni.pmni_plaga,
    ni.pmni_nombrecomun,
    ni.pmni_rango,
    ni.pmni_lminferior,
    ni.pmni_lmsuperior,
    ni.pmni_tipoobservacion,
    ni.pmni_observacion,
    ni.pmni_cintaidentificadora,
    ni.pmni_estatus,
    ni.pmni_creadopor,
    ni.pmni_fechacreacion,
    ni.pmni_modificadopor,
    ni.pmni_fechamodificacion
  FROM pm_nivelesinfestacion ni
  WHERE ni.pmni_secuencia = p_id;
END;
$$;


ALTER FUNCTION public.sp_get_nivel_by_id(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_niveles_plaga(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_niveles_plaga(p_plaga_nombre character varying) RETURNS TABLE(pmni_secuencia integer, pmni_plaga integer, pmni_nombrecomun character varying, pmni_lminferior integer, pmni_lmsuperior integer, pmni_nivel integer, pmni_rango character varying, pmni_tipoobservacion character varying, pmni_observacion text, pmni_cintalidentificadora character varying, pmni_estatus integer, pmni_creadopor integer, pmni_fechacreacion timestamp without time zone, pmni_modificadopor integer, pmni_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ni.pmni_secuencia,
        ni.pmni_plaga,
        ni.pmni_nombrecomun,
        ni.pmni_lminferior,                     -- ✅ CORRECTO
        ni.pmni_lmsuperior,                     -- ✅ CORRECTO
        ni.pmni_nivel,
        ni.pmni_rango,
        ni.pmni_tipoobservacion,
        ni.pmni_observacion,
        ni.pmni_cintaidentificadora,
        ni.pmni_estatus,
        ni.pmni_creadopor,
        ni.pmni_fechacreacion,
        ni.pmni_modificadopor,
        ni.pmni_fechamodificacion
    FROM pm_nivelesinfestacion ni
    JOIN pm_plagas p ON p.pmpl_id = ni.pmni_plaga
    WHERE p.pmpl_nombrecomun = p_plaga_nombre
    AND ni.pmni_estatus = 1
    ORDER BY ni.pmni_nivel;
END;
$$;


ALTER FUNCTION public.sp_get_niveles_plaga(p_plaga_nombre character varying) OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_niveles_plaga(p_plaga_nombre character varying); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_niveles_plaga(p_plaga_nombre character varying) IS 'Función para obtener los niveles de infestación asociados a una plaga específica.';


--
-- Name: sp_get_niveles_plaga_api(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_niveles_plaga_api(p_plaga_nombre character varying) RETURNS TABLE(id integer, plaga integer, nombre_comun character varying, lim_inferior integer, lim_superior integer, nivel integer, rango character varying, observacion text, color character varying, estatus integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        ni.pmni_secuencia as id,
        ni.pmni_plaga as plaga,
        ni.pmni_nombrecomun as nombre_comun,
        ni.pmni_liminferior as lim_inferior,
        ni.pmni_limsuperior as lim_superior,
        ni.pmni_nivel as nivel,
        ni.pmni_rango as rango,
        ni.pmni_observacion as observacion,
        ni.pmni_cintalidentificadora as color,
        ni.pmni_estatus as estatus
    FROM pm_nivelesinfestacion ni
    JOIN pm_plagas p ON p.pmpl_id = ni.pmni_plaga
    WHERE p.pmpl_nombrecomun = p_plaga_nombre
    AND ni.pmni_estatus = 1
    ORDER BY ni.pmni_nivel;
END;
$$;


ALTER FUNCTION public.sp_get_niveles_plaga_api(p_plaga_nombre character varying) OWNER TO pestuser;

--
-- Name: sp_get_niveles_por_plaga(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_niveles_por_plaga(p_plaga_id integer) RETURNS TABLE(pmni_secuencia integer, pmni_nivel integer, pmni_plaga integer, pmni_nombrecomun character varying, pmni_rango character varying, pmni_lminferior integer, pmni_lmsuperior integer, pmni_tipoobservacion character varying, pmni_observacion text, pmni_cintaidentificadora character varying, pmni_estatus integer, pmni_creadopor integer, pmni_fechacreacion timestamp without time zone, pmni_modificadopor integer, pmni_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    ni.pmni_secuencia,
    ni.pmni_nivel,
    ni.pmni_plaga,
    ni.pmni_nombrecomun,
    ni.pmni_rango,
    ni.pmni_lminferior,
    ni.pmni_lmsuperior,
    ni.pmni_tipoobservacion,
    ni.pmni_observacion,
    ni.pmni_cintaidentificadora,
    ni.pmni_estatus,
    ni.pmni_creadopor,
    ni.pmni_fechacreacion,
    ni.pmni_modificadopor,
    ni.pmni_fechamodificacion
  FROM pm_nivelesinfestacion ni
  WHERE ni.pmni_plaga = p_plaga_id AND ni.pmni_estatus = 1
  ORDER BY ni.pmni_nivel ASC;
END;
$$;


ALTER FUNCTION public.sp_get_niveles_por_plaga(p_plaga_id integer) OWNER TO pestuser;

--
-- Name: sp_get_plaga_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_plaga_by_id(p_id integer) RETURNS TABLE(pmpl_id integer, pmpl_nombrecomun character varying, pmpl_genero character varying, pmpl_familia character varying, pmpl_tipo character varying, pmpl_estatus integer, pmpl_creadopor integer, pmpl_fechacreacion timestamp without time zone, pmpl_modificadopor integer, pmpl_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.pmpl_id,
    pl.pmpl_nombrecomun,
    pl.pmpl_genero,
    pl.pmpl_familia,
    pl.pmpl_tipo,
    pl.pmpl_estatus,
    pl.pmpl_creadopor,
    pl.pmpl_fechacreacion,
    pl.pmpl_modificadopor,
    pl.pmpl_fechamodificacion
  FROM pm_plagas pl
  WHERE pl.pmpl_id = p_id;
END;
$$;


ALTER FUNCTION public.sp_get_plaga_by_id(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_plagas(character varying, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_plagas(p_tipo character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_busqueda character varying DEFAULT NULL::character varying) RETURNS TABLE(pmpl_id integer, pmpl_nombrecomun character varying, pmpl_genero character varying, pmpl_familia character varying, pmpl_tipo character varying, pmpl_estatus integer, pmpl_creadopor integer, pmpl_fechacreacion timestamp without time zone, pmpl_modificadopor integer, pmpl_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pl.pmpl_id,
    pl.pmpl_nombrecomun,
    pl.pmpl_genero,
    pl.pmpl_familia,
    pl.pmpl_tipo,
    pl.pmpl_estatus,
    pl.pmpl_creadopor,
    pl.pmpl_fechacreacion,
    pl.pmpl_modificadopor,
    pl.pmpl_fechamodificacion
  FROM pm_plagas pl
  WHERE (p_tipo IS NULL OR pl.pmpl_tipo = p_tipo)
    AND (p_estatus IS NULL OR pl.pmpl_estatus = p_estatus)
    AND (p_busqueda IS NULL OR 
         pl.pmpl_nombrecomun ILIKE '%' || p_busqueda || '%' OR 
         pl.pmpl_genero ILIKE '%' || p_busqueda || '%' OR 
         pl.pmpl_familia ILIKE '%' || p_busqueda || '%')
  ORDER BY pl.pmpl_id DESC;
END;
$$;


ALTER FUNCTION public.sp_get_plagas(p_tipo character varying, p_estatus integer, p_busqueda character varying) OWNER TO pestuser;

--
-- Name: sp_get_plagas_activas(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_plagas_activas() RETURNS TABLE(pmpl_id integer, pmpl_nombrecomun character varying, pmpl_genero character varying, pmpl_familia character varying, pmpl_tipo character varying, pmpl_estatus integer, pmpl_creadopor integer, pmpl_fechacreacion timestamp without time zone, pmpl_modificadopor integer, pmpl_fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    p.pmpl_id,
    p.pmpl_nombrecomun,
    p.pmpl_genero,
    p.pmpl_familia,
    p.pmpl_tipo,
    p.pmpl_estatus,
    p.pmpl_creadopor,
    p.pmpl_fechacreacion,
    p.pmpl_modificadopor,
    p.pmpl_fechamodificacion
  FROM pm_plagas p
  WHERE p.pmpl_estatus = 1
  ORDER BY p.pmpl_nombrecomun;
END;
$$;


ALTER FUNCTION public.sp_get_plagas_activas() OWNER TO pestuser;

--
-- Name: sp_get_rol_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_rol_by_id(rol_id integer) RETURNS TABLE(id integer, descripcion character varying, estatus integer, fechacreacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmrl_id,
        pmrl_descripcion,
        pmrl_estatus,
        pmrl_fechacreacion
    FROM pm_rol
    WHERE pmrl_id = rol_id;
END;
$$;


ALTER FUNCTION public.sp_get_rol_by_id(rol_id integer) OWNER TO pestuser;

--
-- Name: sp_get_roles(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_roles(busqueda character varying DEFAULT NULL::character varying) RETURNS TABLE(id integer, descripcion character varying, estatus integer, fechacreacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmrl_id,
        pmrl_descripcion,
        pmrl_estatus,
        pmrl_fechacreacion
    FROM pm_rol
    WHERE (busqueda IS NULL OR pmrl_descripcion ILIKE '%' || busqueda || '%')
    ORDER BY pmrl_id DESC;
END;
$$;


ALTER FUNCTION public.sp_get_roles(busqueda character varying) OWNER TO pestuser;

--
-- Name: sp_get_roles_dropdown(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_roles_dropdown() RETURNS TABLE(id integer, descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmrl_id,
        pmrl_descripcion
    FROM pm_rol
    WHERE pmrl_estatus = 1
    ORDER BY pmrl_descripcion;
END;
$$;


ALTER FUNCTION public.sp_get_roles_dropdown() OWNER TO pestuser;

--
-- Name: sp_get_tipos_plagas(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_tipos_plagas() RETURNS TABLE(id integer, descripcion character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
  i INT := 1;
BEGIN
  CREATE TEMP TABLE temp_tipos (
    id INT,
    descripcion VARCHAR
  ) ON COMMIT DROP;
  
  -- Insertar tipos únicos en la tabla temporal con un ID secuencial
  INSERT INTO temp_tipos(id, descripcion)
  SELECT 
    ROW_NUMBER() OVER (ORDER BY pmpl_tipo) AS id, 
    pmpl_tipo AS descripcion
  FROM (
    SELECT DISTINCT pmpl_tipo 
    FROM pm_plagas 
    WHERE pmpl_tipo IS NOT NULL AND pmpl_tipo != ''
    ORDER BY pmpl_tipo
  ) AS tipos;

  -- Devolver los tipos con IDs
  RETURN QUERY SELECT t.id, t.descripcion FROM temp_tipos t ORDER BY t.descripcion;
END;
$$;


ALTER FUNCTION public.sp_get_tipos_plagas() OWNER TO pestuser;

--
-- Name: sp_get_unidad_cultivo_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_unidad_cultivo_by_id(p_secuencia integer) RETURNS TABLE(secuencia integer, codigo character varying, cantero character varying, id integer, estatus integer, creadopor integer, fechacreacion timestamp without time zone, modificadopor integer, fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pmuc_secuencia as secuencia,
    pmuc_codigo as codigo,
    pmuc_cantero as cantero,
    pmuc_id as id,
    pmuc_estatus as estatus,
    pmuc_creadopor as creadopor,
    pmuc_fechacreacion as fechacreacion,
    pmuc_modificadopor as modificadopor,
    pmuc_fechamodificacion as fechamodificacion
  FROM pm_unidadescultivo
  WHERE pmuc_secuencia = p_secuencia;
END;
$$;


ALTER FUNCTION public.sp_get_unidad_cultivo_by_id(p_secuencia integer) OWNER TO pestuser;

--
-- Name: sp_get_unidades_cultivo(character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_unidades_cultivo(p_busqueda character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer) RETURNS TABLE(secuencia integer, codigo character varying, cantero character varying, id integer, estatus integer, creadopor integer, fechacreacion timestamp without time zone, modificadopor integer, fechamodificacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
  -- Log para depuración
  RAISE NOTICE 'Ejecutando sp_get_unidades_cultivo con parámetros: p_busqueda=%, p_estatus=%', p_busqueda, p_estatus;

  RETURN QUERY
  SELECT 
    pmuc_secuencia as secuencia,
    pmuc_codigo as codigo,
    pmuc_cantero as cantero,
    pmuc_id as id,
    pmuc_estatus as estatus,
    pmuc_creadopor as creadopor,
    pmuc_fechacreacion as fechacreacion,
    pmuc_modificadopor as modificadopor,
    pmuc_fechamodificacion as fechamodificacion
  FROM pm_unidadescultivo
  WHERE (p_busqueda IS NULL OR 
         pmuc_codigo ILIKE '%' || p_busqueda || '%' OR 
         pmuc_cantero ILIKE '%' || p_busqueda || '%')
    AND (p_estatus IS NULL OR pmuc_estatus = p_estatus)
  ORDER BY pmuc_secuencia DESC;
END;
$$;


ALTER FUNCTION public.sp_get_unidades_cultivo(p_busqueda character varying, p_estatus integer) OWNER TO pestuser;

--
-- Name: sp_get_usuario_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_usuario_by_id(usuario_id integer) RETURNS TABLE(id integer, codigo integer, usuario character varying, funcion integer, rol_descripcion character varying, estatus integer, correo character varying, telefono character varying, fechacreacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.pmus_id,
        u.pmus_codigo,
        u.pmus_usuario,
        u.pmus_funcion,
        r.pmrl_descripcion,
        u.pmus_estatus,
        u.pmus_correo,
        u.pmus_telefono,
        u.pmus_fechacreacion
    FROM pm_usuarios u
    LEFT JOIN pm_rol r ON u.pmus_funcion = r.pmrl_id
    WHERE u.pmus_id = usuario_id;
END;
$$;


ALTER FUNCTION public.sp_get_usuario_by_id(usuario_id integer) OWNER TO pestuser;

--
-- Name: sp_get_usuario_login(character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_usuario_login(username_param character varying) RETURNS TABLE(usuario_id integer, usuario character varying, funcion integer, password character varying, estatus integer)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmus_id,
        pmus_usuario,
        pmus_funcion,
        pmus_password,
        pmus_estatus
    FROM pm_usuarios
    WHERE pmus_usuario = username_param;
END;
$$;


ALTER FUNCTION public.sp_get_usuario_login(username_param character varying) OWNER TO pestuser;

--
-- Name: sp_get_usuarios(integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_usuarios(rol_id integer DEFAULT NULL::integer, estatus_param integer DEFAULT NULL::integer, busqueda character varying DEFAULT NULL::character varying) RETURNS TABLE(id integer, codigo integer, usuario character varying, funcion integer, rol_descripcion character varying, estatus integer, correo character varying, telefono character varying, fechacreacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        u.pmus_id,
        u.pmus_codigo,
        u.pmus_usuario,
        u.pmus_funcion,
        r.pmrl_descripcion,
        u.pmus_estatus,
        u.pmus_correo,
        u.pmus_telefono,
        u.pmus_fechacreacion
    FROM pm_usuarios u
    LEFT JOIN pm_rol r ON u.pmus_funcion = r.pmrl_id
    WHERE (rol_id IS NULL OR u.pmus_funcion = rol_id)
    AND (estatus_param IS NULL OR u.pmus_estatus = estatus_param)
    AND (busqueda IS NULL OR 
         u.pmus_usuario ILIKE '%' || busqueda || '%' OR 
         CAST(u.pmus_codigo AS TEXT) ILIKE '%' || busqueda || '%')
    ORDER BY u.pmus_id DESC;
END;
$$;


ALTER FUNCTION public.sp_get_usuarios(rol_id integer, estatus_param integer, busqueda character varying) OWNER TO pestuser;

--
-- Name: sp_get_variedad_by_id(integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_variedad_by_id(p_id integer) RETURNS TABLE(id integer, codigo character varying, descripcion character varying, responsable character varying, estatus integer, fecha_creacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmva_id,
        pmva_codigo,
        pmva_descripcion,
        pmva_responsable,
        pmva_estatus,
        pmva_fechacreacion
    FROM 
        pm_variedades 
    WHERE 
        pmva_id = p_id;
END;
$$;


ALTER FUNCTION public.sp_get_variedad_by_id(p_id integer) OWNER TO pestuser;

--
-- Name: sp_get_variedades(character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_variedades(p_busqueda character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer) RETURNS TABLE(id integer, codigo character varying, descripcion character varying, responsable character varying, estatus integer, fecha_creacion timestamp without time zone)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmva_id,
        pmva_codigo,
        pmva_descripcion,
        pmva_responsable,
        pmva_estatus,
        pmva_fechacreacion
    FROM 
        pm_variedades
    WHERE 
        (p_estatus IS NULL OR pmva_estatus = p_estatus)
        AND
        (p_busqueda IS NULL OR 
            pmva_descripcion ILIKE '%' || p_busqueda || '%' OR 
            pmva_codigo ILIKE '%' || p_busqueda || '%')
    ORDER BY 
        pmva_id DESC;
END;
$$;


ALTER FUNCTION public.sp_get_variedades(p_busqueda character varying, p_estatus integer) OWNER TO pestuser;

--
-- Name: sp_get_variedades_activas(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_variedades_activas() RETURNS TABLE(pmva_codigo character varying, pmva_descripcion character varying, pmva_responsable character varying, pmva_ancho numeric, pmva_estatus integer, pmva_creadopor integer, pmva_fechacreacion timestamp without time zone, pmva_modificadopor integer, pmva_fechamodificacion timestamp without time zone, cuenta bigint)
    LANGUAGE plpgsql
    AS $$
BEGIN
  RETURN QUERY
  SELECT 
    v.*,
    COUNT(m.pmmo_secuencia) as cuenta
  FROM pm_variedades v
  LEFT JOIN pm_lotes l ON l.pmlt_idvariedad = v.pmva_codigo::INT
  LEFT JOIN pm_monitoreos m ON m.pmlt_codigo = l.pmlt_codigo AND m.pmmo_estatus = 1
  WHERE v.pmva_estatus = 1
  GROUP BY v.pmva_codigo, v.pmva_descripcion, v.pmva_responsable, v.pmva_ancho, 
           v.pmva_estatus, v.pmva_creadopor, v.pmva_fechacreacion, 
           v.pmva_modificadopor, v.pmva_fechamodificacion
  ORDER BY v.pmva_descripcion;
END;
$$;


ALTER FUNCTION public.sp_get_variedades_activas() OWNER TO pestuser;

--
-- Name: FUNCTION sp_get_variedades_activas(); Type: COMMENT; Schema: public; Owner: pestuser
--

COMMENT ON FUNCTION public.sp_get_variedades_activas() IS 'Función para obtener las variedades activas con conteo de monitoreos.';


--
-- Name: sp_get_variedades_dropdown(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_get_variedades_dropdown() RETURNS TABLE(id integer, descripcion character varying)
    LANGUAGE plpgsql
    AS $$
BEGIN
    RETURN QUERY
    SELECT 
        pmva_id,
        pmva_descripcion
    FROM 
        pm_variedades
    WHERE 
        pmva_estatus = 1
    ORDER BY 
        pmva_descripcion;
END;
$$;


ALTER FUNCTION public.sp_get_variedades_dropdown() OWNER TO pestuser;

--
-- Name: sp_import_lotes_batch(json); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_import_lotes_batch(p_lotes json) RETURNS TABLE(success boolean, message text, lotes_creados integer, errores json)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_lote JSON;
    v_codigo VARCHAR;
    v_canteros VARCHAR;
    v_cantidad INTEGER;
    v_estatus INTEGER;
    v_idvariedad INTEGER;
    v_contenedor VARCHAR;
    v_grower VARCHAR;
    v_variedad VARCHAR;
    v_casa VARCHAR;
    v_creadopor INTEGER;
    v_code_exists BOOLEAN;
    v_creados INTEGER := 0;
    v_errores JSON[] := '{}';
    v_error_info JSON;
    v_lote_idx INTEGER := 0;
BEGIN
    -- Verificar si el JSON de lotes está vacío
    IF p_lotes IS NULL OR p_lotes::TEXT = '[]' THEN
        RETURN QUERY
        SELECT false, 'No se proporcionaron lotes para importar', 0, '[]'::JSON;
        RETURN;
    END IF;
    
    -- Procesar cada lote del JSON
    FOR v_lote IN SELECT * FROM json_array_elements(p_lotes)
    LOOP
        v_lote_idx := v_lote_idx + 1;
        BEGIN
            -- Extraer valores del JSON para cada lote
            v_codigo := v_lote->>'pmlt_codigo';
            v_canteros := v_lote->>'pmlt_canteros';
            
            -- Convertir cantidad a INTEGER con manejo de nulos
            BEGIN
                v_cantidad := (v_lote->>'pmlt_cantidad')::INTEGER;
            EXCEPTION WHEN OTHERS THEN
                v_cantidad := 0;
            END;
            
            -- Convertir estatus a INTEGER con manejo de nulos
            BEGIN
                v_estatus := (v_lote->>'pmlt_estatus')::INTEGER;
            EXCEPTION WHEN OTHERS THEN
                v_estatus := 1;
            END;
            
            -- Convertir idvariedad a INTEGER con manejo de nulos
            BEGIN
                v_idvariedad := (v_lote->>'pmlt_idvariedad')::INTEGER;
            EXCEPTION WHEN OTHERS THEN
                v_idvariedad := NULL;
            END;
            
            v_contenedor := v_lote->>'pmlt_contenedor';
            v_grower := v_lote->>'pmlt_grower';
            v_variedad := v_lote->>'pmlt_variedad';
            v_casa := v_lote->>'pmlt_casa';
            
            -- Convertir creadopor a INTEGER con manejo de nulos
            BEGIN
                v_creadopor := (v_lote->>'pmlt_creadopor')::INTEGER;
            EXCEPTION WHEN OTHERS THEN
                v_creadopor := 1;
            END;
            
            -- Validar código (campo obligatorio)
            IF v_codigo IS NULL OR v_codigo = '' THEN
                v_error_info := json_build_object(
                    'lote', v_lote_idx,
                    'error', 'El código del lote es obligatorio'
                );
                v_errores := array_append(v_errores, v_error_info);
                CONTINUE;
            END IF;
            
            -- Verificar si ya existe un lote con el mismo código
            SELECT EXISTS(
                SELECT 1 FROM pm_lotes WHERE pmlt_codigo = v_codigo
            ) INTO v_code_exists;
            
            IF v_code_exists THEN
                v_error_info := json_build_object(
                    'lote', v_lote_idx,
                    'codigo', v_codigo,
                    'error', 'Ya existe un lote con ese código'
                );
                v_errores := array_append(v_errores, v_error_info);
                CONTINUE;
            END IF;
            
            -- Insertar el lote
            INSERT INTO pm_lotes (
                pmlt_codigo,
                pmlt_canteros,
                pmlt_cantidad,
                pmlt_estatus,
                pmlt_idvariedad,
                pmlt_contenedor,
                pmlt_grower,
                pmlt_variedad,
                pmlt_casa,
                pmlt_creadopor,
                pmlt_fechacreacion
            ) VALUES (
                v_codigo,
                v_canteros,
                v_cantidad,
                v_estatus,
                v_idvariedad,
                v_contenedor,
                v_grower,
                v_variedad,
                v_casa,
                v_creadopor,
                NOW()
            );
            
            v_creados := v_creados + 1;
            
        EXCEPTION WHEN OTHERS THEN
            v_error_info := json_build_object(
                'lote', v_lote_idx,
                'codigo', v_codigo,
                'error', 'Error: ' || SQLERRM
            );
            v_errores := array_append(v_errores, v_error_info);
        END;
    END LOOP;
    
    -- Retornar resultados
    RETURN QUERY
    SELECT 
        true, 
        'Importación completada: ' || v_creados || ' lotes creados' || 
        CASE 
            WHEN array_length(v_errores, 1) > 0 
            THEN ' con ' || array_length(v_errores, 1)::TEXT || ' errores' 
            ELSE '' 
        END,
        v_creados,
        CASE 
            WHEN array_length(v_errores, 1) > 0 
            THEN to_json(v_errores) 
            ELSE '[]'::JSON 
        END;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error en la importación: ' || SQLERRM, 0, '[]'::JSON;
END;
$$;


ALTER FUNCTION public.sp_import_lotes_batch(p_lotes json) OWNER TO pestuser;

--
-- Name: sp_update_lote(integer, character varying, character varying, integer, integer, integer, character varying, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_lote(p_id integer, p_codigo character varying, p_canteros character varying DEFAULT NULL::character varying, p_cantidad integer DEFAULT 0, p_estatus integer DEFAULT 1, p_idvariedad integer DEFAULT NULL::integer, p_contenedor character varying DEFAULT NULL::character varying, p_grower character varying DEFAULT NULL::character varying, p_variedad character varying DEFAULT NULL::character varying, p_casa character varying DEFAULT NULL::character varying, p_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message text, lote_data json)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_exists BOOLEAN;
    v_code_exists BOOLEAN;
    v_lote_actualizado pm_lotes%ROWTYPE;
BEGIN
    -- Validar campos obligatorios
    IF p_codigo IS NULL OR p_codigo = '' THEN
        RETURN QUERY
        SELECT false, 'El código del lote es obligatorio', NULL::JSON;
        RETURN;
    END IF;
    
    -- Verificar si el lote existe
    SELECT EXISTS(
        SELECT 1 FROM pm_lotes WHERE pmlt_secuencia = p_id
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RETURN QUERY
        SELECT false, 'Lote no encontrado', NULL::JSON;
        RETURN;
    END IF;
    
    -- Verificar si ya existe otro lote con el mismo código
    SELECT EXISTS(
        SELECT 1 FROM pm_lotes 
        WHERE pmlt_codigo = p_codigo AND pmlt_secuencia <> p_id
    ) INTO v_code_exists;
    
    IF v_code_exists THEN
        RETURN QUERY
        SELECT false, 'Ya existe otro lote con ese código', NULL::JSON;
        RETURN;
    END IF;
    
    -- Actualizar lote
    UPDATE pm_lotes SET
        pmlt_codigo = p_codigo,
        pmlt_canteros = p_canteros,
        pmlt_cantidad = p_cantidad,
        pmlt_estatus = p_estatus,
        pmlt_idvariedad = p_idvariedad,
        pmlt_contenedor = p_contenedor,
        pmlt_grower = p_grower,
        pmlt_variedad = p_variedad,
        pmlt_casa = p_casa,
        pmlt_modificadopor = p_modificadopor,
        pmlt_fechamodificacion = NOW()
    WHERE 
        pmlt_secuencia = p_id
    RETURNING * INTO v_lote_actualizado;
    
    -- Retornar éxito con objeto JSON del lote actualizado
    RETURN QUERY
    SELECT 
        true, 
        'Lote actualizado exitosamente', 
        row_to_json(v_lote_actualizado)::JSON;
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM, NULL::JSON;
END;
$$;


ALTER FUNCTION public.sp_update_lote(p_id integer, p_codigo character varying, p_canteros character varying, p_cantidad integer, p_estatus integer, p_idvariedad integer, p_contenedor character varying, p_grower character varying, p_variedad character varying, p_casa character varying, p_modificadopor integer) OWNER TO pestuser;

--
-- Name: sp_update_monitoreo(integer, character varying, character varying, character varying, character varying, character varying, character varying, character varying, character varying, integer, integer, text, timestamp without time zone, boolean, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, integer, character varying); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_monitoreo(p_pmmo_secuencia integer, p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_canteros character varying, p_pmmo_variedad character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_estatus integer, p_pmmo_modificadopor integer, p_pmmo_nivmuestram1 integer, p_pmmo_nivmuestram2 integer, p_pmmo_nivmuestram3 integer, p_pmmo_nivmuestraa1 integer, p_pmmo_nivmuestraa2 integer, p_pmmo_nivmuestraa3 integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_contenedor character varying) RETURNS TABLE(success boolean, message character varying, id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_plaga_id INT;
    v_current_timestamp TIMESTAMP := CURRENT_TIMESTAMP;
    v_affected_rows INT;
BEGIN
    -- Verificar si el monitoreo existe
    PERFORM 1
    FROM pm_monitoreos
    WHERE pmmo_secuencia = p_pmmo_secuencia;
    
    IF NOT FOUND THEN
        RETURN QUERY SELECT 
            FALSE, 
            'No se encontró el monitoreo con ID: '||p_pmmo_secuencia::VARCHAR(255), 
            NULL::INT;
        RETURN;
    END IF;

    -- Obtener ID de la plaga por nombre
    SELECT pmpl_id INTO v_plaga_id
    FROM pm_plagas
    WHERE pmpl_nombrecomun = p_pmni_nombrecomun AND pmpl_estatus = 1;
    
    -- Verificar si se encontró la plaga
    IF v_plaga_id IS NULL THEN
        RETURN QUERY SELECT 
            FALSE, 
            ('No se encontró la plaga con nombre: ' || p_pmni_nombrecomun)::VARCHAR(255), 
            NULL::INT;
        RETURN;
    END IF;
    
    -- Actualizar monitoreo y contar filas afectadas
    UPDATE pm_monitoreos
    SET 
        pmlt_codigo = p_pmlt_codigo,
        pmmo_casa = p_pmmo_casa,
        pmmo_cantero = p_pmmo_cantero,
        pmmo_canteros = p_pmmo_canteros,
        pmmo_variedad = p_pmmo_variedad,
        pmmo_idvariedad = p_pmmo_idvariedad,
        pmmo_grower = p_pmmo_grower,
        pmni_id = v_plaga_id,
        pmmo_cantidad = p_pmmo_cantidad,
        pmmo_cant_botada = p_pmmo_cant_botada,
        pmmo_comentarios = p_pmmo_comentarios,
        pmmo_fecha = p_pmmo_fecha,
        pmmo_automatico = p_pmmo_automatico,
        pmmo_estatus = p_pmmo_estatus,
        pmmo_modificadopor = p_pmmo_modificadopor,
        pmmo_fechamodificacion = v_current_timestamp,
        pmmo_nivmuestram1 = p_pmmo_nivmuestram1,
        pmmo_nivmuestram2 = p_pmmo_nivmuestram2,
        pmmo_nivmuestram3 = p_pmmo_nivmuestram3,
        pmmo_nivmuestraa1 = p_pmmo_nivmuestraa1,
        pmmo_nivmuestraa2 = p_pmmo_nivmuestraa2,
        pmmo_nivmuestraa3 = p_pmmo_nivmuestraa3,
        pmmo_muestra1 = p_pmmo_muestra1,
        pmmo_muestra2 = p_pmmo_muestra2,
        pmmo_muestra3 = p_pmmo_muestra3,
        pmmo_contenedor = p_pmmo_contenedor
    WHERE pmmo_secuencia = p_pmmo_secuencia;
    
    GET DIAGNOSTICS v_affected_rows = ROW_COUNT;
    
    -- Verificar si se actualizó correctamente
    IF v_affected_rows > 0 THEN
        RETURN QUERY SELECT TRUE, 'Monitoreo actualizado correctamente'::VARCHAR(255), p_pmmo_secuencia;
    ELSE
        RETURN QUERY SELECT FALSE, 'No se pudo actualizar el monitoreo. Verifique los datos'::VARCHAR(255), NULL::INT;
    END IF;
END;
$$;


ALTER FUNCTION public.sp_update_monitoreo(p_pmmo_secuencia integer, p_pmlt_codigo character varying, p_pmmo_casa character varying, p_pmmo_cantero character varying, p_pmmo_canteros character varying, p_pmmo_variedad character varying, p_pmmo_idvariedad character varying, p_pmmo_grower character varying, p_pmni_nombrecomun character varying, p_pmmo_cantidad integer, p_pmmo_cant_botada integer, p_pmmo_comentarios text, p_pmmo_fecha timestamp without time zone, p_pmmo_automatico boolean, p_pmmo_estatus integer, p_pmmo_modificadopor integer, p_pmmo_nivmuestram1 integer, p_pmmo_nivmuestram2 integer, p_pmmo_nivmuestram3 integer, p_pmmo_nivmuestraa1 integer, p_pmmo_nivmuestraa2 integer, p_pmmo_nivmuestraa3 integer, p_pmmo_muestra1 integer, p_pmmo_muestra2 integer, p_pmmo_muestra3 integer, p_pmmo_contenedor character varying) OWNER TO pestuser;

--
-- Name: sp_update_nivel(integer, character varying, integer, integer, character varying, text, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_nivel(p_secuencia integer, p_rango character varying, p_lminferior integer DEFAULT NULL::integer, p_lmsuperior integer DEFAULT NULL::integer, p_tipoobservacion character varying DEFAULT NULL::character varying, p_observacion text DEFAULT NULL::text, p_cintaidentificadora character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, nivel_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_exists BOOLEAN;
BEGIN
  -- Validaciones básicas
  IF p_rango IS NULL OR p_rango = '' THEN
    RETURN QUERY SELECT FALSE, 'El rango es obligatorio'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar si el nivel existe
  SELECT EXISTS (
    SELECT 1 FROM pm_nivelesinfestacion WHERE pmni_secuencia = p_secuencia
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'Nivel de infestación no encontrado'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Actualizar nivel de infestación
  UPDATE pm_nivelesinfestacion SET 
    pmni_rango = p_rango,
    pmni_lminferior = COALESCE(p_lminferior, pmni_lminferior),
    pmni_lmsuperior = COALESCE(p_lmsuperior, pmni_lmsuperior),
    pmni_tipoobservacion = p_tipoobservacion,
    pmni_observacion = p_observacion,
    pmni_cintaidentificadora = p_cintaidentificadora,
    pmni_estatus = COALESCE(p_estatus, pmni_estatus),
    pmni_modificadopor = p_modificadopor,
    pmni_fechamodificacion = NOW()
  WHERE pmni_secuencia = p_secuencia;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Nivel de infestación actualizado correctamente'::VARCHAR, p_secuencia;
END;
$$;


ALTER FUNCTION public.sp_update_nivel(p_secuencia integer, p_rango character varying, p_lminferior integer, p_lmsuperior integer, p_tipoobservacion character varying, p_observacion text, p_cintaidentificadora character varying, p_estatus integer, p_modificadopor integer) OWNER TO pestuser;

--
-- Name: sp_update_plaga(integer, character varying, character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_plaga(p_id integer, p_nombrecomun character varying, p_genero character varying DEFAULT NULL::character varying, p_familia character varying DEFAULT NULL::character varying, p_tipo character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT NULL::integer, p_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying, plaga_id integer)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_exists BOOLEAN;
  v_estatus_actual INT;
BEGIN
  -- Validaciones básicas
  IF p_nombrecomun IS NULL OR p_nombrecomun = '' THEN
    RETURN QUERY SELECT FALSE, 'El nombre común de la plaga es obligatorio'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Verificar si la plaga existe
  SELECT EXISTS (
    SELECT 1 FROM pm_plagas WHERE pmpl_id = p_id
  ) INTO v_exists;
  
  IF NOT v_exists THEN
    RETURN QUERY SELECT FALSE, 'Plaga no encontrada'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Obtener el estado actual
  SELECT pmpl_estatus INTO v_estatus_actual FROM pm_plagas WHERE pmpl_id = p_id;
  
  -- Verificar si ya existe otra plaga con el mismo nombre
  SELECT EXISTS (
    SELECT 1 FROM pm_plagas 
    WHERE pmpl_nombrecomun = p_nombrecomun AND pmpl_id != p_id
  ) INTO v_exists;
  
  IF v_exists THEN
    RETURN QUERY SELECT FALSE, 'Ya existe otra plaga con ese nombre común'::VARCHAR, NULL::INT;
    RETURN;
  END IF;
  
  -- Actualizar plaga
  UPDATE pm_plagas SET 
    pmpl_nombrecomun = p_nombrecomun,
    pmpl_genero = p_genero,
    pmpl_familia = p_familia,
    pmpl_tipo = p_tipo,
    pmpl_estatus = COALESCE(p_estatus, pmpl_estatus),
    pmpl_modificadopor = p_modificadopor,
    pmpl_fechamodificacion = NOW()
  WHERE pmpl_id = p_id;
  
  -- Si estamos reactivando la plaga (de inactivo a activo)
  IF v_estatus_actual = 0 AND COALESCE(p_estatus, 1) = 1 THEN
    -- Reactivar los niveles de infestación asociados
    UPDATE pm_nivelesinfestacion 
    SET pmni_estatus = 1, 
        pmni_fechamodificacion = NOW()
    WHERE pmni_plaga = p_id;
  END IF;
  
  -- Devolver resultado exitoso
  RETURN QUERY SELECT TRUE, 'Plaga actualizada correctamente'::VARCHAR, p_id;
END;
$$;


ALTER FUNCTION public.sp_update_plaga(p_id integer, p_nombrecomun character varying, p_genero character varying, p_familia character varying, p_tipo character varying, p_estatus integer, p_modificadopor integer) OWNER TO pestuser;

--
-- Name: sp_update_rol(integer, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_rol(rol_id integer, descripcion_param character varying, estatus_param integer DEFAULT 1, modificador_param integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    existe_rol BOOLEAN;
    existe_duplicado BOOLEAN;
BEGIN
    -- Verificar si el rol existe
    SELECT EXISTS(
        SELECT 1 FROM pm_rol WHERE pmrl_id = rol_id
    ) INTO existe_rol;
    
    IF NOT existe_rol THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Rol no encontrado'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Verificar si ya existe otro rol con el mismo nombre
    SELECT EXISTS(
        SELECT 1 FROM pm_rol 
        WHERE pmrl_descripcion = descripcion_param 
        AND pmrl_id != rol_id
    ) INTO existe_duplicado;
    
    IF existe_duplicado THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Ya existe otro rol con esa descripción'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Actualizar rol
    UPDATE pm_rol SET 
        pmrl_descripcion = descripcion_param,
        pmrl_estatus = estatus_param,
        pmrl_modificadopor = modificador_param,
        pmrl_fechamodificacion = NOW()
    WHERE pmrl_id = rol_id;
    
    -- Retornar resultado exitoso
    RETURN QUERY SELECT 
        TRUE::BOOLEAN AS success, 
        'Rol actualizado correctamente'::VARCHAR(255) AS message;
END;
$$;


ALTER FUNCTION public.sp_update_rol(rol_id integer, descripcion_param character varying, estatus_param integer, modificador_param integer) OWNER TO pestuser;

--
-- Name: sp_update_unidad_cultivo(integer, character varying, character varying, integer, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_unidad_cultivo(p_secuencia integer, p_codigo character varying, p_cantero character varying, p_id integer DEFAULT NULL::integer, p_estatus integer DEFAULT NULL::integer, p_modificadopor integer DEFAULT 1) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
  v_existe INT;
  v_duplicado INT;
BEGIN
  -- Verificar parámetros requeridos
  IF p_codigo IS NULL OR trim(p_codigo) = '' THEN
    RETURN QUERY SELECT FALSE, 'El código es obligatorio';
    RETURN;
  END IF;
  
  IF p_cantero IS NULL OR trim(p_cantero) = '' THEN
    RETURN QUERY SELECT FALSE, 'El cantero es obligatorio';
    RETURN;
  END IF;
  
  -- Verificar si la unidad existe
  SELECT COUNT(*) INTO v_existe FROM pm_unidadescultivo WHERE pmuc_secuencia = p_secuencia;
  IF v_existe = 0 THEN
    RETURN QUERY SELECT FALSE, 'Unidad de cultivo no encontrada';
    RETURN;
  END IF;
  
  -- Verificar si ya existe otra unidad con el mismo código
  SELECT COUNT(*) INTO v_duplicado 
  FROM pm_unidadescultivo 
  WHERE pmuc_codigo = p_codigo AND pmuc_secuencia != p_secuencia;
  
  IF v_duplicado > 0 THEN
    RETURN QUERY SELECT FALSE, 'Ya existe otra unidad de cultivo con ese código';
    RETURN;
  END IF;
  
  -- Actualizar unidad de cultivo
  UPDATE pm_unidadescultivo SET 
    pmuc_codigo = p_codigo,
    pmuc_cantero = p_cantero,
    pmuc_id = COALESCE(p_id, pmuc_id),
    pmuc_estatus = COALESCE(p_estatus, pmuc_estatus),
    pmuc_modificadopor = COALESCE(p_modificadopor, 1),
    pmuc_fechamodificacion = NOW()
  WHERE pmuc_secuencia = p_secuencia;
  
  RETURN QUERY SELECT TRUE, 'Unidad de cultivo actualizada correctamente';
END;
$$;


ALTER FUNCTION public.sp_update_unidad_cultivo(p_secuencia integer, p_codigo character varying, p_cantero character varying, p_id integer, p_estatus integer, p_modificadopor integer) OWNER TO pestuser;

--
-- Name: sp_update_usuario(integer, character varying, integer, integer, integer, character varying, character varying, character varying, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_usuario(usuario_id integer, usuario_param character varying, funcion_param integer, codigo_param integer DEFAULT 0, estatus_param integer DEFAULT 1, password_param character varying DEFAULT NULL::character varying, correo_param character varying DEFAULT NULL::character varying, telefono_param character varying DEFAULT NULL::character varying, modificador_param integer DEFAULT 1) RETURNS TABLE(success boolean, message character varying)
    LANGUAGE plpgsql
    AS $$
DECLARE
    existe_usuario BOOLEAN;
    existe_duplicado BOOLEAN;
BEGIN
    -- Verificar si el usuario existe
    SELECT EXISTS(
        SELECT 1 FROM pm_usuarios WHERE pmus_id = usuario_id
    ) INTO existe_usuario;
    
    IF NOT existe_usuario THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Usuario no encontrado'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Verificar si ya existe otro usuario con el mismo nombre
    SELECT EXISTS(
        SELECT 1 FROM pm_usuarios 
        WHERE pmus_usuario = usuario_param 
        AND pmus_id != usuario_id
    ) INTO existe_duplicado;
    
    IF existe_duplicado THEN
        RETURN QUERY SELECT 
            FALSE::BOOLEAN AS success, 
            'Ya existe otro usuario con ese nombre'::VARCHAR(255) AS message;
        RETURN;
    END IF;
    
    -- Actualizar usuario
    IF password_param IS NULL THEN
        -- Actualizar sin cambiar la contraseña
        UPDATE pm_usuarios SET 
            pmus_codigo = codigo_param,
            pmus_usuario = usuario_param,
            pmus_funcion = funcion_param,
            pmus_estatus = estatus_param,
            pmus_modificadopor = modificador_param,
            pmus_fechamodificacion = NOW(),
            pmus_correo = correo_param,
            pmus_telefono = telefono_param
        WHERE pmus_id = usuario_id;
    ELSE
        -- Actualizar incluyendo la contraseña
        UPDATE pm_usuarios SET 
            pmus_codigo = codigo_param,
            pmus_usuario = usuario_param,
            pmus_funcion = funcion_param,
            pmus_estatus = estatus_param,
            pmus_modificadopor = modificador_param,
            pmus_fechamodificacion = NOW(),
            pmus_correo = correo_param,
            pmus_telefono = telefono_param,
            pmus_password = password_param
        WHERE pmus_id = usuario_id;
    END IF;
    
    -- Retornar resultado exitoso con conversión explícita de tipos
    RETURN QUERY SELECT 
        TRUE::BOOLEAN AS success, 
        'Usuario actualizado correctamente'::VARCHAR(255) AS message;
END;
$$;


ALTER FUNCTION public.sp_update_usuario(usuario_id integer, usuario_param character varying, funcion_param integer, codigo_param integer, estatus_param integer, password_param character varying, correo_param character varying, telefono_param character varying, modificador_param integer) OWNER TO pestuser;

--
-- Name: sp_update_usuario_status(integer, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_usuario_status(usuario_id integer, nuevo_estatus integer, modificador_id integer DEFAULT 1) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
DECLARE
    existe_usuario BOOLEAN;
BEGIN
    -- Verificar si el usuario existe
    SELECT EXISTS(
        SELECT 1 FROM pm_usuarios WHERE pmus_id = usuario_id
    ) INTO existe_usuario;
    
    IF NOT existe_usuario THEN
        RETURN FALSE;
    END IF;
    
    -- Actualizar estatus
    UPDATE pm_usuarios SET 
        pmus_estatus = nuevo_estatus,
        pmus_modificadopor = modificador_id,
        pmus_fechamodificacion = NOW()
    WHERE pmus_id = usuario_id;
    
    RETURN TRUE;
END;
$$;


ALTER FUNCTION public.sp_update_usuario_status(usuario_id integer, nuevo_estatus integer, modificador_id integer) OWNER TO pestuser;

--
-- Name: sp_update_variedad(integer, character varying, character varying, character varying, integer, integer); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.sp_update_variedad(p_id integer, p_codigo character varying, p_descripcion character varying, p_responsable character varying DEFAULT NULL::character varying, p_estatus integer DEFAULT 1, p_modificado_por integer DEFAULT 1) RETURNS TABLE(success boolean, message text)
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_exists BOOLEAN;
    v_code_exists BOOLEAN;
BEGIN
    -- Validar campos obligatorios
    IF p_codigo IS NULL OR p_codigo = '' THEN
        RETURN QUERY
        SELECT false, 'El código es obligatorio';
        RETURN;
    END IF;
    
    IF p_descripcion IS NULL OR p_descripcion = '' THEN
        RETURN QUERY
        SELECT false, 'La descripción es obligatoria';
        RETURN;
    END IF;
    
    -- Verificar si la variedad existe
    SELECT EXISTS(
        SELECT 1 FROM pm_variedades WHERE pmva_id = p_id
    ) INTO v_exists;
    
    IF NOT v_exists THEN
        RETURN QUERY
        SELECT false, 'Variedad no encontrada';
        RETURN;
    END IF;
    
    -- Verificar si ya existe otra variedad con el mismo código
    SELECT EXISTS(
        SELECT 1 FROM pm_variedades 
        WHERE pmva_codigo = p_codigo AND pmva_id <> p_id
    ) INTO v_code_exists;
    
    IF v_code_exists THEN
        RETURN QUERY
        SELECT false, 'Ya existe otra variedad con ese código';
        RETURN;
    END IF;
    
    -- Actualizar la variedad
    UPDATE pm_variedades SET
        pmva_codigo = p_codigo,
        pmva_descripcion = p_descripcion,
        pmva_responsable = p_responsable,
        pmva_estatus = p_estatus,
        pmva_modificadopor = p_modificado_por,
        pmva_fechamodificacion = NOW()
    WHERE pmva_id = p_id;
    
    -- Retornar éxito
    RETURN QUERY
    SELECT true, 'Variedad actualizada exitosamente';
    
EXCEPTION WHEN OTHERS THEN
    RETURN QUERY
    SELECT false, 'Error: ' || SQLERRM;
END;
$$;


ALTER FUNCTION public.sp_update_variedad(p_id integer, p_codigo character varying, p_descripcion character varying, p_responsable character varying, p_estatus integer, p_modificado_por integer) OWNER TO pestuser;

--
-- Name: trigger_consistencia_plagas(); Type: FUNCTION; Schema: public; Owner: pestuser
--

CREATE FUNCTION public.trigger_consistencia_plagas() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    -- Si se inserta/actualiza pmni_plaga, actualizar también pmni_nombrecomun
    IF NEW.pmni_plaga IS NOT NULL THEN
        SELECT pmpl_nombrecomun INTO NEW.pmni_nombrecomun
        FROM pm_plagas 
        WHERE pmpl_id = NEW.pmni_plaga;
    END IF;
    
    RETURN NEW;
END;
$$;


ALTER FUNCTION public.trigger_consistencia_plagas() OWNER TO pestuser;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: pm_lotes; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_lotes (
    pmlt_secuencia integer NOT NULL,
    pmlt_codigo character varying(50),
    pmlt_casa character varying(50),
    pmlt_canteros character varying(100),
    pmlt_idvariedad integer,
    pmlt_contenedor character varying(100),
    pmlt_cantidad integer,
    pmlt_grower character varying(100),
    pmlt_variedad character varying(100),
    pmlt_estatus integer DEFAULT 1,
    pmlt_creadopor integer,
    pmlt_fechacreacion timestamp without time zone DEFAULT now(),
    pmlt_modificadopor integer,
    pmlt_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_lotes OWNER TO pestuser;

--
-- Name: pm_lotes_pmlt_secuencia_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_lotes_pmlt_secuencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_lotes_pmlt_secuencia_seq OWNER TO pestuser;

--
-- Name: pm_lotes_pmlt_secuencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_lotes_pmlt_secuencia_seq OWNED BY public.pm_lotes.pmlt_secuencia;


--
-- Name: pm_monitoreos; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_monitoreos (
    pmmo_secuencia integer NOT NULL,
    pmlt_codigo character varying(50),
    pmmo_casa character varying(50),
    pmmo_canteros character varying(100),
    pmmo_idvariedad character varying(50),
    pmmo_contenedor character varying(100),
    pmmo_cantidad integer,
    pmmo_grower character varying(100),
    pmmo_variedad character varying(100),
    pmmo_cantero character varying(50),
    pmni_nombrecomun character varying(100),
    pmmo_muestra1 integer,
    pmmo_muestra2 integer,
    pmmo_muestra3 integer,
    lmsupniv1 integer,
    lmsupniv2 integer,
    lmsupniv3 integer,
    pmmo_nivmuestraa1 integer,
    pmmo_nivmuestraa2 integer,
    pmmo_nivmuestraa3 integer,
    pmmo_nivmuestram1 integer,
    pmmo_nivmuestram2 integer,
    pmmo_nivmuestram3 integer,
    pmmo_estatus integer DEFAULT 1,
    pmmo_fecha timestamp without time zone DEFAULT now(),
    pmmo_creadopor integer,
    pmmo_fechacreacion timestamp without time zone DEFAULT now(),
    pmmo_modificadopor integer,
    pmmo_fechamodificacion timestamp without time zone,
    pmmo_comentarios character varying(255),
    pmmo_cant_botada integer,
    pmmo_automatico boolean,
    pmni_id integer
);


ALTER TABLE public.pm_monitoreos OWNER TO pestuser;

--
-- Name: pm_monitoreos_pmmo_secuencia_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_monitoreos_pmmo_secuencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_monitoreos_pmmo_secuencia_seq OWNER TO pestuser;

--
-- Name: pm_monitoreos_pmmo_secuencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_monitoreos_pmmo_secuencia_seq OWNED BY public.pm_monitoreos.pmmo_secuencia;


--
-- Name: pm_nivelesinfestacion; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_nivelesinfestacion (
    pmni_secuencia integer NOT NULL,
    pmni_plaga integer,
    pmni_nombrecomun character varying(100),
    pmni_lminferior integer,
    pmni_lmsuperior integer,
    pmni_nivel integer,
    pmni_rango character varying(50),
    pmni_tipoobservacion character varying(100),
    pmni_observacion text,
    pmni_cintaidentificadora character varying(50),
    pmni_estatus integer DEFAULT 1,
    pmni_creadopor integer,
    pmni_fechacreacion timestamp without time zone DEFAULT now(),
    pmni_modificadopor integer,
    pmni_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_nivelesinfestacion OWNER TO pestuser;

--
-- Name: pm_nivelesinfectacion_pmni_secuencia_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_nivelesinfectacion_pmni_secuencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_nivelesinfectacion_pmni_secuencia_seq OWNER TO pestuser;

--
-- Name: pm_nivelesinfectacion_pmni_secuencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_nivelesinfectacion_pmni_secuencia_seq OWNED BY public.pm_nivelesinfestacion.pmni_secuencia;


--
-- Name: pm_plagas; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_plagas (
    pmpl_id integer NOT NULL,
    pmpl_genero character varying(100),
    pmpl_familia character varying(100),
    pmpl_nombrecomun character varying(100),
    pmpl_tipo character varying(50),
    pmpl_estatus integer DEFAULT 1,
    pmpl_creadopor integer,
    pmpl_fechacreacion timestamp without time zone DEFAULT now(),
    pmpl_modificadopor integer,
    pmpl_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_plagas OWNER TO pestuser;

--
-- Name: pm_plagas_pmpl_id_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_plagas_pmpl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_plagas_pmpl_id_seq OWNER TO pestuser;

--
-- Name: pm_plagas_pmpl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_plagas_pmpl_id_seq OWNED BY public.pm_plagas.pmpl_id;


--
-- Name: pm_potes; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_potes (
    pmpo_id integer NOT NULL,
    pmpo_codigo character varying(50) NOT NULL,
    pmpo_contenedor character varying(100),
    pmpo_estatus integer DEFAULT 1,
    pmpo_creadopor integer,
    pmpo_fechacreacion timestamp without time zone DEFAULT now(),
    pmpo_modificadopor integer,
    pmpo_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_potes OWNER TO pestuser;

--
-- Name: pm_potes_pmpo_id_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_potes_pmpo_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_potes_pmpo_id_seq OWNER TO pestuser;

--
-- Name: pm_potes_pmpo_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_potes_pmpo_id_seq OWNED BY public.pm_potes.pmpo_id;


--
-- Name: pm_rol; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_rol (
    pmrl_id integer NOT NULL,
    pmrl_descripcion character varying(100) NOT NULL,
    pmrl_estatus integer DEFAULT 1,
    pmrl_fechacreacion timestamp without time zone DEFAULT now(),
    pmrl_fechamodificacion timestamp without time zone,
    pmrl_creadopor integer,
    pmrl_modificadopor integer
);


ALTER TABLE public.pm_rol OWNER TO pestuser;

--
-- Name: pm_rol_pmrl_id_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_rol_pmrl_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_rol_pmrl_id_seq OWNER TO pestuser;

--
-- Name: pm_rol_pmrl_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_rol_pmrl_id_seq OWNED BY public.pm_rol.pmrl_id;


--
-- Name: pm_unidadescultivo; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_unidadescultivo (
    pmuc_secuencia integer NOT NULL,
    pmuc_id integer NOT NULL,
    pmuc_codigo character varying(50) NOT NULL,
    pmuc_cantero character varying(50) NOT NULL,
    pmuc_estatus integer DEFAULT 1,
    pmuc_creadopor integer,
    pmuc_fechacreacion timestamp without time zone DEFAULT now(),
    pmuc_modificadopor integer,
    pmuc_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_unidadescultivo OWNER TO pestuser;

--
-- Name: pm_unidadescultivo_pmuc_secuencia_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_unidadescultivo_pmuc_secuencia_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_unidadescultivo_pmuc_secuencia_seq OWNER TO pestuser;

--
-- Name: pm_unidadescultivo_pmuc_secuencia_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_unidadescultivo_pmuc_secuencia_seq OWNED BY public.pm_unidadescultivo.pmuc_secuencia;


--
-- Name: pm_usuarios; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_usuarios (
    pmus_id integer NOT NULL,
    pmus_codigo integer NOT NULL,
    pmus_usuario character varying(50) NOT NULL,
    pmus_funcion integer,
    pmus_estatus integer DEFAULT 1,
    pmus_creadopor integer,
    pmus_fechacreacion timestamp without time zone DEFAULT now(),
    pmus_modificadopor integer,
    pmus_fechamodificacion timestamp without time zone,
    pmus_password character varying(255),
    pmus_correo character varying(50) DEFAULT NULL::character varying,
    pmus_telefono character varying(50) DEFAULT NULL::character varying
);


ALTER TABLE public.pm_usuarios OWNER TO pestuser;

--
-- Name: pm_usuarios_pmus_id_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_usuarios_pmus_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_usuarios_pmus_id_seq OWNER TO pestuser;

--
-- Name: pm_usuarios_pmus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_usuarios_pmus_id_seq OWNED BY public.pm_usuarios.pmus_id;


--
-- Name: pm_variedades; Type: TABLE; Schema: public; Owner: pestuser
--

CREATE TABLE public.pm_variedades (
    pmva_id integer NOT NULL,
    pmva_codigo character varying(50) NOT NULL,
    pmva_descripcion character varying(255),
    pmva_responsable character varying(100),
    pmva_estatus integer DEFAULT 1,
    pmva_creadopor integer,
    pmva_fechacreacion timestamp without time zone DEFAULT now(),
    pmva_modificadopor integer,
    pmva_fechamodificacion timestamp without time zone
);


ALTER TABLE public.pm_variedades OWNER TO pestuser;

--
-- Name: pm_variedades_pmva_id_seq; Type: SEQUENCE; Schema: public; Owner: pestuser
--

CREATE SEQUENCE public.pm_variedades_pmva_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.pm_variedades_pmva_id_seq OWNER TO pestuser;

--
-- Name: pm_variedades_pmva_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pestuser
--

ALTER SEQUENCE public.pm_variedades_pmva_id_seq OWNED BY public.pm_variedades.pmva_id;


--
-- Name: pm_lotes pmlt_secuencia; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_lotes ALTER COLUMN pmlt_secuencia SET DEFAULT nextval('public.pm_lotes_pmlt_secuencia_seq'::regclass);


--
-- Name: pm_monitoreos pmmo_secuencia; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_monitoreos ALTER COLUMN pmmo_secuencia SET DEFAULT nextval('public.pm_monitoreos_pmmo_secuencia_seq'::regclass);


--
-- Name: pm_nivelesinfestacion pmni_secuencia; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_nivelesinfestacion ALTER COLUMN pmni_secuencia SET DEFAULT nextval('public.pm_nivelesinfectacion_pmni_secuencia_seq'::regclass);


--
-- Name: pm_plagas pmpl_id; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_plagas ALTER COLUMN pmpl_id SET DEFAULT nextval('public.pm_plagas_pmpl_id_seq'::regclass);


--
-- Name: pm_potes pmpo_id; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_potes ALTER COLUMN pmpo_id SET DEFAULT nextval('public.pm_potes_pmpo_id_seq'::regclass);


--
-- Name: pm_rol pmrl_id; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_rol ALTER COLUMN pmrl_id SET DEFAULT nextval('public.pm_rol_pmrl_id_seq'::regclass);


--
-- Name: pm_unidadescultivo pmuc_secuencia; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_unidadescultivo ALTER COLUMN pmuc_secuencia SET DEFAULT nextval('public.pm_unidadescultivo_pmuc_secuencia_seq'::regclass);


--
-- Name: pm_usuarios pmus_id; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_usuarios ALTER COLUMN pmus_id SET DEFAULT nextval('public.pm_usuarios_pmus_id_seq'::regclass);


--
-- Name: pm_variedades pmva_id; Type: DEFAULT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_variedades ALTER COLUMN pmva_id SET DEFAULT nextval('public.pm_variedades_pmva_id_seq'::regclass);


--
-- Data for Name: pm_lotes; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_lotes (pmlt_secuencia, pmlt_codigo, pmlt_casa, pmlt_canteros, pmlt_idvariedad, pmlt_contenedor, pmlt_cantidad, pmlt_grower, pmlt_variedad, pmlt_estatus, pmlt_creadopor, pmlt_fechacreacion, pmlt_modificadopor, pmlt_fechamodificacion) FROM stdin;
1	15708	B14	4-4	0	0	40	Stefano A Barahona	Vinca Roseus Soiree Kawaii Blueberry Kiss	1	1	2025-06-03 15:33:20.948961	\N	\N
2	15707	B14	4-4	0	0	40	Stefano A Barahona	Vinca Roseus Soiree Kawaii Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
3	15706	B14	4-4	0	0	40	Stefano A Barahona	Vinca Roseus Soiree Kawaii Light Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
4	15705	B14	4-4	0	0	40	Stefano A Barahona	Vinca Roseus Soiree Kawaii Red Shades	1	1	2025-06-03 15:33:20.948961	\N	\N
5	15704	B14	4-4	0	0	40	Stefano A Barahona	Vinca Roseus Soiree Kawaii White Peppermint	1	1	2025-06-03 15:33:20.948961	\N	\N
6	15819	C01	27-27	0	0	315	Ana I Morales	Verbena Bonariensis Lollipop	1	1	2025-06-03 15:33:20.948961	\N	\N
7	15805	C01	26-27	0	0	2101	Ana I Morales	Ajuga Reptans Burgundy Glow	1	1	2025-06-03 15:33:20.948961	\N	\N
8	15814	C01	24-24	0	0	1050	Ana I Morales	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
9	15711	B12	17-25	0	0	1750	Stefano A Barahona	Euphorbia Pulcherrima A1 Red	1	1	2025-06-03 15:33:20.948961	\N	\N
10	15815	C01	24-24	0	0	1050	Ana I Morales	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
11	15710	B12	45-48	0	0	830	Stefano A Barahona	Euphorbia Pulcherrima Legacy Red	1	1	2025-06-03 15:33:20.948961	\N	\N
12	15808	C02	10-10	0	0	2100	Ana I Morales	Aloe SP Minibelle	1	1	2025-06-03 15:33:20.948961	\N	\N
13	15806	C02	10-10	0	0	1890	Ana I Morales	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
14	15850	D01	22-25	0	0	2000	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
15	15851	D02	49-51	0	0	1000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
16	15810	C02	11-11	0	0	2100	Ana I Morales	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
17	15693	C01	27-27	0	0	2310	Ana I Morales	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
18	15779	B27	11-11	0	0	1295	Juan D Hernandez	Haworthia SP Tessellata	1	1	2025-06-03 15:33:20.948961	\N	\N
19	15780	E06	44-55	0	0	1360	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
20	15813	C01	19-20	0	0	3150	Ana I Morales	Muehlenbeckia Axillaris Nana	1	1	2025-06-03 15:33:20.948961	\N	\N
21	15817	C01	27-27	0	0	158	Ana I Morales	Verbena Peruviana Endurascape Pink Bicolor	1	1	2025-06-03 15:33:20.948961	\N	\N
22	15818	C01	27-27	0	0	158	Ana I Morales	Verbena Peruviana Endurascape Red	1	1	2025-06-03 15:33:20.948961	\N	\N
23	15820	C01	24-24	0	0	1575	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
24	15712	B09	33-37	0	0	4000	Stefano A Barahona	Sedum Spurium John Creech	1	1	2025-06-03 15:33:20.948961	\N	\N
25	15702	B24	21-21	0	0	250	Stefano A Barahona	Sedum Tetractinum Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
26	15816	C01	20-20	0	0	5250	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
27	15778	B09	32-33	0	0	1000	Stefano A Barahona	Sedum Kamtschaticum Weihenstephaner Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
28	15848	E01	1-5	0	0	1000	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
29	15849	D01	43-46	0	0	1900	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
30	15807	C02	10-11	0	0	3780	Ana I Morales	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
31	15775	E04	11-13	0	0	320	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
32	15812	C02	11-11	0	0	552	Ana I Morales	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
33	15811	C02	11-11	0	0	1103	Ana I Morales	Echeveria SP Giant Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
34	15841	D00	5-5	0	0	120	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
35	15777	B15	49-49	0	0	95	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
36	15786	B18	35-35	0	0	500	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
37	15789	B18	50-51	0	0	1650	Juan D Hernandez	Vriesea SP Intenso Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
38	15787	B18	50-50	0	0	700	Juan D Hernandez	Vriesea SP Intenso Peach	1	1	2025-06-03 15:33:20.948961	\N	\N
39	15781	B25	9-10	0	0	1200	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
40	15797	C04	14-23	0	0	15328	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
41	15800	C05	18-36	0	0	29184	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
42	15799	C05	1-17	0	0	26112	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
43	15788	B18	39-40	0	0	1000	Juan D Hernandez	Vriesea SP Intenso Red	1	1	2025-06-03 15:33:20.948961	\N	\N
44	15847	E11	59-59	0	0	53	Karen Orozco	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
45	15776	E11	49-49	0	0	160	Karen Orozco	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
46	15829	B04	29-29	0	0	1575	Ana I Morales	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
47	15798	C04	24-32	0	0	13824	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
48	15741	C04	7-13	0	0	10000	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
49	15742	C04	1-7	0	0	10000	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
50	13661	B26	19-19	0	Bed Bench [0.9 m]	26	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
51	13170	B26	22-22	0	Bed Bench [0.9 m]	94	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
52	13164	B26	22-22	0	Bed Bench [0.9 m]	114	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
53	13167	B26	21-21	0	Bed Bench [0.9 m]	119	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
54	13163	B26	24-24	0	Bed Bench [0.9 m]	145	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
55	13166	B26	23-23	0	Bed Bench [0.9 m]	115	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
56	13162	B26	24-24	0	Bed Bench [0.9 m]	141	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
57	13158	B26	25-25	0	Bed Bench [0.9 m]	89	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
58	13161	B26	26-27	0	Bed Bench [0.9 m]	541	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
59	13171	B26	28-28	0	Bed Bench [0.9 m]	141	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
60	13165	B26	28-29	0	Bed Bench [0.9 m]	311	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
61	13160	B26	30-30	0	Bed Bench [0.9 m]	141	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
62	13159	B26	30-30	0	Bed Bench [0.9 m]	144	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
63	13168	B26	29-29	0	Bed Bench [0.9 m]	96	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
64	8955	E12	61-90	0	Bed Bench [0.9 m]	6411	Karen Orozco	Epipremnum Asplissium Narrow Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
65	9153	E12	30-60	0	Bed Bench [0.9 m]	6315	Karen Orozco	Epipremnum Aureum Global Green	1	1	2025-06-03 15:33:20.948961	\N	\N
66	14265	VI	1-1	0	Bed Bench [1.20 m]	510764	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
67	15840	C06	37-51	0	Bed Ground [0.9 m]	13126	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
68	15726	C06	66-70	0	Bed Ground [0.9 m]	4800	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
69	15728	C06	61-61	0	Bed Ground [0.9 m]	560	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
70	15729	C06	31-34	0	Bed Ground [0.9 m]	4000	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
71	15731	C06	25-28	0	Bed Ground [0.9 m]	3600	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
72	15596	C06	77-83	0	Bed Ground [0.9 m]	6488	Ana I Morales	Dracaena Fragrans Massangeana 1.66' CC	1	1	2025-06-03 15:33:20.948961	\N	\N
73	15058	B02	17-27	0	Ground	3067	Jesus Moriña	Sansevieria trifasciata Laurentii	1	1	2025-06-03 15:33:20.948961	\N	\N
74	15059	A02	61-84	0	Ground	1720	Jesus Moriña	Sansevieria trifasciata Superba	1	1	2025-06-03 15:33:20.948961	\N	\N
75	14995	I	57-91	0	Ground	9946	Karen Orozco	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
76	14996	I	45-45	0	Ground	199	Karen Orozco	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
77	13867	B34	1-6	0	Ground	220	Juan D Hernandez	Euphorbia Lactea Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
78	13866	B33	1-8	0	Ground	288	Juan D Hernandez	Euphorbia Lactea Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
79	13865	B32	1-8	0	Ground	324	Juan D Hernandez	Euphorbia Lactea Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
80	6255	B34	1-6	0	Ground	221	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
81	6256	B33	1-8	0	Ground	287	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
82	6258	B31	1-8	0	Ground	318	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
83	6259	B30	1-8	0	Ground	328	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
84	6257	B32	1-8	0	Ground	353	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
85	9575	A13	1-4	0	Ground	38	Juan D Hernandez	Euphorbia SP Acrurensis	1	1	2025-06-03 15:33:20.948961	\N	\N
86	9574	A12	1-15	0	Ground	239	Juan D Hernandez	Euphorbia SP Acrurensis	1	1	2025-06-03 15:33:20.948961	\N	\N
87	2733	A15	1-5	0	Ground	43	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
88	2734	A14	1-7	0	Ground	60	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
89	9573	A09	1-8	0	Ground	230	Juan D Hernandez	Euphorbia SP Acrurensis	1	1	2025-06-03 15:33:20.948961	\N	\N
90	2108	A11	1-8	0	Ground	195	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
91	11	A10	1-8	0	Ground	210	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
92	10418	I	1-21	0	Ground	2281	Jesus Moriña	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
93	15391	H19	1-1	0	Ground	245	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
94	15392	H18	1-1	0	Ground	1130	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
95	15240	H15	1-1	0	Ground	12516	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
96	15239	H17	1-1	0	Ground	13097	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
97	15266	H19	1-1	0	Ground	13097	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
98	15241	H16	1-1	0	Ground	21732	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
99	15267	H18	1-1	0	Ground	21732	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
100	15195	H14	1-1	0	Ground	22670	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
101	15022	H12	1-1	0	Ground	23275	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
102	14561	H06	1-1	0	Ground	20839	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
103	14559	H08	1-1	0	Ground	21883	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
104	14562	H05	1-1	0	Ground	22585	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
105	14560	H07	1-1	0	Ground	22689	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
106	14563	H04	1-1	0	Ground	24623	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
107	14564	H03	1-1	0	Ground	26188	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
108	14558	H10	1-1	0	Ground	26713	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
109	14565	H02	1-1	0	Ground	30715	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
110	14566	H01	1-1	0	Ground	35199	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
111	14129	J14	1-1	0	Ground	23768	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
112	14127	J16	1-1	0	Ground	25426	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
113	14130	J13	1-1	0	Ground	25586	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
114	14128	J15	1-1	0	Ground	28642	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
115	13500	J07	1-1	0	Ground	6777	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
116	10492	J09	1-1	0	Ground	11719	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
117	10493	J11	1-1	0	Ground	15640	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
118	10494	J10	1-1	0	Ground	21045	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
119	10495	J12	1-1	0	Ground	23954	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
120	15047	G28	1-1	0	Ground	1743	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
121	9723	G25	1-1	0	Ground	2572	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
122	9724	G24	1-1	0	Ground	5528	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
123	9845	J05	1-1	0	Ground	5767	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
124	9848	J06	1-1	0	Ground	6504	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
125	15048	G27	1-1	0	Ground	6564	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
126	15046	J01	1-1	0	Ground	7761	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
127	15049	G26	1-1	0	Ground	7875	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
128	13442	G29	1-1	0	Ground	8585	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
129	15045	J02	1-1	0	Ground	12836	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
130	9847	J03	1-1	0	Ground	14521	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
131	9846	J04	1-1	0	Ground	15275	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
132	9849	J08	1-1	0	Ground	16205	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
133	13437	G22	1-1	0	Ground	4423	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
134	11558	G20	1-1	0	Ground	6145	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
135	15050	G23	1-1	0	Ground	7609	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
136	11557	G18	1-1	0	Ground	11336	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
137	9383	G21	1-1	0	Ground	14002	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
138	15053	G16	1-1	0	Ground	2678	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
139	15052	G17	1-1	0	Ground	3508	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
140	13501	G10	1-1	0	Ground	3989	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
141	15051	G19	1-1	0	Ground	3995	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
142	9041	G12	1-1	0	Ground	5292	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
143	9090	G13	1-1	0	Ground	5450	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
144	8855	G11	1-1	0	Ground	7712	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
145	15054	G15	1-1	0	Ground	8623	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
146	13438	G08	1-1	0	Ground	1796	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
147	8808	G09	1-1	0	Ground	5025	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
148	13439	G07	1-1	0	Ground	5472	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
149	13445	G04	1-1	0	Ground	6712	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
150	13440	G06	1-1	0	Ground	8372	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
151	4783	C05	1-1	0	Ground	2402	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
152	15056	F06	1-1	0	Ground	3459	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
153	4778	E06	1-1	0	Ground	1239	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
154	4782	B03	1-1	0	Ground	3896	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
155	4767	G05	1-1	0	Ground	7661	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
156	4785	C06	1-1	0	Ground	8140	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
157	4806	G01	1-1	0	Ground	4149	Jesus Moriña	Cycas Revoluta Palm Sago	1	1	2025-06-03 15:33:20.948961	\N	\N
158	14998	I	46-50	0	Ground	879	Jesus Moriña	Asparagus Meyeri Foxtail	1	1	2025-06-03 15:33:20.948961	\N	\N
159	14997	I	51-56	0	Ground	1089	Jesus Moriña	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
160	15683	C01	5-5	0	Oasis T10	62	Ana I Morales	Euphorbia Pulcherrima Pepita Early Red	1	1	2025-06-03 15:33:20.948961	\N	\N
161	15684	C01	5-5	0	Oasis T10	1050	Ana I Morales	Euphorbia Pulcherrima Legacy Red	1	1	2025-06-03 15:33:20.948961	\N	\N
162	15682	C01	5-5	0	Oasis T10	74	Ana I Morales	Euphorbia Pulcherrima Ranch Red	1	1	2025-06-03 15:33:20.948961	\N	\N
163	10416	I	22-22	0	P10	9	Jesus Moriña	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
164	15102	C25	15-20	0	P10	1289	Juan D Hernandez	Codiaeum Variegatum Petra	1	1	2025-06-03 15:33:20.948961	\N	\N
165	14772	C25	13-15	0	P10	430	Juan D Hernandez	Codiaeum Variegatum Petra	1	1	2025-06-03 15:33:20.948961	\N	\N
166	12486	C25	8-13	0	P10	1200	Juan D Hernandez	Codiaeum Variegatum Petra	1	1	2025-06-03 15:33:20.948961	\N	\N
167	12485	C25	1-8	0	P10	1925	Juan D Hernandez	Codiaeum Variegatum Petra	1	1	2025-06-03 15:33:20.948961	\N	\N
168	9593	E05	1-15	0	P10	1508	Karen Orozco	Ixora Coccinea Maui Multicolor	1	1	2025-06-03 15:33:20.948961	\N	\N
169	11315	E05	16-42	0	P10	2794	Karen Orozco	Ixora Coccinea Maui Red	1	1	2025-06-03 15:33:20.948961	\N	\N
170	11312	E05	50-53	0	P12	336	Karen Orozco	Ixora Coccinea Taiwanese Dwarf Red	1	1	2025-06-03 15:33:20.948961	\N	\N
171	11310	E05	57-59	0	P12	255	Karen Orozco	Ixora Coccinea Taiwanese Dwarf Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
172	3831	A01	19-20	0	P12	226	Juan D Hernandez	Adenium Obesum Desert Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
173	11314	E05	43-50	0	P12	783	Karen Orozco	Ixora Coccinea Maui Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
174	11311	E05	59-62	0	P12	330	Karen Orozco	Ixora Coccinea Taiwanese Dwarf Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
175	11313	E05	53-57	0	P12	327	Karen Orozco	Ixora Coccinea Taiwanese Dwarf Red	1	1	2025-06-03 15:33:20.948961	\N	\N
176	3830	A01	13-18	0	P14	567	Juan D Hernandez	Adenium Obesum Desert Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
177	15021	I	44-44	0	P17	15	Jesus Moriña	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
178	10415	I	23-43	0	P17	268	Jesus Moriña	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
179	5768	A01	24-29	0	P23	281	Juan D Hernandez	Adenium Obesum Desert Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
180	15631	E11	1-8	0	P4	2924	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
181	15664	B22	45-49	0	P4	6000	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
182	15620	B23	23-30	0	P4	12096	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
183	15619	B23	1-22	0	P4	33264	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
184	15621	B23	31-53	0	P4	34776	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
185	15387	B22	33-41	0	P4	12000	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
186	15383	B22	7-7	0	P4	1100	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
187	15416	B22	42-45	0	P4	6048	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
188	15385	B22	8-13	0	P4	7960	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
189	15384	B21	39-53	0	P4	23040	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
190	15386	B22	13-33	0	P4	30000	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
191	15380	B22	1-6	0	P4	9000	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf TV	1	1	2025-06-03 15:33:20.948961	\N	\N
192	15196	B21	31-39	0	P4	12400	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
193	14557	B21	14-20	0	P4	8350	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
194	14917	B21	29-31	0	P4	3980	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
195	14916	B21	27-29	0	P4	3302	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
196	14820	B21	25-25	0	P4	100	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
197	14821	B21	1-2	0	P4	1812	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
198	14822	B21	25-27	0	P4	2997	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
199	14745	B21	25-25	0	P4	200	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
200	14744	B21	25-25	0	P4	200	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
201	14512	B21	10-14	0	P4	6072	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
202	14655	B21	20-25	0	P4	8115	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
203	14511	B21	7-10	0	P4	4927	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
204	13929	B21	4-7	0	P4	3080	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
205	13928	B21	2-4	0	P4	2600	Jairo Gonzalez	Zamioculca Zamiifolia Black Raven Leaf (P4)	1	1	2025-06-03 15:33:20.948961	\N	\N
206	14197	B19	42-42	0	P4	400	Juan D Hernandez	Vriesea SP Harmony	1	1	2025-06-03 15:33:20.948961	\N	\N
207	13642	B19	30-30	0	P4	624	Juan D Hernandez	Vriesea Carinata Dorado	1	1	2025-06-03 15:33:20.948961	\N	\N
208	13092	B19	42-42	0	P4	597	Juan D Hernandez	Vriesea SP Harmony	1	1	2025-06-03 15:33:20.948961	\N	\N
209	12355	B19	37-37	0	P4	218	Juan D Hernandez	Vriesea Carinata Dorado	1	1	2025-06-03 15:33:20.948961	\N	\N
210	13972	E16	1-20	0	P4	30000	Karen Orozco	Portulacaria Afra Green (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
211	13087	E13	8-17	0	P4	12804	Karen Orozco	Portulacaria Afra Green (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
212	12462	E13	64-70	0	P4	6132	Karen Orozco	Portulacaria Afra Green (Small)	1	1	2025-06-03 15:33:20.948961	\N	\N
213	11047	E14	57-65	0	P4	11220	Karen Orozco	Portulacaria Afra Green (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
214	13637	B19	46-46	0	P4	516	Juan D Hernandez	Vriesea Carinata Christiane	1	1	2025-06-03 15:33:20.948961	\N	\N
215	13635	B19	50-50	0	P4	726	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
216	13094	B18	63-64	0	P4	636	Juan D Hernandez	Vriesea Carinata Tosca	1	1	2025-06-03 15:33:20.948961	\N	\N
217	13089	B19	45-46	0	P4	795	Juan D Hernandez	Vriesea Carinata Christiane	1	1	2025-06-03 15:33:20.948961	\N	\N
218	13095	B18	64-65	0	P4	806	Juan D Hernandez	Vriesea Carinata Tosca	1	1	2025-06-03 15:33:20.948961	\N	\N
219	13091	B19	52-52	0	P4	1192	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
220	12358	B19	50-50	0	P4	228	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
221	12357	B18	63-63	0	P4	300	Juan D Hernandez	Vriesea Carinata Tosca	1	1	2025-06-03 15:33:20.948961	\N	\N
222	12350	B19	46-46	0	P4	437	Juan D Hernandez	Vriesea Carinata Christiane	1	1	2025-06-03 15:33:20.948961	\N	\N
223	12031	B19	50-50	0	P4	1684	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
224	11780	B18	64-64	0	P4	711	Juan D Hernandez	Vriesea Carinata Tosca	1	1	2025-06-03 15:33:20.948961	\N	\N
225	11781	B19	45-45	0	P4	1068	Juan D Hernandez	Vriesea Carinata Christiane	1	1	2025-06-03 15:33:20.948961	\N	\N
226	11653	B19	52-52	0	P4	526	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
227	14201	B19	32-32	0	P4	198	Juan D Hernandez	Vriesea SP Splenriet	1	1	2025-06-03 15:33:20.948961	\N	\N
228	14198	B18	56-56	0	P4	400	Juan D Hernandez	Vriesea SP Intenso Peach	1	1	2025-06-03 15:33:20.948961	\N	\N
229	14199	B18	59-59	0	P4	780	Juan D Hernandez	Vriesea SP Intenso Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
230	14200	B19	39-39	0	P4	800	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
231	14076	B19	31-31	0	P4	1555	Juan D Hernandez	Vriesea SP Intenso Red	1	1	2025-06-03 15:33:20.948961	\N	\N
232	13639	B19	38-38	0	P4	234	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
233	13640	B19	37-37	0	P4	264	Juan D Hernandez	Vriesea SP Davine	1	1	2025-06-03 15:33:20.948961	\N	\N
234	13641	B19	35-35	0	P4	492	Juan D Hernandez	Vriesea SP Draco	1	1	2025-06-03 15:33:20.948961	\N	\N
235	13367	B18	58-58	0	P4	1104	Juan D Hernandez	Vriesea SP Intenso Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
236	13093	B19	32-32	0	P4	102	Juan D Hernandez	Vriesea SP Splenriet	1	1	2025-06-03 15:33:20.948961	\N	\N
237	13088	B18	60-60	0	P4	811	Juan D Hernandez	Vriesea SP Cathy	1	1	2025-06-03 15:33:20.948961	\N	\N
238	12786	B19	34-34	0	P4	45	Juan D Hernandez	Vriesea SP Draco	1	1	2025-06-03 15:33:20.948961	\N	\N
239	12782	B18	56-56	0	P4	70	Juan D Hernandez	Vriesea SP Intenso Peach	1	1	2025-06-03 15:33:20.948961	\N	\N
240	12781	B19	39-39	0	P4	268	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
241	12788	B19	32-32	0	P4	339	Juan D Hernandez	Vriesea SP Splenriet	1	1	2025-06-03 15:33:20.948961	\N	\N
242	12787	B19	36-36	0	P4	479	Juan D Hernandez	Vriesea SP Cathy	1	1	2025-06-03 15:33:20.948961	\N	\N
243	12610	B19	34-34	0	P4	30	Juan D Hernandez	Vriesea SP Draco	1	1	2025-06-03 15:33:20.948961	\N	\N
244	12611	B19	39-39	0	P4	108	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
245	12608	B19	36-36	0	P4	136	Juan D Hernandez	Vriesea SP Cathy	1	1	2025-06-03 15:33:20.948961	\N	\N
246	12612	B18	56-56	0	P4	155	Juan D Hernandez	Vriesea SP Intenso Peach	1	1	2025-06-03 15:33:20.948961	\N	\N
247	12606	B18	57-58	0	P4	368	Juan D Hernandez	Vriesea SP Intenso Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
248	12353	B19	34-34	0	P4	54	Juan D Hernandez	Vriesea SP Draco	1	1	2025-06-03 15:33:20.948961	\N	\N
249	12354	B19	36-36	0	P4	116	Juan D Hernandez	Vriesea SP Cathy	1	1	2025-06-03 15:33:20.948961	\N	\N
250	12351	B19	38-38	0	P4	212	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
251	12352	B19	37-37	0	P4	312	Juan D Hernandez	Vriesea SP Davine	1	1	2025-06-03 15:33:20.948961	\N	\N
252	12359	B19	32-32	0	P4	627	Juan D Hernandez	Vriesea SP Splenriet	1	1	2025-06-03 15:33:20.948961	\N	\N
253	11771	B19	32-32	0	P4	150	Juan D Hernandez	Vriesea SP Splenriet	1	1	2025-06-03 15:33:20.948961	\N	\N
254	11773	B19	38-38	0	P4	191	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
255	11777	B19	34-34	0	P4	1308	Juan D Hernandez	Vriesea SP Draco	1	1	2025-06-03 15:33:20.948961	\N	\N
256	11776	B19	35-36	0	P4	1572	Juan D Hernandez	Vriesea SP Cathy	1	1	2025-06-03 15:33:20.948961	\N	\N
257	14792	B25	10-11	0	P4	1893	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
258	14682	B25	11-24	0	P4	18207	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
259	14556	B25	24-35	0	P4	15048	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
260	14164	B25	53-53	0	P4	600	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
261	14165	B25	53-53	0	P4	240	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
262	15092	B25	52-53	0	P4	1530	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
263	13310	B25	51-52	0	P4	1498	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
264	12638	B25	45-47	0	P4	3450	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
265	12492	B25	41-42	0	P4	1903	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
266	11765	B25	35-37	0	P4	5231	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
267	13174	B26	47-47	0	P4	575	Juan D Hernandez	Echeveria SP Opalina	1	1	2025-06-03 15:33:20.948961	\N	\N
268	13172	B26	42-43	0	P4	849	Juan D Hernandez	Echeveria SP Opalina	1	1	2025-06-03 15:33:20.948961	\N	\N
269	13173	B26	44-44	0	P4	747	Juan D Hernandez	Echeveria SP Opalina	1	1	2025-06-03 15:33:20.948961	\N	\N
270	15381	D00	3-3	0	P4	129	Maybelle Flores	Hibiscus SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
271	15539	D00	11-11	0	P4	133	Maybelle Flores	Hibiscus SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
272	13659	B26	52-52	0	P4	96	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
273	13227	B26	50-50	0	P4	730	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
274	13202	B26	48-48	0	P4	714	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
275	13201	B26	44-44	0	P4	204	Juan D Hernandez	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
276	11686	E15	17-24	0	P4	10000	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
277	11608	E15	24-27	0	P4	3500	Karen Orozco	Ficus Microcarpa Ginseng (500)	1	1	2025-06-03 15:33:20.948961	\N	\N
278	11607	E15	1-5	0	P4	7000	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
279	11605	E15	10-15	0	P4	7000	Karen Orozco	Ficus Microcarpa Ginseng (100)	1	1	2025-06-03 15:33:20.948961	\N	\N
280	11606	E15	5-10	0	P4	7000	Karen Orozco	Ficus Microcarpa Ginseng (250)	1	1	2025-06-03 15:33:20.948961	\N	\N
281	11624	E14	33-36	0	P4	5292	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
282	11169	E14	24-32	0	P4	13716	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
283	11129	E14	13-20	0	P4	10694	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
284	10915	E14	4-13	0	P4	14522	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
285	10914	E14	1-4	0	P4	5252	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
286	13204	B26	47-47	0	P4	132	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
287	13203	B26	42-42	0	P4	384	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
288	13205	B26	45-46	0	P4	577	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
289	13231	B26	51-51	0	P4	575	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
290	13232	B26	51-51	0	P4	641	Juan D Hernandez	Echeveria Elegans Ghost white	1	1	2025-06-03 15:33:20.948961	\N	\N
291	13239	B26	50-50	0	P4	767	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
292	13208	B26	46-46	0	P4	450	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
293	13207	B26	45-45	0	P4	866	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
294	13238	B26	51-51	0	P4	857	Juan D Hernandez	Echeveria SP Perle Von Nurnberg	1	1	2025-06-03 15:33:20.948961	\N	\N
295	12635	B19	11-11	0	P4	1014	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
296	13236	B26	50-50	0	P4	917	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
297	13235	B26	49-49	0	P4	796	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
298	13234	B26	51-51	0	P4	157	Juan D Hernandez	Echeveria Gibbiflora Metalica	1	1	2025-06-03 15:33:20.948961	\N	\N
299	15524	B19	29-29	0	P4	400	Juan D Hernandez	Vriesea SP Intenso Red	1	1	2025-06-03 15:33:20.948961	\N	\N
300	13188	B26	49-49	0	P4	467	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
301	13187	B26	47-47	0	P4	618	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
302	13186	B26	43-43	0	P4	1067	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
303	13185	B26	44-44	0	P4	492	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
304	13229	B26	51-51	0	P4	216	Juan D Hernandez	Echeveria Tolimanensis Haegii	1	1	2025-06-03 15:33:20.948961	\N	\N
305	15718	B19	42-42	0	P4	186	Juan D Hernandez	Vriesea SP Harmony	1	1	2025-06-03 15:33:20.948961	\N	\N
306	15719	B19	47-47	0	P4	933	Juan D Hernandez	Vriesea Carinata Evita	1	1	2025-06-03 15:33:20.948961	\N	\N
307	15525	B19	39-39	0	P4	300	Juan D Hernandez	Vriesea SP Salmon	1	1	2025-06-03 15:33:20.948961	\N	\N
308	15522	B19	42-42	0	P4	400	Juan D Hernandez	Vriesea SP Harmony	1	1	2025-06-03 15:33:20.948961	\N	\N
309	15523	B18	59-59	0	P4	400	Juan D Hernandez	Vriesea SP Intenso Yellow	1	1	2025-06-03 15:33:20.948961	\N	\N
310	13192	B26	49-49	0	P4	505	Juan D Hernandez	Echeveria SP Peacockii	1	1	2025-06-03 15:33:20.948961	\N	\N
311	13191	B26	48-48	0	P4	2352	Juan D Hernandez	Echeveria SP Peacockii	1	1	2025-06-03 15:33:20.948961	\N	\N
312	13190	B26	41-42	0	P4	2509	Juan D Hernandez	Echeveria SP Peacockii	1	1	2025-06-03 15:33:20.948961	\N	\N
313	13189	B26	45-45	0	P4	1230	Juan D Hernandez	Echeveria SP Peacockii	1	1	2025-06-03 15:33:20.948961	\N	\N
314	13133	B20	54-54	0	P4	106	Juan D Hernandez	Neoregelia SP Carolinae	1	1	2025-06-03 15:33:20.948961	\N	\N
315	13130	B20	20-20	0	P4	1481	Juan D Hernandez	Neoregelia SP Hybrid #23	1	1	2025-06-03 15:33:20.948961	\N	\N
316	14769	B29	25-26	0	P4	3312	Juan D Hernandez	Aloe SP Minibelle	1	1	2025-06-03 15:33:20.948961	\N	\N
317	14097	B29	25-25	0	P4	1243	Juan D Hernandez	Aloe SP Minibelle	1	1	2025-06-03 15:33:20.948961	\N	\N
318	13349	B27	1-1	0	P4	180	Juan D Hernandez	Senecio Radicans String of Bananas	1	1	2025-06-03 15:33:20.948961	\N	\N
319	13347	B27	3-3	0	P4	24	Juan D Hernandez	Senecio Rowleyanus String of Pearls	1	1	2025-06-03 15:33:20.948961	\N	\N
320	13350	B27	1-1	0	P4	462	Juan D Hernandez	Senecio Radicans String of Bananas	1	1	2025-06-03 15:33:20.948961	\N	\N
321	13348	B27	1-1	0	P4	4	Juan D Hernandez	Senecio Rowleyanus String of Pearls	1	1	2025-06-03 15:33:20.948961	\N	\N
322	13794	B29	21-22	0	P4	2136	Juan D Hernandez	Aloe Jucunda x acutissima Bright Star	1	1	2025-06-03 15:33:20.948961	\N	\N
323	10349	B27	27-27	0	P4	181	Juan D Hernandez	Haworthia SP Spirit 88	1	1	2025-06-03 15:33:20.948961	\N	\N
324	11711	B27	24-26	0	P4	2682	Juan D Hernandez	Haworthia SP Tessellata	1	1	2025-06-03 15:33:20.948961	\N	\N
325	13829	B27	19-19	0	P4	1100	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
326	15421	B27	19-19	0	P4	874	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
327	10982	B27	19-19	0	P4	344	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
328	10878	B27	19-20	0	P4	1469	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
329	15422	B27	22-22	0	P4	1056	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
330	15480	B27	21-21	0	P4	2123	Juan D Hernandez	Haworthia SP Concolor	1	1	2025-06-03 15:33:20.948961	\N	\N
331	10877	E00	12-12	0	P4	448	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
332	15278	C02	24-25	0	P4	1958	Ana I Morales	Asparagus Sprengeri Fernleaf	1	1	2025-06-03 15:33:20.948961	\N	\N
333	14955	B07	2-2	0	P4	200	Stefano A Barahona	Verbena Bonariensis Lollipop	1	1	2025-06-03 15:33:20.948961	\N	\N
334	15727	B10	20-20	0	P6	944	Stefano A Barahona	Liriope SP Silvery Sunproof	1	1	2025-06-03 15:33:20.948961	\N	\N
335	15570	B10	23-26	0	P6	949	Stefano A Barahona	Liriope Muscari Big Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
336	15725	B10	42-43	0	P6	1286	Stefano A Barahona	Ophiopogon Japonicus Dwarf Mondo	1	1	2025-06-03 15:33:20.948961	\N	\N
337	14466	B10	33-42	0	P6	11024	Stefano A Barahona	Ophiopogon Japonicus Dwarf Mondo	1	1	2025-06-03 15:33:20.948961	\N	\N
338	13226	B26	61-61	0	P6	84	Juan D Hernandez	Echeveria SP Ebony	1	1	2025-06-03 15:33:20.948961	\N	\N
339	15721	E16	44-50	0	P6	4819	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
340	15722	E16	62-72	0	P6	9477	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
341	14033	E16	38-43	0	P6	2712	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
342	13926	E16	32-38	0	P6	5826	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
343	13521	E13	36-38	0	P6	1819	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
344	13514	E13	33-35	0	P6	2838	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
345	13515	E13	19-24	0	P6	4002	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
346	13583	E16	38-38	0	P6	136	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
347	13586	E13	19-19	0	P6	407	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
348	13584	E13	36-36	0	P6	558	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
349	13520	E16	43-44	0	P6	912	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
350	13585	E15	35-38	0	P6	3438	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
351	13516	E16	53-58	0	P6	3722	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
352	13587	E15	39-53	0	P6	13219	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
353	13519	E13	38-39	0	P6	900	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
354	13517	E13	28-33	0	P6	2994	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
355	13518	E16	60-62	0	P6	2321	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
356	10774	E13	18-19	0	P6	272	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
357	10775	E13	18-18	0	P6	288	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
358	10769	E16	43-43	0	P6	382	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
359	10773	E16	60-60	0	P6	86	Karen Orozco	Serissa Foetida Thousand Stars	1	1	2025-06-03 15:33:20.948961	\N	\N
360	10768	E13	38-38	0	P6	134	Karen Orozco	Zelkova Parvifolia Orme	1	1	2025-06-03 15:33:20.948961	\N	\N
361	14941	D02	56-56	0	P6	500	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
362	14943	D02	41-41	0	P6	500	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
363	13046	D01	15-17	0	P6	1604	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
364	12836	D23	17-31	0	P6	14103	Karen Orozco	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
365	11814	D25	1-16	0	P6	13624	Karen Orozco	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
366	11499	D23	32-48	0	P6	15029	Karen Orozco	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
367	11426	D22	29-68	0	P6	35527	Karen Orozco	Ehretia Microphylla Fukien Tea (Small)	1	1	2025-06-03 15:33:20.948961	\N	\N
368	11163	D22	12-28	0	P6	15029	Karen Orozco	Ehretia Microphylla Fukien Tea (Small)	1	1	2025-06-03 15:33:20.948961	\N	\N
369	15173	D02	17-19	0	P6	2250	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
370	14791	D02	17-17	0	P6	720	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
371	14647	D02	16-17	0	P6	524	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
372	14362	D02	15-16	0	P6	1120	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
373	14202	D02	14-15	0	P6	1118	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
374	14071	D02	13-14	0	P6	1342	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
375	13043	D02	14-14	0	P6	502	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
376	12692	D02	12-13	0	P6	960	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
377	12490	D02	9-12	0	P6	3642	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
378	12033	D02	8-9	0	P6	1337	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
379	12183	D02	8-8	0	P6	402	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
380	11713	D02	7-7	0	P6	540	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
381	11518	D02	7-7	0	P6	240	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
382	11516	D02	7-7	0	P6	282	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
383	11152	D02	7-7	0	P6	216	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
384	11517	D02	5-7	0	P6	1355	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
385	10977	D02	2-5	0	P6	4872	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
386	12924	B25	47-50	0	P6	3924	Juan D Hernandez	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
387	13261	B26	32-33	0	P6	438	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
388	13148	B26	38-39	0	P6	1091	Juan D Hernandez	Echeveria SP Giant Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
389	13156	B26	32-32	0	P6	416	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
390	13155	B26	35-35	0	P6	339	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
391	13147	B26	35-36	0	P6	999	Juan D Hernandez	Echeveria SP Giant Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
392	13154	B26	35-35	0	P6	373	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
393	13153	B26	34-35	0	P6	542	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
394	13152	B26	34-34	0	P6	173	Juan D Hernandez	Echeveria SP First Lady	1	1	2025-06-03 15:33:20.948961	\N	\N
395	15540	D02	23-23	0	P6	840	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
396	15223	D02	1-1	0	P6	1230	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
397	15432	D02	22-23	0	P6	1300	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
398	15264	D02	19-22	0	P6	3400	Karen Orozco	Begonia Maculata Polka Dots	1	1	2025-06-03 15:33:20.948961	\N	\N
399	15519	D00	16-16	0	P6	318	Maybelle Flores	Hibiscus SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
400	13872	D01	47-48	0	P6	800	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
401	13561	D01	48-49	0	P6	1002	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
402	13562	D01	49-50	0	P6	1050	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
403	13045	D01	50-50	0	P6	568	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
404	11609	E16	21-31	0	P6	10000	Karen Orozco	Ficus Microcarpa Ginseng (100)	1	1	2025-06-03 15:33:20.948961	\N	\N
405	12852	E08	31-31	0	P6	52	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
406	15025	B18	38-38	0	P6	1000	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
407	14774	B20	15-15	0	P6	850	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
408	14723	B20	17-17	0	P6	1000	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
409	13603	B20	39-39	0	P6	243	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
410	13601	B20	19-19	0	P6	800	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
411	13271	B20	39-39	0	P6	132	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
412	13275	B20	18-18	0	P6	700	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
413	13064	B20	18-18	0	P6	777	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
414	12726	B19	13-13	0	P6	42	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
415	12728	B20	8-8	0	P6	804	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
416	12315	B20	16-17	0	P6	803	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
417	15205	B20	16-16	0	P6	489	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
418	13592	B20	3-3	0	P6	238	Juan D Hernandez	Neoregelia SP Bob and Grace	1	1	2025-06-03 15:33:20.948961	\N	\N
419	13593	B20	5-6	0	P6	520	Juan D Hernandez	Neoregelia SP Bob and Grace	1	1	2025-06-03 15:33:20.948961	\N	\N
420	13267	B20	4-5	0	P6	750	Juan D Hernandez	Neoregelia SP Bob and Grace	1	1	2025-06-03 15:33:20.948961	\N	\N
421	13062	B19	17-17	0	P6	743	Juan D Hernandez	Neoregelia SP Bob and Grace	1	1	2025-06-03 15:33:20.948961	\N	\N
422	15026	B19	12-12	0	P6	800	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
423	14722	B19	11-11	0	P6	800	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
424	14775	B19	13-13	0	P6	1043	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
425	13596	B19	11-11	0	P6	24	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
426	13598	B19	16-16	0	P6	96	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
427	13597	B19	9-9	0	P6	210	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
428	13595	B19	7-7	0	P6	780	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
429	13629	B19	23-24	0	P6	1314	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
430	13272	B19	16-16	0	P6	146	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
431	13063	B19	15-16	0	P6	1203	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
432	12727	B19	11-11	0	P6	90	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
433	12413	B19	9-9	0	P6	515	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
434	12316	B19	9-9	0	P6	210	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
435	15023	B19	27-27	0	P6	800	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
436	14776	B19	25-25	0	P6	676	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
437	14724	B19	25-26	0	P6	800	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
438	13600	B19	24-24	0	P6	433	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
439	13599	B19	13-13	0	P6	744	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
440	13268	B19	23-23	0	P6	306	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
441	13132	B19	17-17	0	P6	467	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
442	13131	B20	54-54	0	P6	548	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
443	12637	B19	20-20	0	P6	895	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
444	12231	B19	21-21	0	P6	179	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
445	12230	B19	18-19	0	P6	1285	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
446	11971	B19	18-19	0	P6	1380	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
447	15024	B18	69-69	0	P6	1000	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
448	13714	B20	48-48	0	P6	117	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
449	13713	B20	45-46	0	P6	1200	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
450	13270	B20	39-39	0	P6	1216	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
451	13066	B20	44-45	0	P6	1169	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
452	12603	B20	51-51	0	P6	480	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
453	13512	B29	36-36	0	P6	593	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
454	13511	B29	36-37	0	P6	757	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
455	13619	B29	35-35	0	P6	1047	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
456	11947	B29	38-39	0	P6	1701	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
457	12308	B29	35-35	0	P6	383	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
458	11336	B29	38-38	0	P6	448	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
459	11337	B29	37-38	0	P6	560	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
460	10963	B29	37-37	0	P6	618	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
461	10886	B29	38-38	0	P6	965	Juan D Hernandez	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
462	13602	B20	39-39	0	P6	486	Juan D Hernandez	Neoregelia SP Hybrid #23	1	1	2025-06-03 15:33:20.948961	\N	\N
463	13269	B20	34-35	0	P6	913	Juan D Hernandez	Neoregelia SP Hybrid #23	1	1	2025-06-03 15:33:20.948961	\N	\N
464	12723	B20	24-24	0	P6	534	Juan D Hernandez	Neoregelia SP Hybrid #23	1	1	2025-06-03 15:33:20.948961	\N	\N
465	12724	B20	17-17	0	P6	990	Juan D Hernandez	Neoregelia SP Hybrid #23	1	1	2025-06-03 15:33:20.948961	\N	\N
466	12747	B26	55-55	0	P6	260	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
467	13399	B26	55-56	0	P6	1400	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
468	13316	B26	56-56	0	P6	1020	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
469	13315	B26	59-59	0	P6	1650	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
470	13314	B26	60-61	0	P6	2130	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
471	13142	B26	54-55	0	P6	2340	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
472	13216	B26	57-58	0	P6	3192	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
473	13215	B26	61-61	0	P6	1014	Juan D Hernandez	Echeveria SP Agavoide	1	1	2025-06-03 15:33:20.948961	\N	\N
474	15717	B19	19-19	0	P6	290	Juan D Hernandez	Vriesea SP Intenso Red	1	1	2025-06-03 15:33:20.948961	\N	\N
475	15371	D01	47-47	0	P6	100	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
476	15261	D01	47-47	0	P6	180	Karen Orozco	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
477	14098	B10	51-61	0	P6	14298	Stefano A Barahona	Ophiopogon Japonicus Mondo	1	1	2025-06-03 15:33:20.948961	\N	\N
478	13385	B29	32-33	0	P6	2500	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
479	11948	B29	28-29	0	P6	1833	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
480	11335	B29	30-31	0	P6	1034	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
481	11282	B29	29-30	0	P6	730	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
482	10964	B29	29-30	0	P6	1864	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
483	9983	B29	27-27	0	P6	816	Juan D Hernandez	Aloe Hybrid White Beauty	1	1	2025-06-03 15:33:20.948961	\N	\N
484	15646	B18	5-6	0	P6	1000	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
485	15271	B18	67-67	0	P6	500	Juan D Hernandez	Neoregelia SP Kahala Down	1	1	2025-06-03 15:33:20.948961	\N	\N
486	15785	B18	26-27	0	P6	800	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
487	15649	B18	25-26	0	P6	800	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
488	15270	B19	28-28	0	P6	492	Juan D Hernandez	Neoregelia SP Donna	1	1	2025-06-03 15:33:20.948961	\N	\N
489	15784	B18	22-23	0	P6	1000	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
490	15648	B18	23-24	0	P6	1000	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
491	15273	B18	16-16	0	P6	895	Juan D Hernandez	Neoregelia SP Raphael	1	1	2025-06-03 15:33:20.948961	\N	\N
492	15782	B19	3-3	0	P6	750	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
493	15645	B19	1-1	0	P6	750	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
494	15272	B18	7-7	0	P6	391	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
495	15783	B18	12-12	0	P6	800	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
496	15647	B18	9-10	0	P6	800	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
497	15274	B18	10-10	0	P6	792	Juan D Hernandez	Neoregelia SP Tricolor	1	1	2025-06-03 15:33:20.948961	\N	\N
498	13524	B20	2-2	0	P6	1500	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
499	13594	B19	16-16	0	P6	347	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
500	13065	B19	14-15	0	P6	1575	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
501	12636	B19	4-4	0	P6	1232	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
502	12319	B19	22-22	0	P6	792	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
503	12318	B19	5-5	0	P6	837	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
504	11973	B19	4-4	0	P6	369	Juan D Hernandez	Neoregelia SP Pimento	1	1	2025-06-03 15:33:20.948961	\N	\N
505	14855	B27	5-5	0	P6	800	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
506	14316	B27	9-9	0	P6	500	Juan D Hernandez	Senecio Barbertonicus Himalaya	1	1	2025-06-03 15:33:20.948961	\N	\N
507	14442	B27	4-4	0	P6	480	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
508	14077	B27	7-7	0	P6	486	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
509	13657	B27	1-2	0	P6	1380	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
510	13123	B27	1-1	0	P6	160	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
511	13122	B27	1-1	0	P6	50	Juan D Hernandez	Senecio Peregrinus String of Dolphin	1	1	2025-06-03 15:33:20.948961	\N	\N
512	9666	B27	8-8	0	P6	780	Juan D Hernandez	Senecio Barbertonicus Himalaya	1	1	2025-06-03 15:33:20.948961	\N	\N
513	14315	B27	6-6	0	P6	500	Juan D Hernandez	Senecio SP Crassissimus	1	1	2025-06-03 15:33:20.948961	\N	\N
514	10405	B27	5-6	0	P6	1004	Juan D Hernandez	Senecio SP Crassissimus	1	1	2025-06-03 15:33:20.948961	\N	\N
515	13394	B29	3-3	0	P6	602	Juan D Hernandez	Aloe SP Walmsley Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
516	13395	B29	1-2	0	P6	780	Juan D Hernandez	Aloe SP Walmsley Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
517	13393	B29	2-3	0	P6	1440	Juan D Hernandez	Aloe SP Walmsley Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
518	13621	B29	23-24	0	P6	1903	Juan D Hernandez	Aloe Jucunda x acutissima Bright Star	1	1	2025-06-03 15:33:20.948961	\N	\N
519	12647	B29	22-23	0	P6	1865	Juan D Hernandez	Aloe Jucunda x acutissima Bright Star	1	1	2025-06-03 15:33:20.948961	\N	\N
520	11769	B29	20-21	0	P6	290	Juan D Hernandez	Aloe Jucunda x acutissima Bright Star	1	1	2025-06-03 15:33:20.948961	\N	\N
521	13768	B28	19-20	0	P6	1620	Juan D Hernandez	Aloe Hybrid Pink Blush	1	1	2025-06-03 15:33:20.948961	\N	\N
522	12645	B28	20-22	0	P6	3000	Juan D Hernandez	Aloe Hybrid Pink Blush	1	1	2025-06-03 15:33:20.948961	\N	\N
523	13000	B28	18-19	0	P6	860	Juan D Hernandez	Aloe Hybrid Pink Blush	1	1	2025-06-03 15:33:20.948961	\N	\N
524	9815	B28	18-18	0	P6	160	Juan D Hernandez	Aloe Hybrid Pink Blush	1	1	2025-06-03 15:33:20.948961	\N	\N
525	12644	B27	14-16	0	P6	4065	Juan D Hernandez	Aloe SP Royal Highness	1	1	2025-06-03 15:33:20.948961	\N	\N
526	11187	B27	16-17	0	P6	906	Juan D Hernandez	Aloe SP Royal Highness	1	1	2025-06-03 15:33:20.948961	\N	\N
527	13651	B27	27-27	0	P6	330	Juan D Hernandez	Haworthia SP Spirit 88	1	1	2025-06-03 15:33:20.948961	\N	\N
528	11712	B27	27-27	0	P6	551	Juan D Hernandez	Haworthia SP Spirit 88	1	1	2025-06-03 15:33:20.948961	\N	\N
529	14950	B10	14-17	0	P6	3960	Stefano A Barahona	Liriope Muscari Big Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
530	14654	B10	5-14	0	P6	12936	Stefano A Barahona	Liriope Muscari Big Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
531	13927	B10	4-4	0	P6	264	Stefano A Barahona	Liriope Muscari Big Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
532	15520	D00	2-2	0	P6	100	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
533	13828	B27	37-37	0	P6	1300	Juan D Hernandez	Haworthia SP Fasciata	1	1	2025-06-03 15:33:20.948961	\N	\N
534	13398	B27	34-36	0	P6	3000	Juan D Hernandez	Haworthia SP Fasciata	1	1	2025-06-03 15:33:20.948961	\N	\N
535	13397	B27	41-41	0	P6	722	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
536	13630	B27	41-42	0	P6	777	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
537	13318	B27	42-42	0	P6	963	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
538	13076	B27	44-46	0	P6	1529	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
539	10267	B27	43-44	0	P6	1376	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
540	15481	B27	45-45	0	P6	843	Juan D Hernandez	Haworthia Attenuata Zebra	1	1	2025-06-03 15:33:20.948961	\N	\N
541	14102	C13	1-4	0	P6	6150	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
542	12812	C16	23-30	0	P6	3850	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
543	11185	C16	1-23	0	P6	11750	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
544	11184	C12	1-15	0	P6	23250	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
545	10876	C12	15-26	0	P6	15816	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
546	10320	C12	26-39	0	P6	20495	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
547	8162	C12	39-48	0	P6	14543	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
548	8163	C12	48-50	0	P6	2819	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
549	8164	C12	50-52	0	P6	3869	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
550	8167	C12	52-54	0	P6	2835	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
551	8165	C12	54-59	0	P6	7937	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
552	9671	B29	55-56	0	P6	900	Juan D Hernandez	Mammillaria Elongata Lemon	1	1	2025-06-03 15:33:20.948961	\N	\N
553	13317	B27	38-38	0	P6	473	Juan D Hernandez	Haworthia SP Black Night	1	1	2025-06-03 15:33:20.948961	\N	\N
554	13077	B27	39-39	0	P6	26	Juan D Hernandez	Haworthia SP Black Night	1	1	2025-06-03 15:33:20.948961	\N	\N
555	10966	B27	40-40	0	P6	282	Juan D Hernandez	Haworthia SP Black Night	1	1	2025-06-03 15:33:20.948961	\N	\N
556	11147	B27	40-40	0	P6	578	Juan D Hernandez	Haworthia SP Black Night	1	1	2025-06-03 15:33:20.948961	\N	\N
557	15265	B27	12-13	0	P6	3300	Juan D Hernandez	Haworthia SP Tessellata	1	1	2025-06-03 15:33:20.948961	\N	\N
558	14365	B29	43-43	0	P6	240	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
559	13831	B29	43-45	0	P6	525	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
560	13396	B29	45-46	0	P6	885	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
561	13617	B29	43-44	0	P6	831	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
562	15419	B29	43-43	0	P6	131	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
563	15418	B29	46-46	0	P6	207	Juan D Hernandez	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
564	15478	C03	16-16	0	P6	210	Karen Orozco	Epipremnum Aureum Neon Joy	1	1	2025-06-03 15:33:20.948961	\N	\N
565	10702	C16	36-36	0	P6	394	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
566	14657	E00	26-29	0	P6	2600	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
567	14327	E00	25-26	0	P6	1160	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
568	14326	E00	19-20	0	P6	1170	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
569	14329	E00	18-19	0	P6	1170	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
570	13358	E00	29-35	0	P6	4918	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
571	12996	E00	36-40	0	P6	3218	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
572	13004	E00	40-44	0	P6	3750	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
573	12932	E00	21-22	0	P6	1056	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
574	12762	C04	46-46	0	P6	316	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
575	12697	E00	1-2	0	P6	1086	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
576	12696	E00	2-4	0	P6	1182	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
577	12578	E00	4-4	0	P6	488	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
578	12273	E00	4-7	0	P6	2350	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
579	12042	E00	7-9	0	P6	1472	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
580	11525	E00	9-9	0	P6	612	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
581	11478	C04	46-46	0	P6	71	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
582	11479	E00	22-23	0	P6	1334	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
583	11477	E00	9-12	0	P6	2188	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
584	11075	E00	23-24	0	P6	998	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
585	10793	E00	12-15	0	P6	2131	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
586	10611	C04	46-49	0	P6	912	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
587	10012	C04	49-54	0	P6	2017	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
588	10076	E00	15-18	0	P6	2360	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
589	10011	C04	54-58	0	P6	1765	Karen Orozco	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
590	8166	C12	59-59	0	P6	660	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
591	13312	B27	50-51	0	P6	1025	Juan D Hernandez	Haworthia SP Limifolia	1	1	2025-06-03 15:33:20.948961	\N	\N
592	13129	B27	51-53	0	P6	3140	Juan D Hernandez	Haworthia SP Limifolia	1	1	2025-06-03 15:33:20.948961	\N	\N
593	15365	B09	19-25	0	P6	5775	Stefano A Barahona	Lithodora Diffusa Grace Ward	1	1	2025-06-03 15:33:20.948961	\N	\N
594	15150	B09	53-53	0	P6	348	Stefano A Barahona	Sagina Subulata Subulata	1	1	2025-06-03 15:33:20.948961	\N	\N
595	12866	B09	51-51	0	P6	483	Stefano A Barahona	Sedum Rupestre Lemon Ball	1	1	2025-06-03 15:33:20.948961	\N	\N
596	15508	B13	19-21	0	P6	1650	Stefano A Barahona	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
597	15367	B10	67-70	0	P6	4000	Stefano A Barahona	Trachelospermum Asiaticum Asian Jasmine	1	1	2025-06-03 15:33:20.948961	\N	\N
598	13632	B29	52-53	0	P6	997	Juan D Hernandez	Portulacaria Afra Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
599	10908	B29	51-52	0	P6	768	Juan D Hernandez	Portulacaria Afra Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
600	12865	B24	13-16	0	P6	500	Stefano A Barahona	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
601	13392	C13	49-56	0	P6	5943	Jairo Gonzalez	Aglaonema Commutatum Mini Silver Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
602	14080	B29	10-12	0	P6	1530	Juan D Hernandez	Crassula Ovata Hummel's Sunset	1	1	2025-06-03 15:33:20.948961	\N	\N
603	15149	B09	53-53	0	P6	251	Stefano A Barahona	Sagina Subulata Subulata Aurea	1	1	2025-06-03 15:33:20.948961	\N	\N
604	12851	B29	17-19	0	P6	1600	Juan D Hernandez	Crassula Ovata Mini	1	1	2025-06-03 15:33:20.948961	\N	\N
605	15420	B29	19-19	0	P6	1276	Juan D Hernandez	Crassula Ovata Mini	1	1	2025-06-03 15:33:20.948961	\N	\N
606	14126	C16	37-46	0	P6	5000	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
607	12328	C16	47-52	0	P6	2500	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
608	11131	C16	52-56	0	P6	2102	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
609	10699	C16	56-63	0	P6	3552	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
610	10700	C16	63-69	0	P6	3251	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
611	10701	C16	69-77	0	P6	4231	Jairo Gonzalez	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
612	13048	B24	19-20	0	P6	1263	Stefano A Barahona	Sedum Tetractinum Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
613	15176	D00	12-12	0	P6	64	Maybelle Flores	Color SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
614	15080	B13	37-37	0	P6	500	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
615	14506	B13	31-36	0	P6	1088	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
616	14669	B13	30-30	0	P6	312	Stefano A Barahona	Lantana Camara White	1	1	2025-06-03 15:33:20.948961	\N	\N
617	14063	B13	25-30	0	P6	1728	Stefano A Barahona	Lantana Camara White	1	1	2025-06-03 15:33:20.948961	\N	\N
618	14464	B13	57-57	0	P6	220	Stefano A Barahona	Phlox Paniculata Famous Purple Improved	1	1	2025-06-03 15:33:20.948961	\N	\N
619	14114	B11	44-44	0	P6	400	Stefano A Barahona	Ruellia Brittoniana Mayan Purple Showers	1	1	2025-06-03 15:33:20.948961	\N	\N
620	15170	B13	16-17	0	P6	192	Stefano A Barahona	Scaevola Hybrid Surdiva Fashion Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
621	15172	B13	7-7	0	P6	220	Stefano A Barahona	Scaevola Hybrid Surdiva White	1	1	2025-06-03 15:33:20.948961	\N	\N
622	15171	B13	11-11	0	P6	306	Stefano A Barahona	Scaevola Hybrid Surdiva Sky Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
623	15169	B13	15-16	0	P6	318	Stefano A Barahona	Scaevola Hybrid Surdiva Blue Violet	1	1	2025-06-03 15:33:20.948961	\N	\N
624	14992	B13	4-6	0	P6	948	Stefano A Barahona	Scaevola Hybrid Surdiva White	1	1	2025-06-03 15:33:20.948961	\N	\N
625	14994	B13	7-10	0	P6	975	Stefano A Barahona	Scaevola Hybrid Surdiva Sky Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
626	14993	B13	12-15	0	P6	990	Stefano A Barahona	Scaevola Hybrid Surdiva Blue Violet	1	1	2025-06-03 15:33:20.948961	\N	\N
627	14727	B09	56-56	0	P6	339	Stefano A Barahona	Ajuga Reptans Burgundy Glow	1	1	2025-06-03 15:33:20.948961	\N	\N
628	15209	B13	36-37	0	P6	375	Stefano A Barahona	Lantana Camara Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
629	15081	B13	38-48	0	P6	3120	Stefano A Barahona	Lantana Camara Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
630	14350	B13	2-3	0	P6	318	Stefano A Barahona	Verbena Canadensis Homestead Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
631	14113	B13	1-1	0	P6	152	Stefano A Barahona	Verbena Canadensis Homestead Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
632	14984	B13	3-3	0	P6	450	Stefano A Barahona	Verbena Canadensis Homestead Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
633	14364	B09	54-54	0	P6	102	Stefano A Barahona	Artemisia Arborescens Powis Castle	1	1	2025-06-03 15:33:20.948961	\N	\N
634	14330	C03	17-18	0	P6	498	Karen Orozco	Epipremnum Aureum Neon Joy	1	1	2025-06-03 15:33:20.948961	\N	\N
635	14125	B09	49-49	0	P6	134	Stefano A Barahona	Thymus Serpyllum Pink Chintz	1	1	2025-06-03 15:33:20.948961	\N	\N
636	14123	B09	49-49	0	P6	192	Stefano A Barahona	Thymus Lanuginosus Wolly	1	1	2025-06-03 15:33:20.948961	\N	\N
637	14122	B09	49-49	0	P6	286	Stefano A Barahona	Thymus Vulgaris Silver Edge	1	1	2025-06-03 15:33:20.948961	\N	\N
638	12908	B09	49-49	0	P6	114	Stefano A Barahona	Thymus Vulgaris Silver Edge	1	1	2025-06-03 15:33:20.948961	\N	\N
639	12910	B09	48-48	0	P6	264	Stefano A Barahona	Thymus Lanuginosus Wolly	1	1	2025-06-03 15:33:20.948961	\N	\N
640	12935	B09	48-48	0	P6	270	Stefano A Barahona	Thymus Serpyllum Pink Chintz	1	1	2025-06-03 15:33:20.948961	\N	\N
641	14124	B09	49-49	0	P6	209	Stefano A Barahona	Thymus Praecox Coccineus	1	1	2025-06-03 15:33:20.948961	\N	\N
642	12909	B09	49-49	0	P6	373	Stefano A Barahona	Thymus Praecox Coccineus	1	1	2025-06-03 15:33:20.948961	\N	\N
643	14601	B13	62-62	0	P6	189	Stefano A Barahona	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
644	15834	C18	25-25	0	P7	512	Stefano A Barahona	Mandevilla Sanderii Luna	1	1	2025-06-03 15:33:20.948961	\N	\N
645	15521	D00	6-6	0	P7	199	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
646	15207	D00	6-6	0	P7	92	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
647	15208	D00	5-5	0	P7	98	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
648	15735	D00	15-15	0	P7	98	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
649	15734	D00	15-15	0	P7	98	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
650	15821	C17	29-29	0	P7	91	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
651	15835	C18	22-23	0	P7	148	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
652	15506	C17	55-56	0	P7	768	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
653	14861	C17	32-35	0	P7	1818	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
654	15130	C17	46-50	0	P7	2222	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
655	15131	C17	42-46	0	P7	2222	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
656	15132	C17	50-55	0	P7	2363	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
657	14859	C17	11-15	0	P7	2376	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
658	14860	C17	15-20	0	P7	2376	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
659	14862	C17	25-29	0	P7	2376	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
660	15626	C18	23-24	0	P7	1073	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
661	14935	C17	39-41	0	P7	1414	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
662	15016	C18	31-33	0	P7	1620	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
663	14934	C18	41-44	0	P7	1746	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
664	14863	C18	38-41	0	P7	1818	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
665	14865	C17	35-39	0	P7	1818	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
666	15014	C18	27-30	0	P7	2160	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
667	14885	C18	5-9	0	P7	2222	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
668	14883	C18	18-22	0	P7	2363	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
669	14884	C18	13-18	0	P7	2363	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
670	14886	C18	9-13	0	P7	2363	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
671	15015	C18	1-5	0	P7	2363	Stefano A Barahona	Mandevilla Splendens Bella Scarlet	1	1	2025-06-03 15:33:20.948961	\N	\N
672	14864	C18	34-38	0	P7	2376	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
673	14936	C17	20-25	0	P7	2376	Stefano A Barahona	Mandevilla Splendens Q-deville Ainia QD2	1	1	2025-06-03 15:33:20.948961	\N	\N
674	15446	C18	77-77	0	P7	379	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
731	12792	D02	58-60	0	P8	780	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
675	14887	C18	73-75	0	P7	1080	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
676	14888	C18	75-77	0	P7	1080	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
677	14890	C18	71-73	0	P7	1080	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
678	15443	C17	71-73	0	P7	1080	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
679	15442	C17	75-77	0	P7	1105	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
680	14889	C18	69-71	0	P7	1111	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
681	15444	C17	73-75	0	P7	1111	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
682	15445	C17	69-71	0	P7	1111	Stefano A Barahona	Mandevilla Splendens Terra viva  Solar Noon	1	1	2025-06-03 15:33:20.948961	\N	\N
683	15248	B15	1-1	0	P7	5	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD 1111	1	1	2025-06-03 15:33:20.948961	\N	\N
684	15249	B15	1-1	0	P7	4	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD 1670	1	1	2025-06-03 15:33:20.948961	\N	\N
685	15247	B15	1-1	0	P7	4	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD 1671	1	1	2025-06-03 15:33:20.948961	\N	\N
686	15107	B15	1-1	0	P7	197	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD 1673	1	1	2025-06-03 15:33:20.948961	\N	\N
687	15106	B15	1-1	0	P7	29	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD 984	1	1	2025-06-03 15:33:20.948961	\N	\N
688	15200	B15	7-7	0	P7	88	Stefano A Barahona	Mandevilla Splendens Terra viva  Rose Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
689	14452	B15	7-7	0	P7	54	Maybelle Flores	Mandevilla Splendens Terra viva  TVMD-938	1	1	2025-06-03 15:33:20.948961	\N	\N
690	14456	B15	7-7	0	P7	167	Stefano A Barahona	Mandevilla Splendens Bella Compacta Red	1	1	2025-06-03 15:33:20.948961	\N	\N
691	14891	B15	5-5	0	P7	7	Stefano A Barahona	Mandevilla Splendens Q-deville QD116	1	1	2025-06-03 15:33:20.948961	\N	\N
692	14892	C17	4-4	0	P7	505	Stefano A Barahona	Mandevilla Splendens Bella  Magma	1	1	2025-06-03 15:33:20.948961	\N	\N
693	14662	B15	5-5	0	P7	1	Stefano A Barahona	Mandevilla Splendens Q-deville QD116	1	1	2025-06-03 15:33:20.948961	\N	\N
694	15836	B15	3-3	0	P7	4	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-736	1	1	2025-06-03 15:33:20.948961	\N	\N
695	14683	B15	3-3	0	P7	14	Stefano A Barahona	Mandevilla Splendens Q-deville QD154	1	1	2025-06-03 15:33:20.948961	\N	\N
696	15837	B15	3-3	0	P7	20	Maybelle Flores	Mandevilla Splendens Terra viva  TVMD-938	1	1	2025-06-03 15:33:20.948961	\N	\N
697	15838	B15	3-3	0	P7	49	Stefano A Barahona	Mandevilla Splendens Q-deville QD032	1	1	2025-06-03 15:33:20.948961	\N	\N
698	14048	B15	3-3	0	P7	1	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-1688	1	1	2025-06-03 15:33:20.948961	\N	\N
699	14058	B15	3-3	0	P7	1	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-1693	1	1	2025-06-03 15:33:20.948961	\N	\N
700	14057	B15	3-3	0	P7	3	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-1671	1	1	2025-06-03 15:33:20.948961	\N	\N
701	14056	B15	3-3	0	P7	4	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-1073	1	1	2025-06-03 15:33:20.948961	\N	\N
702	14054	B15	3-3	0	P7	6	Stefano A Barahona	Mandevilla Splendens Q-deville QD154	1	1	2025-06-03 15:33:20.948961	\N	\N
703	14096	B15	3-3	0	P7	10	Stefano A Barahona	Mandevilla Splendens Q-deville QD171	1	1	2025-06-03 15:33:20.948961	\N	\N
704	14036	B15	3-3	0	P7	11	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-736	1	1	2025-06-03 15:33:20.948961	\N	\N
705	14095	B15	3-3	0	P7	18	Maybelle Flores	Mandevilla Splendens Terra viva  TVMD-938	1	1	2025-06-03 15:33:20.948961	\N	\N
706	14059	B15	3-3	0	P7	78	Stefano A Barahona	Mandevilla Splendens Terra viva  TVMD-1719	1	1	2025-06-03 15:33:20.948961	\N	\N
707	14037	B15	5-5	0	P7	15	Stefano A Barahona	Mandevilla Splendens Q-deville QD116	1	1	2025-06-03 15:33:20.948961	\N	\N
708	14032	B15	5-5	0	P7	113	Stefano A Barahona	Mandevilla Splendens Bella Compacta Red	1	1	2025-06-03 15:33:20.948961	\N	\N
709	14041	B15	4-4	0	P7	209	Stefano A Barahona	Mandevilla Splendens Bella Red Bolero	1	1	2025-06-03 15:33:20.948961	\N	\N
710	14938	C18	58-60	0	P7	1184	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
711	14866	C18	55-58	0	P7	1918	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
712	14939	C17	68-68	0	P7	306	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
713	15736	C18	60-63	0	P7	1688	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
714	14867	C17	64-68	0	P7	1918	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
715	14869	C17	60-64	0	P7	1918	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
716	14940	C17	57-60	0	P7	1918	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
717	14868	C18	52-55	0	P7	1184	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
718	14870	C18	50-52	0	P7	1184	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
719	14872	C18	45-47	0	P7	1184	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
720	14871	C18	47-50	0	P7	1918	Stefano A Barahona	Mandevilla Splendens Costa Del Sol Marbella Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
721	14878	C18	66-66	0	P7	540	Stefano A Barahona	Mandevilla Madinia Rio Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
722	14880	C18	65-65	0	P7	540	Stefano A Barahona	Mandevilla Madinia Rio Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
723	14873	C18	67-67	0	P7	540	Stefano A Barahona	Mandevilla Madinia Rio Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
724	14874	C18	68-68	0	P7	540	Stefano A Barahona	Mandevilla Madinia Rio Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
725	14876	C18	64-64	0	P7	540	Stefano A Barahona	Mandevilla Madinia Rio Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
726	15181	B15	6-6	0	P7	13	Stefano A Barahona	Mandevilla Splendens Q-deville Doris	1	1	2025-06-03 15:33:20.948961	\N	\N
727	14664	B15	6-6	0	P7	68	Stefano A Barahona	Mandevilla Splendens Q-deville Doris	1	1	2025-06-03 15:33:20.948961	\N	\N
728	14038	B15	5-5	0	P7	61	Stefano A Barahona	Mandevilla Splendens Q-deville QD114	1	1	2025-06-03 15:33:20.948961	\N	\N
729	15842	D00	7-7	0	P8	40	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
730	11085	A02	45-45	0	P8	330	Juan D Hernandez	Cereus SP Peruvianus	1	1	2025-06-03 15:33:20.948961	\N	\N
732	14203	D01	8-8	0	P8	339	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
733	14031	D01	9-12	0	P8	1562	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
734	13852	D01	12-14	0	P8	1446	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
735	14773	D01	20-21	0	P8	831	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
736	12669	D01	18-19	0	P8	1070	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
737	12488	D01	6-8	0	P8	1251	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
738	12186	D01	1-1	0	P8	538	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
739	11317	D01	4-5	0	P8	640	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
740	9603	D01	2-4	0	P8	1501	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
741	13588	E08	15-21	0	P8	838	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
742	13241	E08	21-31	0	P8	1248	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
743	12583	E08	31-46	0	P8	1863	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
744	12040	E08	46-49	0	P8	373	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
745	14645	E07	33-45	0	P8	1580	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
746	14162	E07	18-33	0	P8	2000	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
747	13242	E07	1-7	0	P8	810	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
748	12780	E07	12-18	0	P8	794	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
749	12421	E07	8-12	0	P8	486	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
750	12270	E07	7-8	0	P8	147	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
751	12668	C03	23-32	0	P8	2290	Karen Orozco	Dieffenbachia SP Vesuvius	1	1	2025-06-03 15:33:20.948961	\N	\N
752	12185	C03	40-42	0	P8	602	Karen Orozco	Dieffenbachia SP Vesuvius	1	1	2025-06-03 15:33:20.948961	\N	\N
753	12184	C03	32-40	0	P8	2047	Karen Orozco	Dieffenbachia SP Vesuvius	1	1	2025-06-03 15:33:20.948961	\N	\N
754	14858	B11	52-54	0	P8	890	Stefano A Barahona	Tradescantia Zebrina Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
755	15379	E08	1-5	0	P8	600	Karen Orozco	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
756	15437	E07	65-71	0	P8	890	Karen Orozco	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
757	15370	C03	19-22	0	P8	1000	Karen Orozco	Dieffenbachia SP Vesuvius	1	1	2025-06-03 15:33:20.948961	\N	\N
758	15369	C03	10-15	0	P8	1500	Karen Orozco	Dieffenbachia SP Vesuvius	1	1	2025-06-03 15:33:20.948961	\N	\N
759	11496	C22	29-31	0	P8	1250	Jairo Gonzalez	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
760	8332	C15	41-45	0	P8	1571	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
761	7423	C07	51-56	0	P8	2861	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
762	10330	C07	13-22	0	P8	4621	Jairo Gonzalez	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
763	7407	C07	6-12	0	P8	3291	Jairo Gonzalez	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
764	7408	C07	3-6	0	P8	1581	Jairo Gonzalez	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
765	10618	C07	22-28	0	P8	2965	Jairo Gonzalez	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
766	10629	C08	67-68	0	P8	437	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
767	10628	C08	65-67	0	P8	1229	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
768	10627	C08	59-64	0	P8	2731	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
769	10626	C08	56-59	0	P8	1738	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
770	10625	C08	49-55	0	P8	3438	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
771	11512	C14	90-91	0	P8	1004	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
772	11511	C15	89-93	0	P8	1916	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
773	11510	C08	11-17	0	P8	3053	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
774	11481	C08	86-88	0	P8	612	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
775	11173	C15	80-89	0	P8	4376	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
776	11130	C15	73-80	0	P8	3300	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
777	10317	C15	63-67	0	P8	2036	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
778	10649	C15	67-73	0	P8	2812	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
779	9782	C15	53-63	0	P8	4676	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
780	9462	C15	47-53	0	P8	2516	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
781	8364	C15	45-47	0	P8	1304	Jairo Gonzalez	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
782	15483	E11	58-58	0	P8	60	Karen Orozco	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
783	15304	E11	59-67	0	P8	1002	Karen Orozco	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
784	7413	C07	42-42	0	P8	211	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
785	7412	C07	43-43	0	P8	479	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
786	10325	C07	42-42	0	P8	164	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
787	7496	C08	22-25	0	P8	1719	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
788	8320	C15	5-13	0	P8	4242	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
789	7414	C07	42-42	0	P8	105	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
790	15136	C07	57-64	0	P8	3299	Jairo Gonzalez	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
791	8318	C15	1-3	0	P8	1045	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
792	8319	C15	3-5	0	P8	1189	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
793	14717	B06	39-82	0	P8	20610	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
794	14459	B06	1-39	0	P8	20000	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
795	14100	C22	47-93	0	P8	23865	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
796	14101	C22	31-46	0	P8	7949	Jairo Gonzalez	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
797	15138	C14	15-20	0	P8	2668	Jairo Gonzalez	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
798	15137	C14	13-14	0	P8	1236	Jairo Gonzalez	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
799	11333	C14	85-89	0	P8	2370	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
800	9463	C14	69-85	0	P8	8605	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
801	8950	C14	64-69	0	P8	2582	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
802	8864	C14	61-64	0	P8	1948	Jairo Gonzalez	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
803	15720	E06	55-58	0	P8	384	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
804	15175	E11	46-46	0	P8	55	Karen Orozco	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
805	14328	E11	45-46	0	P8	253	Karen Orozco	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
806	15517	E11	47-47	0	P8	186	Karen Orozco	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
807	13922	E06	9-19	0	P8	1300	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
808	11923	B08	49-52	0	P8	559	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
809	11072	D21	15-19	0	P8	553	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
810	10816	C14	5-5	0	P8	278	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
811	9365	C14	3-5	0	P8	1499	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
812	14670	B11	66-66	0	P8	153	Stefano A Barahona	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
813	14656	E06	58-58	0	P8	100	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
814	14357	E06	59-63	0	P8	553	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
815	13849	E06	63-72	0	P8	1250	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
816	11052	D21	36-41	0	P8	789	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
817	11053	D21	41-42	0	P8	183	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
818	11081	D21	43-48	0	P8	793	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
819	11082	D21	56-63	0	P8	967	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
820	11058	D21	65-73	0	P8	1185	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
821	9778	B24	1-1	0	P8	92	Juan D Hernandez	Kalanchoe SP Humilis	1	1	2025-06-03 15:33:20.948961	\N	\N
822	13513	D02	27-27	0	P8	72	Karen Orozco	Epipremnum Aureum Manjula	1	1	2025-06-03 15:33:20.948961	\N	\N
823	13051	D02	27-27	0	P8	76	Karen Orozco	Epipremnum Aureum Manjula	1	1	2025-06-03 15:33:20.948961	\N	\N
824	14972	B07	28-28	0	P8	70	Stefano A Barahona	Lantana Camara Bandana Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
825	14971	B07	47-49	0	P8	1090	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
826	14970	B07	50-52	0	P8	987	Stefano A Barahona	Lantana Camara White	1	1	2025-06-03 15:33:20.948961	\N	\N
827	15479	B29	46-47	0	P8	1216	Juan D Hernandez	Euphorbia Trigona Red	1	1	2025-06-03 15:33:20.948961	\N	\N
828	14986	E11	58-58	0	P8	67	Karen Orozco	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
829	14969	B07	20-20	0	P8	334	Stefano A Barahona	Cuphea Hyssopifolia Allyson Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
830	15086	D02	56-57	0	P8Az	480	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
831	14942	D02	53-55	0	P8Az	1000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
832	15087	D02	38-38	0	P8Az	390	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
833	14944	D02	39-41	0	P8Az	1000	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
834	11166	B29	6-7	0	P8Az	500	Juan D Hernandez	Euphorbia Lactea Candelabra	1	1	2025-06-03 15:33:20.948961	\N	\N
835	15713	D02	35-35	0	P8Az	104	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
836	15518	D02	34-35	0	P8Az	300	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
837	15376	D01	7-7	0	P8Az	240	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
838	15375	D02	36-37	0	P8Az	460	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
839	15374	D02	35-36	0	P8Az	500	Karen Orozco	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
840	15079	B11	54-54	0	P8Az	100	Stefano A Barahona	Tradescantia Zebrina Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
841	14325	B11	47-52	0	P8Az	2314	Stefano A Barahona	Setcreasea Pallida Purple Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
842	14132	B11	38-40	0	P8Az	1285	Stefano A Barahona	Tradescantia Zebrina Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
843	15654	D01	31-34	0	P8Az	2000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
844	15714	D02	51-51	0	P8Az	105	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
845	15541	D01	35-38	0	P8Az	2000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
846	15534	D01	39-42	0	P8Az	2000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
847	15436	D01	27-30	0	P8Az	2000	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
848	15372	D02	57-58	0	P8Az	500	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
849	15373	D02	52-53	0	P8Az	480	Karen Orozco	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
850	15528	E11	75-82	0	P8Az	925	Karen Orozco	Philodendron SP Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
851	15378	D00	5-5	0	P8Az	249	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
852	15206	D00	7-7	0	P8Az	40	Maybelle Flores	Foliage SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
853	15431	E04	63-71	0	P8Az	1112	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
854	15791	B15	36-36	0	P8Az	31	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
855	15650	B15	35-36	0	P8Az	240	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
856	15390	B14	17-24	0	P8Az	1493	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
857	15830	B15	50-50	0	P8Az	21	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
858	15651	B15	50-50	0	P8Az	83	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
859	15389	B14	43-50	0	P8Az	1506	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
860	15802	B28	54-55	0	P8Az	128	Juan D Hernandez	Graptosedum SP Ghosty	1	1	2025-06-03 15:33:20.948961	\N	\N
861	15715	E04	10-11	0	P8Az	140	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
862	15652	E02	8-13	0	P8Az	690	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
863	15305	B24	22-22	0	P8Az	220	Stefano A Barahona	Sedum Tetractinum Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
864	15571	B14	5-5	0	P8Az	20	Stefano A Barahona	Scaevola Hybrid Surdiva White	1	1	2025-06-03 15:33:20.948961	\N	\N
865	15567	B14	5-5	0	P8Az	10	Stefano A Barahona	Phlox Paniculata Famous Pink Dark Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
866	15568	B14	5-5	0	P8Az	10	Stefano A Barahona	Phlox Paniculata Famous White Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
867	15569	B14	5-5	0	P8Az	10	Stefano A Barahona	Phlox Paniculata Famous Purple Improved	1	1	2025-06-03 15:33:20.948961	\N	\N
868	15587	B14	6-6	0	P8Az	10	Stefano A Barahona	Salvia Farinacea Sallyfun Snowhite	1	1	2025-06-03 15:33:20.948961	\N	\N
869	15588	B14	6-6	0	P8Az	20	Stefano A Barahona	Salvia Farinacea Sallyfun Deep Ocean	1	1	2025-06-03 15:33:20.948961	\N	\N
870	15589	B14	6-6	0	P8Az	20	Stefano A Barahona	Salvia Farinacea Sallyfun Bicolor Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
871	15529	E11	83-90	0	P8Az	954	Karen Orozco	Epipremnum Aureum Marble Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
872	15526	B09	13-14	0	P8Az	246	Stefano A Barahona	Rosmarinus Officinalis Rosemary barbecue	1	1	2025-06-03 15:33:20.948961	\N	\N
873	15557	B14	8-8	0	P8Az	20	Stefano A Barahona	Lantana Camara Bandolero White	1	1	2025-06-03 15:33:20.948961	\N	\N
874	15723	B07	32-32	0	P8Az	267	Stefano A Barahona	Lantana Camara Bandana White	1	1	2025-06-03 15:33:20.948961	\N	\N
875	15560	B14	7-7	0	P8Az	30	Stefano A Barahona	Lantana Camara Bandolero Guava	1	1	2025-06-03 15:33:20.948961	\N	\N
876	15562	B14	7-7	0	P8Az	30	Stefano A Barahona	Lantana Camara Bandana White	1	1	2025-06-03 15:33:20.948961	\N	\N
877	15574	B14	5-5	0	P8Az	20	Stefano A Barahona	Scaevola Hybrid Surdiva Blue Violet	1	1	2025-06-03 15:33:20.948961	\N	\N
878	15572	B14	5-5	0	P8Az	20	Stefano A Barahona	Scaevola Hybrid Surdiva Sky Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
879	15558	B14	7-7	0	P8Az	50	Stefano A Barahona	Lantana Camara Bandolero Red	1	1	2025-06-03 15:33:20.948961	\N	\N
880	15724	B07	69-69	0	P8Az	78	Stefano A Barahona	Strobilanthes Dyeriana Persian Shield	1	1	2025-06-03 15:33:20.948961	\N	\N
881	15586	B14	6-6	0	P8Az	50	Stefano A Barahona	Sanchezia SP Nobilis	1	1	2025-06-03 15:33:20.948961	\N	\N
882	15592	B14	5-5	0	P8Az	50	Stefano A Barahona	Verbena Bonariensis Lollipop	1	1	2025-06-03 15:33:20.948961	\N	\N
883	15543	B14	6-6	0	P8Az	10	Stefano A Barahona	Cuphea Llavea Floriglory Diana	1	1	2025-06-03 15:33:20.948961	\N	\N
884	15575	B14	6-6	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan White	1	1	2025-06-03 15:33:20.948961	\N	\N
885	15577	B14	6-6	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
886	15578	B14	6-6	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
887	15515	B12	8-17	0	P8Az	2000	Stefano A Barahona	Euphorbia Pulcherrima A1 Red	1	1	2025-06-03 15:33:20.948961	\N	\N
888	15363	B12	1-8	0	P8Az	1500	Stefano A Barahona	Euphorbia Pulcherrima A1 Red	1	1	2025-06-03 15:33:20.948961	\N	\N
889	15555	B14	8-8	0	P8Az	49	Stefano A Barahona	Lantana Camara White	1	1	2025-06-03 15:33:20.948961	\N	\N
890	15527	B09	11-12	0	P8Az	990	Stefano A Barahona	Rosmarinus Officinalis Tuscan Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
891	15423	B09	11-11	0	P8Az	279	Stefano A Barahona	Rosmarinus Officinalis Tuscan Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
892	14918	B24	42-43	0	P8Az	418	Juan D Hernandez	Kalanchoe Daigremontiana Pink Butterfly	1	1	2025-06-03 15:33:20.948961	\N	\N
893	13604	B24	42-42	0	P8Az	42	Juan D Hernandez	Kalanchoe Daigremontiana Pink Butterfly	1	1	2025-06-03 15:33:20.948961	\N	\N
894	12922	B24	8-10	0	P8Az	1477	Juan D Hernandez	Kalanchoe SP Krinkle Red	1	1	2025-06-03 15:33:20.948961	\N	\N
895	15510	B12	69-69	0	P8Az	120	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas Bond	1	1	2025-06-03 15:33:20.948961	\N	\N
896	15513	B12	65-66	0	P8Az	300	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas QS-44 (Light Red)	1	1	2025-06-03 15:33:20.948961	\N	\N
897	15426	B12	60-60	0	P8Az	100	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas Qs-113	1	1	2025-06-03 15:33:20.948961	\N	\N
898	15425	B12	61-61	0	P8Az	100	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas Qs-127	1	1	2025-06-03 15:33:20.948961	\N	\N
899	15424	B12	62-62	0	P8Az	100	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas Bond	1	1	2025-06-03 15:33:20.948961	\N	\N
900	15427	B12	65-65	0	P8Az	140	Stefano A Barahona	Euphorbia Pulcherrima Q-ismas QS-44 (Light Red)	1	1	2025-06-03 15:33:20.948961	\N	\N
901	15429	B12	49-53	0	P8Az	860	Stefano A Barahona	Euphorbia Pulcherrima Pepita Early Red	1	1	2025-06-03 15:33:20.948961	\N	\N
902	15430	B12	26-44	0	P8Az	3968	Stefano A Barahona	Euphorbia Pulcherrima Legacy Red	1	1	2025-06-03 15:33:20.948961	\N	\N
903	15556	B14	8-8	0	P8Az	30	Stefano A Barahona	Lantana Camara Bandolero Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
904	15559	B14	7-7	0	P8Az	49	Stefano A Barahona	Lantana Camara Bandolero Pineapple	1	1	2025-06-03 15:33:20.948961	\N	\N
905	15566	B14	7-7	0	P8Az	50	Stefano A Barahona	Lantana Camara Bandana Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
906	15366	B09	10-10	0	P8Az	500	Stefano A Barahona	Lithodora Diffusa Grace Ward	1	1	2025-06-03 15:33:20.948961	\N	\N
907	15576	B14	6-6	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan Purple Showers	1	1	2025-06-03 15:33:20.948961	\N	\N
908	15554	B14	8-8	0	P8Az	47	Stefano A Barahona	Lantana Camara Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
909	14079	B28	27-29	0	P8Az	2723	Juan D Hernandez	Sedum SP Nussbaumerianum	1	1	2025-06-03 15:33:20.948961	\N	\N
910	13401	B28	28-29	0	P8Az	750	Juan D Hernandez	Sedum SP Nussbaumerianum	1	1	2025-06-03 15:33:20.948961	\N	\N
911	9359	B28	24-26	0	P8Az	2000	Juan D Hernandez	Sedum SP Nussbaumerianum	1	1	2025-06-03 15:33:20.948961	\N	\N
912	15112	D03	49-50	0	P8Az	100	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
913	14987	D03	47-49	0	P8Az	581	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
914	13850	D03	41-47	0	P8Az	1600	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
915	13525	D03	38-40	0	P8Az	532	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
916	13406	D03	34-38	0	P8Az	1064	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
917	12694	D03	34-34	0	P8Az	72	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
918	12272	D03	18-23	0	P8Az	1129	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
919	12182	D03	2-2	0	P8Az	204	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
920	12035	D03	15-18	0	P8Az	1185	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
921	11705	D03	13-15	0	P8Az	786	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
922	11480	D03	11-13	0	P8Az	910	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
923	11251	D03	10-11	0	P8Az	274	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
924	11164	D03	10-10	0	P8Az	62	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
925	10961	D03	8-10	0	P8Az	637	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
926	10776	D03	7-8	0	P8Az	522	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
927	10071	D03	2-7	0	P8Az	1727	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
928	10075	D03	1-2	0	P8Az	320	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
929	10073	D03	1-1	0	P8Az	148	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
930	15516	D03	52-53	0	P8Az	440	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
931	15262	D03	50-50	0	P8Az	220	Karen Orozco	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
932	15653	E11	48-49	0	P8Az	105	Karen Orozco	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
933	15561	B14	7-7	0	P8Az	30	Stefano A Barahona	Lantana Camara Bandana Red	1	1	2025-06-03 15:33:20.948961	\N	\N
934	15564	B14	7-7	0	P8Az	49	Stefano A Barahona	Lantana Camara Bandana Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
935	13627	B28	52-54	0	P8Az	761	Juan D Hernandez	Graptosedum SP Bronze	1	1	2025-06-03 15:33:20.948961	\N	\N
936	12847	B28	52-52	0	P8Az	757	Juan D Hernandez	Graptosedum SP Bronze	1	1	2025-06-03 15:33:20.948961	\N	\N
937	9243	B28	53-53	0	P8Az	490	Juan D Hernandez	Graptosedum SP Bronze	1	1	2025-06-03 15:33:20.948961	\N	\N
938	12991	B14	13-13	0	P8Az	50	Stefano A Barahona	Euphorbia Pulcherrima Ranch Red	1	1	2025-06-03 15:33:20.948961	\N	\N
939	15553	B14	8-8	0	P8Az	49	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
940	14628	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandolero Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
941	13841	B07	34-34	0	P8Az	430	Stefano A Barahona	Lantana Camara Bandolero Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
942	14625	B14	1-1	0	P8Az	10	Stefano A Barahona	Lantana Camara Bandolero Red	1	1	2025-06-03 15:33:20.948961	\N	\N
943	14635	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandana Bandana Cherry	1	1	2025-06-03 15:33:20.948961	\N	\N
944	14636	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandana Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
945	13836	B07	39-39	0	P8Az	175	Stefano A Barahona	Lantana Camara Bandolero Red	1	1	2025-06-03 15:33:20.948961	\N	\N
946	13837	B07	38-38	0	P8Az	430	Stefano A Barahona	Lantana Camara Bandolero Red	1	1	2025-06-03 15:33:20.948961	\N	\N
947	13846	B07	22-23	0	P8Az	605	Stefano A Barahona	Lantana Camara Bandana Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
948	13845	B07	26-28	0	P8Az	1061	Stefano A Barahona	Lantana Camara Bandana Bandana Cherry	1	1	2025-06-03 15:33:20.948961	\N	\N
949	15268	B07	32-32	0	P8Az	34	Stefano A Barahona	Lantana Camara Bandana White	1	1	2025-06-03 15:33:20.948961	\N	\N
950	14624	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandolero White	1	1	2025-06-03 15:33:20.948961	\N	\N
951	14631	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandana White	1	1	2025-06-03 15:33:20.948961	\N	\N
952	14961	B07	39-39	0	P8Az	250	Stefano A Barahona	Lantana Camara Bandolero White	1	1	2025-06-03 15:33:20.948961	\N	\N
953	15368	B10	62-63	0	P8Az	500	Stefano A Barahona	Trachelospermum Asiaticum Asian Jasmine	1	1	2025-06-03 15:33:20.948961	\N	\N
954	15563	B14	7-7	0	P8Az	50	Stefano A Barahona	Lantana Camara Bandana Cherry Sunrise	1	1	2025-06-03 15:33:20.948961	\N	\N
955	15565	B14	7-7	0	P8Az	97	Stefano A Barahona	Lantana Camara Bandana Bandana Cherry	1	1	2025-06-03 15:33:20.948961	\N	\N
956	14611	B14	2-2	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
957	15251	B11	65-66	0	P8Az	312	Stefano A Barahona	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
958	14103	B11	66-66	0	P8Az	180	Stefano A Barahona	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
959	13135	B24	46-47	0	P8Az	845	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
960	12937	B24	55-55	0	P8Az	171	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
961	12938	B24	49-49	0	P8Az	320	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
962	12008	B24	54-54	0	P8Az	308	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
963	12321	B24	55-55	0	P8Az	98	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
964	11921	B24	50-50	0	P8Az	121	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
965	11109	B24	50-51	0	P8Az	309	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
966	9152	B24	52-52	0	P8Az	165	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
967	8183	B24	52-53	0	P8Az	128	Juan D Hernandez	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
968	15514	B12	53-54	0	P8Az	420	Stefano A Barahona	Euphorbia Pulcherrima Ranch Red	1	1	2025-06-03 15:33:20.948961	\N	\N
969	13913	B12	70-70	0	P8Az	198	Stefano A Barahona	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
970	14627	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandolero Guava	1	1	2025-06-03 15:33:20.948961	\N	\N
971	14978	B07	33-33	0	P8Az	430	Stefano A Barahona	Lantana Camara Bandolero Guava	1	1	2025-06-03 15:33:20.948961	\N	\N
972	13523	E06	72-75	0	P8Az	400	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
973	13313	B24	1-4	0	P8Az	1712	Juan D Hernandez	Kalanchoe SP Humilis	1	1	2025-06-03 15:33:20.948961	\N	\N
974	15482	B24	5-5	0	P8Az	461	Juan D Hernandez	Kalanchoe SP Humilis	1	1	2025-06-03 15:33:20.948961	\N	\N
975	15109	E03	1-15	0	P8Az	1924	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
976	14207	E03	89-90	0	P8Az	729	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
977	13924	E03	73-88	0	P8Az	2000	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
978	13403	E03	62-73	0	P8Az	1179	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
979	13359	E03	53-61	0	P8Az	1193	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
980	15737	E03	52-52	0	P8Az	66	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
981	13141	E03	34-52	0	P8Az	2470	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
982	10021	E03	21-33	0	P8Az	1864	Karen Orozco	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
983	14626	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandolero Pineapple	1	1	2025-06-03 15:33:20.948961	\N	\N
984	13838	B07	36-37	0	P8Az	860	Stefano A Barahona	Lantana Camara Bandolero Pineapple	1	1	2025-06-03 15:33:20.948961	\N	\N
985	13625	B24	32-32	0	P8Az	488	Juan D Hernandez	Kalanchoe Fedtschenkoi Red Scallop	1	1	2025-06-03 15:33:20.948961	\N	\N
986	13631	B24	36-41	0	P8Az	2607	Juan D Hernandez	Kalanchoe Fedtschenkoi Red Scallop	1	1	2025-06-03 15:33:20.948961	\N	\N
987	12605	B24	39-39	0	P8Az	20	Juan D Hernandez	Kalanchoe Fedtschenkoi Red Scallop	1	1	2025-06-03 15:33:20.948961	\N	\N
988	13830	B29	13-13	0	P8Az	350	Juan D Hernandez	Crassula SP Sarmentosa	1	1	2025-06-03 15:33:20.948961	\N	\N
989	9994	B29	13-13	0	P8Az	72	Juan D Hernandez	Crassula SP Sarmentosa	1	1	2025-06-03 15:33:20.948961	\N	\N
990	12986	B14	13-13	0	P8Az	50	Stefano A Barahona	Euphorbia Pulcherrima 16-499	1	1	2025-06-03 15:33:20.948961	\N	\N
991	12985	B14	13-13	0	P8Az	50	Stefano A Barahona	Euphorbia Pulcherrima 16-324	1	1	2025-06-03 15:33:20.948961	\N	\N
992	12987	B14	14-15	0	P8Az	560	Stefano A Barahona	Euphorbia Pulcherrima A1 Red	1	1	2025-06-03 15:33:20.948961	\N	\N
993	14638	B14	2-2	0	P8Az	5	Stefano A Barahona	Cuphea Llavea Floriglory Diana	1	1	2025-06-03 15:33:20.948961	\N	\N
994	14267	B07	21-21	0	P8Az	210	Stefano A Barahona	Cuphea Llavea Floriglory Diana	1	1	2025-06-03 15:33:20.948961	\N	\N
995	15325	B14	6-6	0	P8Az	80	Stefano A Barahona	Gaura Lindheimeri Belleza Dark Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
996	13526	B28	38-38	0	P8Az	331	Juan D Hernandez	Graptosedum SP California Sunset	1	1	2025-06-03 15:33:20.948961	\N	\N
997	12846	B28	38-39	0	P8Az	1165	Juan D Hernandez	Graptosedum SP California Sunset	1	1	2025-06-03 15:33:20.948961	\N	\N
998	9477	B28	39-40	0	P8Az	998	Juan D Hernandez	Graptosedum SP California Sunset	1	1	2025-06-03 15:33:20.948961	\N	\N
999	12989	B14	16-16	0	P8Az	372	Stefano A Barahona	Euphorbia Pulcherrima Legacy Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1000	14951	B28	41-42	0	P8Az	1029	Juan D Hernandez	Sedum SP Reflexum	1	1	2025-06-03 15:33:20.948961	\N	\N
1001	12849	B28	43-44	0	P8Az	1505	Juan D Hernandez	Graptosedum SP Alpenglow	1	1	2025-06-03 15:33:20.948961	\N	\N
1002	14725	B11	36-37	0	P8Az	820	Stefano A Barahona	Lysimachia Nummularia Goldilocks	1	1	2025-06-03 15:33:20.948961	\N	\N
1003	15031	B11	31-35	0	P8Az	1875	Stefano A Barahona	Lysimachia Nummularia Goldilocks	1	1	2025-06-03 15:33:20.948961	\N	\N
1004	15591	B14	5-5	0	P8Az	40	Stefano A Barahona	Verbena Peruviana Endurascape Pink Bicolor	1	1	2025-06-03 15:33:20.948961	\N	\N
1005	14976	B07	64-64	0	P8Az	235	Stefano A Barahona	Plumbago Auriculata Imperial Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1006	14072	B07	59-59	0	P8Az	216	Stefano A Barahona	Plumbago Auriculata Imperial Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1007	14977	B07	60-64	0	P8Az	1904	Stefano A Barahona	Plumbago Auriculata Imperial Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1008	15552	B14	6-6	0	P8Az	48	Stefano A Barahona	Evolvulus Nuttallianus Blue Daze	1	1	2025-06-03 15:33:20.948961	\N	\N
1009	13919	B11	25-27	0	P8Az	1370	Stefano A Barahona	Pseuderanthemum Laxiflorum Amethyst Star	1	1	2025-06-03 15:33:20.948961	\N	\N
1010	13914	B12	69-69	0	P8Az	184	Stefano A Barahona	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
1011	12988	B14	13-13	0	P8Az	50	Stefano A Barahona	Euphorbia Pulcherrima Pepita Early Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1012	14612	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Blueberry Kiss	1	1	2025-06-03 15:33:20.948961	\N	\N
1013	14610	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Coral	1	1	2025-06-03 15:33:20.948961	\N	\N
1014	15601	B07	70-70	0	P8Az	65	Stefano A Barahona	Cuphea SP Stellar Lilac	1	1	2025-06-03 15:33:20.948961	\N	\N
1015	15599	B07	70-70	0	P8Az	60	Stefano A Barahona	Cuphea SP Stellar White	1	1	2025-06-03 15:33:20.948961	\N	\N
1016	15600	B07	70-70	0	P8Az	41	Stefano A Barahona	Cuphea SP Stellar Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1017	15692	B07	70-70	0	P8Az	50	Stefano A Barahona	Cuphea SP CUH 21 16-01	1	1	2025-06-03 15:33:20.948961	\N	\N
1018	15544	B14	6-6	0	P8Az	10	Stefano A Barahona	Cuphea Llavea Floriglory Selena	1	1	2025-06-03 15:33:20.948961	\N	\N
1019	15542	B14	6-6	0	P8Az	100	Stefano A Barahona	Cuphea Hyssopifolia Allyson Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1020	14609	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1021	14608	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Light Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
1022	14607	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii Red Shades	1	1	2025-06-03 15:33:20.948961	\N	\N
1023	12845	B28	46-48	0	P8Az	2902	Juan D Hernandez	Graptosedum SP Darley Sunshine	1	1	2025-06-03 15:33:20.948961	\N	\N
1024	15085	B24	21-21	0	P8Az	125	Stefano A Barahona	Sedum Tetractinum Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
1025	14633	B14	2-2	0	P8Az	11	Stefano A Barahona	Lantana Camara Bandana Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1026	14632	B14	2-2	0	P8Az	15	Stefano A Barahona	Lantana Camara Bandana Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
1027	13843	B07	31-31	0	P8Az	415	Stefano A Barahona	Lantana Camara Bandana Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1028	13842	B07	23-25	0	P8Az	1066	Stefano A Barahona	Lantana Camara Bandana Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
1029	12850	B28	54-55	0	P8Az	860	Juan D Hernandez	Graptosedum SP Ghosty	1	1	2025-06-03 15:33:20.948961	\N	\N
1030	6757	B28	56-56	0	P8Az	431	Juan D Hernandez	Graptosedum SP Ghosty	1	1	2025-06-03 15:33:20.948961	\N	\N
1031	15573	B14	5-5	0	P8Az	20	Stefano A Barahona	Scaevola Hybrid Surdiva Fashion Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1032	14606	B14	1-1	0	P8Az	10	Stefano A Barahona	Vinca Roseus Soiree Kawaii White Peppermint	1	1	2025-06-03 15:33:20.948961	\N	\N
1033	15210	B15	17-20	0	P8Az	650	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1034	14082	B15	31-31	0	P8Az	205	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1035	15028	B15	21-23	0	P8Az	300	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1036	15029	B15	23-31	0	P8Az	1280	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1037	14634	B14	2-2	0	P8Az	14	Stefano A Barahona	Lantana Camara Bandana Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1038	13844	B07	29-30	0	P8Az	860	Stefano A Barahona	Lantana Camara Bandana Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1039	15590	B14	5-5	0	P8Az	40	Stefano A Barahona	Verbena Peruviana Endurascape Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1040	14630	B14	2-2	0	P8Az	16	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
1041	13832	B07	45-47	0	P8Az	1075	Stefano A Barahona	Lantana Camara New Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
1042	14619	B14	2-2	0	P8Az	10	Stefano A Barahona	Verbena Peruviana Endurascape Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1043	14061	B07	68-68	0	P8Az	381	Stefano A Barahona	Strobilanthes Dyeriana Persian Shield	1	1	2025-06-03 15:33:20.948961	\N	\N
1044	15593	B14	5-5	0	P8Az	40	Stefano A Barahona	Verbena Canadensis Homestead Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
1045	15509	B11	62-62	0	P8Az	450	Stefano A Barahona	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1046	15476	B11	64-65	0	P8Az	550	Stefano A Barahona	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1047	14790	B07	19-20	0	P8Az	140	Stefano A Barahona	Cuphea Llavea Floriglory Selena	1	1	2025-06-03 15:33:20.948961	\N	\N
1048	14637	B14	2-2	0	P8Az	5	Stefano A Barahona	Cuphea Llavea Floriglory Selena	1	1	2025-06-03 15:33:20.948961	\N	\N
1049	14268	B07	21-21	0	P8Az	204	Stefano A Barahona	Cuphea Llavea Floriglory Selena	1	1	2025-06-03 15:33:20.948961	\N	\N
1050	15084	B07	35-35	0	P8Az	90	Stefano A Barahona	Plectranthus X hybrida Burgundy Wedding Train	1	1	2025-06-03 15:33:20.948961	\N	\N
1051	14672	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Salsa Verde	1	1	2025-06-03 15:33:20.948961	\N	\N
1052	14674	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Habanero	1	1	2025-06-03 15:33:20.948961	\N	\N
1053	14671	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus X hybrida Burgundy Wedding Train	1	1	2025-06-03 15:33:20.948961	\N	\N
1054	14676	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chilli Pepper	1	1	2025-06-03 15:33:20.948961	\N	\N
1055	14675	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chipotle	1	1	2025-06-03 15:33:20.948961	\N	\N
1056	14673	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Spiced Curry	1	1	2025-06-03 15:33:20.948961	\N	\N
1057	14677	B14	3-3	0	P8Az	5	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Adobo Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1058	14640	B07	54-54	0	P8Az	205	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Salsa Verde	1	1	2025-06-03 15:33:20.948961	\N	\N
1059	14643	B07	52-52	0	P8Az	205	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chipotle	1	1	2025-06-03 15:33:20.948961	\N	\N
1060	14599	B07	35-35	0	P8Az	207	Stefano A Barahona	Plectranthus X hybrida Burgundy Wedding Train	1	1	2025-06-03 15:33:20.948961	\N	\N
1061	14642	B07	53-53	0	P8Az	215	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Habanero	1	1	2025-06-03 15:33:20.948961	\N	\N
1062	14641	B07	53-53	0	P8Az	215	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Spiced Curry	1	1	2025-06-03 15:33:20.948961	\N	\N
1063	14600	B07	55-55	0	P8Az	362	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chilli Pepper	1	1	2025-06-03 15:33:20.948961	\N	\N
1064	14509	B07	54-54	0	P8Az	145	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Adobo Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1065	14361	B07	56-59	0	P8Az	1412	Stefano A Barahona	Crossandra Infundibuliformis Orange Marmalade	1	1	2025-06-03 15:33:20.948961	\N	\N
1066	11168	B29	47-49	0	P8Az	1935	Juan D Hernandez	Euphorbia Trigona Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1067	15211	B14	1-1	0	P8Az	10	Stefano A Barahona	Gaura Lindheimeri Belleza Dark Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1068	15027	B13	62-67	0	P8Az	1664	Stefano A Barahona	Gaura Lindheimeri Belleza Dark Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1069	14331	E11	56-57	0	P8Az	254	Karen Orozco	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1070	13825	E12	3-30	0	P8Az	3000	Karen Orozco	Epipremnum Asplissium Narrow Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1071	14720	B13	57-57	0	P8Az	40	Stefano A Barahona	Phlox Paniculata Famous Pink Dark Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
1072	14721	B13	57-57	0	P8Az	96	Stefano A Barahona	Phlox Paniculata Famous White Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
1073	14703	B14	3-3	0	P8Az	30	Stefano A Barahona	Phlox Paniculata Famous Pink Dark Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
1074	14701	B14	3-3	0	P8Az	36	Stefano A Barahona	Phlox Paniculata Famous White Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
1075	14702	B14	3-3	0	P8Az	40	Stefano A Barahona	Phlox Paniculata Famous Purple Improved	1	1	2025-06-03 15:33:20.948961	\N	\N
1076	15083	B11	46-46	0	P8Az	205	Stefano A Barahona	Ruellia Brittoniana Mayan Purple Showers	1	1	2025-06-03 15:33:20.948961	\N	\N
1077	14704	B14	1-1	0	P8Az	9	Stefano A Barahona	Ruellia Brittoniana Mayan Purple Showers	1	1	2025-06-03 15:33:20.948961	\N	\N
1078	14707	B14	1-1	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1079	14116	B11	45-45	0	P8Az	240	Stefano A Barahona	Ruellia Brittoniana Mayan Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1080	14705	B14	1-1	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan White	1	1	2025-06-03 15:33:20.948961	\N	\N
1081	14115	B11	45-45	0	P8Az	193	Stefano A Barahona	Ruellia Brittoniana Mayan White	1	1	2025-06-03 15:33:20.948961	\N	\N
1082	15581	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Adobo Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1083	14856	E02	88-90	0	P8Az	416	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1084	14646	E05	68-71	0	P8Az	503	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1085	14507	E02	80-80	0	P8Az	48	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1086	14360	D04	16-27	0	P8Az	1719	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1087	14335	D04	28-39	0	P8Az	1730	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1088	14332	D04	3-16	0	P8Az	2010	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1089	14333	E02	80-87	0	P8Az	1002	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1090	14107	E02	80-80	0	P8Az	50	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1091	14099	D04	39-41	0	P8Az	314	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1092	13925	D04	41-48	0	P8Az	1005	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1093	13718	E02	79-79	0	P8Az	5	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1094	13405	D04	49-60	0	P8Az	1572	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1095	13388	E02	79-79	0	P8Az	18	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1096	13590	D04	61-66	0	P8Az	834	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1097	13139	D04	66-69	0	P8Az	358	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1098	13050	E02	79-79	0	P8Az	12	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1099	12931	D04	69-72	0	P8Az	448	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1100	12826	D04	72-75	0	P8Az	447	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1101	12695	D04	76-78	0	P8Az	404	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1102	12303	D04	78-81	0	P8Az	430	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1103	12324	E02	79-79	0	P8Az	96	Karen Orozco	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1104	11761	D04	82-82	0	P8Az	127	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1105	11165	D04	90-90	0	P8Az	93	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1106	10879	D04	89-90	0	P8Az	195	Karen Orozco	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1107	14719	B11	46-46	0	P8Az	205	Stefano A Barahona	Ruellia Brittoniana Mayan Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
1108	14706	B14	1-1	0	P8Az	10	Stefano A Barahona	Ruellia Brittoniana Mayan Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
1109	14597	B14	3-3	0	P8Az	10	Stefano A Barahona	Scaevola Hybrid Surdiva Fashion Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1110	14598	B14	3-3	0	P8Az	10	Stefano A Barahona	Scaevola Hybrid Surdiva Blue Violet	1	1	2025-06-03 15:33:20.948961	\N	\N
1111	14618	B14	3-3	0	P8Az	10	Stefano A Barahona	Scaevola Hybrid Surdiva Sky Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1112	14617	B14	3-3	0	P8Az	10	Stefano A Barahona	Scaevola Hybrid Surdiva White	1	1	2025-06-03 15:33:20.948961	\N	\N
1113	15580	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Salsa Verde	1	1	2025-06-03 15:33:20.948961	\N	\N
1114	14104	B09	15-15	0	P8Az	169	Stefano A Barahona	Ajuga Reptans Burgundy Glow	1	1	2025-06-03 15:33:20.948961	\N	\N
1115	15174	E04	8-10	0	P8Az	200	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1116	15090	E04	8-8	0	P8Az	30	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1117	14742	E04	5-8	0	P8Az	481	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1118	14334	E04	3-5	0	P8Az	200	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1119	14106	E04	2-3	0	P8Az	200	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1120	13402	E02	76-79	0	P8Az	400	Karen Orozco	Epipremnum Aureum Lemon Meringue	1	1	2025-06-03 15:33:20.948961	\N	\N
1121	13391	E04	1-2	0	P8Az	39	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1122	13078	E02	61-76	0	P8Az	2244	Karen Orozco	Epipremnum Aureum Lemon Meringue	1	1	2025-06-03 15:33:20.948961	\N	\N
1123	12323	E04	1-1	0	P8Az	93	Karen Orozco	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1124	12428	E02	57-61	0	P8Az	670	Karen Orozco	Epipremnum Aureum Lemon Meringue	1	1	2025-06-03 15:33:20.948961	\N	\N
1125	14962	B07	40-44	0	P8Az	65	Stefano A Barahona	Lantana Camara Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1126	14596	B14	2-2	0	P8Az	10	Stefano A Barahona	Sanchezia SP Nobilis	1	1	2025-06-03 15:33:20.948961	\N	\N
1127	13912	B11	28-30	0	P8Az	1399	Stefano A Barahona	Sanchezia SP Nobilis	1	1	2025-06-03 15:33:20.948961	\N	\N
1128	12948	B09	18-18	0	P8Az	299	Stefano A Barahona	Delosperma Cooperi Ice Plant	1	1	2025-06-03 15:33:20.948961	\N	\N
1129	15110	B15	34-34	0	P8Az	67	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1130	15111	B15	50-50	0	P8Az	83	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1131	15088	B15	33-33	0	P8Az	147	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1132	15091	B15	56-56	0	P8Az	89	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1133	14911	B15	52-53	0	P8Az	166	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1134	14555	B15	54-54	0	P8Az	68	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1135	14208	B15	55-55	0	P8Az	34	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1136	14209	B15	32-33	0	P8Az	72	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1137	13715	B15	56-56	0	P8Az	19	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1138	13387	B15	56-56	0	P8Az	12	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1139	13386	B15	31-31	0	P8Az	18	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1140	13477	B15	32-32	0	P8Az	22	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1141	13478	B15	55-55	0	P8Az	42	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1142	13266	E04	55-62	0	P8Az	1025	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1143	13054	B15	55-55	0	P8Az	8	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1144	12325	B15	31-31	0	P8Az	93	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1145	12326	B15	53-54	0	P8Az	96	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1146	11221	E04	21-27	0	P8Az	953	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1147	11139	E04	34-42	0	P8Az	1162	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1148	11521	E04	54-54	0	P8Az	96	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1149	11138	E04	28-34	0	P8Az	917	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1150	11140	E04	43-53	0	P8Az	1458	Karen Orozco	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1151	15108	E02	6-8	0	P8Az	362	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1152	14919	E02	4-5	0	P8Az	193	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1153	14508	E02	3-4	0	P8Az	93	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1154	14034	E02	2-3	0	P8Az	210	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1155	13716	E02	2-2	0	P8Az	10	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1156	13390	E02	1-2	0	P8Az	40	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1157	13053	E02	1-1	0	P8Az	17	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1158	12918	E02	1-1	0	P8Az	96	Karen Orozco	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1159	14639	B14	2-2	0	P8Az	5	Stefano A Barahona	Cuphea Hyssopifolia Allyson Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1160	14980	B07	17-19	0	P8Az	1220	Stefano A Barahona	Cuphea Hyssopifolia Allyson Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1161	13848	B07	12-16	0	P8Az	2102	Stefano A Barahona	Cuphea Hyssopifolia Allyson Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1162	14614	B14	2-2	0	P8Az	5	Stefano A Barahona	Salvia Farinacea Sallyfun Bicolor Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1163	14621	B14	2-2	0	P8Az	5	Stefano A Barahona	Verbena Bonariensis Lollipop	1	1	2025-06-03 15:33:20.948961	\N	\N
1164	14616	B14	2-2	0	P8Az	5	Stefano A Barahona	Salvia Farinacea Sallyfun Deep Ocean	1	1	2025-06-03 15:33:20.948961	\N	\N
1165	12945	B09	18-18	0	P8Az	235	Stefano A Barahona	Muehlenbeckia Axillaris Nana	1	1	2025-06-03 15:33:20.948961	\N	\N
1166	14613	B14	2-2	0	P8Az	10	Stefano A Barahona	Evolvulus Nuttallianus Blue Daze	1	1	2025-06-03 15:33:20.948961	\N	\N
1167	13795	B11	20-24	0	P8Az	2318	Stefano A Barahona	Evolvulus Nuttallianus Blue Daze	1	1	2025-06-03 15:33:20.948961	\N	\N
1168	12666	B09	15-15	0	P8Az	104	Stefano A Barahona	Ajuga Reptans Chocolate Chip	1	1	2025-06-03 15:33:20.948961	\N	\N
1169	15583	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Habanero	1	1	2025-06-03 15:33:20.948961	\N	\N
1170	15579	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus X hybrida Burgundy Wedding Train	1	1	2025-06-03 15:33:20.948961	\N	\N
1171	15585	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chilli Pepper	1	1	2025-06-03 15:33:20.948961	\N	\N
1172	15584	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Chipotle	1	1	2025-06-03 15:33:20.948961	\N	\N
1173	15582	B14	4-4	0	P8Az	20	Stefano A Barahona	Plectranthus Scutellarioides Flame Thrower Spiced Curry	1	1	2025-06-03 15:33:20.948961	\N	\N
1174	11575	B09	6-9	0	P8Az	1232	Stefano A Barahona	Pachysandra SP Terminalis	1	1	2025-06-03 15:33:20.948961	\N	\N
1175	10533	B09	6-6	0	P8Az	246	Stefano A Barahona	Pachysandra SP Terminalis	1	1	2025-06-03 15:33:20.948961	\N	\N
1176	10222	B09	4-5	0	P8Az	1127	Stefano A Barahona	Pachysandra SP Terminalis	1	1	2025-06-03 15:33:20.948961	\N	\N
1177	14615	B14	2-2	0	P8Az	5	Stefano A Barahona	Salvia Farinacea Sallyfun Snowhite	1	1	2025-06-03 15:33:20.948961	\N	\N
1178	12238	B10	64-66	0	P8Az	1491	Stefano A Barahona	Trachelospermum Asiaticum Asian Jasmine	1	1	2025-06-03 15:33:20.948961	\N	\N
1179	14985	E01	30-43	0	P9	1693	Karen Orozco	Epipremnum Aureum Global Green	1	1	2025-06-03 15:33:20.948961	\N	\N
1180	13140	E01	43-50	0	P9	1490	Karen Orozco	Epipremnum Aureum Global Green	1	1	2025-06-03 15:33:20.948961	\N	\N
1181	11160	E09	82-84	0	P9	1006	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	1	2025-06-03 15:33:20.948961	\N	\N
1182	13652	E10	1-4	0	P9	1332	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1183	11005	E09	95-95	0	P9	348	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	1	2025-06-03 15:33:20.948961	\N	\N
1184	10084	E09	84-86	0	P9	714	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	1	2025-06-03 15:33:20.948961	\N	\N
1185	10083	E09	87-90	0	P9	1340	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	1	2025-06-03 15:33:20.948961	\N	\N
1186	10082	E09	91-93	0	P9	1355	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	1	2025-06-03 15:33:20.948961	\N	\N
1187	9509	E10	82-95	0	P9	5040	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf Raven	1	1	2025-06-03 15:33:20.948961	\N	\N
1188	13921	E09	28-54	0	P9	10092	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1189	10822	E10	13-50	0	P9	13524	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1190	7626	C08	41-46	0	P9	2809	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1191	10619	C08	39-40	0	P9	889	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1192	15477	E01	20-29	0	P9	1200	Karen Orozco	Epipremnum Aureum Global Green	1	1	2025-06-03 15:33:20.948961	\N	\N
1193	10645	C08	68-85	0	P9	5694	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1194	8752	C08	17-22	0	P9	2226	Jairo Gonzalez	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
1195	15449	D20	23-25	0	P9	303	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1196	12982	B08	1-48	0	P9	7072	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1197	12983	D15	1-90	0	P9	7500	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1198	12981	D16	1-75	0	P9	7500	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1199	12858	D17	1-75	0	P9	8250	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1200	12023	D12	1-75	0	P9	7500	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1201	12261	D13	1-70	0	P9	7500	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1202	12345	D14	1-90	0	P9	7500	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1203	11493	B08	53-64	0	P9	1595	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1204	9440	D18	1-68	0	P9	6881	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1205	11050	D19	1-75	0	P9	7507	Karen Orozco	Epipremnum Aureum Golden	1	1	2025-06-03 15:33:20.948961	\N	\N
1206	10617	C08	32-39	0	P9	3583	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1207	7629	C08	29-31	0	P9	1445	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1208	13589	E06	2-9	0	P9	897	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1209	13134	E06	1-2	0	P9	193	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1210	11070	D21	11-15	0	P9	569	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1211	11071	D21	26-31	0	P9	826	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1212	11069	D21	20-25	0	P9	850	Karen Orozco	Philodendron SP Cordatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1213	10593	C24	61-76	0	P9	5796	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1214	9982	C23	86-93	0	P9	3368	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1215	9959	C24	76-93	0	P9	6835	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1216	8275	C23	80-86	0	P9	2670	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1217	11182	C24	33-34	0	P9	527	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1218	10399	C24	21-33	0	P9	4875	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1219	9916	C24	8-21	0	P9	5000	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1220	8365	C24	1-8	0	P9	2978	Jairo Gonzalez	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1221	10856	C23	79-80	0	P9	366	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1222	10594	C23	71-79	0	P9	3779	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1223	10402	C23	64-71	0	P9	3095	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1224	8915	C23	60-64	0	P9	2178	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1225	8172	C23	58-60	0	P9	995	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1226	11055	D21	48-55	0	P9	1078	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
1227	11083	D21	63-65	0	P9	269	Karen Orozco	Philodendron Hederaceum Brazil	1	1	2025-06-03 15:33:20.948961	\N	\N
1228	14205	D02	24-25	0	P9	350	Karen Orozco	Epipremnum Aureum Manjula	1	1	2025-06-03 15:33:20.948961	\N	\N
1229	13851	D02	25-27	0	P9	300	Karen Orozco	Epipremnum Aureum Manjula	1	1	2025-06-03 15:33:20.948961	\N	\N
1230	11494	D02	27-31	0	P9	638	Karen Orozco	Epipremnum Aureum Manjula	1	1	2025-06-03 15:33:20.948961	\N	\N
1231	14206	D20	14-22	0	P9	876	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1232	13522	D20	9-14	0	P9	612	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1233	13274	D20	4-9	0	P9	568	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1234	13085	D20	1-3	0	P9	426	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1235	11497	B08	64-68	0	P9	701	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1236	12202	D21	11-11	0	P9	99	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1237	8929	D21	1-11	0	P9	1453	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1238	12201	D21	31-36	0	P9	636	Karen Orozco	Epipremnum Aureum Neon	1	1	2025-06-03 15:33:20.948961	\N	\N
1239	6698	E10	51-74	0	P9.25	8984	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf Raven	1	1	2025-06-03 15:33:20.948961	\N	\N
1240	11162	E10	6-13	0	P9.25	2836	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1241	5453	E10	79-82	0	P9.25	1316	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf Raven	1	1	2025-06-03 15:33:20.948961	\N	\N
1242	5442	E10	74-79	0	P9.25	1852	Jairo Gonzalez	Zamioculca Zamiifolia Black Leaf Raven	1	1	2025-06-03 15:33:20.948961	\N	\N
1243	11161	E10	4-6	0	P9.25	836	Jairo Gonzalez	Zamioculca Zamiifolia Green Leaf	1	1	2025-06-03 15:33:20.948961	\N	\N
1244	3832	A01	10-12	0	P9.25	551	Juan D Hernandez	Adenium Obesum Desert Rose	1	1	2025-06-03 15:33:20.948961	\N	\N
1245	10957	C22	9-14	0	P9.25	3076	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1246	11156	C22	15-20	0	P9.25	3076	Jairo Gonzalez	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1247	10955	C22	1-4	0	P9.25	2001	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1248	10956	C22	5-8	0	P9.25	2047	Jairo Gonzalez	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1249	15739	B03	9-9	0	T105	6006	Ana I Morales	Senecio Peregrinus String of Dolphin CC	1	1	2025-06-03 15:33:20.948961	\N	\N
1250	15665	B03	9-9	0	T105	1417	Ana I Morales	Senecio Peregrinus String of Dolphin CC	1	1	2025-06-03 15:33:20.948961	\N	\N
1251	15758	C01	21-22	0	T105	4536	Ana I Morales	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1252	15681	C01	32-32	0	T105	3675	Ana I Morales	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1253	15635	C01	13-13	0	T105	2100	Ana I Morales	Cleretum Bellidiforme Mezoo Trailing Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1254	15502	C01	29-30	0	T105	11340	Ana I Morales	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
1255	15501	C01	31-32	0	T105	11445	Ana I Morales	Ehretia Microphylla Fukien Tea (Small)	1	1	2025-06-03 15:33:20.948961	\N	\N
1256	15795	C01	28-29	0	T105	19215	Ana I Morales	Ehretia Microphylla Fukien Tea (Mini)	1	1	2025-06-03 15:33:20.948961	\N	\N
1257	15691	C01	33-33	0	T105	827	Ana I Morales	Rosmarinus Officinalis Rosemary barbecue	1	1	2025-06-03 15:33:20.948961	\N	\N
1258	15756	C01	22-22	0	T105	1050	Ana I Morales	Ajuga Reptans Chocolate Chip	1	1	2025-06-03 15:33:20.948961	\N	\N
1259	15803	C01	26-26	0	T105	474	Ana I Morales	Sagina Subulata Subulata Aurea	1	1	2025-06-03 15:33:20.948961	\N	\N
1260	15794	C01	20-21	0	T105	3150	Ana I Morales	Sagina Subulata Subulata Aurea	1	1	2025-06-03 15:33:20.948961	\N	\N
1261	15613	C01	20-20	0	T105	898	Ana I Morales	Sagina Subulata Subulata Aurea	1	1	2025-06-03 15:33:20.948961	\N	\N
1262	15763	C01	21-21	0	T105	945	Ana I Morales	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
1263	15688	C01	23-23	0	T105	1050	Ana I Morales	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
1264	15642	C01	24-24	0	T105	991	Ana I Morales	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
1265	15612	C01	17-17	0	T105	1050	Ana I Morales	Phlox Divaricata Blue Moon	1	1	2025-06-03 15:33:20.948961	\N	\N
1266	15804	C01	26-26	0	T105	1392	Ana I Morales	Sagina Subulata Subulata	1	1	2025-06-03 15:33:20.948961	\N	\N
1267	15793	C01	21-21	0	T105	2310	Ana I Morales	Sagina Subulata Subulata	1	1	2025-06-03 15:33:20.948961	\N	\N
1268	15614	C01	20-20	0	T105	1704	Ana I Morales	Sagina Subulata Subulata	1	1	2025-06-03 15:33:20.948961	\N	\N
1269	15762	C01	21-21	0	T105	966	Ana I Morales	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
1270	15687	C01	23-23	0	T105	1050	Ana I Morales	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
1271	15641	C01	24-24	0	T105	901	Ana I Morales	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
1272	15611	C01	17-17	0	T105	523	Ana I Morales	Phlox Divaricata Chattahoochee	1	1	2025-06-03 15:33:20.948961	\N	\N
1273	15764	C01	22-22	0	T105	3675	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
1274	15689	C01	31-31	0	T105	1995	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
1275	15643	C01	24-24	0	T105	2597	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
1276	15603	C02	13-13	0	T105	3287	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
1277	15602	C02	13-13	0	T105	5000	Ana I Morales	Sedum Spurium Fuldaglut	1	1	2025-06-03 15:33:20.948961	\N	\N
1278	15757	C01	22-22	0	T105	648	Ana I Morales	Artemisia Arborescens Powis Castle	1	1	2025-06-03 15:33:20.948961	\N	\N
1279	15809	C01	26-26	0	T105	1890	Ana I Morales	Artemisia Arborescens Powis Castle	1	1	2025-06-03 15:33:20.948961	\N	\N
1280	15679	C01	27-27	0	T105	420	Ana I Morales	Artemisia Arborescens Powis Castle	1	1	2025-06-03 15:33:20.948961	\N	\N
1281	15759	C01	21-21	0	T105	6090	Ana I Morales	Delosperma Cooperi Ice Plant	1	1	2025-06-03 15:33:20.948961	\N	\N
1282	15743	C01	19-19	0	T105	69	Ana I Morales	Lysimachia Nummularia Goldilocks	1	1	2025-06-03 15:33:20.948961	\N	\N
1283	15471	C01	18-18	0	T105	210	Ana I Morales	Plectranthus X hybrida Burgundy Wedding Train	1	1	2025-06-03 15:33:20.948961	\N	\N
1284	15441	C01	20-20	0	T105	3675	Ana I Morales	Sedum Kamtschaticum Weihenstephaner Gold	1	1	2025-06-03 15:33:20.948961	\N	\N
1285	15752	C01	20-20	0	T105	52	Ana I Morales	Evolvulus Nuttallianus Blue Daze	1	1	2025-06-03 15:33:20.948961	\N	\N
1286	15493	C01	13-13	0	T105	519	Ana I Morales	Phlox Paniculata Famous Purple Improved	1	1	2025-06-03 15:33:20.948961	\N	\N
1287	15492	C01	13-13	0	T105	525	Ana I Morales	Phlox Paniculata Famous White Eye	1	1	2025-06-03 15:33:20.948961	\N	\N
1288	15753	C01	20-20	0	T105	1537	Ana I Morales	Lithodora Diffusa Grace Ward	1	1	2025-06-03 15:33:20.948961	\N	\N
1289	15749	C01	20-20	0	T105	69	Ana I Morales	Vinca Roseus Soiree Kawaii Light Purple	1	1	2025-06-03 15:33:20.948961	\N	\N
1290	15748	C01	20-20	0	T105	73	Ana I Morales	Vinca Roseus Soiree Kawaii Red Shades	1	1	2025-06-03 15:33:20.948961	\N	\N
1291	15746	C01	20-20	0	T105	86	Ana I Morales	Vinca Roseus Soiree Kawaii White Peppermint	1	1	2025-06-03 15:33:20.948961	\N	\N
1292	15744	C01	20-20	0	T105	102	Ana I Morales	Vinca Roseus Soiree Kawaii Lavender	1	1	2025-06-03 15:33:20.948961	\N	\N
1293	15747	C01	20-20	0	T105	94	Ana I Morales	Vinca Roseus Soiree Kawaii Blueberry Kiss	1	1	2025-06-03 15:33:20.948961	\N	\N
1294	15745	C01	20-20	0	T105	100	Ana I Morales	Vinca Roseus Soiree Kawaii Coral Reef	1	1	2025-06-03 15:33:20.948961	\N	\N
1295	15750	C01	20-20	0	T105	97	Ana I Morales	Vinca Roseus Soiree Kawaii Coral	1	1	2025-06-03 15:33:20.948961	\N	\N
1296	15690	C01	33-33	0	T105	1001	Ana I Morales	Rosmarinus Officinalis Tuscan Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1297	15773	C01	23-23	0	T105	2153	Ana I Morales	Thymus Serpyllum Pink Chintz	1	1	2025-06-03 15:33:20.948961	\N	\N
1298	15772	C01	23-23	0	T105	2153	Ana I Morales	Thymus Praecox Coccineus	1	1	2025-06-03 15:33:20.948961	\N	\N
1299	15771	C01	23-23	0	T105	2153	Ana I Morales	Thymus Vulgaris Silver Edge	1	1	2025-06-03 15:33:20.948961	\N	\N
1300	15774	C01	24-24	0	T105	2153	Ana I Morales	Thymus Lanuginosus Wolly	1	1	2025-06-03 15:33:20.948961	\N	\N
1301	15466	C01	17-17	0	T105	149	Ana I Morales	Lantana Camara Bandana White	1	1	2025-06-03 15:33:20.948961	\N	\N
1302	15768	C01	22-22	0	T105	236	Ana I Morales	Scaevola Hybrid Surdiva Blue Violet	1	1	2025-06-03 15:33:20.948961	\N	\N
1303	15766	C01	22-22	0	T105	236	Ana I Morales	Scaevola Hybrid Surdiva Sky Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1304	15767	C01	22-22	0	T105	236	Ana I Morales	Scaevola Hybrid Surdiva Fashion Pink	1	1	2025-06-03 15:33:20.948961	\N	\N
1305	15765	C01	22-22	0	T105	236	Ana I Morales	Scaevola Hybrid Surdiva White	1	1	2025-06-03 15:33:20.948961	\N	\N
1306	15852	C01	24-25	0	T105	3150	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1307	15755	C01	22-22	0	T105	1544	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1308	15792	C01	23-23	0	T105	917	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1309	15632	C01	24-24	0	T105	1121	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1310	15615	C01	19-19	0	T105	1038	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1311	15507	C01	17-17	0	T105	1959	Ana I Morales	Veronica Longifolia Sunny Border Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1312	15625	B01	49-51	0	T18	4594	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1313	15460	B01	37-39	0	T18	5886	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1314	15412	B01	23-25	0	T18	4590	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1315	15212	B02	23-23	0	T18	1874	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1316	15236	B02	31-32	0	T18	2548	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1317	15040	B02	42-44	0	T18	1706	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1318	15220	B04	29-29	0	T40	43	Ana I Morales	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1319	15075	B04	27-27	0	T40	919	Ana I Morales	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1320	15114	C03	74-76	0	T40	10280	Karen Orozco	Ficus Microcarpa Ginseng (50)	1	1	2025-06-03 15:33:20.948961	\N	\N
1321	15676	B03	10-10	0	T40	1476	Ana I Morales	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1322	15282	B03	10-10	0	T40	1492	Ana I Morales	Epipremnum Aureum Champs Elysees	1	1	2025-06-03 15:33:20.948961	\N	\N
1323	15598	B04	29-29	0	T40	963	Ana I Morales	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1324	15452	B04	29-29	0	T40	842	Ana I Morales	Monstera Lechleriana Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1325	15760	B04	32-32	0	T40	1313	Ana I Morales	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1326	15832	B03	13-13	0	T40	2880	Ana I Morales	Epipremnum Aureum Shangri-La	1	1	2025-06-03 15:33:20.948961	\N	\N
1327	15761	B04	32-32	0	T40	2625	Ana I Morales	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1328	15833	B03	12-12	0	T40	2890	Ana I Morales	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1329	15630	B04	23-23	0	T40	1750	Ana I Morales	Epipremnum Aureum Lemon Top	1	1	2025-06-03 15:33:20.948961	\N	\N
1330	15597	B04	28-28	0	T40	1022	Ana I Morales	Epipremnum Aureum Neon Joy	1	1	2025-06-03 15:33:20.948961	\N	\N
1331	15655	C01	36-36	0	T40	3459	Ana I Morales	Epipremnum Aureum Global Green	1	1	2025-06-03 15:33:20.948961	\N	\N
1332	15500	B04	27-27	0	T40	3937	Ana I Morales	Epipremnum Pinnatum Baltic Blue	1	1	2025-06-03 15:33:20.948961	\N	\N
1333	15451	B04	1-1	0	T40	4160	Ana I Morales	Epipremnum Pinnatum Albo Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1334	15751	C01	16-16	0	T40	440	Ana I Morales	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
1335	15673	C01	12-12	0	T40	880	Ana I Morales	Monstera Stendleyana Cobra	1	1	2025-06-03 15:33:20.948961	\N	\N
1336	15616	B04	23-23	0	T40	1153	Ana I Morales	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1337	15617	B04	28-28	0	T40	1181	Ana I Morales	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1338	15294	C05	54-54	0	T40	400	Karen Orozco	Scindapsus Pictus Mount Salak	1	1	2025-06-03 15:33:20.948961	\N	\N
1339	15295	C05	54-54	0	T40	640	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1340	15845	C02	13-13	0	T40	1575	Ana I Morales	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
1341	15695	C02	15-15	0	T40	701	Ana I Morales	Aloe Hybrid Aristata	1	1	2025-06-03 15:33:20.948961	\N	\N
1342	15730	B04	27-27	0	T40	1500	Ana I Morales	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1343	15415	B04	31-31	0	T40	3210	Ana I Morales	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1344	15694	C02	15-15	0	T40	1680	Ana I Morales	Aloe Hybrid White Lightning	1	1	2025-06-03 15:33:20.948961	\N	\N
1345	15218	B04	30-30	0	T40	2385	Ana I Morales	Scindapsus Pictus Sterling Silver	1	1	2025-06-03 15:33:20.948961	\N	\N
1346	15139	D04	27-27	0	T40	1181	Karen Orozco	Scindapsus Pictus Platinum Java	1	1	2025-06-03 15:33:20.948961	\N	\N
1347	15839	B04	13-22	0	T40	42586	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1348	15801	B05	28-39	0	T40	55680	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1349	15697	B02	4-4	0	T40	293	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1350	15535	B04	32-40	0	T40	35990	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1351	15623	B05	40-50	0	T40	47423	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1352	15410	B03	27-43	0	T40	57948	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1353	15298	B03	16-26	0	T40	20030	Ana I Morales	Aglaonema Commutatum Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1354	15701	B02	7-8	0	T40	2537	Ana I Morales	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
1355	15624	B01	48-49	0	T40	4325	Ana I Morales	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
1356	15434	B01	25-27	0	T40	3745	Ana I Morales	Aglaonema Commutatum Golden Flourite	1	1	2025-06-03 15:33:20.948961	\N	\N
1357	15831	B04	46-46	0	T40	410	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1358	15733	B04	46-46	0	T40	1844	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1359	15662	B04	24-24	0	T40	2511	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1360	15532	B04	44-45	0	T40	4400	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1361	15433	B04	51-52	0	T40	3440	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1362	15700	B02	6-7	0	T40	3753	Ana I Morales	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
1363	15485	B01	44-45	0	T40	5242	Ana I Morales	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
1364	15663	B02	45-50	0	T40	9030	Ana I Morales	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
1365	15448	B01	30-37	0	T40	18297	Ana I Morales	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
1366	15185	B03	6-7	0	T40	2580	Ana I Morales	Aglaonema Commutatum Leprechaum	1	1	2025-06-03 15:33:20.948961	\N	\N
1367	15629	B01	5-7	0	T40	7137	Ana I Morales	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
1368	15628	B01	3-5	0	T40	7268	Ana I Morales	Philodendron SP Painted Laidy	1	1	2025-06-03 15:33:20.948961	\N	\N
1369	14914	C05	35-37	0	T40	4700	Ana I Morales	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1370	15740	B04	29-29	0	T40	213	Ana I Morales	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1371	15499	B04	29-29	0	T40	375	Ana I Morales	Epipremnum Asplissium Variegata	1	1	2025-06-03 15:33:20.948961	\N	\N
1372	15699	B02	5-6	0	T40	1762	Ana I Morales	Aglaonema Commutatum Edgy White	1	1	2025-06-03 15:33:20.948961	\N	\N
1373	15204	C05	45-45	0	T40	796	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1374	15732	B04	46-47	0	T40	4400	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1375	15661	B04	25-26	0	T40	8320	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1376	15531	B04	44-44	0	T40	3665	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1377	15530	B04	49-50	0	T40	8752	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1378	15417	B04	52-52	0	T40	3920	Ana I Morales	Aglaonema Commutatum Silver Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1379	15187	B03	11-12	0	T40	302	Ana I Morales	Aglaonema Commutatum Phuket	1	1	2025-06-03 15:33:20.948961	\N	\N
1380	15450	B01	2-2	0	T40	773	Ana I Morales	Dieffenbachia Maculata Alix	1	1	2025-06-03 15:33:20.948961	\N	\N
1381	15698	B02	4-5	0	T40	2410	Ana I Morales	Aglaonema Commutatum Mini Silver Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1382	15533	B01	46-47	0	T40	3721	Ana I Morales	Aglaonema Commutatum Mini Silver Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1383	15411	B01	23-23	0	T40	1025	Ana I Morales	Aglaonema Commutatum Mini Silver Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1384	15213	C05	47-47	0	T40	1676	Ana I Morales	Aglaonema Commutatum Golden Bay	1	1	2025-06-03 15:33:20.948961	\N	\N
1385	15627	B01	1-1	0	T40	2651	Ana I Morales	Dieffenbachia Maculata Snow	1	1	2025-06-03 15:33:20.948961	\N	\N
1386	15696	B02	1-4	0	T40	8588	Ana I Morales	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1387	15484	B01	39-43	0	T40	12814	Ana I Morales	Aglaonema Commutatum Pink Siam	1	1	2025-06-03 15:33:20.948961	\N	\N
1388	15658	B02	50-51	0	T40	2094	Ana I Morales	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
1389	15447	B01	29-30	0	T40	2583	Ana I Morales	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
1390	15237	B03	14-14	0	T40	132	Ana I Morales	Aglaonema Commutatum Mini Silver Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1391	15039	B02	40-42	0	T40	5016	Ana I Morales	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
1392	15203	B03	13-14	0	T40	739	Ana I Morales	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
1393	14973	B02	36-38	0	T40	400	Ana I Morales	Aglaonema Commutatum White Tip	1	1	2025-06-03 15:33:20.948961	\N	\N
1394	15660	B01	51-51	0	T40	2008	Ana I Morales	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
1395	15659	B02	51-53	0	T40	5809	Ana I Morales	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
1396	15435	B01	27-29	0	T40	6648	Ana I Morales	Aglaonema Commutatum Spathonema	1	1	2025-06-03 15:33:20.948961	\N	\N
1397	15678	C01	26-27	0	T50	2000	Ana I Morales	Ajuga Reptans Chocolate Chip	1	1	2025-06-03 15:33:20.948961	\N	\N
1398	15633	C01	25-26	0	T50	3960	Ana I Morales	Ajuga Reptans Chocolate Chip	1	1	2025-06-03 15:33:20.948961	\N	\N
1399	15634	C01	18-19	0	T50	6825	Ana I Morales	Ajuga Reptans Burgundy Glow	1	1	2025-06-03 15:33:20.948961	\N	\N
1400	15382	C01	25-25	0	T50	1995	Ana I Morales	Hibiscus SP Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
1401	15680	C05	54-54	0	T50	1879	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1402	15644	C05	54-54	0	T50	2625	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1403	15604	C05	55-56	0	T50	1934	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1404	15496	C05	55-55	0	T50	2450	Stefano A Barahona	Chlorophytum Comosum Variegatum	1	1	2025-06-03 15:33:20.948961	\N	\N
1405	15754	C02	12-12	0	T60	2040	Ana I Morales	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
1406	15618	C02	23-23	0	T60	2040	Ana I Morales	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
1407	15306	C02	23-23	0	T60	3000	Ana I Morales	Adenium Obesum Desert Rose (Seed)	1	1	2025-06-03 15:33:20.948961	\N	\N
1408	15846	C02	8-8	0	T60	2426	Ana I Morales	Echeveria SP Blue Bird	1	1	2025-06-03 15:33:20.948961	\N	\N
1409	15844	C02	8-8	0	T60	3308	Ana I Morales	Graptosedum SP Darley Sunshine	1	1	2025-06-03 15:33:20.948961	\N	\N
1410	15491	C01	2-2	0	T60	508	Ana I Morales	Euphorbia Pulcherrima A1 Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1411	15388	C01	25-25	0	T60	200	Ana I Morales	Euphorbia Pulcherrima Assortment	1	1	2025-06-03 15:33:20.948961	\N	\N
1412	15843	C02	8-8	0	T60	2205	Ana I Morales	Kalanchoe SP Thyrsiflora	1	1	2025-06-03 15:33:20.948961	\N	\N
1413	15639	C01	4-4	0	T60	1050	Ana I Morales	Euphorbia Pulcherrima Legacy Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1414	15638	C01	4-4	0	T60	154	Ana I Morales	Euphorbia Pulcherrima Pepita Early Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1415	15607	C01	4-4	0	T60	96	Ana I Morales	Euphorbia Pulcherrima Ranch Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1416	15608	C01	4-4	0	T60	172	Ana I Morales	Euphorbia Pulcherrima Pepita Early Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1417	15606	C01	4-4	0	T60	58	Ana I Morales	Euphorbia Pulcherrima Q-ismas Qs-127	1	1	2025-06-03 15:33:20.948961	\N	\N
1418	15672	C01	25-25	0	T60	2100	Ana I Morales	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
1419	15503	C01	9-10	0	T60	1994	Ana I Morales	Dieffenbachia SP Compacta	1	1	2025-06-03 15:33:20.948961	\N	\N
1420	15504	C01	9-9	0	T60	1343	Ana I Morales	Dieffenbachia SP Sublime	1	1	2025-06-03 15:33:20.948961	\N	\N
1421	15671	C01	23-23	0	T60	525	Ana I Morales	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
1422	15505	C01	10-10	0	T60	870	Ana I Morales	Dieffenbachia SP Camille	1	1	2025-06-03 15:33:20.948961	\N	\N
1423	15824	C01	47-47	0	T72	259	Ana I Morales	Mandevilla Splendens Terra viva  Rose Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1424	15827	C01	47-47	0	T72	252	Ana I Morales	Mandevilla Splendens Terra viva  TVMD-1719	1	1	2025-06-03 15:33:20.948961	\N	\N
1425	15669	C01	48-48	0	T72	210	Ana I Morales	Mandevilla Splendens Terra viva  Rose Queen	1	1	2025-06-03 15:33:20.948961	\N	\N
1426	15825	C01	47-47	0	T72	925	Ana I Morales	Mandevilla Splendens Bella Compacta Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1427	15828	C01	47-47	0	T72	924	Ana I Morales	Mandevilla Splendens Q-deville Doris	1	1	2025-06-03 15:33:20.948961	\N	\N
1428	15822	C01	47-47	0	T72	159	Ana I Morales	Mandevilla Splendens Q-deville QD116	1	1	2025-06-03 15:33:20.948961	\N	\N
1429	15826	C01	47-47	0	T72	324	Ana I Morales	Mandevilla Splendens Terra viva  TVMD-938	1	1	2025-06-03 15:33:20.948961	\N	\N
1430	15823	C01	47-47	0	T72	441	Ana I Morales	Mandevilla Splendens Q-deville QD114	1	1	2025-06-03 15:33:20.948961	\N	\N
1431	15670	C01	48-48	0	T72	315	Ana I Morales	Mandevilla Splendens Bella Compacta Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1432	15668	C01	48-48	0	T72	105	Ana I Morales	Mandevilla Splendens Q-deville QD116	1	1	2025-06-03 15:33:20.948961	\N	\N
1433	15667	C01	48-48	0	T72	315	Ana I Morales	Mandevilla Splendens Q-deville QD114	1	1	2025-06-03 15:33:20.948961	\N	\N
1434	15666	C01	48-48	0	T72	630	Ana I Morales	Mandevilla Splendens Terra viva  TVMD-938	1	1	2025-06-03 15:33:20.948961	\N	\N
1435	15675	C01	48-48	0	T72	104	Ana I Morales	Mandevilla Splendens Q-deville Doris	1	1	2025-06-03 15:33:20.948961	\N	\N
1436	15674	C01	47-47	0	T72	945	Ana I Morales	Mandevilla Splendens Bella Red Bolero	1	1	2025-06-03 15:33:20.948961	\N	\N
1437	15134	C01	41-41	0	T72	863	Ana I Morales	Mandevilla Splendens Bella Compacta Red	1	1	2025-06-03 15:33:20.948961	\N	\N
1438	14937	C01	48-48	2	T72	1263	Ana I Morales	Mandevilla Splendens Bella Red Bolero	1	1	2025-06-03 15:33:20.948961	1	2025-06-03 15:38:04.15995
\.


--
-- Data for Name: pm_monitoreos; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_monitoreos (pmmo_secuencia, pmlt_codigo, pmmo_casa, pmmo_canteros, pmmo_idvariedad, pmmo_contenedor, pmmo_cantidad, pmmo_grower, pmmo_variedad, pmmo_cantero, pmni_nombrecomun, pmmo_muestra1, pmmo_muestra2, pmmo_muestra3, lmsupniv1, lmsupniv2, lmsupniv3, pmmo_nivmuestraa1, pmmo_nivmuestraa2, pmmo_nivmuestraa3, pmmo_nivmuestram1, pmmo_nivmuestram2, pmmo_nivmuestram3, pmmo_estatus, pmmo_fecha, pmmo_creadopor, pmmo_fechacreacion, pmmo_modificadopor, pmmo_fechamodificacion, pmmo_comentarios, pmmo_cant_botada, pmmo_automatico, pmni_id) FROM stdin;
1	14328	E11	45-46	4506	P8	2	Karen Orozco	Monstera lechleriana  Variegata	46	\N	2	\N	\N	\N	\N	\N	1	1	1	2	\N	\N	1	2025-03-28 14:38:24.445	1	2025-03-28 14:38:24.731636	\N	\N	Planta con necro\nSe encontraron clorosis\nManchas necrotica(posible coletotrichum) \nDaño por oruga	\N	t	23
2	15207	A02	41	0	CONT_GENERAL	26		Variedad genérica	41	\N	7	10	9	\N	\N	\N	1	1	1	2	3	3	1	2025-03-28 18:54:13.982	1	2025-03-28 14:54:14.250254	1	2025-03-28 14:55:17.905445	Presencia bajas secas	0	f	14
5	15708	B14	4-4	86	0	10	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	5	4	1	\N	\N	\N	1	1	1	2	2	1	1	2025-03-29 11:31:34.782	1	2025-03-29 11:31:34.974793	\N	\N	sdfgasfdghadfg	5	t	22
6	9440	D18	1-68	181	P9	19	Karen Orozco	Epipremnum aureum Golden	2	\N	15	2	2	\N	\N	\N	2	1	1	1	2	3	1	2025-03-29 12:06:25.665	4	2025-03-29 12:06:25.865182	\N	\N	zdfgadfg	10	t	22
7	9440	D18	1-68	181	P9	35	Karen Orozco	Epipremnum aureum Golden	1	\N	5	5	25	\N	\N	\N	1	1	3	2	1	3	1	2025-03-29 13:52:42.927	4	2025-03-29 13:52:43.116371	\N	\N	dthsfdtjhsghsdghsfghsrftgh	10	t	14
8	15207	A07	2	655	CONT_GENERAL	10	Karen Orozco	Zelkova parvifolia Orme	2	\N	4	2	4	\N	\N	\N	1	1	1	3	1	1	1	2025-03-29 13:55:50.521	4	2025-03-29 13:55:50.681185	\N	\N	MNHQecfb;lasdv;lkZSDLfvbasdgb	5	f	22
9	15207	A07	3	655	CONT_GENERAL	19	Karen Orozco	Zelkova parvifolia Orme	3	\N	8	9	2	\N	\N	\N	1	1	1	2	2	1	1	2025-03-29 13:56:20.998	4	2025-03-29 13:56:21.157354	\N	\N	drtjhsdrfgsftgsbhrtfg	3	f	14
10	15207	D00	6-6	3424	P7	12	Maybelle Flores	Foliage SP Assortment	1	\N	4	5	3	\N	\N	\N	1	1	1	2	2	3	1	2025-03-29 15:44:17.662	4	2025-03-29 15:44:17.841038	\N	\N	zdghadfbadfbadfbadfb	10	t	22
11	15708	A07	Canteros genéricos	0	CONT_GENERAL	18	Responsable genérico	Variedad genérica	10	\N	10	5	3	\N	\N	\N	1	1	1	2	2	2	1	2025-03-30 19:39:46.373	1	2025-03-30 19:40:27.707877	\N	\N	Probando	50	t	15
12	15708	A07	Canteros genéricos	650	CONT_GENERAL	29	Jairo Gonzalez	Zamioculca Zamiifolia Camaleon	1	\N	12	11	6	\N	\N	\N	2	2	1	2	2	1	1	2025-03-30 19:49:12.474	1	2025-03-30 19:49:45.592724	\N	\N	funcionando con cache	\N	t	14
13	15708	A09	Canteros genéricos	647	CONT_GENERAL	6	Jairo Gonzalez	Zamioculca Zamiifolia  Black Leaf TV (P4)	6	\N	1	2	3	\N	\N	\N	1	1	1	3	2	1	1	2025-03-30 19:53:14.995	4	2025-03-30 19:53:51.336422	\N	\N	Seguimos revisando cache	5	t	22
14	15708	B14	4-4	86	0	4	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	1	\N	2	1	1	\N	\N	\N	1	1	1	1	2	3	1	2025-03-30 22:38:52.395	4	2025-03-30 22:38:52.700063	\N	\N	Retro	\N	t	14
15	9440	D18	1-68	181	P9	4	Karen Orozco	Epipremnum aureum Golden	1	\N	1	2	1	\N	\N	\N	1	1	1	3	3	1	1	2025-03-31 07:39:28.047	3	2025-03-31 07:39:28.322349	\N	\N	Revisando	10	t	14
16	15608	C01	4-4	3341	T60	8	Stefano Albertazzi Barahona	Euphorbia pulcherrima Pepita Early Red	3	\N	1	2	5	\N	\N	\N	1	1	1	2	2	1	1	2025-03-31 07:42:56.684	3	2025-03-31 07:42:56.887485	\N	\N	Revisando	5	t	22
17	9440	D18	1-68	181	P9	7	Karen Orozco	Epipremnum aureum Golden	6	\N	1	2	4	\N	\N	\N	1	1	1	2	2	2	1	2025-03-31 18:17:07.193	1	2025-03-31 18:17:07.496497	\N	\N	Se boto de mas	29	t	22
18	15710	B12	45-48	217	0	10	Stefano Albertazzi Barahona	Euphorbia pulcherrima Legacy Red	3	\N	2	3	5	\N	\N	\N	1	1	1	2	1	3	1	2025-03-31 18:20:32.059	1	2025-03-31 18:20:32.440274	\N	\N	Seguimos probando	11	t	23
19	15710	B12	45-48	217	0	6	Stefano Albertazzi Barahona	Euphorbia pulcherrima Legacy Red	4	\N	3	1	2	\N	\N	\N	1	1	1	2	1	3	1	2025-03-31 18:22:11.401	1	2025-03-31 18:22:11.705377	\N	\N	Revisando	\N	t	22
20	15710	B12	45-48	217	0	7	Stefano Albertazzi Barahona	Euphorbia pulcherrima Legacy Red	5	\N	3	3	1	\N	\N	\N	1	1	1	2	3	2	1	2025-03-31 18:23:02.513	1	2025-03-31 18:23:02.823654	\N	\N	Revisando	34	t	14
21	2108	A11	1-8	265	Ground	28	Juan D. Hernández	Cereus SP Peruvianus	12	\N	23	2	3	\N	\N	\N	3	1	1	2	1	3	1	2025-03-31 18:27:30.575	1	2025-03-31 18:27:30.794676	\N	\N	Revisando	23	t	14
22	2108	A11	1-8	265	Ground	28	Juan D. Hernández	Cereus SP Peruvianus	12	\N	23	1	4	\N	\N	\N	3	1	1	2	1	3	1	2025-03-31 18:28:37.802	1	2025-03-31 18:28:38.115945	\N	\N	Rervisar otra ves	23	t	14
23	2108	A11	1-8	265	Ground	7	Juan D. Hernández	Cereus SP Peruvianus	14	\N	3	3	1	\N	\N	\N	1	1	1	2	3	1	1	2025-03-31 18:29:44.076	1	2025-03-31 18:29:44.304651	\N	\N	Revisando	6	t	22
24	2108	A11	1-8	265	Ground	6	Juan D. Hernández	Cereus SP Peruvianus	16	\N	1	3	2	\N	\N	\N	1	1	1	1	2	1	1	2025-03-31 18:31:20.559	1	2025-03-31 18:31:20.846216	\N	\N	Seguimos revisando	23	t	22
25	10418	I	1-21	3461	Ground	30	Tony Moriña	Asparagus sprengeri Fernleaf	23	\N	23	2	5	\N	\N	\N	3	1	1	2	1	3	1	2025-03-31 18:35:26.346	1	2025-03-31 18:35:26.635144	\N	\N	Revisando	45	t	22
26	10418	I	1-21	3461	Ground	26	Tony Moriña	Asparagus sprengeri Fernleaf	13	\N	23	2	1	\N	\N	\N	3	1	1	2	3	2	1	2025-03-31 18:36:53.275	1	2025-03-31 18:36:53.51537	\N	\N	Entrando al campo	23	t	14
27	15708	E12	Canteros genéricos	457	CONT_GENERAL	6	Juan D. Hernández	Mandevilla splendens Terra viva TVMD-1719	3	\N	1	3	2	\N	\N	\N	1	1	1	2	2	2	1	2025-04-01 00:00:03.5	1	2025-04-01 00:00:49.323849	\N	\N	arfgvzdsfvasdfvSDvSDv	10	t	14
28	15708	Casa genérica	Canteros genéricos	644	CONT_GENERAL	13	Juan D. Hernández	Vriesea SP Salmon	7	\N	5	3	5	\N	\N	\N	1	1	1	3	1	2	1	2025-04-01 00:03:19.275	1	2025-04-01 00:03:54.996535	\N	\N	\N	10	t	14
29	9440	D18	1-68	181	P9	15	Karen Orozco	Epipremnum aureum Golden	1	\N	10	4	1	\N	\N	\N	1	1	1	2	2	3	1	2025-04-01 12:34:41.026	1	2025-04-01 12:34:41.236969	\N	\N	Trabajabdo	10	t	14
30	9440	D18	1-68	181	P9	8	Karen Orozco	Epipremnum aureum Golden	2	\N	1	2	5	\N	\N	\N	1	1	1	3	2	2	1	2025-04-01 12:36:08.94	1	2025-04-01 12:37:52.06705	\N	\N	Vamonos	13	t	22
31	9440	D18	1-68	181	P9	8	Karen Orozco	Epipremnum aureum Golden	3	\N	3	4	1	\N	\N	\N	1	1	1	3	3	3	1	2025-04-01 12:37:01.127	1	2025-04-01 12:37:52.278642	\N	\N	OK	2	t	22
32	9440	D18	1-68	181	P9	6	Karen Orozco	Epipremnum aureum Golden	12	\N	2	3	1	\N	\N	\N	1	1	1	1	1	3	1	2025-04-01 12:54:46.87	4	2025-04-01 12:54:47.185852	\N	\N	No hay novedad	12	t	14
33	15708	B14	4-4	86	0	21	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	4	\N	5	10	6	\N	\N	\N	1	1	1	2	3	1	1	2025-04-01 14:12:21.806	1	2025-04-01 14:12:22.047505	\N	\N	Comentario	20	t	14
34	15708	B14	4-4	86	0	9	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	5	\N	5	1	3	\N	\N	\N	1	1	1	2	2	2	1	2025-04-01 14:13:03.334	1	2025-04-01 14:13:03.512513	\N	\N	Another	5	t	22
35	15708	B14	4-4	86	0	11	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	15	\N	1	2	8	\N	\N	\N	1	1	1	2	3	2	1	2025-04-01 14:15:37.877	1	2025-04-01 14:16:42.446816	\N	\N	SjdNBDSKFnaslikjcga	15	t	14
36	15708	B14	4-4	623	0	9	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	1	\N	2	5	2	\N	\N	\N	1	1	1	3	3	1	1	2025-04-04 17:21:32.508	4	2025-04-04 13:21:32.798173	1	2025-04-04 19:06:31.10059	akmdjdj	0	t	14
37	14722	B19	11-11	1229	P6	9	Juan D. Hernández	Neoregelia SP Tricolor	2	\N	6	2	1	\N	\N	\N	1	1	1	2	2	3	1	2025-04-04 19:27:30.369	1	2025-04-04 19:27:30.566419	\N	\N	Nueva plaga	10	t	22
39	9440	E16	Canteros genéricos	175	CONT_GENERAL	36	Karen Orozco	Epipremnum aureum Golden	2	\N	3	32	1	\N	\N	\N	1	3	1	2	2	3	1	2025-04-05 19:35:58.093	1	2025-04-05 19:36:16.967667	\N	\N	Revisando	15	t	14
4	15708	B14	4-4	623	0	10	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	2	6	2	\N	\N	\N	1	1	1	2	1	3	1	2025-03-29 15:00:02.364	4	2025-03-29 11:00:02.568169	4	2025-04-05 20:30:46.524647		10	t	14
40	9440	D18	1-68	181	P9	20	Karen Orozco	Epipremnum aureum Golden	12	\N	12	3	5	\N	\N	\N	2	1	1	2	2	3	1	2025-04-06 18:08:57.481	3	2025-04-06 18:08:57.804594	\N	\N	Revisando nueva inerfaz	12	t	14
38	15708	E12	12	655	CONT_GENERAL	47	Karen Orozco	Zelkova parvifolia Orme	11	\N	12	31	4	\N	\N	\N	2	3	1	2	2	1	1	2025-04-05 23:31:45.506	4	2025-04-05 19:32:22.320237	4	2025-04-06 18:31:48.494645	revisando interfase	2	t	22
41	15708	B14	4-4	86	0	14	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	3	\N	5	2	7	\N	\N	\N	1	1	1	2	1	3	1	2025-04-06 20:58:28.154	4	2025-04-06 20:59:58.958554	\N	\N	Revisar humedad del cultivo	12	t	14
42	15708	B14	4-4	86	0	13	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	5	\N	2	10	1	\N	\N	\N	1	1	1	2	3	1	1	2025-04-07 09:47:03.248	4	2025-04-07 09:47:03.486262	\N	\N	Testing	20	t	14
43	15708	B14	4-4	86	0	19	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	1	\N	5	6	8	\N	\N	\N	1	1	1	1	2	3	1	2025-04-07 09:48:33.65	4	2025-04-07 09:49:26.076494	\N	\N	kjcnzfpdvjzdo;'fijhsdfz	20	t	14
44	15708	B14	4-4	86	0	12	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	4	\N	4	5	3	\N	\N	\N	1	1	1	2	3	2	1	2025-04-07 19:44:38.833	4	2025-04-07 19:45:29.536175	\N	\N	afeghsregaergardfgadfgvba	20	t	14
45	15708	B14	4-4	86	0	12	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	6	\N	5	2	5	\N	\N	\N	1	1	1	2	1	2	1	2025-04-11 23:06:32.759	4	2025-04-11 23:06:32.849343	\N	\N	Hola	15	t	14
46	15708	B14	4-4	86	0	15	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	5	5	5	\N	\N	\N	1	1	1	1	2	3	1	2025-04-12 16:36:30.536	1	2025-04-12 16:36:30.745477	\N	\N	Hola!	12	t	14
51	15708	B14	4-4	86	0	39	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	4	25	10	\N	\N	\N	1	3	1	1	3	2	1	2025-05-23 15:42:55.058	4	2025-05-23 15:42:55.213159	\N	\N	muy afectadas	20	t	14
52	15708	B14	4-4	86	0	20	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	12	3	5	\N	\N	\N	2	1	1	3	1	2	1	2025-05-23 15:44:11.783	4	2025-05-23 15:44:11.874232	\N	\N	ese lote ta feo	5	t	16
53	9440	D18	1-68	181	P9	12	Karen Orozco	Epipremnum aureum Golden	40	\N	3	4	5	\N	\N	\N	1	1	1	1	2	2	1	2025-05-23 15:46:47.525	4	2025-05-23 15:46:47.659104	\N	\N	Plata my seca	\N	t	14
55	15708	B14	4-4	86	0	13	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	9	\N	5	3	5	\N	\N	\N	1	1	1	2	1	2	1	2025-05-24 03:22:43.567	1	2025-05-24 03:32:23.520188	\N	\N	Hola	10	t	16
47	9440	D18	1-68	181	P9	22	Karen Orozco	Epipremnum aureum Golden	12	\N	10	5	7	\N	\N	\N	1	1	1	2	1	2	1	2025-04-13 13:35:40.007	4	2025-04-13 09:35:40.290744	1	2025-04-13 13:14:42.513696	Hola Mundo!	10	t	22
63	15436	D01	27-30	272	P8Az	37	Karen Orozco	Dieffenbachia SP Compacta	12	\N	12	15	10	\N	\N	\N	2	2	1	3	3	3	1	2025-05-25 21:25:28.637	4	2025-05-25 21:25:29.457414	\N	\N	plantas muy secas	12	t	14
48	9440	D18	1-68	175	P9	20	Karen Orozco	Epipremnum aureum Golden	5	\N	10	5	5	\N	\N	\N	1	1	1	2	1	3	1	2025-04-14 01:10:12.496	4	2025-04-13 13:10:12.690893	1	2025-05-20 21:35:49.267447	Hola otra vez	12	t	22
49	9440	D18	1-68	181	P9	10	Karen Orozco	Epipremnum aureum Golden	5	\N	5	3	2	\N	\N	\N	1	1	1	2	1	1	1	2025-04-13 21:54:46.706	4	2025-04-13 21:55:19.286566	1	2025-05-20 21:34:49.221229	Elimine 12 plantas	12	t	23
56	15708	B14	4-4	86	0	60	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	10	\N	25	25	10	\N	\N	\N	3	3	1	3	3	3	1	2025-05-24 03:33:43.95	1	2025-05-24 03:36:37.848598	1	2025-05-24 04:32:27.0323	Hola	5	t	14
54	15207	E15	5	0	CONT_GENERAL	21	\N	Variedad genérica	5	\N	4	12	5	\N	\N	\N	1	2	1	1	3	2	1	2025-05-23 19:49:29.945	4	2025-05-23 15:49:30.087795	4	2025-05-24 15:47:42.274226	planta sin paletas	0	f	14
57	15708	B14	4-4	86	0	8	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	12	\N	2	5	1	\N	\N	\N	1	1	1	2	3	1	1	2025-05-24 17:30:44.347	4	2025-05-24 17:30:43.692939	\N	\N	no hay humedad	20	t	14
58	15708	B14	4-4	86	0	8	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	22	\N	2	3	3	\N	\N	\N	1	1	1	1	2	2	1	2025-05-24 22:22:27.438	4	2025-05-24 22:22:28.184806	\N	\N	si	12	t	22
50	15708	B14	4-4	86	0	7	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	2	\N	1	1	5	\N	\N	\N	1	1	1	2	3	3	1	2025-05-21 01:44:05.277	1	2025-05-20 21:44:05.428503	1	2025-05-20 21:51:08.141976	botamos 18 plantas	20	t	22
59	9440	D18	1-68	181	P9	6	Karen Orozco	Epipremnum aureum Golden	45	\N	2	3	1	\N	\N	\N	1	1	1	1	2	1	1	2025-05-24 22:37:28.373	4	2025-05-24 22:37:29.734141	\N	\N	plantas secas	\N	t	14
60	9440	D18	1-68	175	P9	12	Karen Orozco	Epipremnum aureum Golden	45	\N	1	10	1	\N	\N	\N	1	1	1	1	3	1	1	2025-05-25 02:38:39.553	4	2025-05-24 22:38:41.102845	4	2025-05-25 15:15:10.951802	incidencias cochinillas aqui	0	t	22
62	15708	B14	4-4	86	0	14	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	12	\N	2	5	7	\N	\N	\N	1	1	1	1	2	3	1	2025-05-25 16:42:22.148	4	2025-05-25 16:42:23.074628	\N	\N	botado de 12	12	t	22
64	15436	D01	27-30	272	P8Az	4	Karen Orozco	Dieffenbachia SP Compacta	10	\N	1	2	1	\N	\N	\N	1	1	1	1	3	1	1	2025-05-28 19:49:22.99	4	2025-05-28 19:49:23.171888	\N	\N	si probando	10	t	23
65	15708	B14	4-4	86	0	9	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	10	\N	2	2	5	\N	\N	\N	1	1	1	1	1	3	1	2025-05-28 20:55:20.29	4	2025-05-28 20:55:20.413482	\N	\N	Bote 10	10	t	14
66	15436	D01	27-30	272	P8Az	10	Karen Orozco	Dieffenbachia SP Compacta	15	\N	1	1	8	\N	\N	\N	1	1	1	1	1	3	1	2025-05-28 21:07:37.94	4	2025-05-28 21:07:37.378312	\N	\N	hola	10	t	14
68	15436	D01	27-30	272	P8Az	5	Karen Orozco	Dieffenbachia SP Compacta	25	\N	2	2	1	\N	\N	\N	1	1	1	3	3	1	1	2025-05-29 01:13:09.425	4	2025-05-28 21:13:09.035185	4	2025-05-28 21:19:35.330956	eso es	15	t	22
67	15436	D01	27-30	272	P8Az	6	Karen Orozco	Dieffenbachia SP Compacta	25	\N	1	4	1	\N	\N	\N	1	1	1	1	3	1	1	2025-05-29 05:10:10.654	4	2025-05-28 21:10:09.911603	4	2025-05-28 21:18:31.602179	todo	6	t	16
72	15436	D01	27-30	272	P8Az	11	Karen Orozco	Dieffenbachia SP Compacta	34	\N	1	2	8	\N	\N	\N	1	1	1	1	1	3	1	2025-05-28 21:53:17.759	3	2025-05-28 21:53:16.594691	\N	\N	hola	10	t	14
70	15436	D01	27-30	272	P8Az	10	Karen Orozco	Dieffenbachia SP Compacta	20	\N	2	3	5	\N	\N	\N	1	1	1	1	2	3	1	2025-05-28 21:24:39.577	4	2025-05-28 21:24:38.851555	\N	\N	hola	7	t	16
71	15436	D01	27-30	272	P8Az	10	Karen Orozco	Dieffenbachia SP Compacta	20	\N	2	2	6	\N	\N	\N	1	1	1	1	1	3	1	2025-05-28 21:25:26.466	4	2025-05-28 21:25:25.825693	\N	\N	hola	6	t	22
69	15436	D01	27-30	272	P8Az	9	Karen Orozco	Dieffenbachia SP Compacta	20	\N	1	3	5	\N	\N	\N	1	1	1	1	1	3	1	2025-05-29 05:23:06.864	4	2025-05-28 21:23:06.595462	4	2025-05-28 21:25:48.129963	hola	2	t	14
73	15436	D01	27-30	272	P8Az	13	Karen Orozco	Dieffenbachia SP Compacta	34	\N	2	2	9	\N	\N	\N	1	1	1	1	1	3	1	2025-05-28 21:54:14.427	3	2025-05-28 21:54:13.294253	\N	\N	plantas secas	12	t	22
74	15436	D01	27-30	272	P8Az	7	Karen Orozco	Dieffenbachia SP Compacta	34	\N	2	2	3	\N	\N	\N	1	1	1	1	1	2	1	2025-05-28 21:55:06.343	3	2025-05-28 21:55:05.18516	\N	\N	ya se ejecuto	12	t	16
75	15436	D01	27-30	272	P8Az	14	Karen Orozco	Dieffenbachia SP Compacta	79	\N	2	9	3	\N	\N	\N	1	1	1	1	3	2	1	2025-05-29 20:20:18.731	3	2025-05-29 20:20:18.062085	\N	\N	plantas secas botadas	12	t	14
76	15436	D01	27-30	272	P8Az	3	Karen Orozco	Dieffenbachia SP Compacta	79	\N	2	1	\N	\N	\N	\N	1	1	1	1	1	\N	1	2025-05-29 20:21:40.001	3	2025-05-29 20:21:39.311293	\N	\N	sucia	1	t	16
77	15436	D01	27-30	272	P8Az	1	Karen Orozco	Dieffenbachia SP Compacta	79	\N	1	\N	\N	\N	\N	\N	1	1	1	1	\N	\N	1	2025-05-29 20:22:07.631	3	2025-05-29 20:22:06.931126	\N	\N	hola	1	t	22
78	15436	D01	27-30	272	P8Az	2	Karen Orozco	Dieffenbachia SP Compacta	8	\N	2	\N	\N	\N	\N	\N	1	1	1	3	\N	\N	1	2025-05-29 20:30:39.955	3	2025-05-29 20:30:39.819851	\N	\N	hola	2	t	23
79	15436	D01	27-30	272	P8Az	6	Karen Orozco	Dieffenbachia SP Compacta	8	\N	2	3	1	\N	\N	\N	1	1	1	1	3	1	1	2025-05-29 20:31:28.154	3	2025-05-29 20:31:27.993626	\N	\N	\N	5	t	16
80	15436	D01	27-30	272	P8Az	7	Karen Orozco	Dieffenbachia SP Compacta	8	\N	3	3	1	\N	\N	\N	1	1	1	2	2	1	1	2025-05-29 20:32:08.257	3	2025-05-29 20:32:07.947911	\N	\N	hola	5	t	14
81	15708	B14	4-4	86	0	17	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	8	\N	2	5	10	\N	\N	\N	1	1	1	1	2	3	1	2025-05-30 21:10:17.854	4	2025-05-30 21:10:17.439909	\N	\N	hola	5	t	14
82	15436	D01	27-30	272	P8Az	13	Karen Orozco	Dieffenbachia SP Compacta	8	\N	3	1	9	\N	\N	\N	1	1	1	2	2	3	1	2025-05-31 16:34:27.753	1	2025-05-31 16:34:27.992484	\N	\N	Hola Mundo!	5	t	16
83	15436	D01	27-30	272	P8Az	3	Karen Orozco	Dieffenbachia SP Compacta	8	\N	1	1	1	\N	\N	\N	1	1	1	1	1	1	1	2025-05-31 16:35:00.516	1	2025-05-31 16:35:00.701496	\N	\N	Hola!	2	t	22
84	15436	D01	27-30	272	P8Az	8	Karen Orozco	Dieffenbachia SP Compacta	45	\N	2	5	1	\N	\N	\N	1	1	1	2	3	1	1	2025-05-31 16:57:57.369	3	2025-05-31 16:57:57.274343	\N	\N	hola	12	t	14
85	15436	D01	27-30	272	P8Az	13	Karen Orozco	Dieffenbachia SP Compacta	45	\N	2	5	6	\N	\N	\N	1	1	1	1	3	3	1	2025-05-31 16:58:37.14	3	2025-05-31 16:58:37.123328	\N	\N	hola	2	t	16
86	15436	D01	27-30	272	P8Az	6	Karen Orozco	Dieffenbachia SP Compacta	44	\N	1	2	3	\N	\N	\N	1	1	1	1	1	2	1	2025-05-31 16:59:57.491	4	2025-05-31 16:59:58.323756	\N	\N	hola	1	t	14
87	15436	D01	27-30	272	P8Az	10	Karen Orozco	Dieffenbachia SP Compacta	44	\N	1	1	8	\N	\N	\N	1	1	1	1	1	3	1	2025-05-31 17:00:32.442	4	2025-05-31 17:00:33.372373	\N	\N	hola	2	t	16
61	15708	B14	4-4	623	0	17	Stefano Albertazzi Barahona	Vinca roseus Soiree Kawaii Blueberry Kiss	15	\N	2	5	10	\N	\N	\N	1	1	1	1	2	3	1	2025-05-25 19:36:14.426	4	2025-05-25 15:36:15.693726	1	2025-06-04 01:31:44.97116	Hola	20	t	14
88	15436	D01	27-30	131	P8Az	14	Karen Orozco	Dieffenbachia SP Compacta	12	\N	6	7	1	\N	\N	\N	1	1	1	3	3	1	1	2025-06-04 02:10:08.387	1	2025-06-04 02:10:08.473207	\N	\N	Hola	6	t	16
89	15436	D01	27-30	131	P8Az	8	Karen Orozco	Dieffenbachia SP Compacta	12	\N	1	5	2	\N	\N	\N	1	1	1	1	3	1	1	2025-06-04 02:10:45.694	1	2025-06-04 02:10:45.758516	\N	\N	8	3	t	22
90	15436	D01	27-30	0	P8Az	11	Karen Orozco	Dieffenbachia SP Compacta	25	\N	5	5	1	\N	\N	\N	1	1	1	3	3	1	1	2025-06-05 06:43:41.043	1	2025-06-05 06:43:41.105988	\N	\N	Probando	16	t	16
91	15436	D01	27-30	0	P8Az	4	Karen Orozco	Dieffenbachia SP Compacta	25	\N	1	3	\N	\N	\N	\N	1	1	1	1	3	\N	1	2025-06-05 06:44:12.42	1	2025-06-05 06:44:12.461773	\N	\N	Hola	2	t	22
92	15436	D01	27-30	0	P8Az	7	Karen Orozco	Dieffenbachia SP Compacta	6	\N	3	1	3	\N	\N	\N	1	1	1	2	1	2	1	2025-06-07 09:31:38.154	4	2025-06-07 09:31:38.736198	\N	\N	Hola mundo	3	t	22
3	15267	H18	1-1	122	Ground	8	Tony Moriña	Cycas Revoluta Palm Sago	6	\N	4	3	1	\N	\N	\N	1	1	1	2	3	2	1	2025-03-29 13:44:07.784	4	2025-03-29 09:44:07.975927	4	2025-06-07 09:33:53.281766	afgadfgadfgafdsgaSDGsdfgA	10	t	14
93	15436	D01	27-30	0	P8Az	13	Karen Orozco	Dieffenbachia SP Compacta	45	\N	2	10	1	\N	\N	\N	1	1	1	1	3	1	1	2025-06-12 19:49:43.295	1	2025-06-12 19:49:43.579252	\N	\N	hola	12	t	22
94	15436	D01	27-30	0	P8Az	15	Karen Orozco	Dieffenbachia SP Compacta	45	\N	2	2	11	\N	\N	\N	1	1	2	1	1	3	1	2025-06-12 19:50:21.808	1	2025-06-12 19:50:21.944309	\N	\N	hola	2	t	14
95	15436	D01	27-30	0	P8Az	14	Karen Orozco	Dieffenbachia SP Compacta	26	\N	12	1	1	\N	\N	\N	2	1	1	3	1	1	1	2025-06-12 22:18:37.619	1	2025-06-12 22:18:37.769092	\N	\N	Hey	12	t	16
96	15436	D01	27-30	0	P8Az	5	Karen Orozco	Dieffenbachia SP Compacta	26	\N	1	1	3	\N	\N	\N	1	1	1	1	1	2	1	2025-06-12 22:19:16.013	1	2025-06-12 22:19:16.063004	\N	\N	Abc	2	t	22
97	15436	D01	27-30	0	P8Az	8	Karen Orozco	Dieffenbachia SP Compacta	32	\N	1	2	5	\N	\N	\N	1	1	1	1	1	3	1	2025-06-12 22:23:56.247	4	2025-06-12 23:09:29.511882	\N	\N	hola	6	t	20
98	15436	D01	27-30	0	P8Az	15	Karen Orozco	Dieffenbachia SP Compacta	32	\N	2	1	12	\N	\N	\N	1	1	2	1	1	3	1	2025-06-12 22:22:02.823	4	2025-06-12 23:09:34.196726	\N	\N	hola	12	t	23
99	15436	D01	27-30	0	P8Az	5	Karen Orozco	Dieffenbachia SP Compacta	62	\N	2	2	1	\N	\N	\N	1	1	1	2	2	1	1	2025-06-12 23:11:36.385	4	2025-06-12 23:11:36.950132	\N	\N	Hola	11	t	22
100	15436	D01	27-30	0	P8Az	12	Karen Orozco	Dieffenbachia SP Compacta	62	\N	1	10	1	\N	\N	\N	1	1	1	1	3	1	1	2025-06-12 23:12:26.82	4	2025-06-12 23:12:27.352737	\N	\N	hola	2	t	16
101	15436	D01	27-30	0	P8Az	23	Karen Orozco	Dieffenbachia SP Compacta	32	\N	12	10	1	\N	\N	\N	2	1	1	3	3	1	1	2025-06-12 23:30:58.717	3	2025-06-12 23:31:00.160628	\N	\N	Hey	10	t	22
102	15436	D01	27-30	0	P8Az	6	Karen Orozco	Dieffenbachia SP Compacta	32	\N	1	2	3	\N	\N	\N	1	1	1	1	1	2	1	2025-06-12 23:31:35.029	3	2025-06-12 23:31:36.510896	\N	\N	yupi	3	t	14
103	15436	D01	27-30	0	P8Az	8	Karen Orozco	Dieffenbachia SP Compacta	12	\N	6	1	1	\N	\N	\N	1	1	1	3	1	1	1	2025-06-13 17:12:46.904	4	2025-06-13 17:12:47.009756	\N	\N	ljkghlkujgklk	5	t	16
104	15436	D01	27-30	0	P8Az	8	Karen Orozco	Dieffenbachia SP Compacta	12	\N	5	2	1	\N	\N	\N	1	1	1	3	1	1	1	2025-06-13 17:13:16.814	4	2025-06-13 17:13:16.886752	\N	\N	kgkfgkf	5	t	22
105	15436	D01	27-30	0	P8Az	16	Karen Orozco	Dieffenbachia SP Compacta	32	\N	3	1	12	\N	\N	\N	1	1	2	1	1	3	1	2025-06-13 17:29:35.862	3	2025-06-13 17:29:35.969578	\N	\N	hola	3	t	16
106	15436	D01	27-30	0	P8Az	6	Karen Orozco	Dieffenbachia SP Compacta	32	\N	1	2	3	\N	\N	\N	1	1	1	1	1	3	1	2025-06-13 17:31:08.329	3	2025-06-13 17:31:08.558359	\N	\N	hola	2	t	22
107	15436	D01	27-30	0	P8Az	4	Karen Orozco	Dieffenbachia SP Compacta	1	\N	2	1	1	\N	\N	\N	1	1	1	3	1	1	1	2025-06-15 17:53:54.184	4	2025-06-15 21:53:54.324132	\N	\N	Hola	2	t	14
108	15436	D01	27-30	0	P8Az	9	Karen Orozco	Dieffenbachia SP Compacta	1	\N	3	3	3	\N	\N	\N	1	1	1	2	2	2	1	2025-06-15 17:54:35.007	4	2025-06-15 21:54:35.08651	\N	\N	Hola	1	t	22
109	15436	D01	27-30	0	P8Az	4	Karen Orozco	Dieffenbachia SP Compacta	81	\N	2	1	1	\N	\N	\N	1	1	1	3	1	1	1	2025-06-15 18:04:20.41	4	2025-06-15 22:04:21.564742	\N	\N	Holo Docker movil	12	t	22
110	15436	D01	27-30	0	P8Az	10	Karen Orozco	Dieffenbachia SP Compacta	81	\N	1	1	8	\N	\N	\N	1	1	1	1	1	3	1	2025-06-15 18:04:52.964	4	2025-06-15 22:04:54.195188	\N	\N	docker movil	2	t	16
\.


--
-- Data for Name: pm_nivelesinfestacion; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_nivelesinfestacion (pmni_secuencia, pmni_plaga, pmni_nombrecomun, pmni_lminferior, pmni_lmsuperior, pmni_nivel, pmni_rango, pmni_tipoobservacion, pmni_observacion, pmni_cintaidentificadora, pmni_estatus, pmni_creadopor, pmni_fechacreacion, pmni_modificadopor, pmni_fechamodificacion) FROM stdin;
4	20	Trips	1	3	1	1 ~ 3 individuos	Punto de muestreo	Se puede realizar foco	Azul	1	\N	2025-02-22 19:49:00.147207	\N	\N
5	20	Trips	4	6	2	4 ~ 6 individuos	Punto de muestreo	Se puede realizar foco	Azul + amarillo	1	\N	2025-02-22 19:49:00.147207	\N	\N
6	20	Trips	7	\N	3	7 o más individuos	Punto de muestreo	Se puede realizar foco	Azul + rojo	1	\N	2025-02-22 19:49:00.147207	\N	\N
10	22	Cochinilla	1	10	1	1 ~ 10 plantas afectadas por cantero	Cantero (Generalizado)	Dependiendo de la variedad se pueden sacar 20 portes. (Llamar al encargado de monitoreo)	Blanco	1	\N	2025-02-22 19:49:00.147207	\N	\N
11	22	Cochinilla	10	20	2	10 ~ 20 plantas afectadas por cantero	Cantero (Generalizado)	Dependiendo de la variedad se pueden sacar 20 portes. (Llamar al encargado de monitoreo)	Blanco + amarillo	1	\N	2025-02-22 19:49:00.147207	\N	\N
12	22	Cochinilla	20	\N	3	20 ~ más plantas afectadas por cantero	Cantero (Generalizado)	Dependiendo de la variedad se pueden sacar 20 portes. (Llamar al encargado de monitoreo)	Blanca + rojo	1	\N	2025-02-22 19:49:00.147207	\N	\N
22	33	xc	1	2	1	xc	xc	xc	xc	0	1	2025-05-19 22:02:20.907247	\N	2025-05-19 22:18:08.221776
23	33	xc	2	3	2	xc	xc	xc	xc	0	1	2025-05-19 22:02:21.031796	\N	2025-05-19 22:18:08.221776
24	33	xc	3	4	3	xc	xc	xc	xc	0	1	2025-05-19 22:02:21.197196	\N	2025-05-19 22:18:08.221776
19	32	x	1	2	1	x	x	x	x	0	1	2025-05-19 21:55:06.190968	\N	2025-05-19 22:00:34.366521
20	32	x	2	3	2	x	x	x	x	0	1	2025-05-19 21:55:06.214188	\N	2025-05-19 22:00:34.366521
21	32	x	3	4	3	x	x	x	x	0	1	2025-05-19 21:55:06.229078	\N	2025-05-19 22:00:34.366521
25	34	xy	1	2	1	xy	xy	xy	xy	0	1	2025-05-19 22:19:19.118002	1	2025-05-19 22:19:54.768315
26	34	xy	2	3	2	xy	xy	xy	xy	0	1	2025-05-19 22:19:19.145328	1	2025-05-19 22:19:54.768315
27	34	xy	3	4	3	xy	xy	xy	xy	0	1	2025-05-19 22:19:19.166362	1	2025-05-19 22:19:54.768315
2	14	Acaro	4	6	2	4 ~ 6 individuos	Punto de muestreo	Se puede realizar foco	Azul + amarillo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
3	14	Acaro	7	0	3	7 o más individuos	Punto de muestreo	Se puede realizar foco	Azul + rojo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
13	16	Afido	1	2	1	1 planta en el cantero con individuos	Cantero (Generalizado)	Individuos poco moviles	Rosada / negro	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
14	16	Afido	2	3	2	2 ~ 3 plantas en el cantero con individuos	Cantero (Generalizado)	Individuos poco moviles	Rosada / negro + amarillo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
15	16	Afido	3	0	3	3 o más plantas en el cantero con individuos	Cantero (Generalizado)	Individuos poco moviles	Rosada / negro + rojo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
7	23	Oruga	1	2	1	1 individuo, daño fresco o excremento	Cantero (Generalizado)	No se puede realizar foco	Amarillo / rojo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
8	23	Oruga	2	3	2	2 individuos	Cantero (Generalizado)	No se puede realizar foco	Amarillo / rojo + amarillo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
9	23	Oruga	3	0	3	3 individuos	Cantero (Generalizado)	No se puede realizar foco	Amarillo / rojo + rojo	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
1	14	Acaro	1	3	1	1 ~ 3 individuos	Punto de muestreo	Se puede realizar foco	Azul	1	\N	2025-02-22 19:49:00.147207	1	2025-05-28 20:45:40.855713
16	31	No se observa	0	1	1	No se observa	N/A	N/A	N/A	1	1	2025-03-09 18:32:40.101263	1	2025-05-30 19:44:33.537281
17	31	No se observa	0	2	2	N/A	N/A	N/A	N/A	1	1	2025-03-09 18:32:40.125565	1	2025-05-30 19:44:33.537281
18	31	No se observa	0	3	3	N/A	N/A	N/A	N/A	1	1	2025-03-09 18:32:40.138223	1	2025-05-30 19:44:33.537281
\.


--
-- Data for Name: pm_plagas; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_plagas (pmpl_id, pmpl_genero, pmpl_familia, pmpl_nombrecomun, pmpl_tipo, pmpl_estatus, pmpl_creadopor, pmpl_fechacreacion, pmpl_modificadopor, pmpl_fechamodificacion) FROM stdin;
20	Frankliniella	Thripidae	Trips	Insecto (plaga)	1	\N	2025-02-22 19:10:10.370069	\N	\N
22	Planococcus	Pseudococcidae	Cochinilla	Insecto (plaga)	1	\N	2025-02-22 19:10:10.370069	\N	\N
2	Erwinia	Enterobacteriaceae	Erwinia	Bacteria (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:30:29.179008
1	Clavibacter	Microbacteriaceae	Clavibacter	Bacteria (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:30:33.935071
14	Tetranychus	Tetranychidae	Acaro	Acaro (plaga)	1	\N	2025-02-22 19:10:10.370069	1	2025-04-13 15:35:45.374798
16	Aphis	Aphididae	Afido	Insecto (plaga)	1	\N	2025-02-22 19:10:10.370069	1	2025-04-13 15:39:53.616579
30	Tobamovirus	Virgaviridae	Virus del mosaico del tabaco	Virus (patogeno)	0	\N	2025-02-22 19:10:10.370069	1	2025-04-13 09:19:04.422311
29	Potyvirus	Potyviridae	Virus del mosaico del frijol comun	Virus (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:19:18.847212
23	Spodoptera	Noctuidae	Oruga	Insecto (plaga)	1	\N	2025-02-22 19:10:10.370069	1	2025-04-13 15:46:52.971462
27	Cucumovirus	Bromoviridae	Virus del mosaico del pepino	Virus (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:19:31.171749
26	Begomovirus	Geminiviridae	Virus del enrollamiento de la hoja del tomate	Virus (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:19:37.619199
25	Meloidogyne	Heteroderidae	Nematodo de la raíz	Nematodo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:19:44.765688
24	Zeuzera	Cossidae	Barrenador del tallo	Insecto (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:25:02.579736
21	Liriomyza	Agromyzidae	Minador de hojas	Insecto (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:25:26.62854
28	Potyvirus	Potyviridae	Virus de la mancha anular del papayo	Virus (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:25:49.26463
19	Diaspis	Diaspididae	Escama	Insecto (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:26:06.576941
18	Ceratitis	Tephritidae	Mosca del fruto	Insecto (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:26:21.558445
17	Bemisia	Aleyrodidae	Mosca blanca	Insecto (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:26:50.643092
15	Tetranychus	Tetranychidae	Araña roja	Acaro (plaga)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:27:16.8937
32	x	x	x	N/A	0	1	2025-05-19 21:55:06.140676	1	2025-05-19 22:00:34.366521
13	Puccinia	Pucciniaceae	Royas	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:27:43.069775
12	Plasmopara	Peronosporaceae	Mildiu	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:27:51.830876
11	Phytophthora	Peronosporaceae	Pudrición radicular	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:28:57.01188
10	Guignardia	Phyllostictaceae	Mancha negra	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:29:05.963936
9	Fusarium	Nectriaceae	Fusarium	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:29:19.021916
8	Erysiphe	Erysiphaceae	Oídio	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:29:33.980384
7	Colletotrichum	Glomerellaceae	Antracnosis	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:29:52.13767
6	Botrytis	Sclerotiniaceae	Podredumbre gris	Hongo (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:29:59.680511
5	Xanthomonas	Xanthomonadaceae	Xanthomonas	Bacteria (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:30:07.105857
4	Ralstonia	Burkholderiaceae	Ralstonia	Bacteria (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-04-13 09:30:12.929165
33	xc	xc	xc	N/A	0	1	2025-05-19 22:02:20.850789	1	2025-05-19 22:20:08.155745
34	xy	xy	xy	N/A	0	1	2025-05-19 22:19:19.069368	1	2025-05-19 22:20:20.299451
3	Pseudomonas	Pseudomonadaceae	Pseudomonas	Bacteria (patogeno)	0	\N	2025-02-22 19:10:10.370069	\N	2025-05-30 18:20:19.589021
31	N/A	N/A	No se observa	N/A	1	1	2025-03-08 17:47:32.47027	1	2025-05-30 19:44:33.537281
\.


--
-- Data for Name: pm_potes; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_potes (pmpo_id, pmpo_codigo, pmpo_contenedor, pmpo_estatus, pmpo_creadopor, pmpo_fechacreacion, pmpo_modificadopor, pmpo_fechamodificacion) FROM stdin;
1	55	P4	1	\N	2025-02-22 19:48:31.309856	\N	\N
2	56	P6	1	\N	2025-02-22 19:48:31.309856	\N	\N
3	57	P8	1	\N	2025-02-22 19:48:31.309856	\N	\N
\.


--
-- Data for Name: pm_rol; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_rol (pmrl_id, pmrl_descripcion, pmrl_estatus, pmrl_fechacreacion, pmrl_fechamodificacion, pmrl_creadopor, pmrl_modificadopor) FROM stdin;
3	Supervisor	1	2025-02-22 19:08:31.445389	2025-03-05 23:26:22.15332	\N	1
4	Monitoreador	1	2025-02-22 19:08:31.445389	2025-03-05 23:26:36.76504	\N	1
2	Grower	1	2025-02-22 19:08:31.445389	2025-03-05 23:29:49.800399	\N	1
1	Admin	1	2025-02-22 19:08:31.445389	2025-03-08 22:55:45.140398	\N	1
5	Junior Grower	1	2025-03-06 09:52:24.170165	2025-04-27 09:15:53.804288	1	1
\.


--
-- Data for Name: pm_unidadescultivo; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_unidadescultivo (pmuc_secuencia, pmuc_id, pmuc_codigo, pmuc_cantero, pmuc_estatus, pmuc_creadopor, pmuc_fechacreacion, pmuc_modificadopor, pmuc_fechamodificacion) FROM stdin;
1	86	A01	 1-51	1	1	2025-03-31 09:49:27.332494	\N	\N
2	147	A02	 1-48	1	1	2025-03-31 09:49:27.332494	\N	\N
3	148	A03	 1-58	1	1	2025-03-31 09:49:27.332494	\N	\N
4	149	A04	 1-58	1	1	2025-03-31 09:49:27.332494	\N	\N
5	1436	A05	 1-1	1	1	2025-03-31 09:49:27.332494	\N	\N
6	1437	A06	 1-1	1	1	2025-03-31 09:49:27.332494	\N	\N
7	1438	A07	 1-1	1	1	2025-03-31 09:49:27.332494	\N	\N
8	1439	A08	 1-1	1	1	2025-03-31 09:49:27.332494	\N	\N
9	1363	A09	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
10	1364	A10	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
11	1365	A11	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
12	1366	A12	 1-15	1	1	2025-03-31 09:49:27.332494	\N	\N
13	1367	A13	 1-7	1	1	2025-03-31 09:49:27.332494	\N	\N
14	1368	A14	 1-7	1	1	2025-03-31 09:49:27.332494	\N	\N
15	1369	A15	 1-5	1	1	2025-03-31 09:49:27.332494	\N	\N
16	87	B01	 1-51	1	1	2025-03-31 09:49:27.332494	\N	\N
17	88	B02	 1-53	1	1	2025-03-31 09:49:27.332494	\N	\N
18	89	B03	 1-54	1	1	2025-03-31 09:49:27.332494	\N	\N
19	90	B04	 1-52	1	1	2025-03-31 09:49:27.332494	\N	\N
20	91	B05	 1-50	1	1	2025-03-31 09:49:27.332494	\N	\N
21	92	B06	 1-83	1	1	2025-03-31 09:49:27.332494	\N	\N
22	93	B07	 1-70	1	1	2025-03-31 09:49:27.332494	\N	\N
23	94	B08	 1-79	1	1	2025-03-31 09:49:27.332494	\N	\N
24	95	B09	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
25	96	B10	 1-70	1	1	2025-03-31 09:49:27.332494	\N	\N
26	97	B11	 1-66	1	1	2025-03-31 09:49:27.332494	\N	\N
27	98	B12	 1-70	1	1	2025-03-31 09:49:27.332494	\N	\N
28	99	B13	 1-78	1	1	2025-03-31 09:49:27.332494	\N	\N
29	100	B14	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
30	101	B15	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
31	102	B16	 1-70	1	1	2025-03-31 09:49:27.332494	\N	\N
32	103	B17	 1-84	1	1	2025-03-31 09:49:27.332494	\N	\N
33	104	B18	 1-84	1	1	2025-03-31 09:49:27.332494	\N	\N
34	1412	B19	 1-52	1	1	2025-03-31 09:49:27.332494	\N	\N
35	106	B20	 1-54	1	1	2025-03-31 09:49:27.332494	\N	\N
36	107	B21	 1-55	1	1	2025-03-31 09:49:27.332494	\N	\N
37	108	B22	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
38	109	B23	 1-53	1	1	2025-03-31 09:49:27.332494	\N	\N
39	110	B24	 1-55	1	1	2025-03-31 09:49:27.332494	\N	\N
40	111	B25	 1-55	1	1	2025-03-31 09:49:27.332494	\N	\N
41	112	B26	 1-69	1	1	2025-03-31 09:49:27.332494	\N	\N
42	113	B27	 1-55	1	1	2025-03-31 09:49:27.332494	\N	\N
43	114	B28	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
44	115	B29	 1-56	1	1	2025-03-31 09:49:27.332494	\N	\N
45	1370	B30	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
46	1371	B31	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
47	1434	B32	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
48	1373	B33	 1-8	1	1	2025-03-31 09:49:27.332494	\N	\N
49	1433	B34	 1-6	1	1	2025-03-31 09:49:27.332494	\N	\N
50	116	C01	 1-48	1	1	2025-03-31 09:49:27.332494	\N	\N
51	117	C02	 1-27	1	1	2025-03-31 09:49:27.332494	\N	\N
52	118	C03	 1-76	1	1	2025-03-31 09:49:27.332494	\N	\N
53	119	C04	 1-61	1	1	2025-03-31 09:49:27.332494	\N	\N
54	120	C05	 1-59	1	1	2025-03-31 09:49:27.332494	\N	\N
55	121	C06	 1-100	1	1	2025-03-31 09:49:27.332494	\N	\N
56	1415	C07	 1-88	1	1	2025-03-31 09:49:27.332494	\N	\N
57	1414	C08	 1-88	1	1	2025-03-31 09:49:27.332494	\N	\N
58	150	C09	 1-75	1	1	2025-03-31 09:49:27.332494	\N	\N
59	151	C10	 1-89	1	1	2025-03-31 09:49:27.332494	\N	\N
60	152	C11	 1-93	1	1	2025-03-31 09:49:27.332494	\N	\N
61	1432	C12	 1-59	1	1	2025-03-31 09:49:27.332494	\N	\N
62	153	C13	 1-59	1	1	2025-03-31 09:49:27.332494	\N	\N
63	154	C14	 1-108	1	1	2025-03-31 09:49:27.332494	\N	\N
64	155	C15	 1-105	1	1	2025-03-31 09:49:27.332494	\N	\N
65	1431	C16	 1-79	1	1	2025-03-31 09:49:27.332494	\N	\N
66	1416	C17	 1-77	1	1	2025-03-31 09:49:27.332494	\N	\N
67	127	C18	 1-77	1	1	2025-03-31 09:49:27.332494	\N	\N
68	156	C19	 1-95	1	1	2025-03-31 09:49:27.332494	\N	\N
69	157	C20	 1-94	1	1	2025-03-31 09:49:27.332494	\N	\N
70	158	C21	 1-94	1	1	2025-03-31 09:49:27.332494	\N	\N
71	1430	C22	 1-93	1	1	2025-03-31 09:49:27.332494	\N	\N
72	160	C23	 1-94	1	1	2025-03-31 09:49:27.332494	\N	\N
73	161	C24	 1-93	1	1	2025-03-31 09:49:27.332494	\N	\N
74	162	C25	 1-105	1	1	2025-03-31 09:49:27.332494	\N	\N
75	163	C26	 1-89	1	1	2025-03-31 09:49:27.332494	\N	\N
76	1427	C27	 1-32	1	1	2025-03-31 09:49:27.332494	\N	\N
77	1428	C28	 1-48	1	1	2025-03-31 09:49:27.332494	\N	\N
78	142	D00	 1-19	1	1	2025-03-31 09:49:27.332494	\N	\N
79	128	D01	 1-50	1	1	2025-03-31 09:49:27.332494	\N	\N
80	129	D02	 1-60	1	1	2025-03-31 09:49:27.332494	\N	\N
81	130	D03	 1-65	1	1	2025-03-31 09:49:27.332494	\N	\N
82	146	D04	 1-90	1	1	2025-03-31 09:49:27.332494	\N	\N
83	164	D05	 1-81	1	1	2025-03-31 09:49:27.332494	\N	\N
84	165	D06	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
85	131	D07	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
86	132	D08	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
87	133	D09	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
88	143	D10	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
89	134	D11	 1-71	1	1	2025-03-31 09:49:27.332494	\N	\N
90	135	D12	 1-79	1	1	2025-03-31 09:49:27.332494	\N	\N
91	166	D13	 1-70	1	1	2025-03-31 09:49:27.332494	\N	\N
92	167	D14	 1-90	1	1	2025-03-31 09:49:27.332494	\N	\N
93	1410	D15	 1-90	1	1	2025-03-31 09:49:27.332494	\N	\N
94	136	D16	 1-75	1	1	2025-03-31 09:49:27.332494	\N	\N
95	137	D17	 1-75	1	1	2025-03-31 09:49:27.332494	\N	\N
96	138	D18	 1-68	1	1	2025-03-31 09:49:27.332494	\N	\N
97	139	D19	 1-75	1	1	2025-03-31 09:49:27.332494	\N	\N
98	140	D20	 1-81	1	1	2025-03-31 09:49:27.332494	\N	\N
99	141	D21	 1-73	1	1	2025-03-31 09:49:27.332494	\N	\N
100	169	D22	 1-73	1	1	2025-03-31 09:49:27.332494	\N	\N
101	170	D23	 1-68	1	1	2025-03-31 09:49:27.332494	\N	\N
102	171	D24	 1-62	1	1	2025-03-31 09:49:27.332494	\N	\N
103	172	D25	 1-69	1	1	2025-03-31 09:49:27.332494	\N	\N
104	144	E00	 1-44	1	1	2025-03-31 09:49:27.332494	\N	\N
105	1409	E01	 1-50	1	1	2025-03-31 09:49:27.332494	\N	\N
106	174	E02	 1-91	1	1	2025-03-31 09:49:27.332494	\N	\N
107	175	E03	 1-100	1	1	2025-03-31 09:49:27.332494	\N	\N
108	176	E04	 1-92	1	1	2025-03-31 09:49:27.332494	\N	\N
109	177	E05	 1-92	1	1	2025-03-31 09:49:27.332494	\N	\N
110	178	E06	 1-88	1	1	2025-03-31 09:49:27.332494	\N	\N
111	179	E07	 1-87	1	1	2025-03-31 09:49:27.332494	\N	\N
112	180	E08	 1-86	1	1	2025-03-31 09:49:27.332494	\N	\N
113	184	E09	 1-95	1	1	2025-03-31 09:49:27.332494	\N	\N
114	1417	E10	 1-95	1	1	2025-03-31 09:49:27.332494	\N	\N
116	1419	E12	 1-90	1	1	2025-03-31 09:49:27.332494	\N	\N
117	182	E13	 1-86	1	1	2025-03-31 09:49:27.332494	\N	\N
118	181	E14	 1-86	1	1	2025-03-31 09:49:27.332494	\N	\N
119	183	E15	 1-86	1	1	2025-03-31 09:49:27.332494	\N	\N
120	188	E16	 1-73	1	1	2025-03-31 09:49:27.332494	\N	\N
121	189	E17	 1-86	1	1	2025-03-31 09:49:27.332494	1	2025-05-19 19:45:42.784103
115	1418	E11	 1-90	1	1	2025-03-31 09:49:27.332494	1	2025-05-19 19:45:50.136253
122	190	E18	 1-86	1	1	2025-03-31 09:49:27.332494	1	2025-05-19 19:49:13.296069
123	1000	General	1-1	1	1	2025-05-19 20:55:42.315858	1	2025-05-23 11:32:53.385343
\.


--
-- Data for Name: pm_usuarios; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_usuarios (pmus_id, pmus_codigo, pmus_usuario, pmus_funcion, pmus_estatus, pmus_creadopor, pmus_fechacreacion, pmus_modificadopor, pmus_fechamodificacion, pmus_password, pmus_correo, pmus_telefono) FROM stdin;
3	1313	JosePerez	4	1	\N	2025-02-22 19:09:51.53463	1	2025-03-31 07:37:05.929529	$2b$10$Vj9wNKYzUP2MrYiICiTsF./8VSWwjpK9s4urYg5WtMHHptq215cRy	jpena@pepito.com	8092345678
2	1010	JoseCorella	1	1	\N	2025-02-22 19:09:51.53463	1	2025-04-13 13:20:50.091499	$2b$10$dNtHXfiURGIwPQMG/tspsewnMbOED6GCADyULI4nsHTZ1VilBL2a.	jcorella@pepito.com	8092304507
5	6060	AndresMesa	4	1	1	2025-04-13 13:19:03.083704	1	2025-04-26 22:29:55.018701	$2b$10$Wpx6mpUjLu7WnrYWtVRAY.Azzd/x5SvPCoW8EGTxW8opK/XThXJiK	amesa@pepito.com	8097707171
8	9898	LuisMatos	4	1	1	2025-04-26 22:31:45.235118	\N	\N	$2b$10$4kdAC/sgWDQEKsqIqZvOVe4H7G7IJlzrEuXTcgpO.9XfjRIlvaNj2	lmatos@pepito.com	8097789797
4	9876	MiguelGil	4	1	1	2025-03-03 18:41:54.507002	1	2025-04-26 20:54:45.27114	$2b$10$1ReP9CpNxwJctt/ZEfBpPO8.vGmKM2yLwf.aUWnqkVEViRCVlZx4S	mgil@pepito.com	8092346758
1	8228	JuanMendoza	1	1	\N	2025-02-22 19:09:51.53463	1	2025-03-29 16:05:26.857106	$2b$10$oBoyU/ExvDBJlKQW6j5yTuXJklPp1HNYxWDt2gag8Ga04zRa053PO	jmendoza@costanursery.com	8097224957
\.


--
-- Data for Name: pm_variedades; Type: TABLE DATA; Schema: public; Owner: pestuser
--

COPY public.pm_variedades (pmva_id, pmva_codigo, pmva_descripcion, pmva_responsable, pmva_estatus, pmva_creadopor, pmva_fechacreacion, pmva_modificadopor, pmva_fechamodificacion) FROM stdin;
1	3468	Chamaedorea cataractarum Cat Palm	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
2	219	Adenium Obesum Desert Rose	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
3	3467	Adenium Obesum Desert Rose (Seed)	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
4	3382	Aglaonema Commutatum 7 UP	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
5	3327	Aglaonema Commutatum Ambar	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
6	1241	Aglaonema Commutatum Anyamanee	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
7	3331	Aglaonema Commutatum Bangkok Breeder	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
8	3368	Aglaonema Commutatum Beauty	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
9	3381	Aglaonema Commutatum Bella	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
10	220	Aglaonema Commutatum Cecilia	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
11	3332	Aglaonema Commutatum Chon Buri	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
12	3333	Aglaonema Commutatum Dieffenema	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
13	229	Aglaonema Commutatum Edgy White	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
14	235	Aglaonema Commutatum Emerald Red	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
15	230	Aglaonema Commutatum Golden Bay	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
16	231	Aglaonema Commutatum Golden Flourite	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
17	221	Aglaonema Commutatum Hybrid #10	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
18	247	Aglaonema Commutatum Hybrid #13	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
19	222	Aglaonema Commutatum Hybrid #20	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
20	245	Aglaonema Commutatum Hybrid #7	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
21	246	Aglaonema Commutatum Hybrid #9	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
22	223	Aglaonema Commutatum Koh Sumai	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
23	3334	Aglaonema Commutatum Lemon Sunrise	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
24	224	Aglaonema Commutatum Leprechaum	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
25	3383	Aglaonema Commutatum Lightshow	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
26	240	Aglaonema Commutatum Lockhai	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
27	241	Aglaonema Commutatum Lucky	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
28	3335	Aglaonema Commutatum Lumina	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
29	3367	Aglaonema Commutatum Marie	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
30	3336	Aglaonema Commutatum Mini Green Bowl	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
31	232	Aglaonema Commutatum Mini Silver Queen	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
32	225	Aglaonema Commutatum Narrow Spinel	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
33	226	Aglaonema Commutatum Phuket	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
34	233	Aglaonema Commutatum Pink Siam	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
35	234	Aglaonema Commutatum Princess Silver Queen	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
36	3369	Aglaonema Commutatum Red Assortment East Red	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
37	3370	Aglaonema Commutatum Red Assortment Lucky Red	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
38	3364	Aglaonema Commutatum Red Fountain	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
39	3328	Aglaonema Commutatum Red Pea	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
40	1240	Aglaonema Commutatum Red Stripe	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
41	3329	Aglaonema Commutatum Red Sunset	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
42	227	Aglaonema Commutatum Rice	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
43	3372	Aglaonema Commutatum Ruby	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
44	236	Aglaonema Commutatum Siam	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
45	3330	Aglaonema Commutatum Siam Diamond	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
46	237	Aglaonema Commutatum Silver Bay	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
47	3337	Aglaonema Commutatum Silver Frost	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
48	244	Aglaonema Commutatum Silver Shadow	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
49	3371	Aglaonema Commutatum Snow Flake	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
50	3366	Aglaonema Commutatum Snow White	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
51	243	Aglaonema Commutatum Spathonema	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
52	238	Aglaonema Commutatum Super Red Aurora	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
53	1242	Aglaonema Commutatum Super Star	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
54	239	Aglaonema Commutatum Twotone Moonstone	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
55	228	Aglaonema Commutatum White Calcite	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
56	242	Aglaonema Commutatum White Tip	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
57	3365	Aglaonema Commutatum Wishes	Jairo Gonzalez	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
58	154	Ajuga Reptans Burgundy Glow	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
59	164	Ajuga Reptans Chocolate Chip	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
60	1216	Aloe Hybrid Aristata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
61	250	Aloe Hybrid Fang	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
62	251	Aloe Hybrid Green Sand	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
63	254	Aloe Hybrid Pink Blush	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
64	3326	Aloe Hybrid White Beauty	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
65	256	Aloe Hybrid White Lightning	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
66	248	Aloe Jucunda X Acutissima Bright Star	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
67	249	Aloe SP Ciliaris	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
68	252	Aloe SP Juvenna	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
464	2248	Monstera SP Dubia	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
69	253	Aloe SP Minibelle	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
70	1199	Aloe SP Royal Highness	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
71	3462	Aloe SP Ukambensis	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
72	255	Aloe SP Walmsley Variegata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
73	257	Ananas Comosus Pink Stardust	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
74	120	Artemisia Arborescens Powis Castle	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
75	201	Artemisia Schmidtiana Silver Mound	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
76	199	Artemisia Stelleriana Silver Brocade	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
77	85	Asclepias Incarnata Swamp Milkweed	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
78	1246	Asparagus meyeri Foxtail	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
79	3461	Asparagus sprengeri Fernleaf	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
80	258	Begonia maculata BFM	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
81	260	Begonia maculata Polka Dots	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
82	190	Buddleja davidii Black Knight	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
83	142	Buddleja davidii Nanho Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
84	143	Buddleja davidii Nanho Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
85	99	Buddleja davidii Pink Delight	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
86	3481	Cacti SP Assortment	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
87	261	Calathea SP Insignis	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
88	2254	Calathea SP Makoyana	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
89	262	Calathea SP Network	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
90	3387	Ceodes umbellifera Pisonia	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
91	1200	Cereus fairy Castle	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
92	3471	Cereus SP Jamacaru	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
93	265	Cereus SP Peruvianus	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
94	208	Chlorophytum comosum Variegatum	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
95	3488	Cleretum bellidiforme Mezoo Trailing Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
96	3358	Codiaeum variegatum Mamey	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
97	3357	Codiaeum variegatum Petra	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
98	3480	Color SP Assortment	Maybelle Flores	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
99	141	Coreopsis auriculata Nana	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
100	183	Coreopsis grandiflora Solanna Golden Sphere	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
101	3350	Costus erythrophyllus Twotoner	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
102	266	Crassula arborescens Curly Green	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
103	1221	Crassula capitella Campfire	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
104	268	Crassula mesembryanthemoides Tenelli	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
105	1222	Crassula ovata Hummels Sunset	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
106	269	Crassula ovata Mini	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
107	267	Crassula SP Hobbit	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
108	270	Crassula SP Sarmentosa	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
109	174	Crossandra infundibuliformis Florida Sunset	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
110	216	Crossandra infundibuliformis Florida Sunshine	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
111	150	Crossandra infundibuliformis Orange Marmalade	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
112	213	Crossandra infundibuliformis Yellow	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
113	178	Cuphea hyssopifolia Allyson Lavender	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
114	179	Cuphea llavea Floriglory Alonso	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
115	171	Cuphea llavea Floriglory Diana	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
116	138	Cuphea llavea Floriglory Maria	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
117	198	Cuphea llavea Floriglory Selena	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
118	4540	Cuphea SP CUH 21 16-01	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
119	4537	Cuphea SP Stellar Lilac	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
120	4539	Cuphea SP Stellar Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
121	4538	Cuphea SP Stellar White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
122	3393	Cycas Revoluta Palm Sago	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
123	126	Delosperma cooperi Ice Plant	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
124	3307	Dieffenbachia maculata Alix	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
125	3363	Dieffenbachia maculata Crocodile	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
126	273	Dieffenbachia maculata Panther	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
127	3306	Dieffenbachia maculata Snow	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
128	3305	Dieffenbachia maculata Sterling	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
129	3361	Dieffenbachia seguine  Tropic Snow	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
130	271	Dieffenbachia SP Camille	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
131	272	Dieffenbachia SP Compacta	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
132	1243	Dieffenbachia SP Cool Beauty	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
133	1249	Dieffenbachia SP Sublime	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
134	1248	Dieffenbachia SP Vesuvius	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
135	274	Dracaena fragrans Massangeana	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
136	4530	Dracaena fragrans Massangeana 1.66 CC	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
137	4517	Dracaena fragrans Massangeana 2 CC	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
138	180	Duranta erecta Gold Mound	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
139	196	Duranta erecta Sapphire Showers	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
140	285	Echeveria elegans Ghost white	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
141	284	Echeveria elegans Runyonii	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
142	2264	Echeveria gibbiflora Metalica	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
143	275	Echeveria SP Agavoide	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
144	2269	Echeveria SP Blue Bird	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
145	276	Echeveria SP Blue Bird ##	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
146	277	Echeveria SP Blue Frills	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
147	2261	Echeveria SP Colorata Hybrid	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
148	278	Echeveria SP Daren Oliver	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
149	279	Echeveria SP Dash full	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
150	280	Echeveria SP Debbie	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
151	2266	Echeveria SP Debbie ##	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
152	281	Echeveria SP Deremensis	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
153	282	Echeveria SP Domingo	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
154	1187	Echeveria SP Ebony	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
155	283	Echeveria SP Elegans	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
156	3399	Echeveria SP First Lady	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
157	3401	Echeveria SP Giant Blue	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
158	288	Echeveria SP Hercules	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
159	2260	Echeveria SP Lola	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
160	289	Echeveria SP Noble Red	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
161	2267	Echeveria SP Nodulosa	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
162	290	Echeveria SP Opalina	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
163	291	Echeveria SP Peacockii	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
164	292	Echeveria SP Perle Von Nurnberg	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
165	293	Echeveria SP Prims big	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
166	3400	Echeveria SP Raindrop	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
167	286	Echeveria Tolimanensis Haegii	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
168	263	Ehretia Microphylla Fukien Tea (Mini)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
169	1224	Ehretia Microphylla Fukien Tea (Small)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
170	3360	Elatostema sp Thai Dragon	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
171	3349	Epipremnum asplissium Narrow Leaf	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
172	4505	Epipremnum asplissium Variegata	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
173	2268	Epipremnum aureum Champs Elysees	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
174	294	Epipremnum aureum Global Green	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
175	181	Epipremnum aureum Golden	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
176	3359	Epipremnum aureum Lemon Meringue	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
177	3482	Epipremnum aureum Lemon Top	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
178	2265	Epipremnum aureum Manjula	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
179	4518	Epipremnum aureum Marble Queen	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
180	144	Epipremnum aureum Neon	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
181	4504	Epipremnum aureum Neon Joy	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
182	3394	Epipremnum aureum Shangri-La	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
183	3463	Epipremnum pinnatum Albo Variegata	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
184	295	Epipremnum pinnatum Baltic Blue	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
185	207	Epipremnum pinnatum Sunburst	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
186	3377	Epipremnum SP Reflecto	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
187	297	Euphorbia lactea Candelabra	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
188	298	Euphorbia lactea Compacta	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
189	129	Euphorbia milii Karola	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
190	118	Euphorbia pulcherrima 14-874	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
191	3342	Euphorbia pulcherrima 16-324	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
192	3340	Euphorbia pulcherrima 16-499	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
193	3338	Euphorbia pulcherrima 19-806	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
194	176	Euphorbia pulcherrima A1 Pink	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
195	177	Euphorbia pulcherrima A1 Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
196	214	Euphorbia pulcherrima A1 White	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
197	110	Euphorbia pulcherrima Assortment	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
198	3466	Euphorbia pulcherrima Freedom Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
199	217	Euphorbia pulcherrima Legacy Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
200	3341	Euphorbia pulcherrima Pepita Early Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
201	4501	Euphorbia pulcherrima Q-ismas Bond	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
202	3473	Euphorbia pulcherrima Q-ismas Qs-006	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
203	3479	Euphorbia pulcherrima Q-ismas Qs-082	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
204	3472	Euphorbia pulcherrima Q-ismas Qs-104	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
205	3474	Euphorbia pulcherrima Q-ismas Qs-113	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
206	3475	Euphorbia pulcherrima Q-ismas Qs-114	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
207	3476	Euphorbia pulcherrima Q-ismas Qs-126	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
208	3477	Euphorbia pulcherrima Q-ismas Qs-127	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
209	3478	Euphorbia pulcherrima Q-ismas Qs-133	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
210	3343	Euphorbia pulcherrima Q-ismas QS-3	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
211	3345	Euphorbia pulcherrima Q-ismas QS-44 (Light Red)	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
212	3339	Euphorbia pulcherrima Q-ismas QS-59	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
213	3344	Euphorbia pulcherrima Q-ismas QS-71	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
214	111	Euphorbia pulcherrima Ranch Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
215	296	Euphorbia SP Acrurensis	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
216	1203	Euphorbia SP Eritrea	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
217	299	Euphorbia trigona Green	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
218	1204	Euphorbia trigona Red	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
219	156	Euryops pectinatus Bush Daisy Yellow	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
220	192	Evolvulus nuttallianus Blue Daze	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
221	1225	Ficus microcarpa Ginseng (100)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
222	1226	Ficus microcarpa Ginseng (250)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
223	301	Ficus microcarpa Ginseng (50)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
224	3440	Ficus microcarpa Ginseng (500)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
225	3424	Foliage SP Assortment	Maybelle Flores	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
226	1220	Gasteria SP Hybrid	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
227	167	Gaura lindheimeri Belleza Dark Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
228	1206	Geogenanthus ciliatus Hard Purple Leaf	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
229	3374	Geogenanthus ciliatus Hard Rainbow	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
230	3373	Geogenanthus ciliatus Rainbow ##	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
231	1244	Geogenanthus poeppigii  Green Stripe	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
232	302	Graptopetalum SP Paraguayensis	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
233	303	Graptosedum SP Alpenglow	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
234	304	Graptosedum SP Bronze	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
235	305	Graptosedum SP California Sunset	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
236	306	Graptosedum SP Darley Sunshine	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
237	307	Graptosedum SP Ghosty	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
238	308	Haworthia attenuata Zebra	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
239	1223	Haworthia retusa White Ghost	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
240	1236	Haworthia SP Black Night	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
241	309	Haworthia SP Concolor	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
242	311	Haworthia SP Fasciata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
243	313	Haworthia SP Limifolia	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
244	312	Haworthia SP Limifolia Variegata	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
245	1238	Haworthia SP Spirit 88	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
246	3325	Haworthia SP Superfasciata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
247	314	Haworthia SP Tessellata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
248	3302	Hibiscus rosa-sinensis H-2006-4294-02	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
249	3296	Hibiscus rosa-sinensis H-2013-5166	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
250	3317	Hibiscus rosa-sinensis H-2016-0150	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
251	3409	Hibiscus rosa-sinensis H-2020-0215-04	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
252	3318	Hibiscus rosa-sinensis HQ-107	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
253	3275	Hibiscus rosa-sinensis HQ-108	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
254	3300	Hibiscus rosa-sinensis HQ-109	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
255	3320	Hibiscus rosa-sinensis HQ-110	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
256	3321	Hibiscus rosa-sinensis HQ-111	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
257	3281	Hibiscus rosa-sinensis HQ-112	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
258	3273	Hibiscus rosa-sinensis HQ-112-1	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
259	3280	Hibiscus rosa-sinensis HQ-113	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
260	3309	Hibiscus rosa-sinensis HQ-114	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
261	3299	Hibiscus rosa-sinensis HQ-115	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
262	3298	Hibiscus rosa-sinensis HQ-116	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
263	3286	Hibiscus rosa-sinensis HQ-117	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
264	3315	Hibiscus rosa-sinensis HQ-118	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
265	3310	Hibiscus rosa-sinensis HQ-119	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
266	3311	Hibiscus rosa-sinensis HQ-120	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
267	3312	Hibiscus rosa-sinensis HQ-121	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
268	3278	Hibiscus rosa-sinensis HQ-122	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
269	3292	Hibiscus rosa-sinensis HQ-123	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
270	3354	Hibiscus rosa-sinensis HQ-124	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
271	3291	Hibiscus rosa-sinensis HQ-125	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
272	3282	Hibiscus rosa-sinensis HQ-126	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
273	3290	Hibiscus rosa-sinensis HQ-127	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
274	3313	Hibiscus rosa-sinensis HQ-128	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
275	3274	Hibiscus rosa-sinensis HQ-129	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
276	3322	Hibiscus rosa-sinensis HQ-130	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
277	3284	Hibiscus rosa-sinensis HQ-131	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
278	3324	Hibiscus rosa-sinensis HQ-132	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
279	3288	Hibiscus rosa-sinensis HQ-133	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
280	3301	Hibiscus rosa-sinensis HQ-134	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
281	3316	Hibiscus rosa-sinensis HQ-135	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
282	3276	Hibiscus rosa-sinensis HQ-136	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
283	3277	Hibiscus rosa-sinensis HQ-137	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
284	3287	Hibiscus rosa-sinensis HQ-138	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
285	3308	Hibiscus rosa-sinensis HQ-200	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
286	3293	Hibiscus rosa-sinensis HQ-209	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
287	3355	Hibiscus rosa-sinensis HQ-215	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
288	3295	Hibiscus rosa-sinensis HQ-224	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
289	3353	Hibiscus rosa-sinensis HQ-226	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
290	3294	Hibiscus rosa-sinensis HQ-232	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
291	3304	Hibiscus rosa-sinensis HQ-238	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
292	3314	Hibiscus rosa-sinensis HQ-245	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
293	3411	Hibiscus rosa-sinensis HQ-248 + HQ-201	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
294	3319	Hibiscus rosa-sinensis HQ-249 + HQ-241	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
295	3271	Hibiscus rosa-sinensis HQ-250 + HQ-211	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
296	3279	Hibiscus rosa-sinensis HQ-254	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
297	3303	Hibiscus rosa-sinensis HQ-259	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
298	3283	Hibiscus rosa-sinensis HQ-260	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
299	3323	Hibiscus rosa-sinensis HQ-271	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
300	3285	Hibiscus rosa-sinensis HQ-272	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
301	3289	Hibiscus rosa-sinensis HQ-275	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
302	3297	Hibiscus rosa-sinensis HQ-276	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
303	3272	Hibiscus rosa-sinensis HQ-300	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
304	3436	Hibiscus rosa-sinensis HQ-314	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
305	3410	Hibiscus rosa-sinensis HQ-315	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
306	3407	Hibiscus rosa-sinensis HQ-316	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
307	3431	Hibiscus rosa-sinensis HQ-317	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
308	3412	Hibiscus rosa-sinensis HQ-318	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
309	3432	Hibiscus rosa-sinensis HQ-319	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
310	3426	Hibiscus rosa-sinensis HQ-320	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
311	3427	Hibiscus rosa-sinensis HQ-321	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
312	3408	Hibiscus rosa-sinensis HQ-322	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
313	3421	Hibiscus rosa-sinensis HQ-323	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
314	3422	Hibiscus rosa-sinensis HQ-324	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
315	3428	Hibiscus rosa-sinensis HQ-325	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
316	3433	Hibiscus rosa-sinensis HQ-326	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
317	3413	Hibiscus rosa-sinensis HQ-327	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
318	3414	Hibiscus rosa-sinensis HQ-328	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
319	3430	Hibiscus rosa-sinensis HQ-329	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
320	3434	Hibiscus rosa-sinensis HQ-330	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
321	3435	Hibiscus rosa-sinensis HQ-331	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
322	3405	Hibiscus rosa-sinensis HQ-334	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
323	3406	Hibiscus rosa-sinensis HQ-335	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
324	3415	Hibiscus rosa-sinensis HQ-336	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
325	3416	Hibiscus rosa-sinensis HQ-337	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
326	3423	Hibiscus rosa-sinensis HQ-338	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
327	3437	Hibiscus rosa-sinensis HQ-339	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
328	3429	Hibiscus rosa-sinensis HQ-340	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
329	3417	Hibiscus rosa-sinensis HQ-341	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
330	3418	Hibiscus rosa-sinensis HQ-343	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
331	3425	Hibiscus rosa-sinensis HQ-344	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
332	3419	Hibiscus rosa-sinensis HQ-345	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
333	3420	Hibiscus rosa-sinensis HQ-346	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
334	3380	Hibiscus rosa-sinensis Medusa Golden	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
335	300	Hibiscus rosa-sinensis Multi Tropic Red (Beach Ball Red)	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
336	3351	Hibiscus rosa-sinensis Rhea	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
337	3438	Hibiscus SP Assortment	Maybelle Flores	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
338	140	Hypericum inodorum Miracle Grandeur	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
339	318	Ixora coccinea Maui Multicolor	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
340	317	Ixora coccinea Maui Red	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
341	3384	Ixora coccinea Maui Yellow	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
342	315	Ixora coccinea Taiwanese Dwarf Red	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
343	316	Ixora coccinea Taiwanese Dwarf Yellow	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
344	3489	Kalanchoe daigremontiana Pink Butterfly	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
345	1239	Kalanchoe fedtschenkoi  Compacta	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
346	2259	Kalanchoe fedtschenkoi  Red Scallop	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
347	215	Kalanchoe laciniata Variegata	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
348	319	Kalanchoe SP Blossfeldiana	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
349	320	Kalanchoe SP Humilis	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
350	321	Kalanchoe SP Krinkle Red	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
351	322	Kalanchoe SP Laciniata ##	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
352	323	Kalanchoe SP Marmorata	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
353	324	Kalanchoe SP Marnieriana	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
354	325	Kalanchoe SP Synsepala	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
355	2252	Kalanchoe SP Thyrsiflora	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
356	326	Kalanchoe tomentosa Chocolate Soldier	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
357	160	Lantana camara Bandana Bandana Cherry	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
358	161	Lantana camara Bandana Cherry Sunrise	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
359	1153	Lantana camara Bandana Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
360	1159	Lantana camara Bandana Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
361	1164	Lantana camara Bandana Rose	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
362	3460	Lantana camara Bandana White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
363	151	Lantana camara Bandito Orange Sunrise	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
364	1160	Lantana camara Bandito Red	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
365	1165	Lantana camara Bandito Rose	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
366	1175	Lantana camara Bandolero Cherry Sunrise	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
367	122	Lantana camara Bandolero Guava	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
368	153	Lantana camara Bandolero Pineapple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
369	1161	Lantana camara Bandolero Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
370	1170	Lantana camara Bandolero White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
371	135	Lantana camara Bloomify Mango	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
372	1162	Lantana camara Bloomify Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
373	115	Lantana camara Bloomify Rose	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
374	1150	Lantana camara Lavender	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
375	145	Lantana camara New Gold	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
376	148	Lantana camara Orange	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
377	1171	Lantana camara White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
378	1219	Liriope muscari Big Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
379	3443	Liriope SP Silvery Sunproof	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
380	185	Lithodora diffusa Grace Ward	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
381	184	Lysimachia nummularia Goldilocks	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
382	182	Lysimachia procumbens Golden Globes	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
383	327	Mammillaria elongata Anguinea	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
384	328	Mammillaria elongata Lemon	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
385	329	Mammillaria elongata Rubrispina	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
386	1250	Mandevilla madinia Rio Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
387	3375	Mandevilla madinia Rio White	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
388	1252	Mandevilla madinia Velvet Red	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
389	1251	Mandevilla madinia White	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
390	4514	Mandevilla Sanderii Luna	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
391	1258	Mandevilla Sanderii MD17-4056	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
392	3352	Mandevilla SP Assortment	Maybelle Flores	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
393	4499	Mandevilla splendens Bella Magma	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
394	4497	Mandevilla splendens Bella Compacta Red	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
395	121	Mandevilla splendens Bella Grande Pink	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
396	125	Mandevilla splendens Bella Hot Pink	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
397	146	Mandevilla splendens Bella New White	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
398	104	Mandevilla splendens Bella Pink Panther	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
399	119	Mandevilla splendens Bella Pink Star	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
400	175	Mandevilla splendens Bella Red Bolero	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
401	197	Mandevilla splendens Bella Scarlet	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
402	1257	Mandevilla splendens Bella Tropical Sunrise	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
403	4498	Mandevilla splendens Bella White	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
404	218	Mandevilla splendens Costa Del Sol Marbella Rose	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
405	102	Mandevilla splendens Pink Jewel	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
406	4524	Mandevilla splendens Q-deville M24-07	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
407	1254	Mandevilla splendens Q-deville Ainia QD2	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
408	3454	Mandevilla splendens Q-deville Doris	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
409	3457	Mandevilla splendens Q-deville Lilo	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
410	4535	Mandevilla splendens Q-deville M24-01	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
411	4534	Mandevilla splendens Q-deville M24-02	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
412	4533	Mandevilla splendens Q-deville M24-03	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
413	4532	Mandevilla splendens Q-deville M24-04	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
414	4531	Mandevilla splendens Q-deville M24-05	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
415	4525	Mandevilla splendens Q-deville M24-06	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
416	4523	Mandevilla splendens Q-deville M24-08	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
417	4522	Mandevilla splendens Q-deville M24-09	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
418	4521	Mandevilla splendens Q-deville M24-10	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
419	4520	Mandevilla splendens Q-deville M24-11	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
420	3455	Mandevilla splendens Q-deville Merida	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
421	4529	Mandevilla splendens Q-deville QD-197	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
422	4528	Mandevilla splendens Q-deville QD-198	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
423	4527	Mandevilla splendens Q-deville QD-201	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
424	4526	Mandevilla splendens Q-deville QD-203	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
425	3495	Mandevilla splendens Q-deville QD032	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
426	3493	Mandevilla splendens Q-deville QD049	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
427	3470	Mandevilla splendens Q-deville QD114	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
428	3469	Mandevilla splendens Q-deville QD116	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
429	3458	Mandevilla splendens Q-deville QD145	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
430	3456	Mandevilla splendens Q-deville QD149	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
431	3492	Mandevilla splendens Q-deville QD154	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
432	310	Mandevilla splendens Q-deville QD171	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
433	1255	Mandevilla splendens Q-deville QD20	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
434	1256	Mandevilla splendens Q-deville QD22	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
435	3494	Mandevilla splendens Q-deville QD27	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
436	4503	Mandevilla splendens Q-deville QD271	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
437	1253	Mandevilla splendens Q-deville QD34	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
438	1202	Mandevilla splendens Terra viva Rose Queen	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
439	1260	Mandevilla splendens Terra viva Solar Noon	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
440	1259	Mandevilla splendens Terra viva Sunset Glow (MD599 Orange)	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
441	4502	Mandevilla splendens Terra viva TMVD	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
442	3497	Mandevilla splendens Terra viva TVMD	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
443	4511	Mandevilla splendens Terra viva TVMD 1073	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
444	4507	Mandevilla splendens Terra viva TVMD 1111	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
445	4508	Mandevilla splendens Terra viva TVMD 1670	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
446	4512	Mandevilla splendens Terra viva TVMD 1671	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
447	4509	Mandevilla splendens Terra viva TVMD 1673	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
448	4510	Mandevilla splendens Terra viva TVMD 1697	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
449	4513	Mandevilla splendens Terra viva TVMD 984	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
450	4496	Mandevilla splendens Terra viva TVMD-1073	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
451	3501	Mandevilla splendens Terra viva TVMD-1653	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
452	4492	Mandevilla splendens Terra viva TVMD-1670	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
453	4493	Mandevilla splendens Terra viva TVMD-1671	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
454	3498	Mandevilla splendens Terra viva TVMD-1688	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
455	4494	Mandevilla splendens Terra viva TVMD-1693	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
456	3499	Mandevilla splendens Terra viva TVMD-1697	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
457	3496	Mandevilla splendens Terra viva TVMD-1719	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
458	3500	Mandevilla splendens Terra viva TVMD-599	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
459	4495	Mandevilla splendens Terra viva TVMD-736	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
460	169	Mandevilla splendens Terra viva TVMD-938	Maybelle Flores	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
461	1190	Mazus reptans Reptans	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
462	3356	Monstera epipremnoide Esqueleto	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
463	4506	Monstera lechleriana  Variegata	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
465	3346	Monstera SP Sabana	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
466	3388	Monstera stendleyana Cobra	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
467	1152	Muehlenbeckia axillaris Nana	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
468	1232	Neoregelia SP Bob and Grace	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
469	1233	Neoregelia SP Cane Fire	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
470	3484	Neoregelia SP Carolinae	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
471	2251	Neoregelia SP Donna	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
472	330	Neoregelia SP Hybrid #23	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
473	1231	Neoregelia SP Hybrid #25	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
474	331	Neoregelia SP Kahala Down	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
475	1177	Neoregelia SP Pimento	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
476	1235	Neoregelia SP Raphael	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
477	1229	Neoregelia SP Tricolor	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
478	1230	Neoregelia SP Wolfgang	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
479	1218	Ophiopogon japonicus Dwarf Mondo	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
480	1217	Ophiopogon japonicus Mondo	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
481	1191	Pachysandra SP Terminalis	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
482	96	Penta lanceolata Falling Star Pink Bicolor	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
483	113	Penta lanceolata Starcluster Red Improved	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
484	1166	Penta lanceolata Starcluster Rose	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
485	209	Penta lanceolata Starcluster White	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
486	1245	Peperomia albovittata Rana Verde	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
487	333	Peperomia argyreia Watermelon	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
488	332	Peperomia caperata Red luna	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
489	1247	Peperomia SP Fraserii	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
490	1198	Peperomia SP Rubella	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
491	2255	Philodendron cordatum SP Cordatum ##	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
492	335	Philodendron hederaceum Brazil	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
493	334	Philodendron SP Cordatum	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
494	2250	Philodendron SP Golden Violin	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
495	2256	Philodendron SP Painted Laidy	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
496	4536	Philodendron SP Silver	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
497	3386	Philodendron SP Silver Sword	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
498	337	Philodendron squamiferum Hairy Red	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
499	336	Philodendron xanadu Golden Goddess	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
500	193	Phlox divaricata Blue Moon	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
501	159	Phlox divaricata Chattahoochee	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
502	139	Phlox divaricata May Breeze	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
503	1151	Phlox paniculata Famous Light Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
504	98	Phlox paniculata Famous Pink Dark Eye	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
505	1156	Phlox paniculata Famous Purple ##	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
506	107	Phlox paniculata Famous Purple Improved	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
507	1172	Phlox paniculata Famous White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
508	211	Phlox paniculata Famous White Eye	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
509	130	Phlox paniculata Laura	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
510	147	Phlox paniculata Nicky	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
511	106	Phlox subulata Purple Beauty	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
512	114	Phlox subulata Red Wings	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
513	3402	Phoenix Roebelenii Palm	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
514	3378	Plectranthus scutellarioides Flame Thrower Adobo Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
515	162	Plectranthus scutellarioides Flame Thrower Chilli Pepper	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
516	163	Plectranthus scutellarioides Flame Thrower Chipotle	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
517	123	Plectranthus scutellarioides Flame Thrower Habanero	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
518	195	Plectranthus scutellarioides Flame Thrower Salsa Verde	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
519	204	Plectranthus scutellarioides Flame Thrower Spiced Curry	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
520	155	Plectranthus x hybrida Burgundy Wedding Train	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
521	127	Plumbago auriculata Imperial Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
522	131	Portulaca oleracea Colorblast Lemon Twist	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
523	133	Portulaca oleracea Colorblast Mandarin	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
524	136	Portulaca oleracea Colorblast Mango Mojito	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
525	116	Portulaca oleracea Pazzaz Grenadine	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
526	117	Portulaca oleracea Pazzaz Limon	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
527	101	Portulaca oleracea Pazzaz Pink Glow	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
528	112	Portulaca oleracea Pazzaz Red Flare	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
529	103	Portulaca oleracea Pink Lady	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
530	338	Portulacaria afra Green (Mini)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
531	1227	Portulacaria afra Green (Small)	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
532	1196	Portulacaria afra Pink	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
533	1197	Portulacaria afra Variegata	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
534	1195	Portulacaria jade Mini	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
535	186	Pseuderanthemum laxiflorum Amethyst Star	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
536	339	Rhaphidophora korthalsii Shingle Plant	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
537	2249	Rhaphidophora SP Cryptantha	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
538	1205	Rhaphidophora tetrasperma Mini Monstera	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
539	3459	Rosmarinus officinalis Rosemary barbecue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
540	206	Rosmarinus officinalis Tuscan Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
541	1154	Ruellia brittoniana Mayan Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
542	105	Ruellia brittoniana Mayan Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
543	1158	Ruellia brittoniana Mayan Purple Showers	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
544	1173	Ruellia brittoniana Mayan White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
545	109	Ruellia SP Brittonia ##	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
546	1189	Sagina SP Subulata	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
547	188	Sagina SP Subulata Aurea	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
548	3487	Salvia farinacea Farina Bicolor Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
549	137	Salvia farinacea Farina Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
550	259	Salvia farinacea Farina Violet	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
551	3362	Salvia farinacea Farina White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
552	189	Salvia farinacea Sallyfun Bicolor Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
553	170	Salvia farinacea Sallyfun Deep Ocean	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
554	3442	Salvia farinacea Sallyfun Pure White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
555	1168	Salvia farinacea Sallyfun Sky Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
556	203	Salvia farinacea Sallyfun Snowhite	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
557	158	Salvia nemorosa Cardonna	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
558	172	Salvia nemorosa East Friesland	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
559	1188	Sanchezia SP Nobilis	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
560	3397	Sansevieria trifasciata Laurentii	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
561	3398	Sansevieria trifasciata Superba	Tony Moriña	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
562	157	Scabiosa columbaria Butterfly Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
563	194	Scaevola hybrid Surdiva Blue Violet	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
564	173	Scaevola hybrid Surdiva Fashion Pink	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
565	202	Scaevola hybrid Surdiva Sky Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
566	1174	Scaevola hybrid Surdiva White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
567	340	Schefflera arboricola Verde	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
568	341	Scilla SP Violacea	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
569	3439	Scindapsus pictus Mount Salak	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
570	3392	Scindapsus pictus Platinum Java	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
571	342	Scindapsus pictus Sterling Silver	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
572	3265	Sedum hybrida Lemon Ball 2 ##	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
573	1186	Sedum kamtschaticum Weihenstephaner Gold	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
574	1179	Sedum rupestre Lemon Ball	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
575	1192	Sedum SP Adolphii	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
576	1185	Sedum SP Blue Spruce	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
577	1194	Sedum SP Nussbaumerianum	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
578	1193	Sedum SP Reflexum	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
579	3390	Sedum spurium Carnicolor	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
580	1184	Sedum spurium Fuldaglut	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
581	1178	Sedum spurium John Creech	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
582	1181	Sedum tetractinum Coral Reef	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
583	1182	Sedum x hybrida Sunsparkler Dazzleberry	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
584	1183	Sedum x hybrida Sunsparkler Firecracker	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
585	1180	Sedum x hybrida Sunsparkler Lime Zinger	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
586	348	Senecio barbertonicus Himalaya	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
587	3347	Senecio peregrinus String of Dolphin	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
588	4516	Senecio peregrinus String of Dolphin CC	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
589	3490	Senecio radicans String of Bananas	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
590	3491	Senecio rowleyanus String of Pearls	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
591	350	Senecio serpens Blue ##	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
592	2257	Senecio serpens Blue Kleinia	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
593	349	Senecio SP Crassissimus	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
594	351	Senecio SP Stapeliformis	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
595	352	Senecio SP Vitalis	Juan D. Hernández	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
596	3465	Serissa foetida Thousand Stars	Karen Orozco	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
597	108	Setcreasea pallida Purple Queen	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
598	152	Strobilanthes dyeriana Persian Shield	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
599	212	Thymus lanuginosus Wolly	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
600	165	Thymus praecox Coccineus	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
601	97	Thymus serpyllum Pink Chintz	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
602	200	Thymus vulgaris Silver Edge	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
603	187	Trachelospermum asiaticum Asian Jasmine	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
604	353	Tradescantia bermudensis Rhoeo Variegata	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
605	2253	Tradescantia spathacea Roxxo	Karen Orozco	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
606	3444	Tradescantia zebrina Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
607	132	Verbena bonariensis Lollipop	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
608	124	Verbena canadensis Homestead Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
609	168	Verbena peruviana Endurascape Dark Purple	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
610	1176	Verbena peruviana Endurascape Magenta	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
611	1155	Verbena peruviana Endurascape Pink Bicolor	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
612	1157	Verbena peruviana Endurascape Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
613	1163	Verbena peruviana Endurascape Red	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
614	3379	Verbena peruviana Endurascape White	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
615	210	Verbena peruviana Endurascape White Blush	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
616	1169	Veronica longifolia Sunny Border Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
617	191	Veronica longifolia Vernique Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
618	166	Veronica longifolia Vernique Dark Blue	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
619	1167	Veronica longifolia Vernique Rose	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
620	128	Veronica spicata Inspire Blue	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
621	134	Vinca hybrid Little Blaze Magenta	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
622	100	Vinca hybrid Little Blaze Pink Eye	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
623	86	Vinca roseus Soiree Kawaii Blueberry Kiss	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
624	87	Vinca roseus Soiree Kawaii Coral	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
625	93	Vinca roseus Soiree Kawaii Coral Reef	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
626	88	Vinca roseus Soiree Kawaii Lavender	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
627	89	Vinca roseus Soiree Kawaii Light Purple	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
628	90	Vinca roseus Soiree Kawaii Pale Lavender	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
629	91	Vinca roseus Soiree Kawaii Pink	Stefano Albertazzi Barahona	0	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
630	92	Vinca roseus Soiree Kawaii Red Shades	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
631	94	Vinca roseus Soiree Kawaii White Peppermint	Stefano Albertazzi Barahona	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
632	3266	Vriesea carinata Christiane	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
633	3267	Vriesea carinata Dorado	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
634	3268	Vriesea carinata Evita	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
635	3269	Vriesea carinata Tosca	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
636	3449	Vriesea SP Arden	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
637	3447	Vriesea SP Cathy	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
638	3450	Vriesea SP Davine	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
639	3448	Vriesea SP Draco	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
640	3441	Vriesea SP Harmony	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
641	3452	Vriesea SP Intenso Peach	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
642	4500	Vriesea SP Intenso Red	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
643	3451	Vriesea SP Intenso Yellow	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
644	3445	Vriesea SP Salmon	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
645	3453	Vriesea SP Splenriet	Juan D. Hernández	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
646	4519	Zamioculca Zamiifolia  Black Leaf TV	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
647	4541	Zamioculca Zamiifolia  Black Leaf TV (P4)	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
648	354	Zamioculca Zamiifolia Black Leaf Raven	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
649	3486	Zamioculca Zamiifolia Black Raven Leaf (P4)	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
650	355	Zamioculca Zamiifolia Camaleon	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
651	4515	Zamioculca Zamiifolia Camaleon Leaf (P4)	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
652	1234	Zamioculca Zamiifolia Green Leaf	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
653	3485	Zamioculca Zamiifolia Green Leaf (P4)	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	\N	2025-03-26 17:04:01.912278
655	3464	Zelkova parvifolia Orme	Karen Orozco	1	1	2025-03-26 17:04:01.912278	1	2025-04-27 18:43:01.324866
654	3348	Zamioculca Zamiifolia Variegata	Jairo Gonzalez	1	1	2025-03-26 17:04:01.912278	1	2025-04-13 13:05:31.545697
656	9090	Esto es una Prueba	Ninguno	0	1	2025-04-27 18:46:19.28365	1	2025-04-27 18:47:13.037935
\.


--
-- Name: pm_lotes_pmlt_secuencia_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_lotes_pmlt_secuencia_seq', 1438, true);


--
-- Name: pm_monitoreos_pmmo_secuencia_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_monitoreos_pmmo_secuencia_seq', 110, true);


--
-- Name: pm_nivelesinfectacion_pmni_secuencia_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_nivelesinfectacion_pmni_secuencia_seq', 27, true);


--
-- Name: pm_plagas_pmpl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_plagas_pmpl_id_seq', 34, true);


--
-- Name: pm_potes_pmpo_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_potes_pmpo_id_seq', 3, true);


--
-- Name: pm_rol_pmrl_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_rol_pmrl_id_seq', 5, true);


--
-- Name: pm_unidadescultivo_pmuc_secuencia_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_unidadescultivo_pmuc_secuencia_seq', 123, true);


--
-- Name: pm_usuarios_pmus_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_usuarios_pmus_id_seq', 8, true);


--
-- Name: pm_variedades_pmva_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pestuser
--

SELECT pg_catalog.setval('public.pm_variedades_pmva_id_seq', 656, true);


--
-- Name: pm_lotes pm_lotes_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_lotes
    ADD CONSTRAINT pm_lotes_pkey PRIMARY KEY (pmlt_secuencia);


--
-- Name: pm_monitoreos pm_monitoreos_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_monitoreos
    ADD CONSTRAINT pm_monitoreos_pkey PRIMARY KEY (pmmo_secuencia);


--
-- Name: pm_nivelesinfestacion pm_nivelesinfectacion_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_nivelesinfestacion
    ADD CONSTRAINT pm_nivelesinfectacion_pkey PRIMARY KEY (pmni_secuencia);


--
-- Name: pm_plagas pm_plagas_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_plagas
    ADD CONSTRAINT pm_plagas_pkey PRIMARY KEY (pmpl_id);


--
-- Name: pm_potes pm_potes_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_potes
    ADD CONSTRAINT pm_potes_pkey PRIMARY KEY (pmpo_id);


--
-- Name: pm_potes pm_potes_pmpo_codigo_key; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_potes
    ADD CONSTRAINT pm_potes_pmpo_codigo_key UNIQUE (pmpo_codigo);


--
-- Name: pm_rol pm_rol_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_rol
    ADD CONSTRAINT pm_rol_pkey PRIMARY KEY (pmrl_id);


--
-- Name: pm_unidadescultivo pm_unidadescultivo_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_unidadescultivo
    ADD CONSTRAINT pm_unidadescultivo_pkey PRIMARY KEY (pmuc_secuencia);


--
-- Name: pm_usuarios pm_usuarios_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_usuarios
    ADD CONSTRAINT pm_usuarios_pkey PRIMARY KEY (pmus_id);


--
-- Name: pm_variedades pm_variedades_pkey; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_variedades
    ADD CONSTRAINT pm_variedades_pkey PRIMARY KEY (pmva_id);


--
-- Name: pm_variedades pm_variedades_pmva_codigo_key; Type: CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_variedades
    ADD CONSTRAINT pm_variedades_pmva_codigo_key UNIQUE (pmva_codigo);


--
-- Name: pm_nivelesinfestacion tr_mantener_consistencia_plagas; Type: TRIGGER; Schema: public; Owner: pestuser
--

CREATE TRIGGER tr_mantener_consistencia_plagas BEFORE INSERT OR UPDATE ON public.pm_nivelesinfestacion FOR EACH ROW EXECUTE FUNCTION public.trigger_consistencia_plagas();


--
-- Name: pm_lotes pm_lotes_pmlt_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_lotes
    ADD CONSTRAINT pm_lotes_pmlt_creadopor_fkey FOREIGN KEY (pmlt_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_lotes pm_lotes_pmlt_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_lotes
    ADD CONSTRAINT pm_lotes_pmlt_modificadopor_fkey FOREIGN KEY (pmlt_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_monitoreos pm_monitoreos_pmmo_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_monitoreos
    ADD CONSTRAINT pm_monitoreos_pmmo_creadopor_fkey FOREIGN KEY (pmmo_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_monitoreos pm_monitoreos_pmmo_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_monitoreos
    ADD CONSTRAINT pm_monitoreos_pmmo_modificadopor_fkey FOREIGN KEY (pmmo_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_nivelesinfestacion pm_nivelesinfectacion_pmni_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_nivelesinfestacion
    ADD CONSTRAINT pm_nivelesinfectacion_pmni_creadopor_fkey FOREIGN KEY (pmni_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_nivelesinfestacion pm_nivelesinfectacion_pmni_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_nivelesinfestacion
    ADD CONSTRAINT pm_nivelesinfectacion_pmni_modificadopor_fkey FOREIGN KEY (pmni_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_nivelesinfestacion pm_nivelesinfectacion_pmni_plaga_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_nivelesinfestacion
    ADD CONSTRAINT pm_nivelesinfectacion_pmni_plaga_fkey FOREIGN KEY (pmni_plaga) REFERENCES public.pm_plagas(pmpl_id) ON DELETE CASCADE;


--
-- Name: pm_plagas pm_plagas_pmpl_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_plagas
    ADD CONSTRAINT pm_plagas_pmpl_creadopor_fkey FOREIGN KEY (pmpl_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_plagas pm_plagas_pmpl_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_plagas
    ADD CONSTRAINT pm_plagas_pmpl_modificadopor_fkey FOREIGN KEY (pmpl_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_potes pm_potes_pmpo_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_potes
    ADD CONSTRAINT pm_potes_pmpo_creadopor_fkey FOREIGN KEY (pmpo_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_potes pm_potes_pmpo_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_potes
    ADD CONSTRAINT pm_potes_pmpo_modificadopor_fkey FOREIGN KEY (pmpo_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_unidadescultivo pm_unidadescultivo_pmuc_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_unidadescultivo
    ADD CONSTRAINT pm_unidadescultivo_pmuc_creadopor_fkey FOREIGN KEY (pmuc_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_unidadescultivo pm_unidadescultivo_pmuc_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_unidadescultivo
    ADD CONSTRAINT pm_unidadescultivo_pmuc_modificadopor_fkey FOREIGN KEY (pmuc_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_usuarios pm_usuarios_pmus_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_usuarios
    ADD CONSTRAINT pm_usuarios_pmus_creadopor_fkey FOREIGN KEY (pmus_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_usuarios pm_usuarios_pmus_funcion_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_usuarios
    ADD CONSTRAINT pm_usuarios_pmus_funcion_fkey FOREIGN KEY (pmus_funcion) REFERENCES public.pm_rol(pmrl_id) ON DELETE SET NULL;


--
-- Name: pm_usuarios pm_usuarios_pmus_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_usuarios
    ADD CONSTRAINT pm_usuarios_pmus_modificadopor_fkey FOREIGN KEY (pmus_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_variedades pm_variedades_pmva_creadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_variedades
    ADD CONSTRAINT pm_variedades_pmva_creadopor_fkey FOREIGN KEY (pmva_creadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: pm_variedades pm_variedades_pmva_modificadopor_fkey; Type: FK CONSTRAINT; Schema: public; Owner: pestuser
--

ALTER TABLE ONLY public.pm_variedades
    ADD CONSTRAINT pm_variedades_pmva_modificadopor_fkey FOREIGN KEY (pmva_modificadopor) REFERENCES public.pm_usuarios(pmus_id) ON DELETE SET NULL;


--
-- Name: SCHEMA public; Type: ACL; Schema: -; Owner: pestuser
--

REVOKE USAGE ON SCHEMA public FROM PUBLIC;
GRANT ALL ON SCHEMA public TO PUBLIC;


--
-- PostgreSQL database dump complete
--
