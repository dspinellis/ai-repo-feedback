#!/bin/bash
#
# Provide formative feedback on a GitHub repository's contents
#
# Copyright 2024 Diomidis Spinellis
#
# Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.
#

# Fail on command errors and unset variables
set -eu

# Bash option
set -o pipefail

# Display usage information and exit
usage()
{
  cat <<EOF 1>&2
Usage:
  $(basename $0) -d repo-dir [-h]
  $(basename $0) [-t] -l repo-list -f from-address -F from-name -s subject

  -d repo-dir   Output feedback for the specified repository directory
  -f email      Specify sender's email address
  -F name       Specify sender's name
  -h            Output feedback in HTML rather than Markdown
  -l repo-list  Send feedback emails for the repos/emails in the specified file
  -s subject    Specify email's subject
  -t            Test run; send out email only to the sender

Examples:
feedback -d repo-dir >comments.md
feedback -l repo-list -f mary@example.com -F 'Mary Zhu' -s Feedback [-t]
EOF
  exit 1
}

from_email=''
from_name=''
html=''
repo_dir=''
repo_list=''
subject=''
test_run=''
# Process command-line arguments
while getopts "d:F:f:hl:s:t" opt; do
  case $opt in
    d)
      repo_dir="$OPTARG"
      ;;
    F)
      from_name="$OPTARG"
      ;;
    f)
      from_email="$OPTARG"
      ;;
    h)
      html=1
      ;;
    l)
      repo_list="$OPTARG"
      ;;
    s)
      subject="$OPTARG"
      ;;
    t)
      test_run=1
      ;;
    \?) # Illegal option
      usage
      ;;
    :)
      echo "Option -$OPTARG requires an argument." >&2
      usage
      ;;
  esac
done

shift "$((OPTIND-1))"

# Query the AI server with the prompt received from the standard input
query_ai()
{
  tee query.in |
  python query-ai.py "$@" |
  tee query.out
  sleep 59
}

