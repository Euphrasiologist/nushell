# Nushell Environment Config File

# make a left promt with reasonably consistent length.
# so super long left prompts are a thing of the past
def create_left_prompt [] {
  # deal with the special case of being in the root (of everything)
  let in_root = (($env.PWD) | path split | skip 1 | is-empty)

  if $in_root {
    # return RED slaaash
    echo [(ansi {fg: "FD3A2D", bg: ""}) "/"] | str collect
  } else {
    # get first two and last two path elements...
    let first = (($env.PWD) | path split | skip 1 | first 2)
    let last = (($env.PWD) | path split | last 2)
    
    # check if the last contains either the first or last elements of last.
    let last_first = ($last | any ($it | str contains $first.0))
    let last_second = ($last | any ($it | str contains $first.1))

    if $last_first || $last_second {
      # I deal with this really badly
      let pwd = (($env.PWD) | path split)
      let root = $pwd.0
      # ignore errors if we get them
      let one = do -i { $pwd.1 } 
      let two = do -i { $pwd.2 }
      let three = do -i { $pwd.3 }
      
      let one_sep = (if ($two | is-empty) { echo } else { echo / })
      let two_sep = (if ($three | is-empty) { echo } else { echo / })

      echo [ (ansi reset) $root (ansi {fg: "FE612C", bg: ""}) $one (ansi reset) $one_sep (ansi {fg: "FF872C", bg: ""}) $two (ansi reset) $two_sep (ansi {fg: "FFA12C", bg: ""}) $three] | str collect
      
    } else {
      # combine both in this wonderful format.
      # with colour!
      echo [(ansi {fg: "FD3A2D", bg: ""}) $first.0 (ansi reset) / (ansi {fg: "FE612C", bg: ""}) $first.1 (ansi reset) ... (ansi {fg: "FF872C", bg: ""}) $last.0 (ansi reset) / (ansi {fg: "FFA12C", bg: ""}) $last.1 ] | str collect
    }
  }
}

def create_right_prompt [] {
    let time_segment = ([
        # changed to UK date format
        (ansi {fg: "FFA12C", bg: ""}) (date now | date format '%d/%m/%Y %r')
    ] | str collect)

    $time_segment
}

# Use nushell functions to define your right and left prompt
let-env PROMPT_COMMAND = { panache-git }
let-env PROMPT_COMMAND_RIGHT = { create_right_prompt }

# The prompt indicators are environmental variables that represent
# the state of the prompt
let-env PROMPT_INDICATOR = (echo (ansi {fg: "FFA12C", bg: ""}) " > " | str collect)
let-env PROMPT_INDICATOR_VI_INSERT = ": "
let-env PROMPT_INDICATOR_VI_NORMAL = (echo (ansi {fg: "FFA12C", bg: ""}) " > " | str collect)
let-env PROMPT_MULTILINE_INDICATOR = (echo (ansi {fg: "FE612C", bg: ""}) ":" (ansi {fg: "FF872C", bg: ""}) ":" (ansi {fg: "FFA12C", bg: ""}) ": "  | str collect)

# Specifies how environment variables are:
# - converted from a string to a value on Nushell startup (from_string)
# - converted from a value back to a string when running external commands (to_string)
# Note: The conversions happen *after* config.nu is loaded
let-env ENV_CONVERSIONS = {
  "PATH": {
    from_string: { |s| $s | split row (char esep) }
    to_string: { |v| $v | str collect (char esep) }
  }
  "Path": {
    from_string: { |s| $s | split row (char esep) }
    to_string: { |v| $v | str collect (char esep) }
  }
}

# Directories to search for scripts when calling source or use
#
# By default, <nushell-config-dir>/scripts is added
let-env NU_LIB_DIRS = [
    ($nu.config-path | path dirname | path join 'scripts')
]

# Directories to search for plugin binaries when calling register
#
# By default, <nushell-config-dir>/plugins is added
let-env NU_PLUGIN_DIRS = [
    ($nu.config-path | path dirname | path join 'plugins')
]

