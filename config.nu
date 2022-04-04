# Nushell Config File

# add to path
# not sure why this was not there.
let-env PATH = ($env.PATH | append ["/usr/local/bin/" 
  "/Users/mb39/homebrew/opt/gnu-sed/libexec/gnubin" 
  "/Users/mb39/.cargo/bin"
  "/Users/mb39/perl5/bin"
  "/Users/mb39/Library/Python/3.8/bin"
  "/Users/mb39/homebrew/Cellar/cmake/3.21.3/bin/cmake"
  "/Users/mb39/homebrew/Cellar/pkg-config/0.29.2_3/bin/"])

let-env PKG_CONFIG_PATH = "/Users/mb39/homebrew/opt/icu4c/lib/pkgconfig"

# :/Users/mb39/perl5/bin:/Users/mb39/Library/Python/3.8/bin:/usr/bin:/bin:/usr/sbin:/sbin:/usr/local/bin/:/Users/mb39/homebrew/Cellar/cmake/3.21.3/bin/cmake

# add git status to ls (experiment, requires dfr)
# mangles file names if there are spaces in them
# which there probably shouldn't be anyway :)

def lg [] {
  # check if it's a git repo
  let is_fatal = (do -i {git status} | complete | get stderr | str contains "fatal")

  if $is_fatal {
    # vanilla ls
    ls
  } else {
    let status = (git status -s --ignored
    | lines 
    | str trim
    | split column " " -c status name
    | update name { get name | split row "/" | first }
    | uniq
    | dfr to-df)

    let ls_dfr = (ls | dfr to-df)

    # but you lose syntax highlighting
    $ls_dfr | dfr join $status -l [name] -r [name] -t left | dfr to-nu
  }
}

# A function to open Visual Studio Code
def vsc [
  path: path # the path to a dir or file
  ] {
  '/Applications/Visual\ Studio\ Code.app/Contents/Resources/app/bin/code' + " " + $path | bash
}

# show the git log in pretty print
def gl [] {
  # check if it's a git repo
  let is_fatal = (do -i {git status} | complete | get stderr | str contains "fatal")
  if $is_fatal {
      error make {
        msg: "Not a git repo!"
    }
  }
  git log --pretty=%h»¦«%aN»¦«%s»¦«%aD | lines | split column "»¦«" sha1 committer desc merged_at
}

# make a left promt with reasonably consistent length.
# so super long left prompts are a thing of the past
def create_left_prompt [] {
  # deal with the special case of being in the root (of everything)
  let in_root = (($env.PWD) | path split | skip 1 | empty?)

  if $in_root {
    # return RED slaaash
    echo [(ansi {fg: "FD3A2D", bg: ""}) "/"] | str collect
  } else {
    # get first two and last two path elements...
    let first = (($env.PWD) | path split | skip 1 | first 2)
    let last = (($env.PWD) | path split | last 2)
    
    # check if the last contains either the first or last elements of last.
    let last_first = ($last | any? (echo $it | str contains $first.0))
    let last_second = ($last | any? (echo $it | str contains $first.1))

    if $last_first || $last_second {
      # I deal with this really badly
      let pwd = (($env.PWD) | path split)
      let root = $pwd.0
      # ignore errors if we 
      let one = do -i { $pwd.1 } 
      let two = do -i { $pwd.2 }
      let three = do -i { $pwd.3 }
      
      let one_sep = (if ($two | empty?) { echo } else { echo / })
      let two_sep = (if ($three | empty?) { echo } else { echo / })

      echo [ (ansi reset) $root (ansi {fg: "FE612C", bg: ""}) $one (ansi reset) $one_sep (ansi {fg: "FF872C", bg: ""}) $two (ansi reset) $two_sep (ansi {fg: "FFA12C", bg: ""}) $three] | str collect
      
    } else {
      # combine both in this wonderful format.
      # with colour!
      echo [(ansi {fg: "FD3A2D", bg: ""}) $first.0 (ansi reset) / (ansi {fg: "FE612C", bg: ""}) $first.1 (ansi reset) ... (ansi {fg: "FF872C", bg: ""}) $last.0 (ansi reset) / (ansi {fg: "FFA12C", bg: ""}) $last.1 ] | str collect
    }
  }
}

