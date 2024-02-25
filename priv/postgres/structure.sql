--
-- PostgreSQL database dump
--

-- Dumped from database version 12.15 (Ubuntu 12.15-0ubuntu0.20.04.1)
-- Dumped by pg_dump version 12.15 (Ubuntu 12.15-0ubuntu0.20.04.1)

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
-- Name: pg_trgm; Type: EXTENSION; Schema: -; Owner: -
--

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;


--
-- Name: EXTENSION pg_trgm; Type: COMMENT; Schema: -; Owner: -
--

COMMENT ON EXTENSION pg_trgm IS 'text similarity measurement and index searching based on trigrams';


--
-- Name: Dice; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Dice" AS (
	dienum integer,
	dietype integer
);


--
-- Name: Element; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Element" AS ENUM (
    'Null',
    'Fire',
    'Aqua',
    'Elec',
    'Wood',
    'Wind',
    'Sword',
    'Break',
    'Cursor',
    'Recov',
    'Invis',
    'Object'
);


--
-- Name: Blight; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Blight" AS (
	elem public."Element",
	dmg public."Dice",
	duration public."Dice"
);


--
-- Name: ChipClass; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ChipClass" AS ENUM (
    'Standard',
    'Mega',
    'Giga'
);


--
-- Name: ChipEffect; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ChipEffect" AS ENUM (
    'Stagger',
    'Blind',
    'Confuse',
    'Lock',
    'Shield',
    'Barrier',
    'AC Pierce',
    'AC Down',
    'Weakness',
    'Aura',
    'Invisible',
    'Paralysis',
    'Panic',
    'Heal',
    'Dmg Boost',
    'Move'
);


--
-- Name: ChipType; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."ChipType" AS ENUM (
    'Melee',
    'Projectile',
    'Wave',
    'Burst',
    'Summon',
    'Construct',
    'Support',
    'Heal',
    'Trap'
);


--
-- Name: Color; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Color" AS ENUM (
    'White',
    'Pink',
    'Yellow',
    'Red',
    'Green',
    'Blue',
    'Gray'
);


--
-- Name: Range; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Range" AS ENUM (
    'Varies',
    'Self',
    'Near',
    'Far',
    'Close'
);


--
-- Name: Skill; Type: TYPE; Schema: public; Owner: -
--

CREATE TYPE public."Skill" AS ENUM (
    'PER',
    'INF',
    'TCH',
    'STR',
    'AGI',
    'END',
    'CHM',
    'VLR',
    'AFF'
);


--
-- Name: die_average(public."Dice"); Type: FUNCTION; Schema: public; Owner: -
--

CREATE FUNCTION public.die_average(die public."Dice") RETURNS double precision
    LANGUAGE plpgsql IMMUTABLE STRICT
    AS $$
BEGIN
RETURN die.dienum * (die.dietype / 2.0 + 0.5);
END;
$$;


SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: Battlechip; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Battlechip" (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    elem public."Element"[] NOT NULL,
    skill public."Skill"[],
    range public."Range" NOT NULL,
    hits character varying(12),
    targets character varying(16),
    description text NOT NULL,
    effect public."ChipEffect"[],
    effduration integer,
    blight public."Blight",
    damage public."Dice",
    kind public."ChipType" NOT NULL,
    class public."ChipClass" NOT NULL,
    custom boolean DEFAULT false NOT NULL,
    cr integer DEFAULT 0 NOT NULL,
    median_hits double precision DEFAULT 1.0 NOT NULL,
    median_targets double precision DEFAULT 1.0 NOT NULL
);


--
-- Name: Battlechip_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Battlechip_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Battlechip_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Battlechip_id_seq" OWNED BY public."Battlechip".id;


--
-- Name: NaviCust; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."NaviCust" (
    id integer NOT NULL,
    name character varying NOT NULL,
    description text NOT NULL,
    size integer NOT NULL,
    color public."Color" NOT NULL,
    custom boolean DEFAULT false NOT NULL,
    conflicts character varying(255)[]
);


