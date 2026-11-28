# Reading companion (AI) – plan & design

Put this file in the repo as `docs/ai-companion.md`. Updated 27 Nov 2026.

## What it is
An opt-in **chat companion like Oura Advisor**. You open it and talk about your reading. It does four jobs:

- find a book
- talk about a book
- check how my reading is going
- plan what to read

Book picks (max 3 cards, each with a "why"), stats and plans appear inside the conversation.

**Release:** v1.1, after the core app and widgets. Launch first as an opt-in "Labs" beta.

## Entry points
- **iPhone:** a floating **AI button** (sparkles icon, 56 pt) at the bottom right, above the tab bar. It is hidden while the chat is open.
- **iPhone Duo:** the AI button (48 pt) sits in the side bar above the nav, never floating over content.
- **Optional Home card:** "From your companion", shown only near the end of a book, at most one at a time, and easy to dismiss.

## iPhone Duo behaviour
The companion is a side panel, not a separate place.

- **Open:** the chat is always in the right pane, next to the current content. A book tapped in the chat opens in the left pane.
- **Closed:** the chat fills the outer screen.
- **Upright:** answers on the top half; chips, composer and keyboard on the bottom half.
- **Tabletop:** the latest answer on top; big reply chips and push-to-talk below.
- Nothing crosses the fold. Swap sides mirrors the panes.

## Principles
1. Opt-in and clearly labelled ("Reading companion · AI").
2. Real books only: every pick is validated against a catalogue ID.
3. Always says why, using the reader's own books.
4. Talks about your reading but never judges or labels you.
5. Calm: no streaks or notifications by default.
6. Private first: on-device where possible; only titles, authors and ratings are shared.

## AI text formatting
The model returns a small Markdown subset. The app renders it natively: SwiftUI `AttributedString` on iOS and Compose `AnnotatedString` on Android. Everything outside the subset is stripped.

**Allowed in model output:**

- `**bold**`
- `*Book title*` together with a `book_id`
- `- bullet`
- `1. step`
- a blank line for a new paragraph

**Rules:**

1. Lead with the answer. 1–3 short sentences per paragraph, max ~90 words before a card.
2. Body text uses UI/Regular/15 with Dynamic Type, line height 145% and 8 pt paragraph spacing. Companion text has no bubble.
3. Bold (Inter Semi Bold) only for key numbers and facts, max 2–3 per answer.
4. Book titles use Newsreader Italic 17 in accentInk, underlined and tappable. Only titles that match a real catalogue ID become links.
5. Bullets for 3–4 parallel items; numbers only for steps or a plan; no nesting.
6. Never use headings, tables, emoji, URLs, code, exclamation marks, long quotes or words that judge the reader.
7. Books become cards (max 3), actions become chips or buttons, and numbers come from a stat card built from app data.
8. Text streams sentence by sentence; cards fade in after it (motion/base 250 ms). With Reduce Motion, the whole answer appears at once.
9. VoiceOver/TalkBack reads one element per answer. Titles are read as links, and each card is its own element.

## Architecture
- **On device:** Apple Foundation Models on iOS 26+ with Apple Intelligence; Gemini Nano via the ML Kit Prompt API on supported Android phones.
- **Cloud fallback:** a Supabase Edge Function `companion` calls a budget LLM (Claude Haiku / Gemini Flash-Lite). The API key stays server-side.
- **Tools:** `get_taste_profile`, `search_catalog`, `get_similar`, `get_book_details`, `is_in_library`, `save_feedback`
- **Catalogue sources:** Hardcover, Open Library, Google Books
- **Safeguards:** rate limit per user, caching, an 8 s timeout with a calm fallback, and an evaluation set of 30 reader profiles.

## Compliance
- An in-app consent screen before the first chat, as required by App Store guideline 5.1.2(i). It names the provider and lists the data shared.
- GDPR: data processing agreement (DPA) with the provider, EU region, no training on our data, chat text deleted after 30 days, and data export and delete.
- Privacy policy, App Store privacy labels and the Play Data safety form all updated; an option to report AI content (Google Play).
- Settings › Companion & privacy has these controls:
  - companion on/off
  - on-device only
  - gentle nudge
  - include notes
  - chat history
  - delete history

## Cost
- About $0.005–0.015 per cloud answer on Claude Haiku 4.5, and less on the Flash-Lite class.
- About $400 a month for 5,000 active users asking 8 times a month.
- The one-time $4.99 Plus can't fund unlimited cloud chat.
- **To decide:** unlimited on-device chat plus a monthly cloud cap (20 in the mockups), or a small AI subscription later.

## Figma (playground file)
- **Research:** page 🤖 AI companion → https://www.figma.com/design/Tq6PW3rvfMxncJfpmyjKoz?node-id=213-2
- **Components:** C · Reading companion → https://www.figma.com/design/Tq6PW3rvfMxncJfpmyjKoz?node-id=230-1481
- **Mockups:** Flow 12 · Reading companion (AI), with iOS, edge cases, formatting rules and iPhone Duo → https://www.figma.com/design/Tq6PW3rvfMxncJfpmyjKoz?node-id=234-12513

The new components are:

- AI button
- Chat message
- Chat book card
- Chat composer
- Starter prompt
- Typing indicator
- AI marker
- Answer actions

## Status
- [x] Research, market and costs
- [x] UX exploration (🤖 AI companion page)
- [x] Components (C · Reading companion)
- [x] Flow 12 mockups for iOS and iPhone Duo
- [ ] Flow 12 mockups for Android
- [ ] Companion in the coded prototype
- [ ] Backend proxy and consent (Phase 7, together with accounts)
- [ ] On-device and cloud implementation on iOS and Android
- [ ] Labs beta and a test with 5 readers

## Open questions
- **Name:** "Reading companion" or a named character?
- **Cloud cost model:** monthly cap or a small subscription?
- **Memory between chats:** suggest keeping feedback and deleting chat text after 30 days.
- **Spoiler-safe series recaps:** allow them or not?

## iOS implementation of persona v0.3 (28 Nov 2026)
- **Natural answers without the model** (`CompanionConversation`): greeting, who are you, what can you do, are you real, how do you know what I like, thanks, goodbye, goal facts (no advice), change my goal, should I read more, "I just finished X", "I gave up on X". No book cards, no stats unless asked.
- **When books are suggested:** a vague request gets one question first; "yes" to an offer, an answer to her question, or an explicit request (planner `wantsBooks`) suggests. Book talk and moods only offer once (`offersBooks`); after a "no" she doesn't offer again in that chat.
- **Eligibility:** excluded = Read, Reading now, Didn't finish, Not for me (title key; rereads only when asked). Want to read is allowed: max one, shown first, card "On your Want to read" + "Open book". Checked when retrieving and again before showing cards.
- **Real books only:** model-named titles are verified against Google Books / Open Library; "short" is checked against real page counts; when fewer than two survive and the request names a genre, well-known catalogue books fill in (Open Library, 100+ ratings). Otherwise the honest "Shall I look a little wider?".
- **Settings:** "Include my profile" (first name + About me), off by default.
- **Evaluation:** `-qsAstridEval 70` = 10 tastes × 7 questions (identity, hello, vague request, short and cosy, year, should I read more, finished a book). Checks no cards where the persona says none, no unasked goal talk, no goal advice, one question max, no read books, voice rules. Last run: 70 answers, 0 rule problems.
- **Still to do:** series order (next unread volume) and work-level matching across editions need Hardcover work IDs (backend); Figma "On Want to read" card state.
