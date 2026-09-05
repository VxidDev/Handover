"""Legal documents and versions served by the API.

Keeping the documents and their version numbers here gives us a single
source of truth: signup records the exact version each user consented to,
and the app renders the same text the consent refers to.
"""

TOS_VERSION = "1.1.0"
PRIVACY_VERSION = "1.2.0"
EFFECTIVE_DATE = "2026-09-01"

CONTROLLER_NAME = "Handover Community"
CONTROLLER_EMAIL = "support@fvlabs.org"
CONTROLLER_ADDRESS = "Poland"
CHILD_SAFETY_EMAIL = "support@fvlabs.org"
# Play Child Safety Standards – designated contact for CSAE notifications from Google Play
CHILD_SAFETY_CONTACT = "support@fvlabs.org"

TERMS_OF_SERVICE = """\
## 1. Introduction
Welcome to Handover, a community-powered platform that connects neighbors so they can exchange skills and support. By creating an account or using the service, you agree to these Terms of Service.

## 2. The Service
Handover lets you offer skills, discover skills offered by people in your area, request help, and chat with neighbors. The service is provided **"as is"** and is intended for community mutual aid. It is **not** a substitute for professional services such as medical, legal, financial, or emergency help.

## 3. Eligibility
You must be at least **16 years old** to use Handover. By creating an account, you confirm that you meet this requirement and that the information you provide is accurate and up to date.

## 4. Accounts
You are responsible for keeping your login credentials **confidential** and for all activity under your account. You may not use another person's account.

## 5. Acceptable Use
You agree not to:
- **Post** unlawful, harmful, deceptive, or harassing content.
- **Use** the service to discriminate, defraud, or harm others.
- **Attempt** to access another user's account or data.
- **Misuse** the service, including automated scraping or abuse.
- **Use** the service for commercial solicitation without consent.
- **Post** any content that exploits or endangers children — see §5A.

## 5A. Child Safety — Zero Tolerance for Child Sexual Abuse and Exploitation (CSAE)
Handover has **zero tolerance** for child sexual abuse material (CSAM) and any conduct that endangers children. You must not create, upload, store, share, or distribute:
- **CSAM** or any sexual content involving minors (including solicitation, acquisition, or distribution).
- **Grooming, sexualization, or sexual exploitation** of a minor, including forming relationships with minors for sexual purposes.
- **Sextortion, trafficking, or employment of minors** in sexual services, or any predatory behavior toward children.
- **Romantic or sexual relationships** between adults and minors, or content that encourages them.

We **prohibit** any content that depicts, describes, enables, or encourages the above. We remove such content immediately upon discovery, terminate offending accounts, and cooperate with law enforcement as required. If we obtain actual knowledge of CSAM, we will remove it, preserve evidence where legally required, and report it to the **National Center for Missing and Exploited Children (NCMEC) CyberTipline** (https://report.cybertip.org/) or to your relevant regional authority (https://support.google.com/websearch/answer/148666). Reports can also be made in-app (Report button) or to {safety_email}.

Handover is not directed to children under 16 and is not intended for use by children. See Privacy Policy §10.

## 6. Skills and Content
You remain responsible for the skills and messages you publish. You grant the community the limited right to see and respond to the content you share through the service. We do not claim ownership of your content. By publishing, you represent that your content complies with these Terms, including §5A, and does not contain CSAM or other child-endangerment material.

## 7. Privacy and Consent
Your use of the service involves the processing of personal data as described in our Privacy Policy. By accepting these Terms, you also confirm that you have read the Privacy Policy. You may **withdraw your consent** at any time, which may limit what we can offer you.

## 8. Community Standards and Moderation
We encourage mutual respect. We operate **robust, ongoing moderation** of user-generated content (skills, messages, images):
- In-app **Report** buttons for every skill and chat message, and **Block** for 1:1 interactions.
- Automated screening (toxicity) plus human review; violating content is hidden within 24 hours and warnings/bans are issued.
- **No tolerance** for CSAM/CSAE, harassment, or threats — such content and accounts are removed promptly.

Reports of misuse are handled reasonably and promptly, and accounts that seriously or repeatedly violate these terms may be suspended or terminated. For child-safety concerns, contact {safety_email} — our designated point of contact for CSAE notifications from Google Play and users.

## 9. Termination
You may stop using the service at any time and delete your account from the settings page, which erases your personal data. We may suspend or close accounts that violate these Terms, the law, or the rights of others.

## 10. Disclaimers
The service is provided without warranties of any kind, to the extent permitted by law. You use the service and act on offers at your own risk, and you are responsible for your own safety and decisions.

## 11. Limitation of Liability
To the maximum extent permitted by law, Handover and its operators are not liable for indirect, incidental, or consequential damages arising from your use of the service or from interactions with other users.

## 12. Changes to These Terms
We may update these Terms from time to time. Material changes will be communicated in the app. Continued use of the service after changes take effect constitutes acceptance of the updated Terms.

## 13. Governing Law
These Terms are governed by the laws of **Poland**, without prejudice to the mandatory consumer protection laws of your country of residence.

## 14. Contact
Questions about these Terms can be sent to {contact_email}. Child safety reports: {safety_email}.
"""

