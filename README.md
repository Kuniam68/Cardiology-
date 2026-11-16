# Cardiology website

A responsive, dependency-free clinic website built with HTML, CSS, and JavaScript.

## Pages
- Home: index.html
- About: about.html
- Services: services.html
- Team: doctors.html
- Patient resources and FAQs: resources.html
- Contact: contact.html
- Appointment preference demonstration: appointment.html
- Privacy: privacy.html
- Custom missing-page screen: 404.html

## Run locally
Open index.html in your browser, or serve this folder:
```sh
python3 -m http.server 8000
```
Then visit http://localhost:8000. There is no install or build step.

## Customize
Edit page HTML for clinic identity, actual services, verified clinician profiles, opening hours, address, and contact details. Shared visual styling is in assets/styles.css; behavior is in assets/script.js. The illustration and favicon are local assets and require no third-party requests. Replace template notices only once real clinic details are supplied.

## Features
Responsive navigation, current-page indicators, keyboard-accessible controls, skip link, native form validation, date validation, appointment preference review, FAQ accordions, printable patient guide, dynamic copyright year, favicon, and per-page descriptions. No cookies, analytics, external libraries, or remote fonts.

## Appointment handling
The appointment form is intentionally a browser-only demonstration. It sends no requests, stores nothing, and does not reserve appointments. Connect a clinic-approved secure booking service before accepting real patient information. Never put passwords, API keys, patient records, or other secrets into this public client-side code. There is no authentication backend or patient portal.

## Hosting on GitHub Pages
In repository Settings → Pages, select Deploy from a branch, main, and / (root), if Pages is available for your repository/account. Private repository support depends on your GitHub plan. This change supplies source files; it does not enable hosting. Relative links support hosting under the Cardiology- repository path.

## Before real clinic launch
Confirm all medical descriptions and available services with a qualified clinician; replace placeholder profiles and contact details; update privacy information for the actual operator and hosting; connect and verify booking delivery and confirmation if needed. No testimonials or clinician credentials have been invented.

## Maintenance
No package dependencies. Keep HTML navigation/footer consistent across pages when adding pages.
