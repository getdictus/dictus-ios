# Feature Landscape

**Domain:** iOS Dictation App Premium Tier (Dictus Pro v1.5)
**Researched:** 2026-04-08
**Focus:** StoreKit 2 subscription, Smart Mode LLM reformulation, transcription history with search/export, custom vocabulary, paywall UI

## Table Stakes

Features users expect from a premium dictation/voice app tier in 2026. Missing = users won't pay.

| Feature | Why Expected | Complexity | Notes |
|---------|--------------|------------|-------|
| Subscription with restore purchases | Every premium iOS app has this. Apple requires restore. | Med | StoreKit 2 native async/await API. No RevenueCat needed for single-tier. |
| Paywall showing clear value | Users must see what they get before paying. Wispr, Otter, SuperWhisper all do this. | Low | Soft paywall after onboarding or on first Pro feature tap. Show benefits, not features. |
| Free trial (7-14 days) | Wispr Flow gives 14-day trial. Otter gives 300 min/month free. Users expect to try before buying. | Low | StoreKit 2 supports introductory offers natively. 7 days recommended (shorter commitment). |
| Transcription history (basic list) | Google Eloquent, Otter, Spokenly, SuperWhisper all show history. Users expect to find past dictations. | Med | SwiftData local store. Free tier gets list view with last 50 entries. |
| Custom vocabulary / personal dictionary | Otter Pro has 200 custom words. Google Eloquent has personal context dictionary. Wispr Flow has custom dictionary on all plans. | Med | WhisperKit initialPrompt injection. Argmax confirms custom vocab "surpasses standard offerings" in keyword accuracy. |
| Text reformulation / cleanup | Google Eloquent does "Formal", "Short", "Long", "Key points" post-dictation. Wispr Flow Command Mode rewrites selected text. This is now baseline for premium dictation. | High | On-device LLM required. Apple Foundation Models (iOS 26+) or downloadable open-source model. |
| Graceful feature gating | Free users see what Pro offers without being blocked aggressively. Soft paywall, not hard lock. | Low | Feature flags in DictusCore via App Group. Beta override for testing. |

## Differentiators

Features that set Dictus Pro apart from competitors. Not universally expected but highly valued.

| Feature | Value Proposition | Complexity | Notes |
|---------|-------------------|------------|-------|
| 100% on-device LLM reformulation | Wispr Flow uses cloud AI. Otter uses cloud. Only Google Eloquent offers offline reformulation (but limited). Dictus Pro = zero data leaves the phone. | High | Apple Foundation Models (3B params, on-device) for iPhone 15 Pro+. Open-source fallback (Gemma 3 1B, Mistral) for older devices. |
| French-first Smart Mode templates | No competitor offers French-optimized email/SMS/notes/summary templates. Wispr is English-first. Otter is English-first. | Med | Template prompts in French. "Reformule en email professionnel", "Resume en 3 points", etc. |
| Full-text search across transcription history | Otter Pro has this. SuperWhisper has search. Google Eloquent has search. But combined with on-device = privacy differentiator. | Med | SwiftData with FTS (full-text search) on transcription content. Pro-only feature. |
| Export transcriptions (txt, clipboard, share sheet) | Otter Pro exports. Spokenly exports. Basic but valued by power users. | Low | iOS share sheet integration. Pro-only. |
| Custom vocab as contextual sentences | fazm-style approach: "Mon fils s'appelle Raphaël" vs flat word list "Raphaël". Context sentences in initialPrompt give Whisper better accuracy than isolated words. | Low | UI: text field for contextual phrases, stored in App Group. Injected as initialPrompt prefix. |
| Open Core transparency | Code is MIT, Pro gated by StoreKit 2 entitlement. Users can audit what runs on their device. No competitor offers this. | Low | Already decided. Marketing differentiator, not engineering effort. |
| Keyboard-integrated reformulation | Dictate, then tap "Smart Mode" template directly from keyboard overlay, get reformulated text inserted at cursor. No app-switching. | High | Requires LLM inference accessible from keyboard context (tricky with 50MB limit -- must run in main app process). |