PRIVACY_POLICY = """\
## 1. Who We Are
Handover is operated by {controller_name} (based in {controller_address}). For any questions about how we handle personal data, contact {contact_email}. Child safety: {safety_email}.

## 2. What We Collect
We only collect what is necessary to run the service — exactly what we declare in Play Data safety:
- **Account data:** your name and email address (required to create and secure your account).
- **Contact (optional):** phone number, **encrypted at rest with Fernet** and only disclosed when you tap “Share” on an accepted request (logged in `DisclosureLog`; never shown to other users by default).
- **Location (approximate, optional):** coarse lat/lng + privacy grid (e.g. Warsaw grid cell). Collected **only in foreground** with low accuracy (`geolocator` `LocationAccuracy.low`), never in background; downgraded from precise if granted. You can also pick a grid manually on the map. Purpose: find nearby neighbors, distance sort, radius filter. See prominent disclosure before permission.
- **Photos / Media:** profile photo and skill images you choose via system picker (`image_picker`, `READ_MEDIA_IMAGES`). Stored at `/uploads` (5 MB limit), magic-byte validated and screened for NSFW/CSAM via Hive/Google Vision SafeSearch when configured; mismatched or corrupt images are rejected.
- **App activity:** skills, requests, chat messages, ratings, tips, reports, blocks — user-generated content you create.
- **Purchases / Financial info:** tips via Google Play Billing (through RevenueCat). We store `amount_cents`, `recipient_amount_cents` (80% to recipient / 20% platform), `product_id`, `transaction_id` after verification with RevenueCat; no card data is handled by us — charging and receipt are via Google Play.
- **Technical data:** device-agnostic logs for security/troubleshooting; **no Advertising ID collected** (OneSignal push may use its own `player_id` if you enable notifications — see §4).
- **Device identifiers (only if you enable push):** OneSignal `player_id` if you opt into notifications; not used for ads or cross-app tracking.

If you deny optional location or photos, the service still works with manual equivalents.

## 3. Why We Process Your Data (Legal Bases)
- **Consent:** providing your name, email, phone (if given), location/grid, photos, skills and messages you choose to share. Consent is freely given and can be withdrawn at any time (affects functionality).
- **Performance of a contract:** operating your account and delivering the service you asked for (matching neighbors, chat, tipping).
- **Legitimate interests:** keeping the service safe and secure (moderation via Detoxify for text, NSFW checks for images, report/block, 24-hour hide), troubleshooting technical issues, and preventing CSAM/CSAE.
- **Legal obligations:** where we must retain or disclose data by law (e.g., CSAM reporting to NCMEC, fraud prevention).

## 4. How We Use Your Data
We use your data only to provide and improve Handover: to show your skills to neighbors nearby (distance-sort using coarse location/grid), to let you chat, to display your profile/skill photos, to process tips via Google Play Billing (price shown before purchase, “Recipient gets 80% · platform 20% · Charged via Google Play”), and to keep the platform safe via automated + human moderation. We **never sell** your personal data and **never use it for ads**. Push notifications (OneSignal) are optional; if enabled, your `player_id` is used solely to deliver handover alerts.

## 5. Sharing
Your name, availability, skills and skill/profile photos are visible to neighbors in your area. Your coarse grid/approximate location is used for distance, not your exact address. Your phone number is only shared with a neighbor when you explicitly choose to share it for a specific accepted request (audited via `DisclosureLog`). Your email is **never shown** to other users. Tips are processed by Google Play / RevenueCat; we share only the verification identifiers. We do not share data with advertisers and do not sell data.

## 6. Data Retention
We keep your data only as long as your account is active. When you delete your account, we erase your personal data and content, including uploaded images and chat messages. Backup copies are deleted on a schedule consistent with applicable law.

## 7. Your Rights
Under applicable data protection laws (including the EU GDPR and Swiss FADP), you have the right to:
- **Access** your data and request a copy.
- **Rectify** inaccurate or incomplete data.
- **Erase** your data ("right to be forgotten").
- **Restrict** or **object** to certain processing.
- **Data portability:** export your data in a structured, machine-readable format.
- **Withdraw consent** at any time.

You can exercise most of these directly from the settings page. For anything else, contact {contact_email}. You may also lodge a complaint with your local data protection authority.

## 8. Security
Passwords are stored as Argon2 hashes (legacy PBKDF2 verified and migrated), phone numbers and TOTP secrets are Fernet-encrypted at rest, and access requires authentication (JWT `HS256` with `jti` revocation via `BlockedToken`). All traffic is HTTPS only (`network_security_config.xml` `cleartextTrafficPermitted="false"`; debug LAN cleartext is debug-only). We apply reasonable technical and organizational measures to protect your data. In production uploads are limited to `jpg`/`png`/`webp`, validated by magic bytes + Pillow integrity + optional Hive / Google Vision SafeSearch (`NSFW_THRESHOLD 0.85`).

## 9. Data Storage and International Transfers
Your data is stored on secure servers physically located in the **European Union (Poland region) with encrypted backups in Switzerland**, managed by third-party infrastructure providers. Switzerland is recognized by the European Commission as providing an adequate level of data protection where applicable. We contractually require our infrastructure providers to maintain strict security standards and prohibit unauthorized access or transfer of your data outside the agreed-upon regions.

## 10. Children's Privacy
Handover is not intended for children under 16, and we do not knowingly collect data from them. If we learn that a child under 16 has created an account, we will delete the account and associated data promptly. If you believe a child is using Handover, please contact {contact_email} or {safety_email}. We do not allow CSAM and will report it as described in our Terms §5A.

## 11. Changes to This Policy
We will notify you of material changes in the app and update the version number shown here. Continued use of the service after the effective date constitutes acceptance of the updated policy.

## 12. Contact
Privacy questions or requests: {contact_email}. Child safety: {safety_email}.
You can also request account deletion at any time in-app (Settings → Delete account) or via https://fvlabs.org/delete-account .
"""


def format_document(document: str, version: str) -> str:
    return document.format(
        effective_date=EFFECTIVE_DATE,
        version=version,
        controller_name=CONTROLLER_NAME,
        controller_address=CONTROLLER_ADDRESS,
        contact_email=CONTROLLER_EMAIL,
        safety_email=CHILD_SAFETY_EMAIL,
    )
