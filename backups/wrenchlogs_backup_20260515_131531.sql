--
-- PostgreSQL database dump
--

\restrict a4VmP9g3p924dRH87VXjdKlHfyI8Vo5ayES9EIK3DrelNfm4IodbRMwPh1xPWXa

-- Dumped from database version 16.11
-- Dumped by pg_dump version 16.11

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
-- Name: car_partners; Type: TABLE; Schema: public; Owner: coownerly
--

CREATE TABLE public.car_partners (
    id bigint NOT NULL,
    car_id bigint NOT NULL,
    partner_id bigint NOT NULL,
    share_pct numeric DEFAULT 50 NOT NULL
);


ALTER TABLE public.car_partners OWNER TO coownerly;

--
-- Name: car_partners_id_seq; Type: SEQUENCE; Schema: public; Owner: coownerly
--

CREATE SEQUENCE public.car_partners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.car_partners_id_seq OWNER TO coownerly;

--
-- Name: car_partners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: coownerly
--

ALTER SEQUENCE public.car_partners_id_seq OWNED BY public.car_partners.id;


--
-- Name: car_payments; Type: TABLE; Schema: public; Owner: coownerly
--

CREATE TABLE public.car_payments (
    id bigint NOT NULL,
    car_id bigint NOT NULL,
    payment_type text DEFAULT 'purchase'::text NOT NULL,
    paid_by text NOT NULL,
    amount numeric DEFAULT 0 NOT NULL,
    notes text DEFAULT ''::text
);


ALTER TABLE public.car_payments OWNER TO coownerly;

--
-- Name: car_payments_id_seq; Type: SEQUENCE; Schema: public; Owner: coownerly
--

CREATE SEQUENCE public.car_payments_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.car_payments_id_seq OWNER TO coownerly;

--
-- Name: car_payments_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: coownerly
--

ALTER SEQUENCE public.car_payments_id_seq OWNED BY public.car_payments.id;


--
-- Name: cars; Type: TABLE; Schema: public; Owner: coownerly
--

CREATE TABLE public.cars (
    id bigint NOT NULL,
    make text NOT NULL,
    model text NOT NULL,
    year integer NOT NULL,
    vin text DEFAULT ''::text,
    auction_name text DEFAULT ''::text,
    purchase_date text DEFAULT ''::text,
    purchase_price numeric DEFAULT 0 NOT NULL,
    auction_fees numeric DEFAULT 0 NOT NULL,
    transport_cost numeric DEFAULT 0 NOT NULL,
    status text DEFAULT 'purchased'::text NOT NULL,
    sale_price numeric,
    notes text DEFAULT ''::text,
    created_at timestamp with time zone DEFAULT now(),
    paid_by_purchase text DEFAULT ''::text,
    paid_by_transport text DEFAULT ''::text,
    market_price numeric
);


ALTER TABLE public.cars OWNER TO coownerly;

--
-- Name: cars_id_seq; Type: SEQUENCE; Schema: public; Owner: coownerly
--

CREATE SEQUENCE public.cars_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.cars_id_seq OWNER TO coownerly;

--
-- Name: cars_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: coownerly
--

ALTER SEQUENCE public.cars_id_seq OWNED BY public.cars.id;


--
-- Name: expenses; Type: TABLE; Schema: public; Owner: coownerly
--

CREATE TABLE public.expenses (
    id bigint NOT NULL,
    car_id bigint NOT NULL,
    category text NOT NULL,
    description text DEFAULT ''::text,
    amount numeric DEFAULT 0 NOT NULL,
    paid_by text DEFAULT ''::text,
    expense_date text DEFAULT ''::text,
    created_at timestamp with time zone DEFAULT now(),
    part_number text DEFAULT ''::text,
    quantity numeric DEFAULT 1 NOT NULL,
    unit_price numeric DEFAULT 0 NOT NULL
);


ALTER TABLE public.expenses OWNER TO coownerly;

--
-- Name: expenses_id_seq; Type: SEQUENCE; Schema: public; Owner: coownerly
--

CREATE SEQUENCE public.expenses_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.expenses_id_seq OWNER TO coownerly;

--
-- Name: expenses_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: coownerly
--

ALTER SEQUENCE public.expenses_id_seq OWNED BY public.expenses.id;


--
-- Name: partners; Type: TABLE; Schema: public; Owner: coownerly
--

CREATE TABLE public.partners (
    id bigint NOT NULL,
    name text NOT NULL,
    phone text DEFAULT ''::text,
    email text DEFAULT ''::text
);


ALTER TABLE public.partners OWNER TO coownerly;

--
-- Name: partners_id_seq; Type: SEQUENCE; Schema: public; Owner: coownerly
--