## Anti-Features

Features to explicitly NOT build in this milestone.

| Anti-Feature | Why Avoid | What to Do Instead |
|--------------|-----------|-------------------|
| Cloud-based reformulation | Contradicts Dictus privacy identity. Would require server infrastructure, accounts, GDPR compliance. | On-device only. Apple Foundation Models + downloadable open-source models. |
| RevenueCat / third-party subscription SDK | Single tier, iOS-only. RevenueCat adds SDK dependency, 1% rev share above $2.5K/mo. Overkill for one subscription product. | Native StoreKit 2. Async/await API is clean enough for single tier. Add RevenueCat later if multi-platform or A/B testing paywalls needed. |
| Multiple subscription tiers at launch | Complexity: different feature gates, pricing psychology, support burden. No data yet on what users value most. | Single "Dictus Pro" tier (~4-5 EUR/month). Split into tiers (Pro / Pro Expert) later based on actual usage data. |
| Lifetime purchase option | Unpredictable revenue. SuperWhisper offers $249 lifetime but they have broader platform. Too risky for a new product. | Monthly + annual only. Annual at ~20% discount (standard App Store pattern). |
| Audio file import/transcription | Different UX flow, storage concerns, not core keyboard dictation value. | Defer to backlog. Focus on live dictation workflow. |
| Voice commands during dictation | "Make this more formal" while speaking. Wispr Flow does this but requires sophisticated voice activity detection + command parsing. | Post-dictation templates only. User dictates, then picks a Smart Mode template. Simpler, more reliable. |
| Real-time streaming reformulation | Reformulating text as user speaks. Latency issues, confused UX, LLM can't reformulate incomplete thoughts. | Batch reformulation after dictation complete. |
| Meeting transcription / recording | Otter's domain. Different product category entirely. | Stay focused on keyboard dictation. |
| Multi-format export (.docx, .pdf) | Over-engineering for v1.5. Most users just need clipboard or share sheet. | Plain text + share sheet. Add formats later if demanded. |
| Server-side receipt validation | Only needed if you have a backend or suspect fraud at scale. StoreKit 2 does local JWS verification. | Local JWS verification via StoreKit 2. No server needed. |

## Feature Dependencies

```
StoreKit 2 SubscriptionManager → Paywall UI (needs product info to display)
StoreKit 2 SubscriptionManager → Feature gating (all Pro features check entitlement)
Feature gating → Smart Mode (Pro-only)
Feature gating → History search/export (Pro-only, basic list is free)
Feature gating → Custom vocabulary (Pro-only)

Transcription history (basic) → History search (FTS index on same data)
Transcription history (basic) → History export (operates on stored data)

Smart Mode LLM → Apple Foundation Models integration (iOS 26+ path)
Smart Mode LLM → Open-source model download + inference (fallback path)
Smart Mode LLM → Template system (prompts for email/SMS/notes/summary)

Custom vocabulary → WhisperKit initialPrompt injection
Custom vocabulary → App Group storage (keyboard reads, app writes)

Paywall UI → SubscriptionManager (purchase flow)
Paywall UI → Feature descriptions (what Pro unlocks)
```

## MVP Recommendation

**Phase 1 -- Infrastructure (build first, everything depends on it):**
1. **SubscriptionManager + StoreKit 2** -- every Pro feature gates on this
2. **Feature gating system** -- boolean checks in DictusCore, App Group synced
3. **Paywall UI** -- soft paywall, shown on first Pro feature tap

**Phase 2 -- Quick wins (visible Pro value with moderate effort):**
4. **Transcription history** -- free list view + Pro search/export
5. **Custom vocabulary** -- small UI, high perceived value, proven accuracy boost

**Phase 3 -- Hero feature (highest complexity, highest value):**
6. **Smart Mode LLM** -- Apple Foundation Models primary path, open-source fallback
   - Start with 2 templates (email formal, SMS casual) to validate UX
   - Add notes/summary templates after validation

