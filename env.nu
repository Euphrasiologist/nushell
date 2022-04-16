# Nushell Environment Config File

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
      # ignore errors if we get them
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

def create_right_prompt [] {
    let time_segment = ([
        # changed to UK date format
        (ansi {fg: "FFA12C", bg: ""}) (date now | date format '%d/%m/%Y %r')
    ] | str collect)

    $time_segment
}

# Use nushell functions to define your right and left prompt
let-env PROMPT_COMMAND = { create_left_prompt }
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
