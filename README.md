# Lane setup

Gets a Lane colleague's Mac ready for Lane's Claude Code plugins, with no Terminal.

## Setting up

1. Open the Claude app and switch to **Claude Code**: the `</>` button at the top of
   the sidebar, beside the chat bubble. The Lane plugins only work there, not in an
   ordinary Claude chat.

   ![The Code button at the top of the Claude app's sidebar](images/code-button.png)
2. Start a new session and paste:

   ```
   Set me up for Lane's Claude plugins. Read https://raw.githubusercontent.com/TheLaneAgency/lane-setup/main/plugins/lane-setup/skills/lane-setup/SKILL.md and follow it.
   ```

Claude does the rest and tells you each time it needs a click from you: Apple's
installer, a GitHub code, a WebTracker token and the Chrome extension. Have these
ready:

- a GitHub account in the TheLaneAgency organisation (ask Rob for an invite);
- a WebTracker login;
- Google Chrome.

To run it again later, to fix a setup or add plugins, type **run lane-setup** in a
Code tab session.

## What's here

This repository is public so it can be installed before GitHub is signed in. It holds
the setup skill only. The Lane plugins themselves are in the private
`TheLaneAgency/lane-claude-skills`, and the build plugins for technical staff in
`TheLaneAgency/lane-dev-skills`.

`plugins/lane-setup/skills/lane-setup/scripts/setup.sh` does the work; `status` shows
where a Mac stands.