# To add entries to PATH (on Windows you might use Path), you can use the following pattern:
# let-env PATH = ($env.PATH | prepend '/some/path')

# add to path
# not sure why this was not there.
let-env PATH = ($env.PATH | append ["/usr/local/bin/" 
  "/Users/mbrown/homebrew/opt/gnu-sed/libexec/gnubin" 
  "/Users/mbrown/.cargo/bin"])

let-env PKG_CONFIG_PATH = "/Users/mbrown/homebrew/opt/icu4c/lib/pkgconfig"

module panache-plumbing {

  # Get the current directory with home abbreviated
  export def "panache-git dir" [] {
    let current_dir = ($env.PWD)

    let current_dir_relative_to_home = (
      do --ignore-errors { $current_dir | path relative-to $nu.home-path } | str collect
    )

    let in_sub_dir_of_home = ($current_dir_relative_to_home | is-empty | nope)

    let current_dir_abbreviated = (if $in_sub_dir_of_home {
      $'~(char separator)($current_dir_relative_to_home)'
    } else {
      $current_dir
    })

    $'(ansi reset)($current_dir_abbreviated)'
  }

  # Get repository status as structured data
  export def "panache-git structured" [] {
    let in_git_repo = (do --ignore-errors { git rev-parse --abbrev-ref HEAD } | is-empty | nope)

    let status = (if $in_git_repo {
      git --no-optional-locks status --porcelain=2 --branch | lines
    } else {
      []
    })

    let on_named_branch = (if $in_git_repo {
      $status
      | where ($it | str starts-with '# branch.head')
      | first
      | str contains '(detached)'
      | nope
    } else {
      false
    })

    let branch_name = (if $on_named_branch {
      $status
      | where ($it | str starts-with '# branch.head')
      | split column ' ' col1 col2 branch
      | get branch
      | first
    } else {
      ''
    })

    let commit_hash = (if $in_git_repo {
      $status
      | where ($it | str starts-with '# branch.oid')
      | split column ' ' col1 col2 full_hash
      | get full_hash
      | first
      | str substring [0 7]
    } else {
      ''
    })

    let tracking_upstream_branch = (if $in_git_repo {
      $status
      | where ($it | str starts-with '# branch.upstream')
      | str collect
      | is-empty
      | nope
    } else {
      false
    })

    let upstream_exists_on_remote = (if $in_git_repo {
      $status
      | where ($it | str starts-with '# branch.ab')
      | str collect
      | is-empty
      | nope
    } else {
      false
    })

    let ahead_behind_table = (if $upstream_exists_on_remote {
      $status
      | where ($it | str starts-with '# branch.ab')
      | split column ' ' col1 col2 ahead behind
    } else {
      [[]]
    })

    let commits_ahead = (if $upstream_exists_on_remote {
      $ahead_behind_table
      | get ahead
      | first
      | into int
    } else {
      0
    })

    let commits_behind = (if $upstream_exists_on_remote {
      $ahead_behind_table
      | get behind
      | first
      | into int
      | math abs
    } else {
      0
    })

    let has_staging_or_worktree_changes = (if $in_git_repo {
      $status
      | where ($it | str starts-with '1') || ($it | str starts-with '2')
      | str collect
      | is-empty
      | nope
    } else {
      false
    })

    let has_untracked_files = (if $in_git_repo {
      $status
      | where ($it | str starts-with '?')
      | str collect
      | is-empty
      | nope
    } else {
      false
    })

    let has_unresolved_merge_conflicts = (if $in_git_repo {
      $status
      | where ($it | str starts-with 'u')
      | str collect
      | is-empty
      | nope
    } else {
      false
    })

    let staging_worktree_table = (if $has_staging_or_worktree_changes {
      $status
      | where ($it | str starts-with '1') || ($it | str starts-with '2')
      | split column ' '
      | get column2
      | split column '' staging worktree --collapse-empty
    } else {
      [[]]
    })

    let staging_added_count = (if $has_staging_or_worktree_changes {
      $staging_worktree_table
      | where staging == 'A'
      | length
    } else {
      0
    })

    let staging_modified_count = (if $has_staging_or_worktree_changes {
      $staging_worktree_table
      | where staging in ['M', 'R']
      | length
    } else {
      0
    })

    let staging_deleted_count = (if $has_staging_or_worktree_changes {
      $staging_worktree_table
      | where staging == 'D'
      | length
    } else {
      0
    })

    let untracked_count = (if $has_untracked_files {
      $status
      | where ($it | str starts-with '?')
      | length
    } else {
      0
    })

    let worktree_modified_count = (if $has_staging_or_worktree_changes {
      $staging_worktree_table
      | where worktree in ['M', 'R']
      | length
    } else {
      0
    })

    let worktree_deleted_count = (if $has_staging_or_worktree_changes {
      $staging_worktree_table
      | where worktree == 'D'
      | length
    } else {
      0
    })

    let merge_conflict_count = (if $has_unresolved_merge_conflicts {
      $status
      | where ($it | str starts-with 'u')
      | length
    } else {
      0
    })

    {
      in_git_repo: $in_git_repo,
      on_named_branch: $on_named_branch,
      branch_name: $branch_name,
      commit_hash: $commit_hash,
      tracking_upstream_branch: $tracking_upstream_branch,
      upstream_exists_on_remote: $upstream_exists_on_remote,
      commits_ahead: $commits_ahead,
      commits_behind: $commits_behind,
      staging_added_count: $staging_added_count,
      staging_modified_count: $staging_modified_count,
      staging_deleted_count: $staging_deleted_count,
      untracked_count: $untracked_count,
      worktree_modified_count: $worktree_modified_count,
      worktree_deleted_count: $worktree_deleted_count,
      merge_conflict_count: $merge_conflict_count
    }
  }