CREATE SEQUENCE public.partners_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


ALTER SEQUENCE public.partners_id_seq OWNER TO coownerly;

--
-- Name: partners_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: coownerly
--

ALTER SEQUENCE public.partners_id_seq OWNED BY public.partners.id;


--
-- Name: car_partners id; Type: DEFAULT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_partners ALTER COLUMN id SET DEFAULT nextval('public.car_partners_id_seq'::regclass);


--
-- Name: car_payments id; Type: DEFAULT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_payments ALTER COLUMN id SET DEFAULT nextval('public.car_payments_id_seq'::regclass);


--
-- Name: cars id; Type: DEFAULT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.cars ALTER COLUMN id SET DEFAULT nextval('public.cars_id_seq'::regclass);


--
-- Name: expenses id; Type: DEFAULT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.expenses ALTER COLUMN id SET DEFAULT nextval('public.expenses_id_seq'::regclass);


--
-- Name: partners id; Type: DEFAULT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.partners ALTER COLUMN id SET DEFAULT nextval('public.partners_id_seq'::regclass);


--
-- Data for Name: car_partners; Type: TABLE DATA; Schema: public; Owner: coownerly
--

COPY public.car_partners (id, car_id, partner_id, share_pct) FROM stdin;
3	2	1	50
4	2	2	50
5	3	2	50
6	3	1	50
9	5	2	50
10	5	1	50
11	6	2	50
12	6	1	50
13	7	2	50
14	7	1	50
\.


--
-- Data for Name: car_payments; Type: TABLE DATA; Schema: public; Owner: coownerly
--

COPY public.car_payments (id, car_id, payment_type, paid_by, amount, notes) FROM stdin;
64	2	purchase	Shailesh Singh	8612.5	
65	2	purchase	Arul	8612.5	
7	2	transport	Arul	150	
8	2	transport	Shailesh Singh	150	
9	3	purchase	Arul	8368.75	
10	3	purchase	Shailesh Singh	8368.75	
78	3	transport	Arul	225	
79	3	transport	Shailesh Singh	225	
82	7	purchase	Arul	11670	
83	7	transport	Arul	1170	
60	5	purchase	Shailesh Singh	15339.375	
61	5	purchase	Arul	15339.375	
62	5	transport	Shailesh Singh	100	
63	5	transport	Arul	100	
161	6	purchase	Arul	17335	
162	6	purchase	Shailesh Singh	17335	
191	6	transport	Shailesh Singh	585	
192	6	transport	Arul	585	
\.


--
-- Data for Name: cars; Type: TABLE DATA; Schema: public; Owner: coownerly
--

COPY public.cars (id, make, model, year, vin, auction_name, purchase_date, purchase_price, auction_fees, transport_cost, status, sale_price, notes, created_at, paid_by_purchase, paid_by_transport, market_price) FROM stdin;
2	Toyota	Prius	2026	JTDACAAUXT3067260	copart	2026-04-10	15800	1425	300	in_repair	\N		2026-04-21 04:13:56.254377+00			\N
3	Volvo	EX40	2025		copart	2026-04-09	16737.5	0	450	in_repair	\N		2026-04-21 04:55:08.702344+00			\N
5	Porsche	Macan	2025		Copart	2026-04-24	30678.75	0	200	in_repair	\N	$30638.75 Purchase price + $40 Wire transfer fee	2026-04-25 04:11:19.33232+00			\N
7	Volvo	XC40	2025		Copart	2026-05-08	11670	0	1170	purchased	\N		2026-05-09 07:08:10.39228+00			\N
6	Porsche	718 Cayman	2024		Copart	2026-05-08	34670	0	1170	purchased	\N		2026-05-09 07:06:44.069151+00			\N
\.


--
-- Data for Name: expenses; Type: TABLE DATA; Schema: public; Owner: coownerly
--

