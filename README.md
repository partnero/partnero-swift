# Partnero Swift SDK

Attribute iOS app users to your [Partnero](https://www.partnero.com) partners. When a user enters a partner's code or opens a partner's link, the SDK claims them for that partner. Their in-app purchases then earn the partner commission, recorded by Partnero's RevenueCat integration or by your backend.

- iOS 15+ and macOS 12+, Swift 6, Xcode 16+
- No dependencies, no analytics and no background work
- Uses only your program's **Program ID**. Never put your Partnero API key in an app.

## Before you start

In Partnero, go to your program's **Integration → Security** page and turn on **Enable mobile app claims** under **Mobile apps**. Until then, every claim fails with `codeNotFound`. The same page has an optional claim window, in days after the app's first launch.

Copy your **Program ID** from the program's **Integration** page in Partnero. It's the same ID as in your PartneroJS snippet.

## Install

In Xcode, choose **File → Add Package Dependencies** and enter:

```
https://github.com/partnero/partnero-swift
```

Or add it to `Package.swift`:

```swift
.package(url: "https://github.com/partnero/partnero-swift", from: "0.1.0")
```

## Configure

Call `configure` once at launch, before any claim:

```swift
import Partnero

Partnero.configure(programId: "YOUR_PROGRAM_ID")
```

The first call records the date the app was first opened on this device. If the program has a claim window, Partnero rejects claims made more than that many days after it.

If your referral links use a parameter other than `ref`, such as `?aff=SAM20`, pass it as `referralParameter: "aff"`. Pass `baseURL` only to point at a staging server.

## Claim a code

Pass the code the user entered, and the ID your purchases are reported under:

```swift
do {
    let result = try await Partnero.claim(code: "SAM20", appUserId: user.id)

    switch result.status {
    case .claimed: break        // attributed to the code's partner
    case .alreadyClaimed: break // was attributed already; nothing changed
    }
} catch PartneroError.codeNotFound {
    // show "That code isn't valid"
} catch {
    // network or server error; let the user try again
}
```

A user can only be claimed once. Claiming again, with any code, returns `.alreadyClaimed`.

The app user ID must be an email address, or letters, numbers, `-`, `_` and `.`. With RevenueCat, claim after `Purchases.shared.logIn(...)`: anonymous IDs such as `$RCAnonymousID:…` are rejected, because they change when the app is reinstalled.

If a code is used as both a partner's link key and a promotion code, say which one the user entered:

```swift
try await Partnero.claim(code: "SAM20", appUserId: user.id, codeType: .promotionCode)
```

Without it, a code that matches two different partners fails with `codeConflict`.

## Claim from a link

When the app opens from a referral link, such as a universal link or a custom URL scheme:

```swift
.onOpenURL { url in
    Task {
        try? await Partnero.claim(url: url, appUserId: user.id)
    }
}
```

The code is read from the link's query string, such as `https://example.com/?ref=SAM20`. `claim(url:)` returns `nil` without calling Partnero when the link has no code. If the user isn't signed in yet, read and store the code with `Partnero.code(from: url)`, and claim it after sign-in.

## RevenueCat

In Partnero, connect RevenueCat under **Payment processors** on your program's **Integration** page, so purchases, renewals and refunds are recorded automatically.

Also store the code as a subscriber attribute. If a claim never reaches Partnero, for example because the device was offline, the first purchase still finds the partner. This also needs **Enable mobile app claims** turned on.

```swift
Purchases.shared.attribution.setAttributes(Partnero.revenueCatAttributes(code: "SAM20"))
```

## Errors

| Error | Meaning |
| --- | --- |
| `notConfigured` | `configure` hasn't been called |
| `invalidInput(field:)` | A blank or malformed value. `field` says which one, such as `.code`, `.appUserId` or `.programId`. Checked before any request when possible. |
| `codeNotFound` | No active code matches, or mobile claims are off for the program |
| `codeConflict(message:)` | The code matches more than one partner (pass a `codeType`), or the program's claim window has closed for this install |
| `rateLimited` | More than 30 claims a minute from one network for the program. Try again in a minute. |
| `network(message:)` | The request didn't reach Partnero |
| `server(status:message:)` | Any other response |

Cancelling the task throws `CancellationError`. The SDK never retries on its own: your app decides whether and when to try again.

## Privacy

The SDK sends Partnero the code, the app user ID, the platform and the first launch date, and nothing else. It stores only the first launch date, in `UserDefaults`. It doesn't track users across apps or websites, and it ships a privacy manifest that declares the app user ID and its `UserDefaults` use.

List the user ID under **App Functionality** in your App Store privacy details if you don't already.

## License

MIT