def up_inner [limit: int] {
  (for $e in 0..$limit { "." } | str collect)
}

# Go up a number of directories
def-env up [
    limit: int # The number of directories to go up
  ] {
    cd (up_inner $limit)
}

def create_right_prompt [] {
    let time_segment = ([
        # changed to UK date format
        (date now | date format '%d/%m/%Y %r')
    ] | str collect)

    $time_segment
}

# Use nushell functions to define your right and left prompt
let-env PROMPT_COMMAND = { create_left_prompt }
let-env PROMPT_COMMAND_RIGHT = { create_right_prompt }

# The prompt indicators are environmental variables that represent
# the state of the prompt
let-env PROMPT_INDICATOR = " > "
let-env PROMPT_INDICATOR_VI_INSERT = ": "
let-env PROMPT_INDICATOR_VI_NORMAL = " > "
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

module completions {
  # Custom completions for external commands (those outside of Nushell)
  # Each completions has two parts: the form of the external command, including its flags and parameters
  # and a helper command that knows how to complete values for those flags and parameters
  #
  # This is a simplified version of completions for git branches and git remotes
  def "nu-complete git branches" [] {
    ^git branch | lines | each { |line| $line | str find-replace '\* ' '' | str trim }
  }

  def "nu-complete git remotes" [] {
    ^git remote | lines | each { |line| $line | str trim }
  }

  export extern "git checkout" [
    branch?: string@"nu-complete git branches" # name of the branch to checkout
    -b: string                                 # create and checkout a new branch
    -B: string                                 # create/reset and checkout a branch
    -l                                         # create reflog for new branch
    --guess                                    # second guess 'git checkout <no-such-branch>' (default)
    --overlay                                  # use overlay mode (default)
    --quiet(-q)                                # suppress progress reporting
    --recurse-submodules: string               # control recursive updating of submodules
    --progress                                 # force progress reporting
    --merge(-m)                                # perform a 3-way merge with the new branch
    --conflict: string                         # conflict style (merge or diff3)
    --detach(-d)                               # detach HEAD at named commit
    --track(-t)                                # set upstream info for new branch
    --force(-f)                                # force checkout (throw away local modifications)
    --orphan: string                           # new unparented branch
    --overwrite-ignore                         # update ignored files (default)
    --ignore-other-worktrees                   # do not check if another worktree is holding the given ref
    --ours(-2)                                 # checkout our version for unmerged files
    --theirs(-3)                               # checkout their version for unmerged files
    --patch(-p)                                # select hunks interactively
    --ignore-skip-worktree-bits                # do not limit pathspecs to sparse entries only
    --pathspec-from-file: string               # read pathspec from file
  ]

  export extern "git push" [
    remote?: string@"nu-complete git remotes", # the name of the remote
    refspec?: string@"nu-complete git branches"# the branch / refspec
    --verbose(-v)                              # be more verbose
    --quiet(-q)                                # be more quiet
    --repo: string                             # repository
    --all                                      # push all refs
    --mirror                                   # mirror all refs
    --delete(-d)                               # delete refs
    --tags                                     # push tags (can't be used with --all or --mirror)
    --dry-run(-n)                              # dry run
    --porcelain                                # machine-readable output
    --force(-f)                                # force updates
    --force-with-lease: string                 # require old value of ref to be at this value
    --recurse-submodules: string               # control recursive pushing of submodules
    --thin                                     # use thin pack
    --receive-pack: string                     # receive pack program
    --exec: string                             # receive pack program
    --set-upstream(-u)                         # set upstream for git pull/status
    --progress                                 # force progress reporting
    --prune                                    # prune locally removed refs
    --no-verify                                # bypass pre-push hook
    --follow-tags                              # push missing but relevant tags
    --signed: string                           # GPG sign the push
    --atomic                                   # request atomic transaction on remote side
    --push-option(-o): string                  # option to transmit
    --ipv4(-4)                                 # use IPv4 addresses only
    --ipv6(-6)                                 # use IPv6 addresses only
  ]
}