COPY public.expenses (id, car_id, category, description, amount, paid_by, expense_date, created_at, part_number, quantity, unit_price) FROM stdin;
2	2	Transmission		633	Shailesh Singh	2024-04-14	2026-04-21 04:20:23.998609+00		1	0
52	5	Body/Paint	Hood paint	900	Shailesh Singh		2026-05-15 09:17:07.832305+00		1	900
53	5	Other	car rental	200	Shailesh Singh	2026-05-06	2026-05-15 09:19:43.32091+00		1	200
3	2	Transmission	Transmission oil	59	Shailesh Singh	2026-04-10	2026-04-21 04:21:11.093846+00		1	0
4	2	Suspension	Link Assembly	94.05	Arul	2024-04-10	2026-04-21 04:22:38.410546+00		1	0
5	2	Suspension	lower joint	63.36	Arul	2024-04-11	2026-04-21 04:24:20.017073+00		1	0
6	2	Body/Paint	Headlight	307.29	Shailesh Singh	2026-04-19	2026-04-21 04:37:19.40428+00		1	0
7	2	Body/Paint	Fender Sub-A	199.32	Shailesh Singh	2026-04-19	2026-04-21 04:43:37.284264+00		1	0
8	2	Body/Paint	Cover Outer	37.65	Shailesh Singh	2026-04-19	2026-04-21 04:44:23.898594+00		1	0
9	2	Transmission	Seal, Type T Oil	20.33	Shailesh Singh	2026-04-17	2026-04-21 04:46:36.464879+00		1	0
10	2	Transmission	Seal	20.33	Shailesh Singh		2026-04-21 04:47:03.420268+00		1	0
11	3	Body/Paint	Bumper Impact bar	500.67	Arul		2026-04-21 04:56:48.768869+00		1	0
12	3	Body/Paint	Front Passenger side fender mounting bracket	81.68	Arul		2026-04-21 04:57:34.374819+00		1	0
13	3	Interior	Knee airbag	301.8	Shailesh Singh	2026-04-11	2026-04-21 04:58:34.424469+00		1	0
14	3	Interior	Inflatable curtain roof left	381.2	Shailesh Singh	2026-04-11	2026-04-21 04:59:09.428732+00		1	0
15	3	Interior	Inflatable curtain roof Right	381.2	Shailesh Singh	2026-04-11	2026-04-21 04:59:31.242523+00		1	0
16	3	Body/Paint	Headlight	478.68	Shailesh Singh	2026-04-11	2026-04-21 05:00:11.889646+00		1	0
17	3	Body/Paint	Hood	609	Shailesh Singh	2026-04-13	2026-04-21 05:00:37.790305+00		1	0
19	3	Body/Paint	Headliner clip	11.81	Arul		2026-04-21 05:01:44.953767+00		1	0
18	3	Body/Paint	Headliner clip	11.81	Arul		2026-04-21 05:01:28.647638+00		1	0
20	3	Body/Paint	Driver Airbag	783.15	Arul	2026-04-17	2026-04-23 05:09:41.032981+00		1	0
21	3	Body/Paint	Spoiler	221.27	Arul	2026-04-17	2026-04-23 05:10:17.52332+00		1	0
24	3	Body/Paint	Fender carrier	43.98	Arul	2026-04-17	2026-04-23 05:12:00.201177+00		1	0
25	3	Body/Paint	Cover 1	229.67	Arul	2026-04-17	2026-04-23 05:12:49.069794+00		1	0
26	3	Body/Paint	Cover 2	229.67	Arul	2026-04-17	2026-04-23 05:13:13.201002+00		1	0
27	3	Body/Paint	Bracket	29.4	Arul	2026-04-17	2026-04-23 05:13:41.46666+00		1	0
30	3	Body/Paint	Windshield washer reservoir	67.8	Arul	2026-04-13	2026-04-23 05:15:54.038427+00		1	0
28	3	Body/Paint	Bumper cover primed	814.26	Arul	2026-04-17	2026-04-23 05:14:13.592445+00		1	0
22	3	Body/Paint	Air guide 1	82.62	Arul	2026-04-17	2026-04-23 05:10:56.586491+00		1	0
23	3	Body/Paint	Air guide 2	83.38	Arul	2026-04-17	2026-04-23 05:11:20.396356+00		1	0
31	3	Body/Paint	Bumper Impact Absorber	42	Arul	2026-04-17	2026-04-23 05:24:14.567254+00		1	0
32	3	Body/Paint	8 Screws	11	Arul	2026-04-17	2026-04-23 05:24:59.906994+00		1	0
33	2	Tires	1 Michelin tire + install	261	Arul	2026-04-13	2026-04-23 05:30:50.277287+00		1	0
34	2	Transmission	Transmission Fluid	74.1	Arul	2026-04-15	2026-04-23 05:32:12.59654+00		1	0
35	2	Other	4 wheel alignment	119.99	Arul	2026-04-17	2026-04-23 05:33:12.22659+00		1	0
36	3	Body/Paint	S Bracket 3	24.5	Arul	2026-04-24	2026-04-25 04:03:44.745233+00		1	0
37	3	Body/Paint	Frunk	118.47	Arul	2026-04-24	2026-04-25 04:04:16.66103+00		1	0
38	3	Body/Paint	Side Pane	109.5	Arul	2026-04-24	2026-04-25 04:04:40.21488+00		1	0
39	3	Body/Paint	2x screws	3.76	Arul	2026-04-24	2026-04-25 04:05:14.859106+00		1	0
40	2	Body/Paint	Fender/Door/Bumper paint job	900	Arul	2026-05-01	2026-05-08 16:23:48.695311+00		0	0
41	3	Body/Paint	Neds Paint shop	86	Arul	2026-04-27	2026-05-09 06:13:34.739719+00		0	0
42	3	Body/Paint	Bumper painting - Hillcrest auto lounge	400	Arul	2026-04-30	2026-05-09 06:15:19.558515+00		0	0
43	3	Body/Paint	Volvo walnut creek	27.68	Arul	2026-04-29	2026-05-09 06:17:05.738885+00		0	0
44	3	Body/Paint	Volvo burlingame	418.86	Arul	2026-05-05	2026-05-09 06:19:30.926912+00		0	0
45	3	Body/Paint	Hood painting - Lepis painting	500	Arul	2026-05-07	2026-05-09 06:21:04.071428+00		0	0
46	5	Body/Paint	Porsche livermore	584.83	Arul	2026-05-04	2026-05-09 06:24:04.255171+00		0	0
47	5	Body/Paint	Porsche hood	480	Arul	2026-04-28	2026-05-09 06:25:48.79879+00		0	0
48	5	Body/Paint	BMA European	950	Arul	2026-04-28	2026-05-09 06:26:38.336215+00		0	0
49	5	Body/Paint	Neds Porsche Paint can	43	Arul	2026-04-27	2026-05-09 06:27:52.680067+00		0	0
50	5	Body/Paint	Porsche livermore	648.03	Arul	2026-04-27	2026-05-09 06:36:13.986791+00		0	0
51	3	Body/Paint	Volvo Walnut creek - Need to check if duplicate	673.77	Arul	2026-04-13	2026-05-09 06:54:15.324581+00		0	0
\.


