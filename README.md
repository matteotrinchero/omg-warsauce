# OMG WARSAUCE
Osteria Matteo & Giovanni. Made in Italy. Cooked in Warsaw.

App per smartphone delle nostre cene: prossima cena con prenotazione, menu con foto, profili della Famiglia (foto, nome, Instagram, storico delle cene e dei piatti), Archivio con le foto, Chef area.
Gira su GitHub Pages (sito) + Supabase (database e foto). Tutto gratis.

## Cosa c'e qui
- `index.html`: tutta l'app.
- `config.js`: indirizzo di Supabase e Publishable key (`sb_publishable_...`). E pubblica per natura: i dati sono protetti dalle regole del database. Mai mettere qui la secret key o la service_role.
- `img/`: foto dei piatti (Pexels, licenza libera).
- `supabase/schema.sql`: tabelle, regole di sicurezza, foto, admin. Gia eseguito.
- `.github/workflows/keepalive.yml`: ogni 3 giorni tiene sveglio il database gratuito (Supabase lo mette in pausa dopo 7 giorni senza visite).

## Setup (una volta sola)
1. Supabase: progetto `omg-warsauce` (West EU, Irlanda), `schema.sql` eseguito nel SQL Editor, "Allow anonymous sign-ins" attivo (Authentication > Sign In / Providers). Serve agli amici per registrarsi senza password.
2. Utente chef: Supabase > Authentication > Users > Add user > Create new user. Email uguale a quella in fondo a `schema.sql`, una password a scelta, "Auto Confirm User" spuntato.
3. GitHub Pages: Settings > Pages > Deploy from a branch > `main` / `(root)` > Save. Il sito e su `https://<utente>.github.io/omg-warsauce/`.

## Primo utilizzo
- Matteo: Profilo > Chef area > email e password. Crea la prima cena (tab Dinner).
- Poi crea il tuo profilo (Profilo > Create my profile) e nel tab Guests segna te e Giovanni come Host.
- Sul telefono: Condividi > "Aggiungi alla schermata Home". Su iPhone l'icona e Safari non condividono i dati: fai login e profilo dall'icona.
- Manda il link agli amici: si registrano con foto, nome e Instagram, e prenotano. Niente password: il profilo resta nel browser in cui si registrano, quindi meglio Safari/Chrome o l'icona sulla Home, non il browser interno di Instagram (l'app lo segnala da sola).
- Dopo la cena: tab Bookings, togli la spunta a chi non e venuto, poi "Dinner done": la cena va nell'Archivio e tutti prendono il timbro.
- Foto: gli invitati le caricano dalla cena in Archivio; nella Chef area, tab Foto, scegli quali pubblicare.

## Aggiungere Giovanni come chef
1. Supabase > SQL Editor: `insert into public.admins (email) values ('email-di-giovanni') on conflict do nothing;`
2. Supabase > Authentication > Users > Add user > Create new user con quella email e una sua password, "Auto Confirm User" spuntato.
3. Giovanni entra nella Chef area e solo dopo crea il suo profilo (se lo crea prima, resta un profilo separato da invitato).
