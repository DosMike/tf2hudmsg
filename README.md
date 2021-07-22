TF2 Hud Msg
=====

Library for hud message stuff in TF2.

This plugins exists mainly because CursorAnnotations, the thing [Annotations](https://forums.alliedmods.net/showthread.php?p=1317304),
[Gravestone Markers](https://forums.alliedmods.net/showthread.php?p=1946768) and [ChatBubbles]() use, require a server wide unique id
for their cursor annotations. Not only does this library track and manage those ids, but it also provides nice natives in form of a
methodmap to manage, show and hide those annotations again.

I also provide natives for HudMessageCustom, a small element centered in the lower half of the Hud. The only thing you should consider
with this is, that `cl_hud_minmode 1` or `tf_hud_notification_duration 0` hides this element, so it probably shouldn't display
critical information.
The HudMessageCustom natives have an option to strip morecolors color values, so if you display messages that would normally be colored
in chat do not print color formats in the hud.

Requires `morecolors.inc` to compile.