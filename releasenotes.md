# 0.9.9

- Renamed "Purchase" settings panel to "Support Us" and changed icon from a coin to a gift, fixed a typo in the panel.
- Fixed height of several settings panels, removing white space at the bottom.
- Internal refactoring and UI test.
- Fixed use of Sparkle API, updated its plist entries and added an entitlement it needed.
- Fixed build number generated during build, removed Sparkle appcast file entries for those versions with a too-large build number (so must manually upgrade from 0.9.7/8 to a new version after all).
- Improve Sparkle setup in GitHub workflow, automating appcast file generation which required making the .zip archive contain only the .app.
- Made GitHub workflow build .dmg containing app and readme (now the disk image is the recommended file to download), other GitHub workflow fixes.

# 0.9.8

- Changed what is left on the clipboard when collecting clipboard items in queue mode, keep last copied item on clipboard and when Paste & Advance switch to desired item before invoking application's paste.
- Fixed bug where Delete History Item wasn't enabled sometimes, particularly when there's only one history item in the menu.
- Fixed bug affecting performace where all history items were added to the menu on first launch, instead of the count in the settings, most of which then have to be removed when the menu is first opened.
- Implemented some Cleepp specific UI Tests, adapting some Mappy tests and then adding ones for using queue copy and paste.

# 0.9.7

- Prevent double paste when using Cleepp shortcut, or paste while Paste All / Paste Multiple is occurring.
- Disable necessary menu items when Paste & Advance, or Paste All / Paste Multiple, are occurring.
- Improve timing when copying and pasting so they work more reliably in general.
- Changed old fix for Microsoft applications support so it only applied to those applications and doesn't apply to ones for which it causes problems (specifically LibreOffice).
- Attempt completion of Sparkle support, the next version after 0.9.7 should be offered as an automatic update.

# 0.9.6

- Fixed regression, replay from history wasn't putting head-of-queue item onto the clipboard.
- Fixed queue item menu separator was sometimes getting left behind.
- Made ARM also use a (shorter) delay between paste and advance in hopes of avoiding timing issue seen on Intel systems.
- Fixed misplaced delay when using Paste All / Paste Multiple, was letting queue advance to happen immediately after invoking paste after all.
- Created credits and licenses window containing app license, plus mentioning each swift package used and including their licenses.
- Simplified about box, added link that opens credits and licenses window.

# 0.9.5

- Increased the delay between issuing paste to the frontmost application and advancing the clipboard to the next item, present on Macs with Intel CPUs and for all systems in-between each paste when using Paste All.
- Used 3rd party library to draw animated GIF in the first page of the Intro window, hopefully that will work on all systems.

# 0.9.4

- New app icon, seen in the Finder and the about box (though your Mac may cache the old one until your next restart), and in the logo in the Intro window's first page, the GitHub README, and start of the documentation pages in the GitHub wiki. Unfortunately it's kind of a blurry mess in the small rendering in the Get Info window 😕 and I might end up changing it again.
- Made last page of the Intro window for non-App Store builds advertise the in-app purchase of the App Store build and provide button to go the app's page (although goes to a placeholder page in the GitHub wiki for now).
- Changed the support email address and documentation web address in the Intro window's last page and About box.
- Minor other changes to the Intro window's last page: fixed Copy Documentation Link button (shown when option key down) was opening it instead, added Make A Donation button opening my buymeacoffee.com link.
- Removed some unused Maccy assets.

Known issues: on either macOS versions older than 14.(tbd) Sonoma, or with less likelihood on all models with Intel CPUs, the animated GIF in the Intro window will be blank. The next release may simply show just the static logo on systems pre-Sonoma.

The app still needs to be opened the first time by right clicking the app icon and choosing Open from the contextual menu. Thank you for you patience for this last build before I deliver signed betas (or maybe one more subsequent build without).

# 0.9.3

- Attempted work-around for timing issues with first paste noticed on macOS 12 MacBook Air.
- Fixed menu behavior on pre-macOS14, workaround longstanding bugs, fix my logic errors.
- Stopped marking head-of-the-queue menu item (displayed at the bottom) with an underline on macOS before 14, instead put a separator line below it.
- Fixed history menu item deletion sometimes not working.
- Reordered Settings panels moving Appearance right next to General.
- Changed number of menu items in Appearance Settings panel to 20, and now say the right default in the tooltip.
- Permit entering a value of 0 for the number of menu items again, and altering the blurb below when it's 0.
- Fixed tabbing between fields in the Appearance Settings.
- Fixed preview popup to always include the line hinting how to copy a single history item.
- Fixed delete intent in case those still do something after migrating from Maccy to Cleepp.
- Improved wording in the third page of the intro, better directing what to do in System Settings/Prefs.
- Attempted work-arounds to fix the logo gif on the first page of the intro not animating on older OS versions.
- Inherit improvements to the Ignore settings panel.
- Minor code cleanup and merge upstream changes all having no effect.

# 0.9.2

