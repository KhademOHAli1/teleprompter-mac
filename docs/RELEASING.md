# Releasing

## Source release

1. Update **Info.plist**, **CHANGELOG.md** and validation evidence together.
2. Run the offline tests, build and source checker from a fresh source extraction:

       ./test.command
       ./build.command
       python3 scripts/check-source.py

3. Run the app with the neutral demo. Check microphone permission, local recognition, pause/resume, manual seek, mirroring and the meter.
4. Test OpenAI separately with your own account if that backend changed. Do not put a key in CI or release fixtures.
5. Create the selected-file source archive:

       python3 scripts/archive-source.py

6. Inspect the archive contents and the diff. Commit only the standalone project folder, tag the version, and attach the source archive to a release.

The packaging script excludes **.git/**, **.build/**, **dist/**, preferences and recordings. It does not read UserDefaults, Keychain or sibling folders. The adjacent local app, earlier build folders and personal teleprompter text are not part of this source project.

## First repository publication

Create an empty repository under the account or organization you choose. From this project folder:

    git init -b main
    git add .
    git diff --cached --check
    git diff --cached
    git commit -m "Initial MIT-licensed Teleprompter source release"

Add the repository's actual remote URL and push **main**. These steps are intentionally not run by build or packaging tools. Review the author identity configured in Git before the initial commit.

On GitHub, enable private vulnerability reporting and repository secret scanning where available. The included CI uses read-only repository permissions and no API secrets. Hosted CI results must be checked after publication; local tests do not establish hosted success.

## Binary distribution

The build script produces an Apple Silicon app for macOS 26+, with ad-hoc signing. It includes a copy of the MIT license. No Developer ID certificate, provisioning profile or notarization credential is included.

For a broadly distributed signed binary, use your own Apple Developer identity and follow Apple's current [signing](https://developer.apple.com/documentation/security/code_signing_services) and [notarization](https://developer.apple.com/documentation/security/notarizing_macos_software_before_distribution) documentation. Verify on a fresh supported Mac with default security settings. Do not represent an ad-hoc local build as notarized, and do not add a Gatekeeper-bypass script.

The public source release and a notarized binary release are separate deliverables.