# Provide the system's general prompt
general_prompt()
{
  cat <<\EOF
Your objective is to provide feedback to a group
of students regarding their group project.
Your feedback should be constructive, backed by concrete evidence,
target only the specific question, and structured to start with
the positive aspects.
Provide the feedback in Markdown format, with headings starting
from the second level (##) and moving downward as required.
DO NOT provide an overall top-level heading (#);
this will be supplied externally.
Where possible, start each heading with a relevant Unicode emoji character,
for example "❌ Missing Files" or "📂 Project Structure".

EOF
}

# Output the specified heading and also report is as a progress indicator
heading()
{
  local heading="$1"

  echo
  echo "$heading"
  echo
  echo "Preparing section: $heading" >&2
}

# Report on the specified repo's contents
report_contents()
{
  local repo="$1"

  heading '# 2. Repository contents'
  (
    general_prompt
    cat <<\EOF
Below you will find a list of the application's source files as taken from
the repository.
Please provide feedback on the structure, missing files, and files
that shouldn't have been included.
Don't forget to comment on building, testing, and documentation.
Comment explicitly on support for continuous integration.
Do not provide comments regarding the (unknown to you) file contents.
EOF
    git --git-dir="$repo"/.git ls-files
  ) | query_ai
}

# Report on the project's architecture
report_architecture()
{
  local repo="$1"

  heading '# 3. Project architecture'

  if (( $(find "$repo" -name \*.java | wc -l) == 0)) ; then
    echo 'No Java files were found in the repository. Nothing to report.'
    return
  fi

  (
    general_prompt
    cat <<\EOF
Below you will find the declarations of the project's classes and interfaces
and the corresponding source code file size.
Provide feedback on their naming and the project's architecture as
revealed by them.
EOF
    cd "$repo"

    find . -name \*.java |
    xargs sed -nE '/\s*((public|final|abstract|sealed|non-sealed)\s+)*(class|interface|enum|record).*\{/s/$/ }/p' | grep -Fv .class || true
    find . -name \*.java |
    xargs wc -l
  ) | query_ai
}

# Report on each source code of the specified file
report_source_code()
{
  local repo="$1"
  local path="$2"
  local number="$3"

  heading "## $number File $(basename $path)"
  (
    general_prompt
    cat <<\EOF
Below you will find the contents of one of the project source code
files.
Provide feedback concerning the code's quality: design, readability,
correctness, and maintainability in general.
Report egregious violations of diverse Java style guides,
for example overly large method bodies.
Comment, if needed, on the adoption of JavaDoc comments.
Only provide concrete constructive suggestions regarding possible
improvements.
Be succinct.
If there is nothing important to repost, just say so, e.g. "The code
is generally OK" and be done.
Do not summarize your findings.
EOF
    echo "File: $path"
    # Remove non-ASCII characters, as we can't know the encoding
    cat "$repo/$path"
  ) | query_ai --model gpt-4o-mini |
    sed 's/^#/##/'
  echo
}

# Report on each source code file
report_all_source_code()
{
  local repo="$1"
  local counter=1

  heading '# 4. Source code'
  if (( $(find "$repo" -name \*.java | wc -l) == 0)) ; then
    echo 'No Java files were found in the repository. Nothing to report.'
    return
  fi

  cat <<\EOF
The following sections provide feedback regarding the source code of
up to the five largest Java files included in the repository.
Consider taking the comments into account for the remaining files.

EOF
  (
    cd "$repo"

    find . -name \*.java -ls |
    sort -k 7nr |
    head -5 |
    awk '{print $11}'
  ) |
  while read path ; do
    report_source_code "$repo" "$path" "4.$counter"
    ((counter++))
  done
}

# Output build specification files
find_build()
{
  local repo="$1"

  find "$repo" -type f \( -name "pom.xml" \
    -o -name "build.xml" \
    -o -name "build.gradle" \
    -o -name "settings.gradle" \
    -o -name "build.gradle.kts" \
    -o -name "settings.gradle.kts" \)
}

# Report on the project's build specification
report_build()
{
  local repo="$1"

  heading '# 5. Project build specification'
  if (( $(find_build "$repo" | wc -l) == 0)) ; then
    echo 'No build files (Maven, Ant, or Gradle) were found in the repository. Consider adding a build file.'
  fi

  (
    general_prompt
    cat <<\EOF
Below you will find the project's build specification.
Provide feedback regarding the included plugins, libraries, and versions.
Focus on whether the build contains appropriate continuous integration
checks via static analysis, testing, etc.
EOF
    cd "$repo"
    find_build . |
    while read file ; do
      echo "File $file"
      cat "$file"
      echo '-------------------------------------------------'
    done
  ) | query_ai
}

# Report on the specified repo's commit history
report_commits()
{
  local repo="$1"

  heading '# 6. Configuration management'
  (
    general_prompt
    cat <<\EOF
Below you will find a summary of the project's commits.
Please provide feedback regarding their frequency, the participation
of team members, their size, and the contents of the commit messages.
Note that some team members may not have any commits associated with
them, so comment only on the ones that appear here but avoid stating
that all team members have contributed.
Regarding commit message wording, we want the summary to be expressed
in the imperative mood ("Fix X" rather than "Fixed x" or "Fixes X").
EOF
    git --git-dir="$repo"/.git log --stat
  ) |
    head -n 5000 |
  query_ai --model gpt-4o-mini
}

# Provide introductory information
report_intro()
{
  local repo="$1"
  local name="$2"
  local url="$3"

  cat <<EOF
# 1. Introduction

This report contains feedback regarding the default branch of
the Git repository [$name]($url) up to commit
$(git --git-dir="$repo/.git" rev-parse --short HEAD).
It was AI-generated by the
[AI repo feedback project](https://github.com/dspinellis/ai-repo-feedback)
version $(git rev-parse --short HEAD) on $(date +%F)
through diverse GPT models with prompts
containing detailed instructions and key elements of the repository.
The report covers the following areas:

* Repository contents
* Project architecture
* Source code
* Project build specification
* Configuration management

As with all AI-generated content,
verify the recommendations' correctness,
evaluate their appropriateness,
and avoid following them blindly.

EOF
}

# Report on the specified repository
report()
{
  local repo="$1"
  local name="$2"
  local url="$3"

  report_intro "$repo" "$name" "$url"
  report_contents "$repo"
  report_architecture "$repo"
  report_all_source_code "$repo"
  report_build "$repo"
  report_commits "$repo"
}

# Convert Markdown input into HTML output
md_to_html()
{
    pandoc --metadata pagetitle="Repository report" --css=pandoc.css \
      --standalone --embed-resources
}

# Main processing starts here
if [ "$repo_dir" ] ; then
  report "$repo_dir" "$(basename $repo_dir)" "file://$(realpath $repo_dir)" |
  if [ "$html" ] ; then
    md_to_html
  else
    cat
  fi
elif [ "$repo_list" ] ; then
  if [ -z "$from_email" -o -z "$from_name" -o -z "$subject" ] ; then
    usage
  fi
  while read url email ; do
    if [ "$test_run" ] ; then
      email="$from_email"
    fi
    echo "Working on $url for $email" 1>&2
    rm -rf repo-dir
    git clone "$url" repo-dir
    repo=$(basename $url)
    report repo-dir "$repo" "$url" |
      tee report.md |
      md_to_html |
      ./send-mail.py \
        --from-name "$from_name" \
        --from-email "$from_email" \
        --to-email "$email" \
        --subject "$subject" \
        --content-type html
    done <"$repo_list"
else
  usage
fi
