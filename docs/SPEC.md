# Bonanza Redux -- Specification

Bonanza Redux is an equipment lending management system for FH Potsdam. Staff
members organize equipment into departments (workshops/studios), manage an
inventory of lendable items, and process checkouts and returns for borrowers
(students and employees). The system enforces borrower verification, tracks item
condition and history, and supports conduct management (warnings and bans).

## Technical Overview

- **Language**: Ruby, **Framework**: Rails
- **Database**: PostgreSQL
- **Search**: Elasticsearch via Searchkick (full-text search with German synonym
  support on equipment and borrowers)
- **Frontend**: Server-rendered ERB with Hotwire (Turbo for page updates,
  Stimulus for interactive behavior), Bootstrap for styling, esbuild for
  JavaScript bundling, Sass for CSS
- **Authentication**: Devise with invitation-based onboarding for staff
- **Authorization**: CanCanCan with role-based abilities scoped per department
- **File Storage**: Active Storage for equipment documentation and manuals
- **Tagging**: Equipment categorization via tags with department-scoped context

The application is a traditional server-rendered Rails app. There is no separate
API or SPA frontend. All interactivity uses Turbo Streams and Stimulus
controllers.

**Deployment**: Docker containers behind a Caddy reverse proxy. Services:
web (Rails), database (PostgreSQL), search (Elasticsearch). The application
runs on an FH Potsdam server accessible only via VPN. Email is delivered
through the FHP SMTP relay.

## Terminology

The user interface is in German. Key terms and their English equivalents:

| German | English | Description |
|--------|---------|-------------|
| Werkstatt | Department | Organizational unit that owns and lends equipment |
| Ausleihe | Lending | A borrowing transaction |
| Entleiher | Borrower | Person borrowing equipment |
| Gerät | Item | Individual piece of equipment |
| Gerätetyp | Parent Item | Equipment type/category grouping individual items |
| Rücknahme | Return | Equipment check-in process |
| Zubehör | Accessory | Optional add-on included with a lent item |
| Verwarnung | Warning | Misconduct record (minor) |
| Sperre | Ban | Misconduct record (blocks lending) |
| Studierende | Student | Borrower type: student |
| Mitarbeitende | Employee | Borrower type: employee |

## User Roles

All staff data is scoped to a **current department**. A staff member can belong
to multiple departments with different roles, but works in one department context
at a time.

| Role | Access |
|------|--------|
| **Admin** | Full access across all departments |
| **Leader** | Manage staff, borrowers, items, and lendings in own department. Can invite new staff (as member or guest) and toggle department staffing. |
| **Member** | Manage borrowers, items, and lendings in own department |
| **Guest** | Read-only access in own department |
| **Hidden** | Like guest, but only visible to admins |

## Core Workflows

### Borrower Registration

Borrowers can self-register via a public form or be created by staff.

**Self-registration flow:**

1. Borrower fills in name, email, phone, and student ID (if student)
2. Borrower accepts terms of service
3. System sends a confirmation email with a verification link
4. Borrower clicks the link to confirm their email
5. Registration is complete; borrower can now be selected for lendings

**Verification requirements:**

- All borrowers must have liability insurance verified by staff
- Students must have their ID checked by staff
- Students must provide a student ID number

### Equipment Lending

Staff search the equipment catalog, build a cart, and walk through a checkout
wizard to complete a lending.

**Checkout flow (state machine):**

```
cart --> borrower --> confirmation --> completed
```

1. **Cart** -- Staff searches equipment by name, tags, status, or condition.
   Adds items to a cart with quantities. Items must be available and belong to
   the current department.
2. **Borrower** -- Staff selects an existing borrower or creates a new one.
   The borrower must have accepted the terms of service.
3. **Confirmation** -- Staff reviews the lending, sets the return duration,
   adds optional accessories, and may add notes. The system checks that all
   items are still available and the borrower has no active bans.
4. **Completed** -- Items are marked as lent, quantities are decremented,
   the lending timestamp is recorded, and a confirmation email is sent. A
   printable lending agreement is generated.

**Constraints:**

- The department must be staffed for checkout to proceed
- Steps cannot be skipped; the wizard enforces order
- Staff can navigate backward to previous steps
- Banned borrowers cannot complete checkout

### Equipment Returns

Staff process returns from a dedicated returns view.

1. The returns view shows lendings due today or later, and overdue lendings,
   grouped by return date
2. Staff marks individual line items as returned, specifying quantity and
   optionally updating condition
