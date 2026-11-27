# Quiet Reading – privacy (draft, 27 Nov 2026)

Status: **draft for review** (needs a legal check before release). It describes the app as built today: local-first, no accounts yet, Astrid on the device only. Update it when accounts/sync (Flow 0) and Astrid's cloud fallback arrive.

## 1. Privacy policy (text for the website and the App Store link)

**Quiet Reading is built to be private.** Your books, progress, notes, quotes and photos stay on your iPhone. There are no ads and no tracking, and we don't sell or share your data.

**What stays on your phone**
- Your library: titles, authors, shelves, pages, ratings, moods, notes (typed or handwritten), quotes and the photos you take of covers and pages.
- Your profile: name, account name, about text and photo. They are only shown in the app and, if you choose, on your widgets.
- Your settings, reading goal and reminders.

**What leaves your phone, and why**
- **Book search and covers.** When you search for a book or the app fills in a cover, the search words (a title, author or ISBN) are sent to Google Books and Open Library. Nothing else about you is sent.
- **Astrid, the reading companion (opt-in).** Astrid runs on your iPhone with Apple Intelligence. Your questions and your books don't leave the phone. To suggest books, Astrid looks them up by title in Google Books and Open Library, as above. Voice input is turned into text on the phone; audio is never stored.
- **Purchases.** Plus is bought through the App Store. Apple handles payment; we never see your card.

**Astrid's chat history** is kept on your phone for 30 days by default (or 7 days, or not at all – your choice in Settings › Astrid & privacy). You can delete it any time.

**Your rights.** Everything is on your device, so you're in control: export your books and quotes as CSV files (Settings › Your data › Export my data) or delete everything (Settings › Your data › Delete everything on this phone). When accounts arrive, this policy will explain what is stored online, where, and how to delete your account in the app.

**Children.** Quiet Reading is not directed at children under 13 and doesn't knowingly collect their data.

**Contact.** [support email – to add]

## 2. App Store privacy "nutrition label" (App Store Connect)

Answer: **Data Not Collected** – as long as everything above stays true.
- Book searches go to Google Books / Open Library without any identifier → not "collected" by us, but the privacy policy names them.
- Astrid runs on-device → no data collected. When the cloud fallback (Claude via our server) arrives, update to: *User Content* (questions, book titles/ratings) · *Linked to the user: No* (if we don't send an account id) · *Used for tracking: No* · purpose *App Functionality*. Also add the in-app consent naming the provider (guideline 5.1.2(i)).
- Accounts (later): *Contact Info – Email*, *Identifiers – User ID*, linked to the user, App Functionality.

## 3. Required purpose strings (Info.plist, already in the app)
- Camera: "Quiet Reading uses the camera only to read book covers and barcodes. Photos stay on your phone."
- Photo library (save): "Quiet Reading saves the reading cards you choose to share to your photos."
- Microphone: "Quiet Reading uses the microphone only while you speak to Astrid. Nothing is recorded or kept."
- Speech recognition: "Quiet Reading turns what you say to Astrid into text on your iPhone."

## 4. Before release
- Legal review of this text; add the support email and the company/owner name.
- Host the policy at a public URL and link it in the app (Plus screen "Privacy" and Settings).
- Replace the Google Books key-less search with our own server or an API key (see CLAUDE.md).
- Accounts + cloud Astrid: GDPR data processing agreements (Supabase, Anthropic), EU region, zero data retention, export and delete including server data.
