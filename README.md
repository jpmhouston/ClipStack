<img width="656px" height="180px" src="Designs/Cleepp/Cleepp GitHub logo.gif" alt="Logo"/>

[![Downloads](https://img.shields.io/github/downloads/jpmhouston/Cleepp/total.svg)](https://github.com/jpmhouston/Cleepp/releases/latest)
[![Donate](https://img.shields.io/badge/buy%20me%20a%20coffee-donate-yellow.svg)](https://www.buymeacoffee.com/bananameterlabs
<!--- [![Build Status](https://img.shields.io/bitrise/716921b669780314/master?token=3pMiCb5dpFzlO-7jTYtO3Q)](https://app.bitrise.io/app/716921b669780314 -->

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
    * [Basic Usage](#basic-usage)
    * [Optional Alternatives](#optional-alternatives)
* [The Cleepp Menu](#the-cleepp-menu)
    * [Menu Icon State](#menu-icon-state)
    * [Special Menu Icon Actions](#special-menu-icon-actions)
    * [Menu Items](#menu-items)
    * [Replay Clipboard Items](#replay-clipboard-items)
    * [Expanded Clipboard History Items](#expanded-clipboard-history-items)
* [Settings](#settings)
*  [Bonus Features for the Mac App Store Version Version](#bonus-features-for-the-mac-app-store-version)
    * [Undo Last Copy](#undo-last-copy)
    * [Start Replaying From History](#start-replaying-from-history)
    * [Additional History Features](#additional-history-features)
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
[releases](https://github.com/jpmhouston/Cleepp/releases/latest) page,
or the Mac App Store


## Usage

### Basic Usage

1. In your source document window(s) copy using the special Cleepp shortcut
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd>.\
\
	*The menu bar icon will change and get a number 1 added beside it*

2. Repeat.\
\
	*The number in the menu bar icon will increment with each item copied.*

3. In your target document window paste using the special  Cleepp shortcut
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd>.\
\
	*Between each paste the clipboard will automatically advance to the next
	item that was copied in order and the number in the menu bar icon will decrement.*

4. Repeat.\
\
	*When all copied items have been pasted, upon which the menu bar icon will
	return to normal, and copying and pasting will return to normal behavior.*


### Optional Alternatives

- You may click the Cleepp menu bar icon with <kbd>CONTROL (^)</kbd> pressed
to start collecting a set of clipboard items, or choose the "Start Collecting" item in the Cleepp menu.
See [Special Menu Icon Actions](#special-menu-icon-actions) and 
[Menu Items](#menu-items) below.

- Once you've started collecting a set of clipboard items, you may use you're
application's normal Copy or Cut command instead of the special Cleepp shortcut
to copy more and they'll still be added to the collected set of item.

- You can return to normal clipboard behavior by again clicking the Cleepp menu bar icon
with <kbd>CONTROL (^)</kbd> pressed, or using the "Cancel Collecting / Replaying" menu item.

- While in the middle of pasting, you are still able to copy more.
The clipboard item will be added to the set of menu items as normal and will get pasted last,
the number in the menu bar icon will increment.


## The Cleepp Menu

### Menu Icon State

On macOS 13 Ventura and later, Cleepp uses the system clipboard symbol as its menu icon,
and some of its variants. This is what those mean:

- <img width="27px" height="34px" src="Designs/Cleepp/clipboard.png" alt="Normal Icon" align="left" />
When the Cleepp menu has the outlined clipboard icon, the clipboard will have
its normal behavior.

- <img width="27px" height="34px" src="Designs/Cleepp/clipboard.fill.png" alt="Collecting Started  Icon" align="left" />
When the Cleepp menu has the empty filled icon, it has started collecting a set of
clipboard items, but has none yet. It will have a number 0 to its left.

- <img width="27px" height="34px" src="Designs/Cleepp/list.clipboard.fill.png" alt="Collecting/Replaying Icon" align="left" />
When the Cleepp menu has the lined filled icon, it has collected some clipboard items.
The number collected will be to its left.

- <img width="27px" height="34px" src="Designs/Cleepp/clipboard.disabled.png" alt="Disabled Icon" align="left" />
When the Cleepp menu has the disabled clipboard icon, the state of the clipboard
is being ignored. See [Ignore Copied Items](#ignore-copied-items) below.


### Special Menu Icon Actions

There are some actions that can be be triggered just by clicking the menu bar icon.
Clicking with these modifiers pressed will have the effects described below
(the menu won't open):

- With <kbd>CONTROL (^)</kbd> pressed: start Cleepp collecting a set of clipboard items,
see also the **Start Collecting** menu item, below.\
\
    If currently collecting or replaying menu items then this will instead cancel
and return the clipboard to its normal behaviour.

- With <kbd>SHIFT (⇧)</kbd> + <kbd>CONTROL (^)</kbd> + <kbd>OPTION (⌥)</kbd>
pressed:
have Cleepp begin ignoring items copied to the clipboard. You may want to do this
if you're dealing with sensitive data and prefer no record of it be saved.
Click again with the same modifiers held down to resume monitoring the clipboard.
See also [Ignore Copied Items](#ignore-copied-items) below.

- With <kbd>CONTROL (^)</kbd> + <kbd>OPTION (⌥)</kbd> pressed:
have Cleepp ignore just the next item copied to the clipboard.
See also [Ignore Copied Items](#ignore-copied-items) below.

Also, clicking the clicking the menu bar icon with <kbd>OPTION (⌥)</kbd> pressed
will opens the expanded Cleepp menu, which also includes recent history of
everything on the clipboard. This gives you some features for replaying a set or
just one previous clipboard item.
See [Expanded Clipboard History Items](#expanded-clipboard-history-items) and
[Start Replaying From History](#start-replaying-from-history) below.


### Menu Items

<img width="300px" height="192px" src="Designs/Cleepp/Normal menu.png" alt="Normal Menu" />

**About...** will open an about window with buttons for going to the Cleepp webpage,
it's source code on GitHub, and a link for sending support email.

**Start Collecting** to start a set of copies. It will put Cleepp into the mode where
items copied to the clipboard will be collected for replay,
Clicking the menu icon with <kbd>CONTROL (^)</kbd> pressed does the same thing.

**Copy & Collect** will start a set of copies, if Cleepp isn't already in collecting mode,
then tell the frontmost application to perform a copy. The default shortcut
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd>
can be changed in the settings.

**Paste & Advance** will tell the frontmost application to perform a paste then
automatically change the clipboard to the next item collected.
If no more items are collected then the clipboard will remain unchanged and
clipboard behavior will revert back to normal. The default shortcut
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd>
can be changed in the settings.

**Settings...** will open a settings window, see [Settings](#settings) below.
The shortcut for this menu item, <kbd>COMMAND (⌘)</kbd> + <kbd>,</kbd>
is not global and will only work when the Cleepp menu is open.

**Quit Cleepp** will remove Cleepp from the menu bar and stop it from monitoring
the clipboard.
The shortcut for this menu item, <kbd>COMMAND (⌘)</kbd> + <kbd>Q</kbd>
is not global and will only work when the Cleepp menu is open.


### Replay Clipboard Items

Having used Cleepp's special copy shortcut or the **Start Collecting** mewnu item
and then collected some clipboard items, each collected item will be shown in
the menu:

<img width="479px" height="313px" src="Designs/Cleepp/Replay items menu.png" alt="Replay Items Menu" />

**Cancel Collecting / Replaying** is available in place of **Start Collecting** 
Choosing this will exit this mode and return the clippboard to its normal behavior.
The most recent item copied will be left in the clipboard.
Clicking the menu icon with <kbd>CONTROL (^)</kbd> pressed will do the same
thing (toggles in and out of Cleepp's collecting / replaying mode).


When collecting and replaying a set of clipboard items, those items remaining
to paste are shows in the middle section of the Cleepp menu. The item at the top
is the most recent copied, the item at the bottom, badged with "replay from here"
will be the one that is pasted next.
(When running macOS versions before 14.0 Sonoma, menu items cannot be badged
the item to be pasted next will simply be the one at the bottom on the history) 


### Expanded Clipboard History Items

Clicking the menu icon with <kbd>OPTION (⌥)</kbd> pressed will show the
expanded menu which also includes recent history of everything on the clipboard:

<img width="405px" height="445px" src="Designs/Cleepp/Expanded menu.png" alt="Expanded Menu" />

When collecting and replaying a set of clipboard items, the item to be pasted
next will probably not be at the bottom but will still be indicated by the
badge "replay from here".
(When running macOS versions before 14.0 Sonoma, this item will instead be
indicated by an underline)

*This expanded menu give a simplified set of clipboard features from the open source
project [Maccy](https://maccy.app). For a more full featured set of features, including
more keyboard shortcuts, a pinning feature, and more, consider using that original app.
It can be found at their homepage [https://maccy.app](https://maccy.app).*

What you can do with the expanded history items:

- To see the full text of a history item, mouse over, or arrow-key to highlight it,
and wait a couple of seconds for tooltip.

- To replay pasting a clipboard item, select that item. It will be placed on the
clipboard and you can use your application's normal Paste command to paste it.

- You can delete a history item. Mouse over, or use arrow-keys to highlight it,
then press <kbd>COMMAND (⌘)</kbd> + <kbd>DELETE (⌫)</kbd>.

- A **Clear History...** menu item will be added at the bottom of the menu.
Use this if you want to completely empty the saved clipboard history.
If currently collecting clipboard items, then all such items will also be
cleared and clipboard behavior will return to normal.
The shortcut for this menu item,
<kbd>COMMAND (⌘)</kbd> + <kbd>OPTION (⌥)</kbd> +  <kbd>DELETE (⌫)</kbd>
is not global and will only work when the Cleepp menu is open. \
\
    *If you're wanting to delete a record of sensitive data you may have copied,
consider instead temporarily pausing Cleepp's monitoring of the clipboard
in the first place, see [Ignore Copied Items](#ignore-copied-items) below*


The number of history items displayed in the menu can be changed in the settings
window, see [Settings](#settings) below.


## Settings

(TBD)



## Bonus Features for the Mac App Store Version

These following extra features are unavailable for versions downloaded
from GitHub, and unlocked by the "Bonus Features" In-App Purchase for
downloads from the Mac App Store.
Purchases can be made in the Settings window, see [Settings](#settings) above.


### Undo Last Copy

Purchasing the Bonus Features unlocks this convenience clipboard feature at
the end of the Cleepp menu.

It can be easy to accidentally do
<kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> to Copy when you instead
meant to Paste. Often its not a problem if there's no selection at the time,
or if it's easy to return to where you copied from and do it again.

But on the occasion where you were trying to replace a selection, and also
it's time consuming to select again the content you had previously copied,
the **Undo Last Copy** command in the Cleepp menu can easily revert to
the previous clipboard item as if your accidental Copy never happened.

While this is similar to just opening the expanded Cleepp menu and choosing
to replay the item that's second from the top, it's less straight-forward to
do the right thing if you're in the middle of capturing / replaying a set of
clipboard items.
The **Undo Last Copy** command also removes the accidental copy from the history.

There is no Redo feature.


### Paste All / Paste Multiple...

Purchasing the Bonus Features unlocks a Paste All menu item. This will
automatically paste each item to be replayed all at once.

With <kbd>OPTION (⌥)</kbd> pressed, an alert will be opened allowing you
to enter a number of items to automatically paste instead of all them.


### Start Replaying From History

In addition to collecting a set of clipboard items by copying them normally,
purchasing the Bonus Features unlocks adds the ability to replay from items
previously copied and in the expanded Cleepp menu:

1. Click the Cleepp menu icon with <kbd>OPTION (⌥)</kbd> pressed.

2. Select a history item with <kbd>OPTION (⌥)</kbd> pressed, or highlighting the item
and press  <kbd>OPTION (⌥)</kbd> + <kbd>ENTER</kbd>.\
\
	*The menu bar icon will change and get a count value added beside it.*

3. Paste with the Cleepp shortcut
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd>
to paste each item in succession.\
\
	*Like regular clip collection and replay described in
[Basic Usage](#basic-usage), when the topmost history item in the menu
has been pasted, copying and pasting will return to normal behavior.
But when replaying from history, if's easy for there to be more items
in the history above the items you need.*\
\
	*As mentioned in [Optional Alternatives](#optional-alternatives), you can
return to normal clipboard behavior after pasting the last item you want to
paste by clicking the Cleepp menu bar icon with
<kbd>CONTROL (^)</kbd> pressed,
or using the “Cancel Collecting / Replaying” menu item*


### Additional History Features

Purchasing the Bonus Features also unlocks these features:

- Open the expanded Cleepp menu with <kbd>SHIFT (⇧)</kbd> pressed as well,
(ie. with <kbd>SHIFT (⇧)</kbd> + <kbd>OPTION (⌥)</kbd> pressed) to
include all stored history items in the menu, not just the size set
in the Appearance Settings panel, see [Settings](#settings) above.
(There is a separate limit on the size of the overall history which
can be changed in the Storage Settings panel)\
\
    *This menu may be longer than will fit on your screen and require
scrolling down to see all of them. This is where the following feature
may be helpful...*

- A Filter search box will be available above all of the history menu items.
Use it to textually filter the history items below, making it easier to
find a specific item within the menu, or not shown in the menu but still
within the saved history. You can then select an item to again put that in
the clipboard for copying, or select with <kbd>OPTION (⌥)</kbd> pressed
to start replaying all the items from that one forward.
See [Start Replaying From History](#start-replaying-from-history) above.


## Advanced

### Ignore Copied Items

You can tell Cleepp to ignore all copied items:

```sh
defaults write lol.bananameter.cleepp ignoreEvents true # default is false
```

This is useful if you have some workflow for copying sensitive data.
You can set `ignoreEvents` to true, copy the data and set `ignoreEvents`
back to false. While Cleepp is ignoring the clipboard the menu bar icon
will appear disabled.

You can do the same by clicking the Cleepp menu icon with
<kbd>SHIFT (⇧)</kbd> + <kbd>CONTROL (^)</kbd> + <kbd>OPTION (⌥)</kbd>
pressed. Do this once to start ignoring the clipboard, and again to resume
monitoring it.

You can also click the menu icon with <kbd>CONTROL (^)</kbd> + <kbd>OPTION (⌥)</kbd>
pressed to ignore only the next copy. After the next copy, normal clipboard
monitoring will automatically resume and the menu bar icon will be restored
to normal.


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
defaults write lol.bananameter.cleepp ignoredPasteboardTypes -array-add "com.myapp.CustomType"
```

If you need to find what custom types are used by an application, you can use the
free application [Pasteboard-Viewer](https://github.com/sindresorhus/Pasteboard-Viewer).
Simply download the application, open it, copy something from the application you
want to ignore and look for any custom types in the left sidebar.
[Here](https://github.com/p0deje/Maccy/issues/125)  is an example of using this approach
to ignore Adobe InDesign *(however where "org.p0deje.Maccy" is mentioned in that
forum thread, substitute "lol.bananameter.cleepp")*.

If you accidentally removed default types, you can restore the original configuration:

```sh
defaults write lol.bananameter.cleepp ignoredPasteboardTypes -array "de.petermaurer.TransientPasteboardType" "com.typeit4me.clipping" "Pasteboard generator type" "com.agilebits.onepassword" "net.antelle.keeweb"
```


## FAQ

### Why don't the Cleepp global shortcuts do anything?

Make sure "Cleepp" is added to System Settings ⮕ Privacy & Security ⮕ Accessibility.
The app will try to suggest and direct you there if you haven't yet given this
permission, but it might not always be able to do so.

The application you're using may also assign the key combinations that are the
same as the Cleepp defaults,
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>C</kbd> or
<kbd>CONTROL (^)</kbd> + <kbd>COMMAND (⌘)</kbd> + <kbd>V</kbd>.
If this is the case, you may use the Cleepp menu bar items
**Copy & Collect** or **Paste & Advance** instead of the corresponding
shortcut when using that application, or consider changing the Cleepp
global shortcuts in the Settings window, see [Settings](#settings) above.


## License

[MIT](./LICENSE)