**Rationale:** Subscription infrastructure must exist before any Pro feature can be gated. History and custom vocab are medium-complexity with clear user value -- they justify the subscription while Smart Mode (the hardest feature) is being built. Smart Mode last because it has the most unknowns (device compatibility, model quality for French, inference latency, memory constraints).

Defer to next milestone:
- **Professional dictionaries** (medical, legal) -- Pro Expert tier
- **Continuous long dictation** (>5 min chunked) -- Pro Expert tier
- **Contextual reformulation** ("make shorter", "more formal" as voice commands) -- after Smart Mode validated

## Competitive Positioning

| Feature | Dictus Pro | Wispr Flow ($15/mo) | Otter Pro ($8.33/mo) | SuperWhisper ($8.49/mo) | Google Eloquent (free) |
|---------|-----------|-------------------|--------------------|-----------------------|----------------------|
| Price | ~4-5 EUR/mo | $15/mo | $8.33/mo annual | $8.49/mo | Free |
| On-device STT | Yes | Yes | No (cloud) | Yes | Yes |
| On-device LLM | Yes | No (cloud) | No (cloud) | No | Partial (optional cloud) |
| French-first | Yes | No (multi-lang) | No (English-first) | No (multi-lang) | No (English-first) |
| Custom vocab | Contextual sentences | Custom dictionary | 200 words | No | Personal dictionary |
| History + search | Yes (Pro) | Yes | Yes | Yes | Yes |
| Open source | Yes (MIT) | No | No | No | No |
| iOS keyboard | Yes (custom AZERTY) | iOS keyboard (2025) | No (app only) | No (app only) | No (app only) |
| Offline-only option | Yes (always) | No | No | Partial | Optional |

**Dictus Pro's unique angle:** The only open-source, 100% on-device, French-first dictation keyboard with LLM reformulation. Priced below all paid competitors. Privacy is not a feature -- it's the architecture.

## Sources

- [Wispr Flow pricing](https://wisprflow.ai/pricing) -- $15/mo Pro, 14-day trial, custom dictionary on all plans, Command Mode for text reformulation
- [Wispr Flow Command Mode](https://docs.wisprflow.ai/articles/4816967992-how-to-use-command-mode) -- highlight text + voice command for reformulation
- [SuperWhisper pricing](https://superwhisper.com/) -- $8.49/mo or $249 lifetime, recording history, search, presets
- [Otter.ai pricing](https://otter.ai/pricing) -- Pro $16.99/mo ($8.33 annual), 200 custom vocabulary words, advanced search
- [Google AI Edge Eloquent](https://techcrunch.com/2026/04/07/google-quietly-releases-an-offline-first-ai-dictation-app-on-ios/) -- free, offline, personal dictionary, history+search, 4 text transformation tools (Key Points, Formal, Short, Long)
- [Apple Foundation Models](https://machinelearning.apple.com/research/apple-foundation-models-2025-updates) -- 3B on-device model, iOS 26, @Generable structured output, guided generation
- [Foundation Models framework tutorial](https://www.createwithswift.com/exploring-the-foundation-models-framework/) -- SystemLanguageModel, LanguageModelSession, streaming, tool calling
- [WhisperKit custom vocabulary](https://arxiv.org/html/2410.18363v1) -- contextual biasing via initialPrompt improves domain-specific keyword accuracy
- [StoreKit 2 paywall best practices](https://www.revenuecat.com/blog/engineering/storekit-views-guide-paywall-swift-ui/) -- fetch products early, soft paywall after value shown, always provide restore
- [RevenueCat vs native StoreKit 2](https://nativelaunch.dev/articles/compare/revenuecat-vs-native-iap) -- native feasible for single-tier iOS-only, RevenueCat for multi-platform/A/B testing
- [Soft vs hard paywalls](https://azamsharp.com/2025/12/27/storekit-subscriptions-soft-vs-hard-paywalls.html) -- soft paywall recommended for utility apps
