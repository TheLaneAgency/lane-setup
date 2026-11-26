---
name: lane-setup
description: Set up a Lane developer's Mac for the build plugins in TheLaneAgency/lane-dev-skills (lane-site-generator, lane-wordpress, lane-hosting), from the Code tab. Installs Apple's command line tools and GitHub's gh tool, signs in to GitHub in the browser, installs the lane-dev plugins, connects WebTracker and Claude in Chrome, then runs the site generator's own environment check. Use when a developer asks to set up or install the Lane dev plugins, when one of them won't install or can't reach GitHub, or when they say "run lane-setup". Safe to run again: it picks up where it left off. Not for account managers or anyone else: their Lane plugins come through Lane's Claude Team account and set themselves up on first run.
---

# Lane setup

The person is one of Lane's technical staff, in the Code tab of the Claude app. Get
their Mac ready for the plugins in the private `TheLaneAgency/lane-dev-skills` repo by
running `scripts/setup.sh` for them, one step at a time. Every command here is yours to
run; what they do is click in the windows Apple, GitHub, WebTracker and Chrome show them,
and paste what you ask for into the chat.

**This is for developers only.** Everyone's Lane plugins (timesheet, populate-content,
branding and the rest) come through Lane's Claude Team account, and each one sets up what
it needs the first time it runs. If someone who doesn't build or host sites asks for
setup, tell them that, and that they ask Rob if a plugin is missing.

**Never ask for a GitHub password or personal access token.** GitHub sign-in is the
browser code in step 3, nothing else.

Say what you're doing and the one thing they need to do. Don't show them the script's
output; tell them what it means.

## The script

When this skill is installed, the script is `scripts/setup.sh` beside this file. On the
first run it isn't installed yet (this file was read from the web): download the script
first, and use that copy until step 4 installs the plugin.

```
mkdir -p ~/.local/share/lane-setup && curl -fsSL https://raw.githubusercontent.com/TheLaneAgency/lane-setup/main/plugins/lane-setup/skills/lane-setup/scripts/setup.sh -o ~/.local/share/lane-setup/setup.sh
```

Run it as `bash <script> <command>`. Start with `bash <script> status`, and run it
again whenever you're unsure where things stand. Each line is `name=yes` or `name=no`.
Skip any step whose line already says yes.

## 0. The Code tab

Check `CLAUDE_CODE_ENTRYPOINT` is set (`echo $CLAUDE_CODE_ENTRYPOINT`). If you're in
an ordinary Claude chat instead, you can't run anything: tell them to click the `</>`
button at the top of the sidebar, beside the chat bubble, to switch to Claude Code,
start a new session there and paste their request again.

## 1. Apple's command line tools (`clt`)

They give the Mac `git` and `python3`. Run `bash <script> clt`. A window from Apple
asks to install the command line developer tools: tell them to click **Install**, agree
to the licence, and tell you when it's finished. Then run `status` again and check
`clt=yes` before going on.

## 2. GitHub's gh tool and the PATH (`gh`, `path`)

Run `bash <script> gh`, then `bash <script> path`. Nothing for them to do.

## 3. GitHub sign-in (`gh_signed_in`, `git_uses_gh`, `dev_repo_access`)

The dev plugins are in a private repo that only technical staff can read, so their
GitHub account has to have access to `TheLaneAgency/lane-dev-skills`.

First ask whether they have a GitHub account. If not, they make one at
https://github.com/signup with their work email, and ask Rob to add it to
TheLaneAgency with access to lane-dev-skills. They accept the invitation email before
going on.

Then run `bash <script> gh-login`. It opens https://github.com/login/device in their
browser and prints `code=XXXX-XXXX`. Show them the code on its own line, in bold, and
say: "On the GitHub page that just opened, sign in if asked, type this code, click
Continue, then Authorize GitHub CLI. Tell me when it says you're done."

When they say it's done, run `bash <script> gh-finish`.

- `not signed in yet`: they haven't finished in the browser. Ask them to check the
  page. If the code has expired (after about 15 minutes), run `gh-login` again.
- `dev_repo_access=no`: their account can't read lane-dev-skills yet. Tell them to ask
  Rob for access, accept the invitation, and tell you. Run `gh-finish` again. Don't go
  on to step 4 until it says yes.

## 4. The dev plugins (`marketplace_lane_dev`, `installed_dev_plugins`, `old_lane_copies`)

Run `bash <script> plugins`. It adds the `lane-dev` marketplace and installs
`lane-site-generator`, `lane-wordpress` and `lane-hosting`, and installs this setup
skill so "run lane-setup" works next time.

Those three plugins used to be in the `lane` marketplace, and a copy installed from
there stops loading. The script removes any it finds (saying "removed"), and if one was
the site generator, installs `lane-populate-content` so they keep that skill. Tell them
in a line.

## 5. WebTracker (`webtracker`)

The hosting and site generator skills record servers and sites in WebTracker, and
populate-content signs in through it. Tell them:

1. Open https://webtracker.thelane.io/claude-code and sign in if asked.
2. Click **Create token** (or **Replace token** if they've made one before).
3. WebTracker shows a command. Click its copy button and paste it here.

From what they paste, take the token: the text after `Bearer ` inside the quotes. Run
it through the script on stdin, never as an argument:

```
printf '%s' '<token>' | bash <script> webtracker
```

Don't repeat the token in chat. If they have no WebTracker login, they ask Rob for one.

## 6. Claude in Chrome (`chrome_extension`)

If `chrome_extension=no`, tell them to open
https://chromewebstore.google.com/detail/fcoeoabgfenejglbffodgkkbkcdhcgfn in Chrome,
click **Add to Chrome**, then click the Claude icon in Chrome's toolbar and sign in with
the same Claude account as this app. They need Google Chrome itself: if they don't have
it, it's at https://www.google.com/chrome/.

## 7. Restart and check

Tell them to quit the Claude app completely (Claude menu > Quit) and open it again, so
the plugins and WebTracker load, then start a new Code tab session and type
**run lane-setup** to finish.

In that new session, run `status`. Everything should say yes. Then:

- WebTracker: call its `search-websites` tool (ToolSearch "webtracker" if it isn't
  loaded). An error means the token didn't take: repeat step 5.
- Chrome: ToolSearch for "claude-in-chrome" and call `tabs_context_mcp`. If it can't
  reach Chrome, tell them to click the Claude icon in Chrome's toolbar and make sure
  it's signed in and connected.
- The rest of a developer's setup: run `bash <script> check`. It's the site generator's
  own check of Herd, WP-CLI, PHP, Node, the database server, Pillow, Playwright and SSH
  access to the `wordpress7` base, and it prints the fix for anything missing. Go
  through the fixes with them. The lane-wordpress skill `wp-local-herd` sets up Herd and
  WP-CLI from nothing.

## When it's done

Tell them it's ready, and give them a few things to try:

- "Get <site> running locally" in a Lane WordPress repo, for `wp-local-herd`.
- "Build this site from Figma: <link>" in an empty `site` folder, for `generate-site`.
- "List the RunCloud servers", for `runcloud`.

To pick up new versions later, they ask Claude in the Code tab to update the lane-dev
plugins.