--
-- Name: NaviCust_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."NaviCust_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: NaviCust_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."NaviCust_id_seq" OWNED BY public."NaviCust".id;


--
-- Name: Virus; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public."Virus" (
    id integer NOT NULL,
    name character varying(64) NOT NULL,
    element public."Element"[] NOT NULL,
    hp integer NOT NULL,
    ac integer NOT NULL,
    stats jsonb NOT NULL,
    skills jsonb NOT NULL,
    drops jsonb NOT NULL,
    description text NOT NULL,
    cr integer NOT NULL,
    abilities character varying(64)[],
    damage public."Dice",
    dmgelem public."Element"[],
    blight public."Blight",
    custom boolean DEFAULT false NOT NULL,
    attack_kind public."ChipType" NOT NULL
);


--
-- Name: Virus_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public."Virus_id_seq"
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: Virus_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public."Virus_id_seq" OWNED BY public."Virus".id;


--
-- Name: schema_migrations; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.schema_migrations (
    version bigint NOT NULL,
    inserted_at timestamp(0) without time zone
);


--
-- Name: Battlechip id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Battlechip" ALTER COLUMN id SET DEFAULT nextval('public."Battlechip_id_seq"'::regclass);


--
-- Name: NaviCust id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NaviCust" ALTER COLUMN id SET DEFAULT nextval('public."NaviCust_id_seq"'::regclass);


--
-- Name: Virus id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Virus" ALTER COLUMN id SET DEFAULT nextval('public."Virus_id_seq"'::regclass);


--
-- Name: Battlechip Battlechip_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Battlechip"
    ADD CONSTRAINT "Battlechip_name_key" UNIQUE (name);


--
-- Name: Battlechip Battlechip_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Battlechip"
    ADD CONSTRAINT "Battlechip_pkey" PRIMARY KEY (id);


--
-- Name: NaviCust NaviCust_Name_Key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NaviCust"
    ADD CONSTRAINT "NaviCust_Name_Key" UNIQUE (name) INCLUDE (name);


--
-- Name: NaviCust NaviCust_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."NaviCust"
    ADD CONSTRAINT "NaviCust_pkey" PRIMARY KEY (id);


--
-- Name: Virus Virus_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public."Virus"
    ADD CONSTRAINT "Virus_pkey" PRIMARY KEY (id);


--
-- Name: schema_migrations schema_migrations_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.schema_migrations
    ADD CONSTRAINT schema_migrations_pkey PRIMARY KEY (version);


--
-- Name: Virus_name_index; Type: INDEX; Schema: public; Owner: -
--

CREATE UNIQUE INDEX "Virus_name_index" ON public."Virus" USING btree (name);


--
-- Name: chip_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX chip_trgm_idx ON public."Battlechip" USING gin (name public.gin_trgm_ops);


--
-- Name: ncp_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ncp_trgm_idx ON public."NaviCust" USING gin (name public.gin_trgm_ops);


--
-- Name: virus_trgm_idx; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX virus_trgm_idx ON public."Virus" USING gin (name public.gin_trgm_ops);


--
-- PostgreSQL database dump complete
--

INSERT INTO public."schema_migrations" (version) VALUES (20220101212038);
INSERT INTO public."schema_migrations" (version) VALUES (20220120043139);
INSERT INTO public."schema_migrations" (version) VALUES (20220126042635);
INSERT INTO public."schema_migrations" (version) VALUES (20220131190559);
INSERT INTO public."schema_migrations" (version) VALUES (20220202171429);
INSERT INTO public."schema_migrations" (version) VALUES (20220203230937);
INSERT INTO public."schema_migrations" (version) VALUES (20220317033651);
INSERT INTO public."schema_migrations" (version) VALUES (20220428032204);
INSERT INTO public."schema_migrations" (version) VALUES (20230521032556);
