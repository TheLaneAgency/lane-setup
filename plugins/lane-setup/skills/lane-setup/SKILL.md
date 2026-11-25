---
name: lane-setup
description: Set up a Lane colleague's Mac for the Lane Claude Code plugins (populate-content, generate-site, timesheet and the rest), from the Code tab, with no Terminal. Installs Apple's command line tools, GitHub's gh tool and pandoc, signs in to GitHub in the browser, installs the Lane plugins, connects WebTracker and Claude in Chrome, then checks it all works. Use when someone asks to set up, onboard or install the Lane plugins or skills, when a Lane plugin won't install or can't reach GitHub, or when they say "run lane-setup". Safe to run again: it picks up where it left off.
---

# Lane setup

The person is a Lane colleague, often not a developer, sitting in the Code tab of the
Claude app. Get their Mac ready for the Lane plugins by running `scripts/setup.sh` for
them, one step at a time.

**The person never uses Terminal.** Don't tell them to open it, don't open the Terminal
panel, don't give them a command to run, and don't offer a sign-in button that opens
one. Every command here is yours to run. The only things they do are click in windows
Apple, GitHub, WebTracker and Chrome show them, and paste what you ask for into this
chat. If a step seems to need Terminal, stop and tell them to ask Rob, rather than
finding another way.

**Never ask for a GitHub password or personal access token.** GitHub sign-in is the
browser code in step 3, nothing else.

Talk to them in plain words, one step at a time: say what you're doing, what they'll
see, and the one thing they need to do. Don't show them the script's output; tell them
what it means.

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

They give the Mac `git` and `python3`, which everything else needs. Run
`bash <script> clt`. A window from Apple appears asking to install the command line
developer tools: tell them to click **Install**, agree to the licence, and tell you
when it says the software was installed. It can take a few minutes. Then run `status`
again and check `clt=yes` before going on.

## 2. GitHub's gh tool (`gh`)

Run `bash <script> gh`. Nothing for them to do.

## 3. GitHub sign-in (`gh_signed_in`, `git_uses_gh`, `lane_repo_access`)

The Lane plugins are in a private GitHub repository, so their GitHub account has to be
in the TheLaneAgency organisation.

First ask whether they have a GitHub account. If not, they make one at
https://github.com/signup with their work email, and ask Rob to invite it to
TheLaneAgency. They accept the invitation email before going on.

Then run `bash <script> gh-login`. It opens https://github.com/login/device in their
browser and prints `code=XXXX-XXXX`. Show them the code on its own line, in bold, and
say: "On the GitHub page that just opened, sign in if asked, type this code, click
Continue, then Authorize GitHub CLI. Tell me when it says you're done."

When they say it's done, run `bash <script> gh-finish`.

- `not signed in yet`: they haven't finished in the browser. Ask them to check the
  page. If the code has expired (after about 15 minutes), run `gh-login` again.
- `lane_repo_access=no`: their account isn't in TheLaneAgency yet. Tell them to ask
  Rob for an invite, then accept it from the email or https://github.com/orgs/TheLaneAgency
  and tell you. Run `gh-finish` again. Don't go on to step 4 until it says yes.

## 4. The Lane plugins (`marketplace_lane`, `installed_lane_plugins`)

Ask what they'll use Claude for, and install to match:

- filling stage sites with client copy (account managers): `lane-site-generator`
- everything Lane has: `all`

Run `bash <script> plugins <names>`, for example `bash <script> plugins lane-site-generator`.
It also installs this setup skill, so "run lane-setup" works next time.

## 5. pandoc and the PATH (`pandoc`, `path`)

Run `bash <script> pandoc`, then `bash <script> path`. Nothing for them to do.

## 6. WebTracker (`webtracker`)

WebTracker signs them in to each WordPress site, so they never make a WordPress
password. Tell them:

1. Open https://webtracker.thelane.io/claude-code and sign in if asked.
2. Click **Create token** (or **Replace token** if they've made one before).
3. WebTracker shows a command. Click its copy button and paste it here.

From what they paste, take the token: the text after `Bearer ` inside the quotes. Run
it through the script on stdin, never as an argument:

```
printf '%s' '<token>' | bash <script> webtracker
```

Don't repeat the token in chat. If they have no WebTracker login, they ask Rob for one.

## 7. Claude in Chrome (`chrome_extension`)

The Lane skills check pages in their own Chrome. If `chrome_extension=no`, tell them
to open https://chromewebstore.google.com/detail/fcoeoabgfenejglbffodgkkbkcdhcgfn in
Chrome, click **Add to Chrome**, then click the Claude icon in Chrome's toolbar and
sign in with the same Claude account as this app. They need Google Chrome itself: if
they don't have it, it's at https://www.google.com/chrome/.

## 8. Restart and check

Tell them to quit the Claude app completely (Claude menu > Quit) and open it again, so
the plugins and WebTracker load, then start a new Code tab session and type
**run lane-setup** to finish.

In that new session, run `status`. Everything should say yes. Then check the parts the
script can't see:

- WebTracker: call its `search-websites` tool (ToolSearch "webtracker" if it isn't
  loaded). An error means the token didn't take: repeat step 6.
- Chrome: ToolSearch for "claude-in-chrome" and call `tabs_context_mcp`. If it can't
  reach Chrome, tell them to click the Claude icon in Chrome's toolbar and make sure
  it's signed in and connected.

If they installed `lane-site-generator`, finish with a real check: ask which stage
site they'll work on first and ask, as them, "Am I signed in to <site> for
populate-content? Sign me in through WebTracker if not." That runs the populate-content
skill's sign-in. If it says they have no account on the site, a developer adds them
in wp-admin with their WebTracker email and the Editor role.

## When it's done

Tell them it's ready, and give them a few things to try, smallest first:

- "List the pages on <site>."
- "Show me what's on the About page, block by block."
- "Use this doc for the content on the About page." with the document's path: in
  Finder, right-click the file, hold Option, choose **Copy "…" as Pathname**, and
  paste it into the message.

To pick up new versions of the Lane plugins later, they ask Claude in the Code tab:
"update the Lane plugins".
