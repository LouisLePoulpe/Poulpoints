# Poulpoints — request for packaging (draft)

Source: https://github.com/LouisLePoulpe/Poulpoints
License: MIT
Application ID: org.poulapp.poulpoints
Release: 0.7.1 (20)

Poulpoints is an offline task manager with projects, subtasks, customizable recurrence, multiple reminders and an Android home screen widget. Cloud synchronization is optional and uses a configurable Supabase-compatible server. The author's hosted instance is currently invitation-only. Local use requires no account. No Firebase, Google Play Services or advertising SDK was found in the resolved Android dependency tree.

French and English Fastlane metadata and the application icon are provided. A candidate build recipe and dependency license inventories are in the source repository. Metadata lint and the APK scanner have passed locally with fdroidserver 2.4.5. A local fdroid build --test --scan-binary --no-tarball from tag v0.7.1 also succeeded on Fedora/Distrobox, including the source scanner. The official buildserver still needs verification. Reproducibility is not established: four native libraries differ from the GitHub release. We would appreciate review of the Flutter build recipe before inclusion.

No account or proprietary service is required to use local task management, reminders and the widget.
