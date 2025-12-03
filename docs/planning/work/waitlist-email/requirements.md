---
type: feature
status: draft
priority: P2
created: 2025-12-03
slug: waitlist-email
feature_branch: feature/waitlist-email
exploration_cache: .exploration-cache.json
---

# Waitlist Email Collection & Notification System

## Overview

**Context**: A landing page has been created for the app where users can express interest by providing their email address. Currently, there's no backend capability to capture and store these emails or communicate with interested users.

**Objective**: Create a waitlist management system that:
1. Accepts email submissions from the landing page
2. Stores emails in a persistent database
3. Sends confirmation emails to users who join the waitlist
4. Enables bulk notifications when the app launches

**Impact**:
- Potential users can express interest and receive confirmation
- Marketing team can track waitlist signups
- Launch communications can reach all interested users

## User Stories

**US-1**: As a visitor, I want to add my email to a waitlist so that I'm notified when the app launches
- **Given** I'm on the landing page, **When** I submit my email, **Then** I receive a confirmation email

**US-2**: As an admin, I want to notify all waitlist subscribers so that they know the app has launched
- **Given** the app is ready to launch, **When** I trigger a notification, **Then** all waitlist emails receive the launch announcement

## Requirements

1. **REQ-001**: System must accept email addresses via a public API endpoint with rate limiting
   - Rationale: Landing page needs to submit emails without authentication; rate limiting prevents abuse/spam

2. **REQ-002**: System must validate email format before storage
   - Rationale: Prevent invalid/spam entries from polluting the waitlist

3. **REQ-003**: System must store email addresses persistently with timestamps
   - Rationale: Track when users signed up for analytics and priority ordering

4. **REQ-004**: System must prevent duplicate email entries
   - Rationale: Each email should only be on the waitlist once

5. **REQ-005**: System must send a confirmation email upon successful signup
   - Rationale: Users need acknowledgment that their email was received

6. **REQ-006**: System must provide capability to send bulk notifications to all subscribers
   - Rationale: Enable launch announcements to reach all interested users

7. **REQ-007**: System must track notification status per subscriber
   - Rationale: Know who has been notified to avoid duplicate notifications

8. **REQ-008**: All emails must include an unsubscribe link
   - Rationale: Legal compliance and user control over communications

9. **REQ-009**: System must support unsubscribe functionality via unique token
   - Rationale: Allow users to remove themselves from the waitlist

## Acceptance Criteria

### Functional
- [ ] **Given** a valid email, **When** submitted to the waitlist endpoint, **Then** email is stored and confirmation sent
- [ ] **Given** an invalid email format, **When** submitted, **Then** return validation error (400)
- [ ] **Given** an already-registered email, **When** submitted again, **Then** return appropriate response without duplicate entry
- [ ] **Given** a successful signup, **When** processed, **Then** user receives confirmation email within 60 seconds
- [ ] **Given** admin access, **When** bulk notification triggered, **Then** all un-notified subscribers receive launch email
- [ ] **Given** a valid unsubscribe token, **When** user clicks unsubscribe link, **Then** email is removed from waitlist
- [ ] **Given** excessive requests from same IP, **When** rate limit exceeded, **Then** return 429 Too Many Requests

### Edge Cases
- [ ] Handles empty email submission with validation error
- [ ] Handles malformed email formats (missing @, invalid domain)
- [ ] Handles concurrent submissions of same email gracefully
- [ ] Handles email service failure gracefully (stores email, queues notification)

## Affected Areas

**Components**:
- `WaitlistModule` - New module for waitlist management
- `EmailService` - Existing service for sending confirmation/notification emails
- `EmailTemplates` - Add new templates for waitlist confirmation and launch notification

**Files**:
- `Sources/App/Modules/Waitlist/` - New module directory (model, router, controller, repository, migrations)
- `Sources/App/Services/Email/Helpers/Templates.swift` - Add waitlist email templates
- `Sources/App/configure.swift` - Register new module

## Assumptions

- Database storage is preferred over file-based storage (aligns with existing architecture)
- Brevo email service is already configured and functional
- No authentication required for the signup endpoint (public API)
- Admin-only endpoint for triggering bulk notifications
- Single confirmation email per signup (no email verification flow required)
- Launch notification is a one-time bulk send operation
- Rate limiting applied to signup endpoint (use existing RateLimitMiddleware)
- Email templates will use simple placeholder content (user to refine later)
- Unsubscribe via unique token per subscriber

---
**Next Steps**: Run `/plan` to create detailed implementation planning.