--
-- Data for Name: partners; Type: TABLE DATA; Schema: public; Owner: coownerly
--

COPY public.partners (id, name, phone, email) FROM stdin;
1	Shailesh Singh	4158024610	shail39@gmail.com
2	Arul	1111	
\.


--
-- Name: car_partners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: coownerly
--

SELECT pg_catalog.setval('public.car_partners_id_seq', 14, true);


--
-- Name: car_payments_id_seq; Type: SEQUENCE SET; Schema: public; Owner: coownerly
--

SELECT pg_catalog.setval('public.car_payments_id_seq', 192, true);


--
-- Name: cars_id_seq; Type: SEQUENCE SET; Schema: public; Owner: coownerly
--

SELECT pg_catalog.setval('public.cars_id_seq', 7, true);


--
-- Name: expenses_id_seq; Type: SEQUENCE SET; Schema: public; Owner: coownerly
--

SELECT pg_catalog.setval('public.expenses_id_seq', 53, true);


--
-- Name: partners_id_seq; Type: SEQUENCE SET; Schema: public; Owner: coownerly
--

SELECT pg_catalog.setval('public.partners_id_seq', 2, true);


--
-- Name: car_partners car_partners_pkey; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_partners
    ADD CONSTRAINT car_partners_pkey PRIMARY KEY (id);


--
-- Name: car_payments car_payments_pkey; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_payments
    ADD CONSTRAINT car_payments_pkey PRIMARY KEY (id);


--
-- Name: cars cars_pkey; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.cars
    ADD CONSTRAINT cars_pkey PRIMARY KEY (id);


--
-- Name: expenses expenses_pkey; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_pkey PRIMARY KEY (id);


--
-- Name: partners partners_name_key; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_name_key UNIQUE (name);


--
-- Name: partners partners_pkey; Type: CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.partners
    ADD CONSTRAINT partners_pkey PRIMARY KEY (id);


--
-- Name: car_partners car_partners_car_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_partners
    ADD CONSTRAINT car_partners_car_id_fkey FOREIGN KEY (car_id) REFERENCES public.cars(id) ON DELETE CASCADE;


--
-- Name: car_partners car_partners_partner_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_partners
    ADD CONSTRAINT car_partners_partner_id_fkey FOREIGN KEY (partner_id) REFERENCES public.partners(id);


--
-- Name: car_payments car_payments_car_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.car_payments
    ADD CONSTRAINT car_payments_car_id_fkey FOREIGN KEY (car_id) REFERENCES public.cars(id) ON DELETE CASCADE;


--
-- Name: expenses expenses_car_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: coownerly
--

ALTER TABLE ONLY public.expenses
    ADD CONSTRAINT expenses_car_id_fkey FOREIGN KEY (car_id) REFERENCES public.cars(id) ON DELETE CASCADE;


--
-- PostgreSQL database dump complete
--

\unrestrict a4VmP9g3p924dRH87VXjdKlHfyI8Vo5ayES9EIK3DrelNfm4IodbRMwPh1xPWXa

