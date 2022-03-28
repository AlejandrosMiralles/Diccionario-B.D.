--
-- PostgreSQL database dump
--

-- Dumped from database version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.9 (Ubuntu 12.9-0ubuntu0.20.04.1)

-- Started on 2022-03-18 12:18:07 CET

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- TOC entry 3 (class 2615 OID 2200)
-- Name: public; Type: SCHEMA; Schema: -; Owner: postgres
--

CREATE SCHEMA public;


ALTER SCHEMA public OWNER TO postgres;

--
-- TOC entry 3113 (class 0 OID 0)
-- Dependencies: 3
-- Name: SCHEMA public; Type: COMMENT; Schema: -; Owner: postgres
--

COMMENT ON SCHEMA public IS 'standard public schema';


--
-- TOC entry 228 (class 1255 OID 16568)
-- Name: buscar_antonimos(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.buscar_antonimos(character varying) RETURNS TABLE(palabra_seleccionada character varying, antonimo character varying)
    LANGUAGE plpgsql
    AS $_$
begin
    return query select $1, p.palabra
        from palabra p, antonimia a, significa s, (select s.idsignificado as definicion from palabra p , significa s
                                            where lower($1)=lower(p.palabra) and p.id = s.idpalabra)
                                        as significadoPalabras
            where a.idsignificado1 = significadoPalabras.definicion and a.idsignificado2 = s.idsignificado
                                and s.idpalabra = p.id
    ;
end; $_$;


ALTER FUNCTION public.buscar_antonimos(character varying) OWNER TO diccionario;

--
-- TOC entry 229 (class 1255 OID 16570)
-- Name: buscar_palabras_por_lugar(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.buscar_palabras_por_lugar(character varying) RETURNS TABLE(lugar_seleccionado character varying, palabra_usada character varying)
    LANGUAGE plpgsql
    AS $_$
begin
    return query select $1, p.palabra from palabra p, se_usa_en s,
                                (select l.id from lugar l,
                                            (select l2.id from lugar l2
                                                    where l2.nombre = $1) as lugarPalabra
                                    where x_esta_dentro_de_y(lugarPalabra.id, l.id)
                                ) as lugaresValidos
            where lugaresValidos.id= s.idlugar and s.idpalabra = p.id;
end; $_$;


ALTER FUNCTION public.buscar_palabras_por_lugar(character varying) OWNER TO diccionario;

--
-- TOC entry 237 (class 1255 OID 16569)
-- Name: buscar_palabras_similares(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.buscar_palabras_similares(character varying) RETURNS TABLE(palabra_seleccionada character varying, palabra_similar character varying)
    LANGUAGE plpgsql
    AS $_$
begin
    return query select $1, p.palabra from palabra p,  (
            select s.idpalabra as palabrasimilar from significa s, trata_sobre t, etiqueta e, (
                    select t2.idetiqueta as etiquet from palabra p2, significa s2, trata_sobre t2
                            where lower(p2.palabra) = lower($1) and p2.id = s2.idpalabra and s2.idsignificado = t2.idsignificado
                    ) as etiquetasDeLaPalabra
                where s.idsignificado  = t.idsignificado and t.idetiqueta = etiquetasDeLaPalabra.etiquet
                        and e.id = t.idetiqueta
                group by s.idpalabra having sum(coalesce(e.valor, 0)) >= 5
    ) as palabrassimilares
        where p.id = palabrassimilares.palabrasimilar and not lower(p.palabra) = lower($1);
end; $_$;


ALTER FUNCTION public.buscar_palabras_similares(character varying) OWNER TO diccionario;

--
-- TOC entry 233 (class 1255 OID 16565)
-- Name: buscar_significados(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.buscar_significados(character varying) RETURNS TABLE(palabra_seleccionado character varying, definicion text, ejemplo_uso text)
    LANGUAGE plpgsql
    AS $_$
begin
    return query select $1, s2.significado, s.ejemplo from palabra p , significa s , significado s2
        where lower($1)=lower(p.palabra) and p.id = s.idpalabra and s.idsignificado = s2.id ;
end; $_$;


ALTER FUNCTION public.buscar_significados(character varying) OWNER TO diccionario;

--
-- TOC entry 234 (class 1255 OID 16566)
-- Name: buscar_sinonimos(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.buscar_sinonimos(character varying) RETURNS TABLE(palabra_seleccionada character varying, sinonimo_encontrado character varying)
    LANGUAGE plpgsql
    AS $_$
begin
    return query select $1  as palabra, p.palabra as sinonimo
        from palabra p, significa s, (select s.idsignificado as definicion from palabra p , significa s
                                            where lower($1)=lower(p.palabra) and p.id = s.idpalabra)
                                        as significadoPalabras
            where significadoPalabras.definicion = s.idsignificado and s.idpalabra = p.id and
                        not lower(p.palabra) = lower($1)
    ;
end; $_$;


ALTER FUNCTION public.buscar_sinonimos(character varying) OWNER TO diccionario;

--
-- TOC entry 235 (class 1255 OID 16535)
-- Name: ejemplo_significa_valido(); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.ejemplo_significa_valido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare 
	cur cursor for select palabra from palabra where palabra.id = new.idpalabra;
	palabraEjemplo varchar;
begin
    if (new.ejemplo is null)
        then return new;
    end if;
	open cur;
	fetch cur into palabraEjemplo;
	palabraEjemplo := lower(palabraEjemplo);
    if (lower(new.ejemplo) like '%' || palabraEjemplo || '%')
        then close cur;
    	return new;
    end if;
   	close cur;
   	raise exception 'El ejemplo debe mostrar el uso de la palabra';
end; $$;


ALTER FUNCTION public.ejemplo_significa_valido() OWNER TO diccionario;

--
-- TOC entry 214 (class 1255 OID 16386)
-- Name: esta_dentro_de_valido(); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.esta_dentro_de_valido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
begin
	if ((not new.id=1) and new.esta_dentro_de is null)
		then raise exception 'Esta_dentro_de no puede ser nulo. Pon un lugar válido';
	end if;
	return new;
end; $$;


ALTER FUNCTION public.esta_dentro_de_valido() OWNER TO diccionario;

--
-- TOC entry 231 (class 1255 OID 16572)
-- Name: id_lugar_correspondiente(character varying); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.id_lugar_correspondiente(localizacion character varying) RETURNS bigint
    LANGUAGE plpgsql
    AS $_$
declare
    resultado bigint;
    cur cursor for select l.id from lugar l where l.nombre= $1;
begin
	open cur;
	if (cur is null)
		then return -1;
    end if;
	fetch cur into resultado;
    close cur; 
    return resultado;
end; $_$;


ALTER FUNCTION public.id_lugar_correspondiente(localizacion character varying) OWNER TO diccionario;

--
-- TOC entry 236 (class 1255 OID 16388)
-- Name: ids_inmodificables(); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.ids_inmodificables() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    cur refcursor;
    ultimoID bigint;
begin
    if TG_OP = 'UPDATE'
    	then if (not new.id = old.id)
        	then raise exception 'Los IDS son invariables';
    	end if;
   	end if;
       if tg_table_name = 'lugar'
        then open cur for select tabla.id from lugar tabla order by 1 desc limit 1;
    elsif tg_table_name = 'palabra'
        then open cur for select tabla.id from palabra tabla order by 1 desc limit 1;
    elsif tg_table_name = 'significado'
        then open cur for select tabla.id from significado tabla order by 1 desc limit 1;
    elsif tg_table_name = 'etiqueta'
        then open cur for select tabla.id from etiqueta tabla order by 1 desc limit 1;
    end if;
    fetch cur into ultimoID;
    if TG_OP = 'INSERT'
        then if (not new.id > coalesce(ultimoID, 0))
                then close cur;
                   raise exception 'El id nuevo debe ser el siguiente número al anterior id';
             end if;
    end if;
       close cur;
    return new;
end; $$;


ALTER FUNCTION public.ids_inmodificables() OWNER TO diccionario;

--
-- TOC entry 232 (class 1255 OID 16553)
-- Name: lugar_lugareliminable(); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.lugar_lugareliminable() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare 
	curHijosActuales cursor for select l.esta_dentro_de  from lugar l where old.id=l.esta_dentro_de;
	idSupuestoHijo bigint;
begin
	open curHijosActuales;
	fetch curHijosActuales  into idSupuestoHijo;
    if (idSupuestoHijo is not null)
        then close curHijosActuales; 
        raise exception 'No se puede eliminar dicho lugar porque otros lugares están dentro de él';
    end if;
   	close curHijosActuales;
    return old;
end; $$;


ALTER FUNCTION public.lugar_lugareliminable() OWNER TO diccionario;

--
-- TOC entry 230 (class 1255 OID 16544)
-- Name: modificacion_estadentrode_valido(); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.modificacion_estadentrode_valido() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
declare
    curAntiguaDescendencia cursor for select l2.esta_dentro_de from lugar l2 where l2.esta_dentro_de=old.id;
    supuestoHijoId bigint;
    curHijosActuales cursor for select * from lugar l where new.id = l.esta_dentro_de;
begin
	open curHijosActuales;
	fetch curHijosActuales into supuestoHijoId;
    if ( supuestoHijoId  is null)
        then close curHijosActuales;
       return new;
    end if;
   	close curHijosActuales;
    open curAntiguaDescendencia;
    fetch curAntiguaDescendencia into supuestoHijoId;
    while supuestoHijoId is not null loop
        if (X_esta_dentro_de_Y(new.id, supuestoHijoId))
            then raise exception 'Se ha indicado que el lugar está dentro de un lugar que está dentro del lugar.';
        end if;
        fetch curAntiguaDescendencia into supuestoHijoId;
    end loop;
    close curAntiguaDescendencia;
    return new;
end; $$;


ALTER FUNCTION public.modificacion_estadentrode_valido() OWNER TO diccionario;

--
-- TOC entry 215 (class 1255 OID 16538)
-- Name: x_esta_dentro_de_y(bigint, bigint); Type: FUNCTION; Schema: public; Owner: diccionario
--

CREATE FUNCTION public.x_esta_dentro_de_y(hijo bigint, padre bigint) RETURNS boolean
    LANGUAGE plpgsql
    AS $$
declare
    cur cursor for select l.esta_dentro_de from lugar l where l.id = hijo;
    nuevoHijo bigint;
begin
    if (hijo=padre)
        then return true;
    end if;
       open cur;
       fetch cur into nuevoHijo;
    if (nuevoHijo is null)
        then close cur;
        return false;
    else     
        close cur;
        return X_esta_dentro_de_Y(nuevoHijo, padre);
    end if;
end; $$;


ALTER FUNCTION public.x_esta_dentro_de_y(hijo bigint, padre bigint) OWNER TO diccionario;

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- TOC entry 212 (class 1259 OID 16490)
-- Name: antonimia; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.antonimia (
    idsignificado1 bigint NOT NULL,
    idsignificado2 bigint NOT NULL
);


ALTER TABLE public.antonimia OWNER TO diccionario;

--
-- TOC entry 207 (class 1259 OID 16415)
-- Name: etiqueta; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.etiqueta (
    id integer NOT NULL,
    etiqueta character varying(50) NOT NULL,
    valor smallint,
    CONSTRAINT valor_etiqueta_valido CHECK (((valor >= 0) AND (valor <= 5)))
);


ALTER TABLE public.etiqueta OWNER TO diccionario;

--
-- TOC entry 206 (class 1259 OID 16413)
-- Name: etiqueta_id_seq; Type: SEQUENCE; Schema: public; Owner: diccionario
--

CREATE SEQUENCE public.etiqueta_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.etiqueta_id_seq OWNER TO diccionario;

--
-- TOC entry 3114 (class 0 OID 0)
-- Dependencies: 206
-- Name: etiqueta_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: diccionario
--

ALTER SEQUENCE public.etiqueta_id_seq OWNED BY public.etiqueta.id;


--
-- TOC entry 209 (class 1259 OID 16426)
-- Name: lugar; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.lugar (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    esta_dentro_de bigint
);


ALTER TABLE public.lugar OWNER TO diccionario;

--
-- TOC entry 208 (class 1259 OID 16424)
-- Name: lugar_id_seq; Type: SEQUENCE; Schema: public; Owner: diccionario
--

CREATE SEQUENCE public.lugar_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.lugar_id_seq OWNER TO diccionario;

--
-- TOC entry 3115 (class 0 OID 0)
-- Dependencies: 208
-- Name: lugar_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: diccionario
--

ALTER SEQUENCE public.lugar_id_seq OWNED BY public.lugar.id;


--
-- TOC entry 204 (class 1259 OID 16400)
-- Name: next_id_significado; Type: SEQUENCE; Schema: public; Owner: diccionario
--

CREATE SEQUENCE public.next_id_significado
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.next_id_significado OWNER TO diccionario;

--
-- TOC entry 203 (class 1259 OID 16391)
-- Name: palabra; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.palabra (
    id integer NOT NULL,
    palabra character varying(20) NOT NULL,
    genero character varying(20),
    origen character varying(20),
    CONSTRAINT genero_valido CHECK ((((genero)::text = 'Masculino'::text) OR ((genero)::text = 'Femenino'::text) OR (genero IS NULL)))
);


ALTER TABLE public.palabra OWNER TO diccionario;

--
-- TOC entry 202 (class 1259 OID 16389)
-- Name: palabra_id_seq; Type: SEQUENCE; Schema: public; Owner: diccionario
--

CREATE SEQUENCE public.palabra_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.palabra_id_seq OWNER TO diccionario;

--
-- TOC entry 3116 (class 0 OID 0)
-- Dependencies: 202
-- Name: palabra_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: diccionario
--

ALTER SEQUENCE public.palabra_id_seq OWNED BY public.palabra.id;


--
-- TOC entry 210 (class 1259 OID 16439)
-- Name: se_usa_en; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.se_usa_en (
    idlugar bigint NOT NULL,
    idpalabra bigint NOT NULL
);


ALTER TABLE public.se_usa_en OWNER TO diccionario;

--
-- TOC entry 211 (class 1259 OID 16472)
-- Name: significa; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.significa (
    idpalabra bigint NOT NULL,
    idsignificado bigint NOT NULL,
    ejemplo text
);


ALTER TABLE public.significa OWNER TO diccionario;

--
-- TOC entry 205 (class 1259 OID 16402)
-- Name: significado; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.significado (
    id bigint DEFAULT nextval('public.next_id_significado'::regclass) NOT NULL,
    significado text NOT NULL
);


ALTER TABLE public.significado OWNER TO diccionario;

--
-- TOC entry 213 (class 1259 OID 16510)
-- Name: trata_sobre; Type: TABLE; Schema: public; Owner: diccionario
--

CREATE TABLE public.trata_sobre (
    idsignificado bigint NOT NULL,
    idetiqueta bigint NOT NULL
);


ALTER TABLE public.trata_sobre OWNER TO diccionario;

--
-- TOC entry 2923 (class 2604 OID 16418)
-- Name: etiqueta id; Type: DEFAULT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.etiqueta ALTER COLUMN id SET DEFAULT nextval('public.etiqueta_id_seq'::regclass);


--
-- TOC entry 2925 (class 2604 OID 16429)
-- Name: lugar id; Type: DEFAULT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.lugar ALTER COLUMN id SET DEFAULT nextval('public.lugar_id_seq'::regclass);


--
-- TOC entry 2920 (class 2604 OID 16394)
-- Name: palabra id; Type: DEFAULT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.palabra ALTER COLUMN id SET DEFAULT nextval('public.palabra_id_seq'::regclass);


--
-- TOC entry 3106 (class 0 OID 16490)
-- Dependencies: 212
-- Data for Name: antonimia; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3101 (class 0 OID 16415)
-- Dependencies: 207
-- Data for Name: etiqueta; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3103 (class 0 OID 16426)
-- Dependencies: 209
-- Data for Name: lugar; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3097 (class 0 OID 16391)
-- Dependencies: 203
-- Data for Name: palabra; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3104 (class 0 OID 16439)
-- Dependencies: 210
-- Data for Name: se_usa_en; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3105 (class 0 OID 16472)
-- Dependencies: 211
-- Data for Name: significa; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3099 (class 0 OID 16402)
-- Dependencies: 205
-- Data for Name: significado; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3107 (class 0 OID 16510)
-- Dependencies: 213
-- Data for Name: trata_sobre; Type: TABLE DATA; Schema: public; Owner: diccionario
--



--
-- TOC entry 3117 (class 0 OID 0)
-- Dependencies: 206
-- Name: etiqueta_id_seq; Type: SEQUENCE SET; Schema: public; Owner: diccionario
--

SELECT pg_catalog.setval('public.etiqueta_id_seq', 4, true);


--
-- TOC entry 3118 (class 0 OID 0)
-- Dependencies: 208
-- Name: lugar_id_seq; Type: SEQUENCE SET; Schema: public; Owner: diccionario
--

SELECT pg_catalog.setval('public.lugar_id_seq', 12, true);


--
-- TOC entry 3119 (class 0 OID 0)
-- Dependencies: 204
-- Name: next_id_significado; Type: SEQUENCE SET; Schema: public; Owner: diccionario
--

SELECT pg_catalog.setval('public.next_id_significado', 5, true);


--
-- TOC entry 3120 (class 0 OID 0)
-- Dependencies: 202
-- Name: palabra_id_seq; Type: SEQUENCE SET; Schema: public; Owner: diccionario
--

SELECT pg_catalog.setval('public.palabra_id_seq', 5, true);


--
-- TOC entry 2943 (class 2606 OID 16443)
-- Name: se_usa_en claves_seusaen; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.se_usa_en
    ADD CONSTRAINT claves_seusaen PRIMARY KEY (idlugar, idpalabra);


--
-- TOC entry 2947 (class 2606 OID 16494)
-- Name: antonimia clavesprincipales; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.antonimia
    ADD CONSTRAINT clavesprincipales PRIMARY KEY (idsignificado1, idsignificado2);


--
-- TOC entry 2945 (class 2606 OID 16479)
-- Name: significa clavesprincipales_significa; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.significa
    ADD CONSTRAINT clavesprincipales_significa PRIMARY KEY (idpalabra, idsignificado);


--
-- TOC entry 2935 (class 2606 OID 16423)
-- Name: etiqueta etiqu_unica; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.etiqueta
    ADD CONSTRAINT etiqu_unica UNIQUE (etiqueta);


--
-- TOC entry 2937 (class 2606 OID 16421)
-- Name: etiqueta etiqueta_clave; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.etiqueta
    ADD CONSTRAINT etiqueta_clave PRIMARY KEY (id);


--
-- TOC entry 2939 (class 2606 OID 16433)
-- Name: lugar lug_valido; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.lugar
    ADD CONSTRAINT lug_valido UNIQUE (nombre);


--
-- TOC entry 2941 (class 2606 OID 16431)
-- Name: lugar lugar_clave; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.lugar
    ADD CONSTRAINT lugar_clave PRIMARY KEY (id);


--
-- TOC entry 2927 (class 2606 OID 16399)
-- Name: palabra pal_unica; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.palabra
    ADD CONSTRAINT pal_unica UNIQUE (palabra);


--
-- TOC entry 2929 (class 2606 OID 16397)
-- Name: palabra palabra_clave; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.palabra
    ADD CONSTRAINT palabra_clave PRIMARY KEY (id);


--
-- TOC entry 2931 (class 2606 OID 16410)
-- Name: significado significado_clave; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.significado
    ADD CONSTRAINT significado_clave PRIMARY KEY (id);


--
-- TOC entry 2933 (class 2606 OID 16412)
-- Name: significado significado_valido; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.significado
    ADD CONSTRAINT significado_valido UNIQUE (significado);


--
-- TOC entry 2949 (class 2606 OID 16514)
-- Name: trata_sobre tratasobre_clavesprincipales; Type: CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.trata_sobre
    ADD CONSTRAINT tratasobre_clavesprincipales PRIMARY KEY (idsignificado, idetiqueta);


--
-- TOC entry 2968 (class 2620 OID 16554)
-- Name: lugar lugar_trigger_eliminaciondelugar_valido; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER lugar_trigger_eliminaciondelugar_valido BEFORE DELETE ON public.lugar FOR EACH ROW EXECUTE FUNCTION public.lugar_lugareliminable();


--
-- TOC entry 2967 (class 2620 OID 16545)
-- Name: lugar lugar_trigger_update_estadentrode_valido; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER lugar_trigger_update_estadentrode_valido BEFORE UPDATE ON public.lugar FOR EACH ROW EXECUTE FUNCTION public.modificacion_estadentrode_valido();


--
-- TOC entry 2969 (class 2620 OID 16536)
-- Name: significa significa_ejemplo_invalido; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER significa_ejemplo_invalido BEFORE INSERT OR UPDATE ON public.significa FOR EACH ROW EXECUTE FUNCTION public.ejemplo_significa_valido();


--
-- TOC entry 2964 (class 2620 OID 16525)
-- Name: lugar trigger_esta_dentro_de; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_esta_dentro_de BEFORE INSERT ON public.lugar FOR EACH ROW EXECUTE FUNCTION public.esta_dentro_de_valido();


--
-- TOC entry 2966 (class 2620 OID 16529)
-- Name: lugar trigger_ids_inmodificables; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables BEFORE INSERT OR UPDATE ON public.lugar FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2963 (class 2620 OID 16533)
-- Name: etiqueta trigger_ids_inmodificables_etiqueta; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_etiqueta BEFORE INSERT OR UPDATE ON public.etiqueta FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2965 (class 2620 OID 16526)
-- Name: lugar trigger_ids_inmodificables_lugar; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_lugar BEFORE INSERT OR UPDATE ON public.lugar FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2959 (class 2620 OID 16527)
-- Name: palabra trigger_ids_inmodificables_lugar; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_lugar BEFORE INSERT OR UPDATE ON public.palabra FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2961 (class 2620 OID 16528)
-- Name: significado trigger_ids_inmodificables_lugar; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_lugar BEFORE INSERT OR UPDATE ON public.significado FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2960 (class 2620 OID 16531)
-- Name: palabra trigger_ids_inmodificables_palabra; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_palabra BEFORE INSERT OR UPDATE ON public.palabra FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2962 (class 2620 OID 16532)
-- Name: significado trigger_ids_inmodificables_significado; Type: TRIGGER; Schema: public; Owner: diccionario
--

CREATE TRIGGER trigger_ids_inmodificables_significado BEFORE INSERT OR UPDATE ON public.significado FOR EACH ROW EXECUTE FUNCTION public.ids_inmodificables();


--
-- TOC entry 2950 (class 2606 OID 16434)
-- Name: lugar dentro_de; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.lugar
    ADD CONSTRAINT dentro_de FOREIGN KEY (esta_dentro_de) REFERENCES public.lugar(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2953 (class 2606 OID 16480)
-- Name: significa idpalabra_significa_referencia; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.significa
    ADD CONSTRAINT idpalabra_significa_referencia FOREIGN KEY (idpalabra) REFERENCES public.palabra(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2954 (class 2606 OID 16485)
-- Name: significa idsignificado_significa_referencia; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.significa
    ADD CONSTRAINT idsignificado_significa_referencia FOREIGN KEY (idsignificado) REFERENCES public.significado(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2957 (class 2606 OID 16515)
-- Name: trata_sobre idsignificado_tratasobre_references; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.trata_sobre
    ADD CONSTRAINT idsignificado_tratasobre_references FOREIGN KEY (idsignificado) REFERENCES public.significado(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2952 (class 2606 OID 16573)
-- Name: se_usa_en referecia_lugar_seusaen; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.se_usa_en
    ADD CONSTRAINT referecia_lugar_seusaen FOREIGN KEY (idlugar) REFERENCES public.lugar(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2951 (class 2606 OID 16449)
-- Name: se_usa_en referencia_palabra_seusaen; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.se_usa_en
    ADD CONSTRAINT referencia_palabra_seusaen FOREIGN KEY (idpalabra) REFERENCES public.palabra(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2955 (class 2606 OID 16495)
-- Name: antonimia significado1_antonimia; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.antonimia
    ADD CONSTRAINT significado1_antonimia FOREIGN KEY (idsignificado1) REFERENCES public.significado(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2956 (class 2606 OID 16500)
-- Name: antonimia significado2_antonimia; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.antonimia
    ADD CONSTRAINT significado2_antonimia FOREIGN KEY (idsignificado2) REFERENCES public.significado(id) ON UPDATE CASCADE ON DELETE CASCADE;


--
-- TOC entry 2958 (class 2606 OID 16520)
-- Name: trata_sobre tratasobre_idetiqueta_references; Type: FK CONSTRAINT; Schema: public; Owner: diccionario
--

ALTER TABLE ONLY public.trata_sobre
    ADD CONSTRAINT tratasobre_idetiqueta_references FOREIGN KEY (idetiqueta) REFERENCES public.etiqueta(id) ON UPDATE CASCADE ON DELETE CASCADE;


-- Completed on 2022-03-18 12:18:07 CET

--
-- PostgreSQL database dump complete
--

