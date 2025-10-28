/*
==========================================================
Script 03: Cria Tabela de Staging (Produto Final)
Cria uma nova tabela 'produto_final_staging' apenas com as
colunas necessárias de 'new_inegi', para acelerar o
processamento.

(Versão corrigida: Inclui 'cp' original para validação)
==========================================================
*/

-- (Opcional) Limpar tabela antiga se estiver re-executando
DROP TABLE IF EXISTS public.produto_final_staging;

-- Cria a tabela base com os dados brutos necessários
CREATE TABLE public.produto_final_staging AS
SELECT
    gid,
    -- Concatena 'tipovial' e 'nomvial' de forma segura (ignora NULLs)
    concat_ws(' ', tipovial, nomvial) AS via,
    numext AS hnum,
    nomasen AS nsvia,
    cp AS postcode_original, -- <-- Coluna 'cp' original da new_inegi
    geom -- A geometria original (SRID 6362)
FROM
    new_inegi;

-- Indexa a nova tabela para performance
CREATE INDEX idx_staging_geom ON public.produto_final_staging USING GIST(geom);
ALTER TABLE public.produto_final_staging ADD PRIMARY KEY (gid);

