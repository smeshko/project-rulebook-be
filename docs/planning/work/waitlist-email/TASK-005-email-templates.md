## TASK-005: Add Waitlist Email Templates

---
**Status:** OPEN
**Branch:** feature/waitlist-email
**Type:** IMPLEMENTATION
**Phase:** 1
**Depends On:** None
---

### Overview

Add HTML email templates for waitlist confirmation and launch notification emails. Both templates include an unsubscribe link in the footer.

**Files:**
- `Sources/App/Services/Email/Helpers/Templates.swift` (modify)

### Implementation Steps

**Commit 1: Add waitlist email templates**
- [ ] Add `waitlistConfirmation(unsubscribeToken:baseURL:)` static method
- [ ] Add `waitlistLaunchNotification(unsubscribeToken:baseURL:)` static method
- [ ] Include unsubscribe link in footer of both templates
- [ ] Use same HTML structure as existing verifyEmail template
- [ ] Keep content simple/placeholder per requirements

### Code Example

```swift
// Add to Templates.swift after existing templates
// Sources/App/Services/Email/Helpers/Templates.swift

static func waitlistConfirmation(unsubscribeToken: String, baseURL: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="x-ua-compatible" content="ie=edge">
      <title>Welcome to the Waitlist</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style type="text/css">
      /* Same styles as verifyEmail template */
      body { width: 100% !important; padding: 0 !important; margin: 0 !important; }
      </style>
    </head>
    <body style="background-color: #e9ecef;">
      <div class="preheader" style="display: none;">You're on the waitlist!</div>
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <tr>
          <td align="center" bgcolor="#e9ecef">
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px;">
              <tr>
                <td align="left" bgcolor="#ffffff" style="padding: 36px 24px 0; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; border-top: 3px solid #d4dadf;">
                  <h1 style="margin: 0; font-size: 32px; font-weight: 700;">You're on the Waitlist!</h1>
                </td>
              </tr>
              <tr>
                <td align="left" bgcolor="#ffffff" style="padding: 24px; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; font-size: 16px; line-height: 24px;">
                  <p>Thanks for signing up! We'll notify you when the app is ready to launch.</p>
                </td>
              </tr>
              <tr>
                <td align="center" bgcolor="#ffffff" style="padding: 24px; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; font-size: 12px; color: #666;">
                  <a href="\\(baseURL)/api/waitlist/unsubscribe/\\(unsubscribeToken)" style="color: #666;">Unsubscribe from this list</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
}

static func waitlistLaunchNotification(unsubscribeToken: String, baseURL: String) -> String {
    """
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <meta http-equiv="x-ua-compatible" content="ie=edge">
      <title>We're Live!</title>
      <meta name="viewport" content="width=device-width, initial-scale=1">
      <style type="text/css">
      body { width: 100% !important; padding: 0 !important; margin: 0 !important; }
      </style>
    </head>
    <body style="background-color: #e9ecef;">
      <div class="preheader" style="display: none;">The app is now live!</div>
      <table border="0" cellpadding="0" cellspacing="0" width="100%">
        <tr>
          <td align="center" bgcolor="#e9ecef">
            <table border="0" cellpadding="0" cellspacing="0" width="100%" style="max-width: 600px;">
              <tr>
                <td align="left" bgcolor="#ffffff" style="padding: 36px 24px 0; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; border-top: 3px solid #d4dadf;">
                  <h1 style="margin: 0; font-size: 32px; font-weight: 700;">We're Live!</h1>
                </td>
              </tr>
              <tr>
                <td align="left" bgcolor="#ffffff" style="padding: 24px; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; font-size: 16px; line-height: 24px;">
                  <p>Great news! The app is now available. Thank you for your patience!</p>
                </td>
              </tr>
              <tr>
                <td align="center" bgcolor="#ffffff" style="padding: 24px; font-family: 'Source Sans Pro', Helvetica, Arial, sans-serif; font-size: 12px; color: #666;">
                  <a href="\\(baseURL)/api/waitlist/unsubscribe/\\(unsubscribeToken)" style="color: #666;">Unsubscribe</a>
                </td>
              </tr>
            </table>
          </td>
        </tr>
      </table>
    </body>
    </html>
    """
}
```

### Success Criteria

- [ ] Build succeeds
- [ ] Both templates render valid HTML
- [ ] Unsubscribe link included in footer
- [ ] String interpolation works for token and baseURL

### Verification

```bash
swift build
```

### Notes

- Keep content simple as requested - user will refine later
- Unsubscribe URL format: `{baseURL}/api/waitlist/unsubscribe/{token}`
- Escape backslashes in Swift string interpolation: `\\(variable)`
- Can copy full CSS from existing templates for better formatting
