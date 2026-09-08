-- Les anciennes chambres de l'Énigme jouent maintenant sous le nom `enigme-chambres` :
-- `enigme` désigne désormais la ferme. La liste des jeux connus est fermée
-- (contrainte et fonction de dépôt) : on l'ouvre au nouveau nom, et à lui seul,
-- sinon leurs scores sont refusés sans que rien ne le dise au joueur.
alter table public.jeu_parties drop constraint if exists jeu_parties_jeu_check;
alter table public.jeu_parties
  add constraint jeu_parties_jeu_check check (jeu in ('carnage', 'enigme', 'enigme-chambres', 'bousculade'));

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
  if p_jeu is null or p_jeu not in ('carnage', 'enigme', 'enigme-chambres', 'bousculade') then
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
  -- Bousculade : cent points par joueur poussé (au plus une poussée toutes
  -- les trois secondes, le temps du repêchage) et deux points par seconde.
  v_plafond := case p_jeu
    when 'carnage' then p_duree_s * 40
    when 'bousculade' then p_duree_s * 36 + 100
    else 2000 end;

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
