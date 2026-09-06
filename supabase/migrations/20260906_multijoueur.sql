-- Multijoueur — tables de scores du hub à portails (multijoueur.piks-l.com)
--
-- Migration strictement additive : rien d'existant n'est touché. Le préfixe
-- `jeu_` isole ces tables du reste de la plateforme.
--
-- Le parti pris de sécurité : les tables n'accordent QUE la lecture à la clé
-- publique. Aucune écriture directe n'est possible ; tout passe par
-- `jeu_deposer_partie`, qui borne les scores à ce qu'une manche de cette durée
-- permet d'atteindre. Sans serveur autoritaire on ne peut pas empêcher un
-- client de mentir — on peut refuser qu'il mente au-delà du vraisemblable, et
-- qu'il écrive n'importe quoi dans la table.

create table if not exists public.jeu_joueurs (
  id       text primary key,
  pseudo   text not null,
  parties  integer not null default 0,
  vu_le    timestamptz not null default now(),
  cree_le  timestamptz not null default now()
);
comment on table public.jeu_joueurs is
  'Joueurs du hub multijoueur. L''identifiant est tiré au sort par le navigateur à la première visite : pas de compte, pas de donnée personnelle.';

create table if not exists public.jeu_parties (
  id       uuid primary key default gen_random_uuid(),
  jeu      text not null check (jeu in ('carnage', 'enigme')),
  code     text not null,
  joueurs  smallint not null check (joueurs between 1 and 4),
  duree_s  integer not null check (duree_s between 5 and 1800),
  cree_le  timestamptz not null default now()
);
comment on table public.jeu_parties is
  'Une manche jouée. Déposée une seule fois, par l''hôte de la table.';

create table if not exists public.jeu_scores (
  id         bigint generated always as identity primary key,
  partie_id  uuid not null references public.jeu_parties(id) on delete cascade,
  joueur_id  text not null references public.jeu_joueurs(id) on delete cascade,
  jeu        text not null,
  pseudo     text not null,
  score      integer not null check (score >= 0),
  cree_le    timestamptz not null default now(),
  unique (partie_id, joueur_id)
);
comment on table public.jeu_scores is
  'Score d''un joueur sur une manche. Le pseudo est recopié : le classement doit rester lisible même si le joueur en change ensuite.';

create index if not exists jeu_scores_classement_idx on public.jeu_scores (jeu, score desc);
create index if not exists jeu_scores_joueur_idx on public.jeu_scores (joueur_id);

alter table public.jeu_joueurs enable row level security;
alter table public.jeu_parties enable row level security;
alter table public.jeu_scores  enable row level security;

drop policy if exists "jeu_joueurs lecture publique" on public.jeu_joueurs;
drop policy if exists "jeu_parties lecture publique" on public.jeu_parties;
drop policy if exists "jeu_scores lecture publique"  on public.jeu_scores;

create policy "jeu_joueurs lecture publique" on public.jeu_joueurs
  for select to anon, authenticated using (true);
create policy "jeu_parties lecture publique" on public.jeu_parties
  for select to anon, authenticated using (true);
create policy "jeu_scores lecture publique" on public.jeu_scores
  for select to anon, authenticated using (true);

grant select on public.jeu_joueurs, public.jeu_parties, public.jeu_scores to anon, authenticated;

-- Le seul chemin d'écriture.
create or replace function public.jeu_deposer_partie(
  p_jeu       text,
  p_code      text,
  p_duree_s   integer,
  p_resultats jsonb
) returns uuid
language plpgsql
security definer
set search_path = public
as $$
declare
  v_partie   uuid;
  v_ligne    jsonb;
  v_nb       integer;
  v_plafond  integer;
  v_id       text;
  v_pseudo   text;
  v_score    integer;
  v_recentes integer;
begin
  if p_jeu is null or p_jeu not in ('carnage', 'enigme') then
    raise exception 'jeu inconnu';
  end if;
  if p_duree_s is null or p_duree_s < 5 or p_duree_s > 1800 then
    raise exception 'durée de manche invalide';
  end if;

  v_nb := jsonb_array_length(coalesce(p_resultats, '[]'::jsonb));
  if v_nb < 1 or v_nb > 4 then
    raise exception 'une manche compte de 1 à 4 joueurs';
  end if;

  -- Plafond de vraisemblance. Carnage : même en écrasant sans arrêt avec le
  -- multiplicateur maximum, on reste très en dessous de 40 points par seconde.
  -- Énigme : trois chambres plus le temps restant plafonnent sous 1 700.
  v_plafond := case p_jeu when 'carnage' then p_duree_s * 40 else 2000 end;

  -- Garde-fou de cadence : un client qui déposerait en boucle est arrêté ici.
  v_id := coalesce(p_resultats -> 0 ->> 'joueur_id', '');
  select count(*) into v_recentes
    from public.jeu_scores
   where joueur_id = v_id
     and cree_le > now() - interval '1 hour';
  if v_recentes > 60 then
    raise exception 'trop de dépôts sur la dernière heure';
  end if;

  insert into public.jeu_parties (jeu, code, joueurs, duree_s)
  values (p_jeu, left(coalesce(p_code, ''), 24), v_nb, p_duree_s)
  returning id into v_partie;

  for v_ligne in select * from jsonb_array_elements(p_resultats)
  loop
    v_id := coalesce(v_ligne ->> 'joueur_id', '');
    continue when v_id !~ '^[a-z0-9]{8,32}$';

    v_pseudo := left(btrim(coalesce(v_ligne ->> 'pseudo', '?')), 16);
    continue when v_pseudo = '';

    v_score := coalesce((v_ligne ->> 'score')::integer, 0);
    v_score := greatest(0, least(v_score, v_plafond));

    insert into public.jeu_joueurs (id, pseudo, vu_le, parties)
    values (v_id, v_pseudo, now(), 1)
    on conflict (id) do update
      set pseudo  = excluded.pseudo,
          vu_le   = now(),
          parties = public.jeu_joueurs.parties + 1;

    insert into public.jeu_scores (partie_id, joueur_id, jeu, pseudo, score)
    values (v_partie, v_id, p_jeu, v_pseudo, v_score)
    on conflict (partie_id, joueur_id) do nothing;
  end loop;

  return v_partie;
end;
$$;

comment on function public.jeu_deposer_partie(text, text, integer, jsonb) is
  'Dépôt d''une manche et de ses scores. Seul chemin d''écriture des tables jeu_* : borne les scores au plausible et limite la cadence de dépôt.';

revoke all on function public.jeu_deposer_partie(text, text, integer, jsonb) from public;
grant execute on function public.jeu_deposer_partie(text, text, integer, jsonb) to anon, authenticated;
