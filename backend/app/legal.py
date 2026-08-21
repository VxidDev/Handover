"""Legal documents and versions served by the API.

Keeping the documents and their version numbers here gives us a single
source of truth: signup records the exact version each user consented to,
and the app renders the same text the consent refers to.
"""

TOS_VERSION = "1.0.0"
PRIVACY_VERSION = "1.0.0"
EFFECTIVE_DATE = "2026-08-19"

CONTROLLER_NAME = "Handover Community"
CONTROLLER_EMAIL = "privacy@handover.app"
CONTROLLER_ADDRESS = "Poland"

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

## 6. Skills and Content
You remain responsible for the skills and messages you publish. You grant the community the limited right to see and respond to the content you share through the service. We do not claim ownership of your content.

## 7. Privacy and Consent
Your use of the service involves the processing of personal data as described in our Privacy Policy. By accepting these Terms, you also confirm that you have read the Privacy Policy. You may **withdraw your consent** at any time, which may limit what we can offer you.

## 8. Community Standards
We encourage mutual respect. Reports of misuse are handled reasonably and promptly, and accounts that seriously or repeatedly violate these terms may be suspended or terminated.

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
Questions about these Terms can be sent to {contact_email}.
"""

PRIVACY_POLICY = """\
## 1. Who We Are
Handover is operated by {controller_name} (based in {controller_address}). For any questions about how we handle personal data, contact {contact_email}.

## 2. What We Collect
We only collect what is necessary to run the service:
- **Account data:** your name and email address.
- **Profile data:** your availability, optionally a phone number (stored encrypted), and a coarse "privacy area" that approximates your neighborhood without revealing your exact address.
- **Skills and messages:** the skills you publish, requests you make, and chat messages you exchange with neighbors.
- **Technical data:** basic logs for security and troubleshooting.

## 3. Why We Process Your Data (Legal Bases)
- **Consent:** providing your name, email, and the skills you choose to share. Consent is freely given and can be withdrawn at any time.
- **Performance of a contract:** operating your account and delivering the service you asked for.
- **Legitimate interests:** keeping the service safe and secure, and troubleshooting technical issues.
- **Legal obligations:** where we must retain or disclose data by law.

## 4. How We Use Your Data
We use your data only to provide and improve Handover: to show your skills to neighbors, to connect you with people who can help, to let you chat, and to keep the platform safe. We **never sell** your personal data.

## 5. Sharing
Your name, availability, and skills are visible to neighbors in your area. Your phone number is only shared with a neighbor when you explicitly choose to share it for a specific request. Your email is **never shown** to other users.

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
Passwords are stored as one-way hashes, phone numbers are encrypted at rest, and access to your account requires authentication. We apply reasonable technical and organizational measures to protect your data.

## 9. Data Storage and International Transfers
Your data is stored on secure servers physically located in **Switzerland**, managed by a third-party infrastructure provider. Switzerland is recognized by the European Commission as providing an adequate level of data protection. We contractually require our infrastructure providers to maintain strict security standards and prohibit unauthorized access or transfer of your data outside the agreed-upon regions.

## 10. Children's Privacy
Handover is not intended for children under 16, and we do not knowingly collect data from them.

## 11. Changes to This Policy
We will notify you of material changes in the app and update the version number shown here. Continued use of the service after the effective date constitutes acceptance of the updated policy.

## 12. Contact
Privacy questions or requests: {contact_email}.
"""


def format_document(document: str, version: str) -> str:
    return document.format(
        effective_date=EFFECTIVE_DATE,
        version=version,
        controller_name=CONTROLLER_NAME,
        controller_address=CONTROLLER_ADDRESS,
        contact_email=CONTROLLER_EMAIL,
    )