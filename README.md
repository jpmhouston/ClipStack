<!--- <img width="128px" src="https://maccy.app/img/maccy/Logo.png" alt="Logo" align="left" /> -->

# Cleepp

[![Downloads](https://img.shields.io/github/downloads/jpmhouston/ClipStack/total.svg)](https://github.com/jpmhouston/ClipStack/releases/latest)
<!--- [![Build Status](https://img.shields.io/bitrise/716921b669780314/master?token=3pMiCb5dpFzlO-7jTYtO3Q)](https://app.bitrise.io/app/716921b669780314 -->
<!--- [![Donate](https://img.shields.io/badge/buy%20me%20a%20coffee-donate-yellow.svg)](https://www.buymeacoffee.com/p0deje -->

Cleepp is a menu bar utility for macOS that adds the ability to copy multiple items
and then paste them in order elsewhere.

Cleepp is a fork of clipboard manager [Maccy](https://maccy.app); it's aim isn't to have
all the features of a full features clipboard history manager, but to provide just that single
multi-clipboard feature.

Cleepp works on macOS Mojave 10.14 or higher.

<!-- vim-markdown-toc GFM -->

* [Features](#features)
* [Install](#install)
* [Usage](#usage)
    * [Basic Usage](#basic-usage )
    * [Alternatives](#alternatives)
    * [The Cleepp Menu](#the-cleepp-menu)
* [Additional Features](#additional-features)
    * [Expanded Clipboard History](#expanded-clipboard-history)
	    * [Start Replaying From History](#start-replaying-from-history)
	    * [Selecting Single Item From History To Paste](#selecting-single-item-from-history-to-paste)
* [Advanced](#advanced)
    * [Ignore Copied Items](#ignore-copied-items)
    * [Ignore Custom Copy Types](#ignore-custom-copy-types)
* [FAQ](#faq)
    * [Why don't the Cleepp global shortcuts do anything?](#why-dont-the-cleepp-global-shortcuts-do-anything)
* [License](#license)

<!-- vim-markdown-toc -->

## Features

* Lightweight and fast
* Simple
* Secure and private
* Native UI
* Open source and free on GitHub (nominal fee on the Mac App Store)

## Install

Download the latest version from the
[releases](https://github.com/jpmhouston/ClipStack/releases/latest) page,
or the Mac App Store

## Usage

### Basic Usage

1. In your source document window(s) copy using the Cleepp shortcut
<kbd>CONTROL (^))</kbd> + <kbd>COMMAND (⌘))</kbd> + C.

2. Repeat.\
\
	*The number in the menu bar icon will increment with each item copied.*

3. In your target document window paste using the Cleepp shortcut
<kbd>CONTROL (^))</kbd> + <kbd>COMMAND (⌘))</kbd> + V.\
\
	*Between each paste the clipboard will automatically advance to the next
	item that was copied in order and the number in the menu bar icon will decrement.*

4. Repeat.\
\
	*When all copied items have been pasted, upon which the menu bar icon will
	return to normal, and copying and pasting will return to normal bahavior.*

### Alternatives

- You may click the Cleepp menu bar icon with <kbd>CONTROL (^)</kbd> pressed
to start a set of copies, or choose the "Start Collecting" item in the Cleepp menu.
The menu bar icon will get a count value added beside it.
You may copy from you source document window(s) using either the Cleepp shortcut,
or the application's normal Copy command or shortcut.

- Starting to collect clipboard items can also be done using the "Start Collecting" item
in the Cleepp menu.

- You can return to normal clipboard behavior by again clicking the Cleepp menu bar icon
with <kbd>CONTROL (^))</kbd> pressed, or using the "Cancel Collecting / Replaying" menu item.

- While in the middle of pasting, you are still able to copy more.
The clipboard item will be added to the set of menu items as normal and will get pasted last,
the number in the menu bar icon will increment.

### The Cleepp Menu

(TBD)

<!--
1. <kbd>SHIFT (⇧)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> to popup Maccy or click on its icon in the menu bar.
2. Type what you want to find.
3. To select the history item you wish to copy, press <kbd>ENTER</kbd>, or click the item, or use <kbd>COMMAND (⌘)</kbd> + `n` shortcut.
4. To choose the history item and paste, press <kbd>OPTION (⌥)</kbd> + <kbd>ENTER</kbd>, or <kbd>OPTION (⌥)</kbd> + <kbd>CLICK</kbd> the item, or use <kbd>OPTION (⌥)</kbd> + `n` shortcut.
5. To choose the history item and paste without formatting, press <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> + <kbd>ENTER</kbd>, or <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> + <kbd>CLICK</kbd> the item, or use <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> + `n` shortcut.
6. To delete the history item, press <kbd>OPTION (⌥)</kbd> + <kbd>DELETE (⌫)</kbd>.
7. To see the full text of the history item, wait a couple of seconds for tooltip.
8. To pin the history item so that it remains on top of the list, press <kbd>OPTION (⌥)</kbd> + <kbd>P</kbd>. The item will be moved to the top with a random but permanent keyboard shortcut. To unpin it, press <kbd>OPTION (⌥)</kbd> + <kbd>P</kbd> again.
9. To clear all unpinned items, select _Clear_ in the menu, or press <kbd>OPTION (⌥)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>DELETE (⌫)</kbd>. To clear all items including pinned, select _Clear_ in the menu with  <kbd>OPTION (⌥)</kbd> pressed, or press <kbd>SHIFT (⇧)</kbd> + <kbd>OPTION (⌥)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>DELETE (⌫)</kbd>.
10. To disable Maccy and ignore new copies, click on the menu icon with <kbd>OPTION (⌥)</kbd> pressed.
11. To ignore only the next copy, click on the menu icon with <kbd>OPTION (⌥)</kbd> + <kbd>SHIFT (⇧)</kbd> pressed.
12. To customize the behavior, check "Preferences..." window, or press <kbd>COMMAND (⌘)</kbd> + <kbd>,</kbd>.
-->

## Additional Features

### Undo Last Copy

(TBD)

### Expanded Clipboard History

You can click the Cleepp menu bar icon with <kbd>OPTION (⌥)</kbd> pressed
to see the expanded menu which displays all your recent clipboard history.
You can use this to start a Cleepp from a previous item, or to select a single item
from you history to paste.

This menu includes a simplified set of clipboard features from the open source project
[Maccy](https://maccy.app). For a more full featured set of features, including
more keyboard shortcuts, a pinning feature, and more, consider using that original app. 
It can be found at their homepage [https://maccy.app](https://maccy.app).

#### Start Replaying From History

1. Click the Cleepp menu icon with <kbd>OPTION (⌥)</kbd> pressed
(you may then release the modifier key).

2. Select a history item, the menu bar icon will get a count value added beside it.

3. Paste with the Cleepp shortcut <kbd>CONTROL (^))</kbd> + <kbd>COMMAND (⌘))</kbd> + V
to paste each item in succession.\
\
	*Like normal clip replay described in section [Basic Usage](#basic-usage) and 
[Alternatives](#alternatives) when the topmost clipped item in the menu has been pasted,
copying and pasting will return to normal bahavior. You can also return to normal
clipboard behavior at any time by clicking the Cleepp menu bar icon with
<kbd>CONTROL (^))</kbd> pressed, or using the “Cancel Collecting / Replaying” menu item*

#### Selecting Single Item From History To Paste

1. Click the Cleepp menu icon with <kbd>OPTION (⌥)</kbd> pressed
(you may then release the modifier key).

2. Optionally type what you want to find in the "Filter" search box to filter the history.

3. Select the desired item from the history item and press <kbd>OPTION (⌥)</kbd> +
<kbd>ENTER</kbd>, or <kbd>OPTION (⌥)</kbd> + <kbd>CLICK</kbd> on the item,
then perform paste as normal in your application's document window.\
\
	These features are also supported for the history items in the menu:

- To see the full text of the history item, mouse over, or arrow-key to highlight it,
and wait a couple of seconds for tooltip.

- To delete the history item, mouse over, or arrow-key to highlight it, then press
<kbd>COMMAND (⌘)</kbd> + <kbd>DELETE (⌫)</kbd>.

## Advanced

### Ignore Copied Items

You can tell Cleepp to ignore all copied items:

```sh
defaults write lol.bananameter.Cleepp ignoreEvents true # default is false
```

This is useful if you have some workflow for copying sensitive data.
You can set `ignoreEvents` to true, copy the data and set `ignoreEvents` back to false.

You can also click the menu icon with <kbd>SHIFT (⇧)</kbd> + <kbd>CONTROL (^)</kbd> pressed.
To ignore only the next copy, click with <kbd>SHIFT (⇧)</kbd> + <kbd>CONTROL (^)</kbd> +
<kbd>OPTION (⌥)</kbd> pressed.

### Ignore Custom Copy Types

By default Cleepp will ignore certain copy types that are considered to be confidential
or temporary. The default list always include the following types:

* `org.nspasteboard.TransientType`
* `org.nspasteboard.ConcealedType`
* `org.nspasteboard.AutoGeneratedType`

Also, default configuration includes the following types but they can be removed
or overwritten:

* `com.agilebits.onepassword`
* `com.typeit4me.clipping`
* `de.petermaurer.TransientPasteboardType`
* `Pasteboard generator type`
* `net.antelle.keeweb`

You can add additional custom types using preferences or `defaults`:

```sh
defaults write lol.bananameter.Cleepp ignoredPasteboardTypes -array-add "com.myapp.CustomType"
```

If you need to find what custom types are used by an application, you can use the
free application [Pasteboard-Viewer](https://github.com/sindresorhus/Pasteboard-Viewer).
Simply download the application, open it, copy something from the application you
want to ignore and look for any custom types in the left sidebar.
[Here](https://github.com/p0deje/Maccy/issues/125)  is an example of using this approach
to ignore Adobe InDesign (*however where "org.p0deje.Maccy" is mentioned, substitute
"lol.bananameter.Cleepp"**).

If you accidentally removed default types, you can restore the original configuration:

```sh
defaults write lol.bananameter.Cleepp ignoredPasteboardTypes -array "de.petermaurer.TransientPasteboardType" "com.typeit4me.clipping" "Pasteboard generator type" "com.agilebits.onepassword" "net.antelle.keeweb"
```

## FAQ

### Why don't the Cleepp global shortcuts do anything?

Make sure "Cleepp" is added to System Settings ⮕ Privacy & Security ⮕ Accessibility.

## License

[MIT](./LICENSE)