  # Get repository status as a styled string
  export def "panache-git styled" [] {
    let status = (panache-git structured)

    let is_local_only = ($status.tracking_upstream_branch != true)

    let upstream_deleted = (
      $status.tracking_upstream_branch &&
      $status.upstream_exists_on_remote != true
    )

    let is_up_to_date = (
      $status.upstream_exists_on_remote &&
      $status.commits_ahead == 0 &&
      $status.commits_behind == 0
    )

    let is_ahead = (
      $status.upstream_exists_on_remote &&
      $status.commits_ahead > 0 &&
      $status.commits_behind == 0
    )

    let is_behind = (
      $status.upstream_exists_on_remote &&
      $status.commits_ahead == 0 &&
      $status.commits_behind > 0
    )

    let is_ahead_and_behind = (
      $status.upstream_exists_on_remote &&
      $status.commits_ahead > 0 &&
      $status.commits_behind > 0
    )

    let branch_name = (if $status.in_git_repo {
      (if $status.on_named_branch {
        $status.branch_name
      } else {
        ['(' $status.commit_hash '...)'] | str collect
      })
    } else {
      ''
    })

    let branch_styled = (if $status.in_git_repo {
      (if $is_local_only {
        (branch-local-only $branch_name)
      } else if $is_up_to_date {
        (branch-up-to-date $branch_name)
      } else if $is_ahead {
        (branch-ahead $branch_name $status.commits_ahead)
      } else if $is_behind {
        (branch-behind $branch_name $status.commits_behind)
      } else if $is_ahead_and_behind {
        (branch-ahead-and-behind $branch_name $status.commits_ahead $status.commits_behind)
      } else if $upstream_deleted {
        (branch-upstream-deleted $branch_name)
      } else {
        $branch_name
      })
    } else {
      ''
    })

    let has_staging_changes = (
      $status.staging_added_count > 0 ||
      $status.staging_modified_count > 0 ||
      $status.staging_deleted_count > 0
    )

    let has_worktree_changes = (
      $status.untracked_count > 0 ||
      $status.worktree_modified_count > 0 ||
      $status.worktree_deleted_count > 0 ||
      $status.merge_conflict_count > 0
    )

    let has_merge_conflicts = $status.merge_conflict_count > 0

    let staging_summary = (if $has_staging_changes {
      (staging-changes $status.staging_added_count $status.staging_modified_count $status.staging_deleted_count)
    } else {
      ''
    })

    let worktree_summary = (if $has_worktree_changes {
      (worktree-changes $status.untracked_count $status.worktree_modified_count $status.worktree_deleted_count)
    } else {
      ''
    })

    let merge_conflict_summary = (if $has_merge_conflicts {
      (unresolved-conflicts $status.merge_conflict_count)
    } else {
      ''
    })

    let delimiter = (if ($has_staging_changes && $has_worktree_changes) {
      ('|' | bright-yellow)
    } else {
      ''
    })

    let local_summary = (
      $'($staging_summary) ($delimiter) ($worktree_summary) ($merge_conflict_summary)' | str trim
    )

    let local_indicator = (if $status.in_git_repo {
      (if $has_worktree_changes {
        ('!' | red)
      } else if $has_staging_changes {
        ('~' | bright-cyan)
      } else {
        ''
      })
    } else {
      ''
    })

    let repo_summary = (
      $'($branch_styled) ($local_summary) ($local_indicator)' | str trim
    )

    let left_bracket = ('[' | bright-yellow)
    let right_bracket = (']' | bright-yellow)

    (if $status.in_git_repo {
      $'($left_bracket)($repo_summary)($right_bracket)'
    } else {
      ''
    })
  }

