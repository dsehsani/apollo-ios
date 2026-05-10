# Apollo

Apollo is an iOS social media app where friends post **daily photo-based wins** — small, real moments of progress documented in the moment, every day. The product flips the dominant social-media reward function on its head: instead of celebrating performance and perfection, it rewards the simple, unfiltered act of showing up.

> _"Win every day."_

This repository contains the SwiftUI iOS client and the Supabase backend (Postgres schema, Edge Functions, Storage policies, and notification system) that power it.

---

## Table of Contents

1. [Tech stack](#tech-stack)
2. [High-level architecture](#high-level-architecture)
3. [Project structure](#project-structure)
4. [Design system](#design-system)
5. [Implemented features](#implemented-features)
   - [Onboarding & Authentication](#1-onboarding--authentication)
   - [Feed](#2-feed)
   - [Camera & Capture flow](#3-camera--capture-flow)
   - [Win List](#4-win-list)
   - [Win Details](#5-win-details)
   - [Profile](#6-profile)
   - [Friends](#7-friends)
   - [Reactions system](#8-reactions-system)
   - [Comments system](#9-comments-system)
   - [Notifications system](#10-notifications-system)
   - [Memories / Calendar](#11-memories--calendar)
   - [Deep linking](#12-deep-linking)
   - [Analytics](#13-analytics)
6. [Supabase backend](#supabase-backend)
7. [Running the app](#running-the-app)
8. [Conventions](#conventions)

---

## Tech stack

| Layer | Choice |
|---|---|
| UI | SwiftUI (iOS 17+) |
| State | `@Observable` view models, `ObservableObject` for app-wide stores |
| Backend | Supabase (Postgres, Auth, Storage, Realtime, Edge Functions) |
| Image loading | [Kingfisher](https://github.com/onevcat/Kingfisher) |
| Realtime | Supabase Realtime subscriptions |
| Push | APNs via Supabase Edge Functions + `pg_net` |
| Cron | `pg_cron` driving Edge Function HTTP triggers |
| Analytics | Lightweight in-process logger (`Analytics.swift`) — pluggable |
| Auth providers | Apple, Google, Phone (SMS OTP) |

The Supabase Swift SDK is exposed as a single global `supabase` constant (see `Apollo/Core/Network/SupabaseClient.swift`). Authentication state, session restore, and token refresh are entirely delegated to the SDK; the app never touches Keychain directly.

---

## High-level architecture

Apollo follows a **MVVM-with-Repositories** pattern:

```
View  ──────►  ViewModel  ──────►  Repository (protocol)
  ▲              (state)             │
  │                                  ├──► SupabaseXRepository (live)
  └──── @Observable / @Published     └──► MockXRepository      (previews / tests)
```

- **Views** are pure SwiftUI; one folder per feature in `Apollo/Features/`.
- **ViewModels** are `@Observable` + `@MainActor`. One per screen.
- **Repositories** are protocols. Each has a `Supabase…Repository` (production) and a `Mock…Repository` (SwiftUI previews + tests). The view model never sees Supabase directly.
- **Models** in `Apollo/Core/Models/` are `Sendable` value types shared across features.
- **`SessionStore`** owns the authoritative auth state. The root `ApolloApp` switches between `OnboardingFlow` and `RootTabView` based on it.
- **Realtime subscriptions** (new posts, reactions, comments, notifications) are owned by view models / `NotificationsService` and torn down on disappear / sign-out.

---

## Project structure

```
Apollo/
├── ApolloApp.swift                 # @main scene; swaps onboarding ↔ tabs
├── RootTabView.swift               # 5-tab shell (Feed, Friends, Camera, North, Profile)
├── Apollo.entitlements             # Sign in with Apple + APNs
├── Info.plist                      # URL schemes (auth + apollo://), permissions, fonts
│
├── Components/
│   └── Theme.swift                 # Color & font tokens
│
├── Core/
│   ├── Network/
│   │   ├── Config.swift            # (gitignored) Supabase URL + anon key
│   │   ├── SupabaseClient.swift    # global `supabase` constant
│   │   └── SessionStore.swift      # auth state, current user, avatar caching
│   ├── Models/                     # Sendable value types (FeedModels, CommentsModels, etc.)
│   ├── Repositories/               # Repository protocols + Supabase + Mock impls
│   ├── Camera/                     # AVFoundation session + image grader + upload queue
│   ├── Notifications/
│   │   ├── AppDelegate.swift       # APNs registration, tap handling
│   │   ├── NotificationsService.swift # Permission, local reminders, unread badge
│   │   ├── PushTokenRegistrar.swift   # Uploads device token to Supabase
│   │   ├── DeepLinkRouter.swift       # Routes apollo:// URLs to tabs / posts
│   │   └── ApolloNotifications.swift  # Notification.Name extensions
│   ├── Logging/                    # CameraLogger, DebugFileLogger
│   └── Analytics/Analytics.swift   # Event taxonomy + DEBUG print sink
│
├── Features/
│   ├── Onboarding/                 # Welcome, capture, wins, sign-in, phone OTP
│   ├── Feed/                       # The main social surface
│   ├── Camera/                     # Live viewfinder + capture review
│   ├── WinList/                    # Today + All wins, win details sheet
│   ├── Profile/                    # Banner, avatar, today's wins
│   ├── Friends/                    # Requests, recommended, search, invite
│   ├── Memories/                   # Calendar of past wins
│   ├── Notifications/              # Notification center + soft-permission UI
│   ├── North/                      # Tab placeholder (future)
│   └── Develop/                    # Polaroid-develop animation views
│
├── Resources/Fonts/                # Goudy Bookletter 1911
└── Assets.xcassets/                # Wordmark, icons, onboarding imagery

supabase/
├── config.toml                     # Local-dev project config
├── migrations/                     # SQL migrations (notifications, photo captions)
└── functions/
    ├── _shared/                    # APNs client + copy/deeplink builder
    ├── notifications-send/         # Fan-out + dedup + push delivery
    ├── notifications-cron-streak/  # 8pm/11pm habit reminders
    └── notifications-cron-north/   # Sunday weekly summary
```

---

## Design system

Defined in `Components/Theme.swift`.

| Token | Hex | Use |
|---|---|---|
| `apolloBackground` | `#080808` | App background |
| `apolloPrimaryText` | `#f3f3f3` | Primary copy |
| `apolloMuted` | `#252525` | Secondary copy |
| `apolloCaption` | `#b5b5b5` | Captions, body |
| `apolloSurface` | `#111111` | Elevated surfaces |
| `apolloBorder` | `#1a1a1a` | Hairline borders |
| `apolloSheetSurface` | `#212121` | Sheet & pill backgrounds |

Plus dedicated tokens for friends pills, win-details sheet, error toasts, reactions, and skeleton loaders.

**Typography**

- **Goudy Bookletter 1911 (Italic + Regular)** — decorative — bundled in `Resources/Fonts/` and registered via `UIAppFonts`. Helpers: `Font.goudyItalic(_:)`, `Font.goudyRegular(_:)`.
- **SF Pro** — system font for all UI.

**Rules**

- Minimum 44×44pt tap targets.
- No dividers — spacing only.
- Dark mode is enforced (`.preferredColorScheme(.dark)` at root).

---

## Implemented features

### 1. Onboarding & Authentication

`Apollo/Features/Onboarding/`

A 5-step `NavigationStack` flow, then sign-in:

1. **Welcome** — animated phone mockups (`OnboardingWelcomeView`).
2. **Capture preview** — "Every win. Documented." (`OnboardingCaptureView` + `OnboardingMatchaCrop`).
3. **Wins grid** — "Your Wins. Every Day." (`OnboardingWinsView` + `OnboardingWinsGrid`).
4. **Sign In** — Apple, Google, or Phone (`SignInView`).
5. **Phone Entry → OTP** — `PhoneEntryView` + `OtpVerificationView` (E.164 + 6-digit OTP).

**Auth backend** (`AuthService.swift`)
- **Apple**: `signInWithIdToken` using a `OpenIDConnectCredentials(.apple, idToken, nonce)` payload.
- **Google**: Supabase OAuth via `ASWebAuthenticationSession` and the `DariusEhsani.Apollo://auth/callback` redirect.
- **Phone**: `signInWithOTP` then `verifyOTP(.sms)`.
- **Sign in with Apple** capability is enabled in `Apollo.entitlements`.

`SessionStore` listens to `supabase.auth.authStateChanges` and flips the root view from `OnboardingFlow` to `RootTabView` automatically — no manual `AppStorage` flags. It also pre-decodes the user's avatar into a circle-masked `UIImage` so it can be used directly in the SwiftUI tab bar's `tabItem`.

### 2. Feed

`Apollo/Features/Feed/`  ·  PRD `01-feed.md`

The primary social surface — a chronological stream of friends' daily wins.

**State machine** (`FeedViewModel.Phase`): `.loading`, `.loaded`, `.empty`, `.partial`, `.yesterdayEmpty`, `.error`.

**Tabs**: `Now` (today) / `Yesterday` (previous calendar day).

**Card composition** (`PostCard`):
- `PostHeader` — avatar (circle), username, time, current streak, ··· menu.
- `PhotoArea` — main photo (single) or `PhotoTower` (1 large + scrollable column of additional photos, pre-scrolled to bottom so the newest is visible).
- `CaptionView` / `CaptionStackView` — per-photo captions stacked above the reactions row.
- `GroupedReactionsLine` / `ReactionsLine` — emoji counts grouped by reactor with avatars.
- `ActionRow` — comment + reaction picker entry points.

**Behaviors**
- Cursor-based pagination (`FeedCursor`, page size 20, prefetch trigger 3 from end).
- Pull-to-refresh.
- Realtime: a buffered "New posts" banner appears when friends post while you're scrolling; tapping it merges them in with animation.
- Optimistic reactions and deletions; rollback on error.
- Inline error toast with "Try again" affordance.
- "End of feed" includes a rotating daily quote for an intentional terminal state.
- ··· action sheet — owner sees Edit / Share strip / Delete (with destructive confirmation alert); other users see Share / Report.
- Tapping a photo opens `FullScreenPhotoViewer` (multi-photo paging, captions overlay).
- Tapping a comment, reactions line, or reaction pill routes to the appropriate sheet.

**Empty / error states**: `EmptyFeedView`, `EndOfFeedView`, `PartialEmptyView`, `YesterdayEmptyView`, `ErrorToast`, `FeedSkeleton` (pulsing skeletons matching post layout).

### 3. Camera & Capture flow

`Apollo/Features/Camera/`  ·  `Apollo/Core/Camera/`  ·  `Apollo/Features/Develop/`  ·  PRDs `02-camera.md` + `03-capture_screen.md`

Apollo's capture surface is a full-screen modal opened by tapping the center "Camera" tab. The tab bar intercepts the selection and presents the camera as `fullScreenCover`.

**Pipeline**

1. **`CameraSession`** — `AVCaptureSession` lifecycle + permission gating. Tap-to-focus + pinch-to-zoom + manual exposure bias.
2. **`CameraView`** — viewfinder (4:5 aspect), flash toggle, "Shooting for [win]" label, max-photos label, shutter, flip, swipe-down-to-dismiss.
3. **`CameraCaptureReviewView`** — instant retake / use-photo decision after shutter tap.
4. **`DevelopView`** — Polaroid develop animation; user shakes or rubs the photo to develop it (`ShakeDetector` + drag gesture). Ends with a checkmark to confirm.
5. **`CameraImageGrader`** — applies Apollo's signature warm-grade Core Image pipeline.
6. **`UploadQueue`** — background-friendly queue posting the rendered image to Supabase Storage and calling the `publish_photo` RPC.

**Win selection**

Tapping the "Shooting for" label opens `WinPickerSheet` (uses `WinListView` in selection mode). The chosen win is attached to the photo so `publish_photo` can log a `win_completion` and bump the streak.

**Limits**

- `MaxPhotosPerDay = 6` (`FeedModels.swift`). The `MaxedOutLabel` is shown when the user hits the cap.

### 4. Win List

`Apollo/Features/WinList/`  ·  PRD `04-win_list.md`

Two-tab list of habits to win.

- **Tabs**: `Today` (only wins not yet completed) / `All Wins`.
- **`WinRowView`** — name, current streak, S/M/L size pill, tappable circle to mark complete, swipe-to-edit.
- **`WinInputField`** — pinned input bar above safe area for quick add.
- **Repeat schedules**: Just once / Every day / Once a week / Pick days (custom days-of-week).
- **Reminders**: per-win local notifications scheduled via `NotificationsService.scheduleWinReminder`.

When opened from the Camera, taps return the chosen `WinListItem` to the camera via the `onSelectWin` callback instead of navigating away.

### 5. Win Details

`Apollo/Features/WinList/WinDetailsView.swift`  ·  PRD `05-win_details_screen.md`

Bottom sheet (`.large` detent) used for both creating and editing a win.

Sections: name field · S/M/L size selector · Repeat picker (+ day selector if "Pick days") · Remind me (+ time picker if on) · Mark as done (in edit mode if not yet completed today) · Delete win.

Tapping "Mark as done" calls the same `publish_photo`-equivalent path so it counts toward the streak.

### 6. Profile

`Apollo/Features/Profile/`  ·  PRD `06-profile-screen.md`

Single screen for both the **signed-in user's own profile** (own profile = tab bar entry) and **other users** (pushed from a feed avatar tap). Signed-in user gets editing affordances; viewers don't.

- **`ProfileHeaderView`** — banner image, avatar, username, total wins, streak, calendar icon.
- **`ProfileBannerView`** — taps open an action sheet:
  1. *Choose from camera roll* (`PhotosPicker`)
  2. *Choose from my wins* (grid picker over the user's recent posts)
  3. *Reset to auto* (regenerates the banner from recent photos)
- **Avatar** — `PhotosPicker` → resize → upload to the `avatars` Storage bucket → broadcast `apolloProfileShouldRefresh`.
- **`TodaysWinsSection`** — 1×N grid of the user's posts from today.
- **Memories button** — pushes `MemoriesView` (calendar) for the signed-in user.
- **Pull to refresh**, upload-progress overlay banners.

### 7. Friends

`Apollo/Features/Friends/`  ·  PRD `07-friends-screen.md`

A search-first social graph screen.

- **`FriendsHeroBar`** — "Connect" hero + QR action.
- **`FriendsSubTabs`** — Friends / Challenges.
- **`FriendsSearchBar`** — debounced search; results replace the main sections while text is present.
- **Sections** when not searching:
  - **Requests** — incoming requests with Accept / Decline (`FriendRequestRow`).
  - **Recommended** — server-ranked suggestions (`RecommendedFriendRow`).
  - **Invite Card** — share/copy invite code (`InviteCard` — fires `inviteCodeCopied` / `inviteCodeShared`).
  - **Invite Friends** — contacts list with one-tap SMS invite (`InviteContactRow`).
- Search results render `SearchResultRow` with optimistic add.
- Soft-permission banner at the top when notifications are denied (`SoftPermissionBanner`).
- Optimistic actions; transient toast on failure.

### 8. Reactions system

PRD `08-reaction-systems.md`

- Picker emojis: ❤️, 🔥, 👑, plus a **+ button** that opens `EmojiPickerSheet` for any custom emoji.
- One reaction per user per post. Tapping the same emoji again removes it.
- Optimistic counts via `Post.reactionCountsByEmoji` and the Realtime `reactions` subscription.
- **Reactions Breakdown sheet** (`ReactionsBreakdownSheet`) — shows every reactor grouped by emoji with filter tabs.
- **Grouped reactors line** — "alex, sam, and 12 others reacted" with avatar stack on the post card.
- Analytics: `post_reaction_added`, `post_reaction_removed`, `breakdown_opened`, `breakdown_filtered`, `custom_emoji_used`.

### 9. Comments system

`Apollo/Features/Feed/CommentsViewModel.swift` + `Sheets/CommentsSheet.swift`  ·  PRD `09-comment-system.md`

- Bottom sheet keyboard-aware list of comments and replies (1-level threading).
- `CommentRow` with avatar, username, body, time, reaction strip, reply CTA.
- `CommentsInputBar` — composer with reply context, emoji shortcut, send button.
- `CommentSkeleton` for loading state.
- Comment reactions (any emoji) using the same model as post reactions.
- Server-side profanity check returns `CommentsRepositoryError.profanityBlocked`, surfaced inline.
- Triggers `apolloPostCommitted` / notifications when posted.
- Analytics: `comments_opened`, `comment_submitted`, `comment_deleted`, `reply_started`.

### 10. Notifications system

`Apollo/Core/Notifications/`  ·  `Apollo/Features/Notifications/`  ·  `supabase/migrations/20260510000001_notifications.sql`  ·  `supabase/functions/`  ·  PRD `10-notification-system.md`

End-to-end push + in-app notification system.

**iOS side**

- `NotificationsService` — singleton owning permission state, the unread badge, local habit reminders, and the post-first-win permission prompt.
- `AppDelegate` — registers for APNs, hands taps to `DeepLinkRouter`.
- `PushTokenRegistrar` — uploads the device token to `public.push_tokens`.
- `DeepLinkRouter` — decodes `apollo://` URLs (`feed/post/{id}?openComments=1`, `friends`, `north`, `notifications`).
- `EnableNotificationsPromptView` — first-win soft prompt; presented as a `.55` fraction sheet after the first post.
- `SoftPermissionBanner` — re-prompt placed in Friends when the user has denied permission.
- `NotificationsView` (Notification Center) — pushed from Feed's bell icon. Marks all read on open. Empty state, error state, skeleton loader.
- `NotificationRow` — type-aware copy + actor avatar + tap-to-deep-link.

**Local reminders**

- 8pm "Win every day." and 11pm "Don't break it." daily reminders.
- Cancelled automatically when the user posts (`apolloPostCommitted` listener).
- Per-win reminders scheduled from Win Details (daily / weekly / once).

**Supported notification types**

`reaction`, `comment`, `reply`, `friend_request`, `friend_accept`, `first_win_today`, `milestone_7`, `milestone_30`, `milestone_100`, `milestone_friend_7`, `habit_no_post`, `habit_streak_break`, `win_reminder`, `north_weekly`.

**Server side** (Supabase)

- Tables: `notifications` (RLS: read/update own), `push_tokens` (RLS: manage own), `notification_prefs` (auto-created via trigger), `notification_quota` (service-role only).
- Triggers: reaction insert → `reaction`; comment insert → `comment` or `reply` (parent_id branch); friendship insert/update → `friend_request` / `friend_accept`; post insert → `first_win_today` + `milestone_check` (only when it's the user's first post of the day).
- `fire_notification_event` (PL/pgSQL) → `extensions.net.http_post` → `notifications-send` Edge Function.
- **Edge Function `notifications-send`** — applies dedup, quiet-hours, daily caps (20 social, 2 habit per PRD §6), inserts the in-app row, and sends APNs pushes for each active token.
- **Edge Function `notifications-cron-streak`** — runs every 15 min via `pg_cron`; emits 8pm / 11pm habit reminders honoring the user's timezone & quiet hours.
- **Edge Function `notifications-cron-north`** — runs Sunday 9am UTC; emits weekly North summary.
- **Retention** — `pg_cron` purges notifications older than 30 days nightly at 3am UTC.

### 11. Memories / Calendar

`Apollo/Features/Memories/`  ·  PRD `11-memories-calendar-screen.md`

A scrollable history of every day the user has posted, grouped by month.

- `MemoriesView` — `LazyVStack` of `MonthSectionView` blocks, infinite-scroll older months.
- `MonthSectionView` — Goudy month header (e.g. "May 2026") + 7-column UTC calendar grid with `DayTileView` cells.
- `DayTileView`:
  - Days with posts → first photo as a thumbnail; tap opens `FullScreenPhotoViewer` over all photos for that day.
  - Today → highlighted ring.
  - Empty days → minimal placeholder.
- Analytics: `memories_opened`, `calendar_tile_tapped`, `calendar_scrolled`.

### 12. Deep linking

Two URL schemes registered in `Info.plist`:

- **`DariusEhsani.Apollo://`** — the OAuth/auth callback used by Supabase + Google.
- **`apollo://`** — used by push payloads for in-app routing. Parsed by `NotificationDeepLink.from(urlString:)`.

`DeepLinkRouter.shared` is observed by `RootTabView` (tab switch) and `FeedView` (post focus + comments sheet).

### 13. Analytics

`Apollo/Core/Analytics/Analytics.swift` defines a typed event taxonomy spanning Feed, Camera, Comments, Reactions, Memories, Friends, and Notifications. The default sink simply prints in `DEBUG` builds; it's a one-line swap to forward to Amplitude / Mixpanel / PostHog.

---

## Supabase backend

### Tables (highlights)

| Table | Purpose |
|---|---|
| `auth.users` | Supabase-managed identity. |
| `users` | Public profile (username, handle, avatar_url, total_wins). Auto-populated via `on_auth_user_created` trigger. |
| `posts` | One row per user per UTC date (unique on `user_id, post_date`). Stores caption, photo_count, win_count, main_photo_url. |
| `photos` | Multiple per post; stores raw_url, position, captured_at, **caption** (per-photo), win_id. |
| `reactions` | Per user per post emoji reaction. |
| `comments` | Threaded comments (1-level via `parent_id`). |
| `friendships` | Status: `pending` / `accepted`. |
| `streaks` | Materialized current_streak per user. |
| `wins` | Habits the user is tracking (size, repeat_schedule, repeat_days, remind_me). |
| `win_completions` | One per win per UTC day. |
| `notifications` | In-app notification rows (RLS, 30-day retention). |
| `push_tokens` | APNs tokens (active vs disabled). |
| `notification_prefs` | Per-user notification preferences. |
| `notification_quota` | Daily quota tracking (service-role only). |

### Views

- **`feed_posts`** — primary read surface for the Feed. Joins posts → users → streaks; aggregates `photo_urls`, `photo_captions` (per-photo), `reaction_count`, `comment_count`, `wins_count`.

### RPC functions

- **`publish_photo(user_id, caption, raw_url, win_id, captured_at, post_date)`** — upserts today's post, inserts a `photos` row at the next position, dual-writes the caption, logs a `win_completion`, and increments `users.total_wins`. Single round-trip per shutter tap.
- **`increment_notification_quota(user_id, day, is_social)`** — service-role only; used by `notifications-send` to enforce daily caps.
- **`fire_notification_event(jsonb)`** — fan-out helper that POSTs to the Edge Function via `pg_net`.

### Storage buckets

- `avatars` — user profile pictures.
- `banners` — profile banner images.
- `photos` — daily win photos (referenced from `photos.raw_url`).

### Edge Functions

| Function | Trigger | Purpose |
|---|---|---|
| `notifications-send` | DB triggers via `pg_net` | Apply rules, insert in-app row, push via APNs. |
| `notifications-cron-streak` | `pg_cron` every 15 min | Habit reminders at 8pm / 11pm local. |
| `notifications-cron-north` | `pg_cron` Sunday 09:00 UTC | Weekly North summary. |

### Auth providers

Configured in `supabase/config.toml`:

- Apple (env-templated client_id + secret).
- Google (manually configured in dashboard).
- Phone (Twilio / MessageBird / Vonage as SMS provider).

Allowed redirect URLs include `DariusEhsani.Apollo://auth/callback`.

---

## Running the app

### Prerequisites

- Xcode 15+ on macOS 14+.
- An iOS 17+ simulator or device.
- A Supabase project (or the local Supabase CLI stack).

### Local setup

1. **Clone**
   ```bash
   git clone <repo-url>
   cd Apollo
   ```

2. **Create `Apollo/Core/Network/Config.swift`** (gitignored) with your project's URL + anon key:
   ```swift
   import Foundation

   enum Config {
       static let supabaseURL = URL(string: "https://YOUR_PROJECT.supabase.co")!
       static let supabaseAnonKey = "YOUR_ANON_KEY"
   }
   ```

3. **Apply migrations** to your project:
   ```bash
   supabase db push
   ```

4. **Configure auth providers** in the Supabase dashboard
   (Apple, Google, Phone — see `Apollo/Features/Onboarding/AuthService.swift` for the full external-setup checklist).

5. **Set the notifications database settings** before applying the notifications migration:
   ```sql
   ALTER DATABASE postgres SET app.settings.supabase_url       TO 'https://YOUR_PROJECT.supabase.co';
   ALTER DATABASE postgres SET app.settings.service_role_key   TO 'YOUR_SERVICE_ROLE_KEY';
   ```

6. **Deploy Edge Functions**:
   ```bash
   supabase functions deploy notifications-send
   supabase functions deploy notifications-cron-streak
   supabase functions deploy notifications-cron-north
   ```

7. **Open `Apollo.xcodeproj`** and run on a simulator or device.

> The Camera and Push Notifications features both require a real device to fully exercise.

---

## Conventions

- **One ViewModel per screen** — `@Observable`, `@MainActor`.
- **Repositories everywhere** — every feature has a protocol + Supabase impl + Mock impl. Mocks power SwiftUI previews and unit tests.
- **Async/await** for every Supabase call.
- **Optimistic updates** for reactions, comments, win completions, and friend actions; rollback on failure with a transient `ErrorToast`.
- **Kingfisher's `KFImage`** for every remote image except the tab-bar avatar (which has to be a pre-decoded `UIImage` for `tabItem`).
- **No dividers** — spacing only.
- **Dark mode locked** at the root (`.preferredColorScheme(.dark)`).
- **PRDs in `Prompts/`** are the source of truth for behavior, copy, and acceptance criteria. They are not committed (see `.gitignore`).
- **Secrets** (`Apollo/Core/Network/Config.swift`) are never committed.

---

_Built with ❤️ on SwiftUI + Supabase._
