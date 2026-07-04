# Albion permissions deny fragment
Merge `permissions-deny.json` into the Claude Code settings file used with Albion.
The fragment is a hard floor beneath `plugin/scripts/pre-tool-guard.sh`.
It uses modern prefix deny syntax where Claude Code can express the command.
Keep local project allow rules separate so this deny list remains reviewable.
