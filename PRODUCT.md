# Port Menu

A macOS menu bar utility for viewing local development servers and running Apple simulators.

## Ports

Show project name, configured LocalCan URL, Git branch, listening port, and uptime. Match existing enabled LocalCan endpoints to loopback target ports. Offer Open .local when a matching saved route exists, retain Open localhost, and keep server termination actions scoped to ports. Multiple matching endpoints are selectable. Never invent addresses or change LocalCan configuration.

## Simulators

Show booted Apple Simulator devices across installed runtimes, including iOS, watchOS, tvOS, and visionOS. Show detected running user app names above device name and runtime; fall back to the device name when no app is detected. App detection is best effort from running processes and does not claim to identify the foreground app. Provide Show and Shut Down actions per device, with failures visible. macOS apps run natively and are not CoreSimulator devices.

## Presentation

Separate Ports and Simulators sections using the existing English language, typography, and controls. Keep the original 340-point menu width, size the menu height to its contents, cap the scroll area at 520 points, and keep actions accessible without hover.
