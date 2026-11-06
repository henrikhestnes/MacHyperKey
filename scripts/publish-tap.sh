#!/bin/zsh
set -euo pipefail
cd "${0:A:h:h}"

if (( $# > 1 )); then
  print -u2 'Usage: ./scripts/publish-tap.sh [vVERSION]'
  exit 2
fi
app_repository="henrikhestnes/MacHyperKey"
tap_repository="henrikhestnes/homebrew-tap"
if [[ "$(git config user.email)" != "henrik.hestnes@hotmail.com" ]]; then
  print -u2 'Set this repository’s user.email to henrik.hestnes@hotmail.com first.'
  exit 1
fi
account=$(gh api user --jq .login)
if [[ "${account:l}" != "henrikhestnes" ]]; then
  print -u2 'Sign gh in as henrikhestnes before publishing the tap.'
  exit 1
fi
if (( $# == 1 )); then
  tag="$1"
else
  tag=$(gh release view --repo "$app_repository" --json tagName --jq .tagName)
fi
if [[ ! "$tag" =~ '^v[0-9]+\.[0-9]+\.[0-9]+$' ]]; then
  print -u2 "Expected a stable release tag, got: $tag"
  exit 1
fi
if [[ "$(gh release view "$tag" --repo "$app_repository" --json isDraft --jq .isDraft)" != "false" ]]; then
  print -u2 'Publish the app release before updating the tap.'
  exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/machyperkey-tap.XXXXXX")
mkdir -p "$work/asset"
# Read the cask from the release tag, never from an unpublished working tree.
gh api "repos/$app_repository/contents/Casks/machyperkey.rb?ref=$tag" --jq .content \
  | /usr/bin/base64 --decode > "$work/machyperkey.rb"
gh release download "$tag" --repo "$app_repository" --pattern MacHyperKey.zip --dir "$work/asset"
python3 - "$work" "$tag" <<'PY'
from pathlib import Path
import hashlib
import plistlib
import re
import sys
from zipfile import ZipFile
work, tag = Path(sys.argv[1]), sys.argv[2]
cask = (work / 'machyperkey.rb').read_text()
checksum = hashlib.sha256((work / 'asset/MacHyperKey.zip').read_bytes()).hexdigest()
assert re.search(r'^cask "machyperkey" do$', cask, re.M), 'Unexpected cask token.'
assert f'  version "{tag[1:]}"' in cask, 'Cask version differs from the published release.'
assert f'  sha256 "{checksum}"' in cask, 'Published ZIP does not match the cask checksum.'
with ZipFile(work / 'asset/MacHyperKey.zip') as archive:
    assert archive.testzip() is None, 'Damaged published ZIP.'
    info = plistlib.loads(archive.read('MacHyperKey.app/Contents/Info.plist'))
    assert info['CFBundleShortVersionString'] == tag[1:], 'Published ZIP contains a different app version.'
    assert info['CFBundleIdentifier'] == 'io.machyperkey.app', 'Unexpected app in the published ZIP.'
assert '  url "https://github.com/henrikhestnes/MacHyperKey/releases/download/v#{version}/MacHyperKey.zip"' in cask, 'Unexpected download URL.'
print(f'Verified the published MacHyperKey {tag} ZIP and cask.')
PY
ruby -c "$work/machyperkey.rb"

existing=false
if gh repo view "$tap_repository" --json nameWithOwner,isPrivate > "$work/repository.json" 2> "$work/repository.error"; then
  python3 - "$work/repository.json" <<'PY'
import json
import sys
repo = json.load(open(sys.argv[1]))
assert repo['nameWithOwner'].lower() == 'henrikhestnes/homebrew-tap', 'Unexpected repository.'
assert repo['isPrivate'] is False, 'The existing homebrew-tap repository is private. It was left unchanged.'
PY
  existing=true
  gh repo clone "$tap_repository" "$work/repo"
else
  if ! /usr/bin/grep -Eq 'Could not resolve to a Repository|HTTP 404|Not Found' "$work/repository.error"; then
    cat "$work/repository.error" >&2
    exit 1
  fi
  git init --quiet --initial-branch=main "$work/repo"
fi

git -C "$work/repo" config user.name "$(git config user.name)"
git -C "$work/repo" config user.email henrik.hestnes@hotmail.com
mkdir -p "$work/repo/Casks"
cp "$work/machyperkey.rb" "$work/repo/Casks/machyperkey.rb"
# The tap is shared with MacMiddleClick, MacMural and MacSnip; describe all four apps if MacHyperKey is not listed yet.
if ! /usr/bin/grep -q 'henrikhestnes/tap/machyperkey' "$work/repo/README.md" 2>/dev/null; then
  cat > "$work/repo/README.md" <<'MD'
# Henrik Hestnes’s Homebrew tap

| App | Install |
| --- | --- |
| [MacHyperKey](https://github.com/henrikhestnes/MacHyperKey), turns caps lock or another key into a hyper key (⌃⌥⌘) | `brew install --cask henrikhestnes/tap/machyperkey` |
| [MacMiddleClick](https://github.com/henrikhestnes/MacMiddleClick), middle clicks with a three-finger tap or click on the trackpad | `brew install --cask henrikhestnes/tap/macmiddleclick` |
| [MacMural](https://github.com/henrikhestnes/MacMural), a lightweight macOS screen annotation app | `brew install --cask henrikhestnes/tap/macmural` |
| [MacSnip](https://github.com/henrikhestnes/MacSnip), an Ubuntu-style screenshot tool for the menu bar | `brew install --cask henrikhestnes/tap/macsnip` |

Homebrew automatically adds this tap. To add it separately, use `brew tap henrikhestnes/tap`.

Update with `brew update` and `brew upgrade --cask <app>`, for example `brew upgrade --cask macsnip`.

Each app’s source and release downloads are hosted in its own repository. This repository contains the Homebrew casks, each pinned to a published release and its SHA-256 checksum.

The apps are not notarized by Apple. These casks do not disable or bypass Gatekeeper.
MD
  git -C "$work/repo" add README.md
fi
git -C "$work/repo" add Casks/machyperkey.rb
if ! git -C "$work/repo" diff --cached --quiet; then
  git -C "$work/repo" commit -m "Update MacHyperKey cask to $tag"
fi
if [[ "$existing" == "true" ]]; then
  git -C "$work/repo" push origin HEAD
else
  gh repo create "$tap_repository" --public \
    --description "Homebrew casks for Henrik Hestnes’s apps" \
    --source "$work/repo" --remote origin --push
fi
branch=$(git -C "$work/repo" branch --show-current)
curl --fail --silent --show-error --location --retry 4 --retry-delay 2 --retry-all-errors \
  "https://raw.githubusercontent.com/$tap_repository/$branch/Casks/machyperkey.rb" \
  --output "$work/public-cask.rb"
cmp "$work/machyperkey.rb" "$work/public-cask.rb"
print "Tap published: https://github.com/$tap_repository"
print 'Install with: brew install --cask henrikhestnes/tap/machyperkey'
