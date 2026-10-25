# Changesets

A changeset says which packages a change releases and how far each version moves. Add one with `pnpm changeset` in the PR that makes the change. On `main`, the release workflow keeps a "Version packages" PR open that applies them. Merging it publishes every package it bumps.
