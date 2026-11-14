-- D45: alinhar 2 funcoes alteradas na producao fora das migracoes (search_path fixo)
CREATE OR REPLACE FUNCTION game.need(l integer)
 RETURNS bigint
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'game', 'public'
AS $function$ select round(50 * power(l, 2.4))::bigint $function$;
CREATE OR REPLACE FUNCTION game.plvl(p jsonb, k text)
 RETURNS integer
 LANGUAGE sql
 IMMUTABLE
 SET search_path TO 'game', 'public'
AS $function$ select floor(sqrt(coalesce((p->>k)::numeric, 0) / 40))::int $function$;