- Restore English strings file accidentally removed while I was stripping the localizations.
- In the Intro window page 2, override the default button to be the one opening the System Settings app.
- Copying support email address by option-clicking the Intro window button was getting the mailto part also, fixed that.
- Using the Purchase or Restore buttons of the purchase settings panel now progresses through simulated states of the forthcoming purchase process.
- The purchase settings panel panel now has a link to web page about the bonus features.
- Fixed something causing settings window to frequently open with the wrong size.

Important: Found these builds I've been making myself have all been ARM-only, though the last two simplified variants done by GitHub actions perhaps were universal. Was finally able to test on an Intel MacBook Air and there's a timing issues with the first paste from the queue. These should be fixed in 0.9.3.

# 0.9.1

- Hide search field options from the settings for github build or when bonus features not purchased.
- Minor improvements to the Intro window, giving pages a little more horizontal space, polished some wording, removed localization email button for now.
- Stripped localizations for now.
- Setup github continuous integration on commits to main branch, and build release when a version is tagged. Script ready to sign and notarize though not doing so yet.
- Note: Withdrawing download b/c a mistake removed made while removing localizations ended up removing some English language text as well.

# 0.9

- Migrated all code that modifies Maccy to turn it into Cleepp out of the experimental branch, and in the process improve the organization of the modifications. This should allow the Maccy unit test to continue to run (though untested so far) and better support future merges of upstream changes (if so desired).
- If user had started ignoring clipboard events, reset to resume monitoring the clipboard when the user starts collecting a set of item (with the shortcut, the Copy & Collect menu item, the Start Collecting menu item, or control-clicking the menu icon).
- Minor tweak to the intro: if permission has already been granted in the system settings, omit a sentence on the first page that implies that setup is still needed.
- Minor improvement when checking for purchases on launch, omitting the process (and its related code) altogether in the direct download version.

# 0.8.5

- Moved bonus features to app store build, for now hardcoded to be as if features have been purchased. The separate simplified build is what will eventually be available on GitHub.
- Animated logo in the intro window and the project readme (build in Drama, from PixelCut the makers of PaintCode). Something like this animation was envisioned when the name "Cleepp" was chosen.
- Simplified preview popup more still, removing last copy time line since Cleepp doesn't collapse duplicates like Maccy does.
- Fixed case where menu items could get stuck in all-disabled state (after using a feature leads to the accessibility-permissions-not-granted alert opening).
- More edits and additions to the project readme file.

# 0.8.4

- Added Paste All / Paste Multiple menu item, mention of it in the purchases settings panel.
- Fixed command-delete to delete history menu item, regression introduced at some point where it no longer work whenever the history filter menu item was hidden. Feature is no longer isn't implemented by the input handling in that item's text field, but by a new menu item "Delete History Item" linked to "Clear". It's enabled only when highlighting a history menu item and so can only be activated with its keyboard shortcut.
- Additional minor fixes to menu behavior.
- Feature for disabling all menu items when the app is busy commanding the frontmost application to copy or paste (especially when using Paste All). A work in progress and might require more tweaks and fixes later but I think it's the right thing to do to prevent possibility of starting another action while one is currently still in progress.
- Removed the redundant copy count line from history menu item preview pop-up window.
- Under the hood preparations for in-app purchases, eg. bringing in libraries for validating purchase receipts.

# 0.8.3

- New purchases settings panel, not functional yet but demonstrates its 2 states, progress spinner and error text field.
- Some sizing and minor language changes in some of the other panels.
- Added new feature where menu shown entire history (can be long, have to scroll).
- Reduces default number of history items shown normally.
- Some fixes, refactoring, simplification of the invisible menu anchor items used when not macOS 13 and earlier.
- Fixed some other menu bugs relating to deleting menu items and operation.
- Fixed minor issues with the menu bar icons, which images are used in different states of the app and transitions between them.
- Fixed preview blurb which labels actions backwards.
- Minor changes to the intro.

# 0.8.2

- An intro window opens up the first time running the app to help walkthrough granting the permission needed in the System Settings app, plus giving essential information for basic usage.
- It can be opened again later via a link in the text of the about box.
- If trying to use the app before granting permission and the alert is shown, the app ends up in a more predictable state afterwards.
- Menubar icons are images again so they work in older OS versions.
- Has a new app icon that's distinct from Maccy's, though perhaps it will get replaced again before 1.0.

# 0.8.1

- Menu bar icon based on SF Symbols clipboard when running on macOS 13.0 Ventura and later, changes appearance when collecting & replaying clips
- Reversed the actions needing the option key when clicking on history items
- Prepare for replay from history, history filtering, and undo copy features to be bonus features
- Updates to repo's readme

# 0.8

Cleepp is fork of Maccy that adds a new mode to the clipboard letting you copy multiple times from one place then paste them all in order someplace else. Many features of Maccy have been stripped away for the sake of simplicity.

Built off a temporary development branch, will shortly be rebasing/redoing these changes off a later commit of the main branch with some improvements to the code along the way.