3. When all line items in a lending are returned, the lending is automatically
   marked as fully returned with a timestamp
4. Returned items become available again immediately

**Partial returns** are supported -- individual items from a lending can be
returned independently.

### Conduct Management

Staff can issue warnings and bans to borrowers, scoped per department.

- **Warning**: A recorded misconduct note. Does not block lending.
- **Ban**: Blocks the borrower from lending in that department. Can be
  temporary (with a duration in days) or permanent.

A borrower can be warned or banned in one department while remaining in good
standing in another.

## Domain Model

### Department

An organizational unit (workshop, studio, lab) that owns equipment and processes
lendings. Has a name, room location, operating hours, and a default lending
duration. Can be marked as staffed or unstaffed (controls whether lending is
allowed). Supports German grammatical gender for UI text.

### User

A staff member who authenticates to manage equipment and process lendings.
Belongs to one or more departments with a role in each. Has a current department
that scopes all their actions. Can be invited by leaders or admins.

### Borrower

A person who borrows equipment. Either a student or an employee. Has contact
information (email, phone), verification flags (ID checked, insurance checked),
and terms-of-service acceptance. Supports self-registration with email
confirmation. Soft-deleted (marked as deleted rather than removed).

### Parent Item

An equipment type or category (e.g., "Sony A7 Camera"). Groups individual items
and their accessories. Belongs to a department. Supports tags, file attachments
(manuals, documentation), and full-text search.

### Item

An individual piece of equipment. Belongs to a parent item. Has a unique
identifier (UID/serial number), a status (available, lent, returned,
unavailable, deleted), a condition (flawless, flawed, broken), a storage
location, and a lending counter. Items without a UID can represent bulk
quantities. All changes are recorded in an audit history. Soft-deleted (marked
as deleted rather than removed).

### Lending

A borrowing transaction that tracks the checkout of one or more items to a
borrower. Progresses through a state machine (cart, borrower, confirmation,
completed). Records the staff member who created it, the lending timestamp,
the return duration, and an optional note. Generates a unique token for
reference. Tracks overdue status and notification count. Abandoned carts
(older than 2 days) are automatically cleaned up.

### Line Item

A single entry in a lending, linking an item to the lending with a quantity.
Tracks when the item was returned. Can have accessories associated with it.

### Accessory

An optional add-on that belongs to a parent item (e.g., lens cap, USB cable,
extra battery). Associated with line items when included in a lending.

### Conduct

A misconduct record for a borrower in a specific department. Either a warning
or a ban. Bans can be temporary (with a duration) or permanent. Records the
reason, the staff member who issued it, and optionally the related lending.

### Legal Text

A versioned legal document: terms of service, privacy policy, or imprint.
Managed by admins. When terms of service are updated, borrowers can be notified.

## Business Rules

- **Insurance required**: All borrowers must have liability insurance verified
  before they can be included in a lending.
- **Student ID required**: Student borrowers must have their ID checked and a
  student ID number on file.
- **Staffing gates lending**: A department must be marked as staffed for any
  checkout to proceed.
- **Bans block lending**: A borrower with an active ban in a department cannot
  complete a lending in that department.
- **Items locked while lent**: Items with status "lent" cannot be modified
  (except for status changes during return).
- **Soft deletes**: Items are marked as deleted (preserving audit history).
  Borrowers are marked as deleted. Department memberships use a deleted role.
  No hard deletes for entities with history.
- **Abandoned cart cleanup**: Lending carts older than 2 days are automatically
  destroyed.
- **Terms of service**: Borrowers must accept the current terms of service.
  Staff can trigger borrower notifications when terms are updated.

## Search

Equipment and borrowers are indexed for full-text search with partial matching.

- **Equipment search**: Matches on name, description, and tags. Filters by
  item status and condition. Boosts frequently lent items in results. Supports
  German synonyms (e.g., "Mikrofon" matches "Micro", "Akku" matches
  "Batterie").
- **Borrower search**: Matches on name, email, and student ID. Filters by
  lending status (active/none), conduct status (blameless/warned/banned), and
  borrower type.

## Legal Content

The system manages three types of legal content:

- **Terms of Service (Ausleihbedingungen)**: Borrowers must accept before
  lending. Versioned; updates can trigger borrower notifications.
- **Privacy Policy (Datenschutz)**: Publicly accessible.
- **Imprint (Impressum)**: Publicly accessible.

Admins can edit and version all legal texts through the staff interface.
