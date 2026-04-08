#!/bin/bash
# engine.sh — route action to ruleset
#
# Given a tool name, command, and file path, output the matching ruleset name.
# The ruleset maps to a file in contexts/{ruleset}.md
#
# Usage: engine.sh <tool> <command> <file_path>

TOOL="$1"
COMMAND="$2"
FILE_PATH="$3"

case "$TOOL" in
  Bash)
    case "$COMMAND" in
      git\ commit*|git\ -c\ *commit*)       echo "commit" ;;
      git\ push*)                            echo "push" ;;
      *test*|*jest*|*pytest*|*vitest*|*cargo\ test*|*go\ test*|*dotnet\ test*|*make\ test*|*bun\ test*|*pnpm\ test*|*yarn\ test*)
                                             echo "test-run" ;;
      *build*|*compile*|*tsc*|*webpack*|*vite\ build*)
                                             echo "build" ;;
      curl*|wget*|http*|*fetch*)             echo "api-call" ;;
      *deploy*|*wrangler*|*kubectl*|*helm*)  echo "infra" ;;
      *)                                     echo "general-bash" ;;
    esac
    ;;
  Edit|Write)
    case "$FILE_PATH" in
      *.tsx|*.jsx|*.vue|*.svelte|*/components/*|*/pages/*|*/views/*|*/layouts/*)
        echo "ui" ;;
      */api/*|*/routes/*|*/handlers/*|*/controllers/*|*/endpoints/*|*/server/*)
        echo "api" ;;
      *.sql|*/migrations/*|*/seeds/*|*/fixtures/*|*/prisma/*)
        echo "data" ;;
      *.test.*|*.spec.*|*__tests__/*|*__mocks__/*|*/test/*|*/tests/*)
        echo "test-write" ;;
      *.yaml|*.yml|*.toml|*/k8s/*|*/deploy/*|*/helm/*|Dockerfile*|docker-compose*|*.tf|*.hcl)
        echo "infra" ;;
      *.md|*.mdx)
        echo "docs" ;;
      *)
        echo "general" ;;
    esac
    ;;
  *)
    echo "general" ;;
esac
