# Breathe analytics privacy contract

Breathe's behavior-change data is sensitive. Analytics events may describe a
product action only; they must never contain the active program, free text,
custom triggers, amounts, quantities, losses, exact episode times, location,
screening answers, or support-contact information.

The allow-listed event names live in `RecoveryAnalyticsEvent`. Adding an event
or property requires a privacy review and tests. Local app functionality never
depends on analytics, and the default implementation sends nothing.

Safety, crisis, data export, and data deletion remain available regardless of
analytics or payment state.