  # Helper commands to encapsulate style and make everything else more readable

  def nope [] {
    each { |it| $it == false }
  }

  def bright-cyan [] {
    each { |it| $"(ansi -e '96m')($it)(ansi reset)" }
  }

  def bright-green [] {
    each { |it| $"(ansi -e '92m')($it)(ansi reset)" }
  }

  def bright-red [] {
    each { |it| $"(ansi -e '91m')($it)(ansi reset)" }
  }

  def bright-yellow [] {
    each { |it| $"(ansi -e '93m')($it)(ansi reset)" }
  }

  def green [] {
    each { |it| $"(ansi green)($it)(ansi reset)" }
  }

  def red [] {
    each { |it| $"(ansi red)($it)(ansi reset)" }
  }

  def branch-local-only [
    branch: string
  ] {
    $branch | bright-cyan
  }

  def branch-upstream-deleted [
    branch: string
  ] {
    $'($branch) (char failed)' | bright-cyan
  }

  def branch-up-to-date [
    branch: string
  ] {
    $'($branch) (char identical_to)' | bright-cyan
  }

  def branch-ahead [
    branch: string
    ahead: int
  ] {
    $'($branch) (char branch_ahead)($ahead)' | bright-green
  }

  def branch-behind [
    branch: string
    behind: int
  ] {
    $'($branch) (char branch_behind)($behind)' | bright-red
  }

  def branch-ahead-and-behind [
    branch: string
    ahead: int
    behind: int
  ] {
    $'($branch) (char branch_behind)($behind) (char branch_ahead)($ahead)' | bright-yellow
  }

  def staging-changes [
    added: int
    modified: int
    deleted: int
  ] {
    $'+($added) ~($modified) -($deleted)' | green
  }

  def worktree-changes [
    added: int
    modified: int
    deleted: int
  ] {
    $'+($added) ~($modified) -($deleted)' | red
  }

  def unresolved-conflicts [
    conflicts: int
  ] {
    $'!($conflicts)' | red
  }
}

# An opinionated Git prompt for Nushell, styled after posh-git
def panache-git [] {
  use panache-plumbing *
  let prompt = ($'(create_left_prompt) (panache-git styled)' | str trim)
  $'($prompt)'
}
