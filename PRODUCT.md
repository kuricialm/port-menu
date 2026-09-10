# Port Menu

A macOS menu bar utility for viewing local development servers and running Apple simulators.

## Ports

Show project name, configured LocalCan URL, Git branch, listening port, and uptime. Place elapsed server-process time immediately after the branch on the existing metadata line. Match existing enabled LocalCan endpoints to loopback target ports. Offer Open .local when a matching saved route exists, retain Open localhost, and keep server termination actions scoped to ports. Shared Docker/vpnkit owners are visible but cannot be killed through ordinary process controls. PostgreSQL listeners remain counted as active ports and offer Copy Address rather than browser/termination actions. When a database shares a canonical Git root with a web server, show it as a compact subordinate line under that server, keeping its port and uptime. Prefer the server with a configured LocalCan route, then the lowest port. Keep additional web servers visible, and show the database as a standalone row when no matching server remains. Never group projects by name alone. Style the database engine label like the secondary LocalCan caption, without a dot before it. Verify the listener and process identity before signaling, and keep failed stop requests visible. Last-known port data is marked stale after a failed scan, with stopping disabled until refreshed. Multiple matching endpoints are selectable. Never invent addresses or change LocalCan configuration.

## Simulators

Show booted Apple Simulator devices across installed runtimes, including iOS, watchOS, tvOS, and visionOS. Show elapsed device-session time beside the existing device/runtime details, using the launchd_sim process start time. Omit unknown start times rather than inventing a duration. Show detected running user app names above device name and runtime; fall back to the device name when no app is detected. App detection is best effort from running processes and does not claim to identify the foreground app. Scan the default Xcode device set, Bitrig’s embedded device set, and active custom sets discovered from simulator processes. Keep each device’s set attached to its shutdown command. Open Bitrig brings the host app forward for its embedded devices (selecting the exact project is unsupported without a documented host API), and opens Simulator for Xcode devices. Provide Show and Shut Down actions per device, with failures visible. macOS apps run natively and are not CoreSimulator devices.

## Presentation

The menu-bar badge counts active port endpoints, including grouped databases, plus booted simulator devices (one count per device, regardless of how many apps run inside). It refreshes even while the menu is closed. Its tooltip and accessibility label give the port/simulator breakdown.

Separate Ports and Simulators sections using the existing English language, typography, and controls. Keep the original 340-point menu width, size the menu height to its contents, cap the scroll area at 520 points, and retain the author’s two-line rows and animated hover reveal. Use compact SF Symbol actions with tooltips, preserving the capsule hover/press springs. Reveal actions for keyboard focus and VoiceOver as well as pointer hover.

## Updates and installation

The fork uses its own signed Sparkle feed and update key. Check hourly and download/install automatically by default; both preferences remain adjustable in Settings. Keep manual checking available. Retain the current bundle identifier/preferences for the existing replacement installation. GitHub Actions tests, signs, notarizes, and publishes app changes on main once distribution credentials are configured; version/build numbers always advance. The first fork-channel app needs one manual installation.

Self-installation validates a staged copy before replacement, restores the previous installation on copy/swap/launch failure, and keeps the source copy. Do not erase a usable backup before confirming the replacement opens.

Run one Port Menu instance per user. Opening another copy brings the running copy forward and exits before adding a menu or starting update checks. During self-installation, the installed replacement acknowledges startup and waits for the source to exit before becoming active. Test hosts are exempt.