# Get just the extern definitions without the custom completion commands
use completions *

# for more information on themes see
# https://github.com/nushell/nushell/blob/main/docs/How_To_Coloring_and_Theming.md
let default_theme = {
    # color for nushell primitives
    separator: white
    leading_trailing_space_bg: { attr: n } # no fg, no bg, attr non effectively turns this off
    header: green_bold
    empty: blue
    bool: white
    int: white
    filesize: white
    duration: white
    date: white
    range: white
    float: white
    string: white
    nothing: white
    binary: white
    cellpath: white
    row_index: green_bold
    record: white
    list: white
    block: white
    hints: dark_gray

    # shapes are used to change the cli syntax highlighting
    shape_garbage: { fg: "#FFFFFF" bg: "#FF0000" attr: b}
    shape_binary: purple_bold
    shape_bool: light_cyan
    shape_int: purple_bold
    shape_float: purple_bold
    shape_range: yellow_bold
    shape_internalcall: cyan_bold
    shape_external: cyan
    shape_externalarg: green_bold
    shape_literal: blue
    shape_operator: yellow
    shape_signature: green_bold
    shape_string: green
    shape_string_interpolation: cyan_bold
    shape_datetime: cyan_bold
    shape_list: cyan_bold
    shape_table: blue_bold
    shape_record: cyan_bold
    shape_block: blue_bold
    shape_filepath: cyan
    shape_globpattern: cyan_bold
    shape_variable: purple
    shape_flag: blue_bold
    shape_custom: green
    shape_nothing: light_cyan
}

# The default config record. This is where much of your global configuration is setup.
let $config = {
  filesize_metric: false
  table_mode: compact # basic, compact, compact_double, light, thin, with_love, rounded, reinforced, heavy, none, other
  use_ls_colors: true
  rm_always_trash: false
  color_config: $default_theme
  use_grid_icons: true
  footer_mode: "25" # always, never, number_of_rows, auto
  quick_completions: true  # set this to false to prevent auto-selecting completions when only one remains
  partial_completions: true  # set this to false to prevent partial filling of the prompt
  animate_prompt: false # redraw the prompt every second
  float_precision: 2
  use_ansi_coloring: true
  filesize_format: "auto" # b, kb, kib, mb, mib, gb, gib, tb, tib, pb, pib, eb, eib, zb, zib, auto
  edit_mode: emacs # emacs, vi
  max_history_size: 100000
  menu_config: {
    columns: 4
    col_width: 20   # Optional value. If missing all the screen width is used to calculate column width
    col_padding: 2
    text_style: green
    selected_text_style: green_reverse
    marker: "| "
  }
  history_config: {
    page_size: 10
    selector: "!"
    text_style: green
    selected_text_style: green_reverse
    marker: "? "
  }
  keybindings: [
    {
      name: completion_menu
      modifier: none
      keycode: tab
      mode: emacs # Options: emacs vi_normal vi_insert
      event: {
        until: [
          { send: menu name: completion_menu }
          { send: menunext }
        ]
      }
    }
    {
      name: completion_previous
      modifier: shift
      keycode: backtab
      mode: [emacs, vi_normal, vi_insert] # Note: You can add the same keybinding to all modes by using a list
      event: { send: menuprevious }
    }
    {
      name: history_menu
      modifier: control
      keycode: char_x
      mode: emacs
      event: {
        until: [
          { send: menu name: history_menu }
          { send: menupagenext }
        ]
      }
    }
    {
      name: history_previous
      modifier: control
      keycode: char_z
      mode: emacs
      event: {
        until: [
          { send: menupageprevious }
          { edit: undo }
        ]
      }
    }
  ]
}
