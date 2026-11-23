--
-- PostgreSQL database dump
--

\restrict 21gerpYRMTVoEVmMMjiqwjXDRMfw016eEE4e4mvPO2MQ7v6jy3lbnklw5VypMYo

-- Dumped from database version 15.19 (Debian 15.19-1.pgdg13+2)
-- Dumped by pg_dump version 15.19 (Debian 15.19-1.pgdg13+2)

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: posts; Type: TABLE; Schema: public; Owner: pocuser
--

CREATE TABLE public.posts (
    id integer NOT NULL,
    content text NOT NULL
);


ALTER TABLE public.posts OWNER TO pocuser;

--
-- Name: posts_id_seq; Type: SEQUENCE; Schema: public; Owner: pocuser
--

CREATE SEQUENCE public.posts_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER TABLE public.posts_id_seq OWNER TO pocuser;

--
-- Name: posts_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: pocuser
--

ALTER SEQUENCE public.posts_id_seq OWNED BY public.posts.id;


--
-- Name: posts id; Type: DEFAULT; Schema: public; Owner: pocuser
--

ALTER TABLE ONLY public.posts ALTER COLUMN id SET DEFAULT nextval('public.posts_id_seq'::regclass);


--
-- Data for Name: posts; Type: TABLE DATA; Schema: public; Owner: pocuser
--

COPY public.posts (id, content) FROM stdin;
1	recovery-test-001
2	recovery-test-001
\.


--
-- Name: posts_id_seq; Type: SEQUENCE SET; Schema: public; Owner: pocuser
--

SELECT pg_catalog.setval('public.posts_id_seq', 2, true);


--
-- Name: posts posts_pkey; Type: CONSTRAINT; Schema: public; Owner: pocuser
--

ALTER TABLE ONLY public.posts
    ADD CONSTRAINT posts_pkey PRIMARY KEY (id);


--
-- PostgreSQL database dump complete
--

\unrestrict 21gerpYRMTVoEVmMMjiqwjXDRMfw016eEE4e4mvPO2MQ7v6jy3lbnklw5VypMYo

