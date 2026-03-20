_autobashcmd_backend() {
  print -r -- "${SHELL_AI_BACKEND:-ollama}"
}

_autobashcmd_debug_enabled() {
  [[ -n "${SHELL_AI_DEBUG:-}" && "${SHELL_AI_DEBUG}" != "0" ]]
}

_autobashcmd_debug() {
  _autobashcmd_debug_enabled || return 0
  print -u2 -r -- "[shell-ai] $*"
}

_autobashcmd_ollama_base_url() {
  print -r -- "${OLLAMA_BASE_URL:-http://localhost:11434}"
}

_autobashcmd_lmstudio_base_url() {
  print -r -- "${LMSTUDIO_BASE_URL:-http://127.0.0.1:1234/v1}"
}

_autobashcmd_lmstudio_default_model() {
  emulate -L zsh
  setopt pipefail

  curl -fsS "$(_autobashcmd_lmstudio_base_url)/models" 2>/dev/null | jq -r '.data[0].id // empty'
}

_autobashcmd_system_prompt_command() {
  cat <<'EOF'
你是一个 shell 命令助手。你会根据用户原始请求、分类结果和当前 shell 上下文，生成一条尽量安全、适合当前上下文的 shell 命令。只输出命令本身，不要解释，不要加代码块，不要输出 markdown。优先使用当前目录中真实存在的文件或目录名。若请求有歧义，优先给出最保守、可检查当前状态的命令，不要猜测不存在的路径。
EOF
}

_autobashcmd_system_prompt_classifier() {
  cat <<'EOF'
你是一个 shell 自然语言分类器。你只能返回一行紧凑 JSON，格式固定为 {"intent":"command|cd|help|reject","content":"..."}，不允许输出任何额外文字、解释、代码块或 markdown。

分类规则：
- command：用户想执行或生成 shell 命令。
- cd：用户想进入、切换、回到某个目录。
- help：用户在问命令、参数、用法、含义、报错解释。
- reject：不适合直接执行，或请求过于模糊、不应生成命令。

content 规则：
- command：返回一句简短的规范化任务描述。
- cd：返回目录目标，尽量短，只保留目录名或路径线索。
- help：返回要解释的主题或命令。
- reject：返回一段简短中文回复，说明为什么不执行。

如果无法安全判断执行目标，优先返回 reject，不要猜。
EOF
}

_autobashcmd_system_prompt_help() {
  cat <<'EOF'
你是一个 shell 助手。对于说明类问题，直接用简洁中文回答，不要生成要执行的命令，除非用户明确要求示例。优先基于提供的本地命令帮助信息回答。输出结构尽量简单：先说它是做什么的，再给 3 到 5 个常用用法，最后补一个注意点。
EOF
}

_autobashcmd_model() {
  local backend
  backend="$(_autobashcmd_backend)"

  if [[ -n "${SHELL_AI_MODEL:-}" ]]; then
    print -r -- "$SHELL_AI_MODEL"
    return 0
  fi

  if [[ -n "${OLLAMA_SHELL_MODEL:-}" ]]; then
    print -r -- "$OLLAMA_SHELL_MODEL"
    return 0
  fi

  if [[ "$backend" == "lmstudio" ]]; then
    local model
    model="$(_autobashcmd_lmstudio_default_model)"
    if [[ -n "$model" ]]; then
      print -r -- "$model"
      return 0
    fi

    print -u2 "LM Studio 没有可用模型"
    return 1
  fi

  print -r -- "qwen2.5-coder:3b"
}

_autobashcmd_text_model() {
  if [[ -n "${SHELL_AI_TEXT_MODEL:-}" ]]; then
    print -r -- "$SHELL_AI_TEXT_MODEL"
    return 0
  fi

  if [[ -n "${OLLAMA_SHELL_TEXT_MODEL:-}" ]]; then
    print -r -- "$OLLAMA_SHELL_TEXT_MODEL"
    return 0
  fi

  _autobashcmd_model
}

_autobashcmd_context() {
  emulate -L zsh
  setopt pipefail

  local cwd entries directories last_command
  cwd="$PWD"
  entries="$(LC_ALL=C command ls -1Ap 2>/dev/null | head -n 80)"
  directories="$(LC_ALL=C command find . -mindepth 1 -maxdepth 2 -type d 2>/dev/null | sed 's#^\./##' | head -n 60)"
  last_command="$(fc -ln -1 2>/dev/null | sed 's/^[[:space:]]*//')"

  jq -n \
    --arg cwd "$cwd" \
    --arg entries "$entries" \
    --arg directories "$directories" \
    --arg last_command "$last_command" \
    '{
      cwd: $cwd,
      entries: $entries,
      directories: $directories,
      last_command: $last_command
    }'
}

_autobashcmd_trim() {
  emulate -L zsh

  local value
  value="$*"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  print -r -- "$value"
}

_autobashcmd_result_json() {
  jq -cn \
    --arg kind "$1" \
    --arg intent "$2" \
    --arg content "$3" \
    '{kind: $kind, intent: $intent, content: $content}'
}

_autobashcmd_normalize_directory_target() {
  emulate -L zsh

  local target
  target="$(_autobashcmd_trim "$1")"
  target="${target#cd }"
  target="${target#进入 }"
  target="${target#切换到 }"
  target="${target#切到 }"
  target="${target#回到 }"
  target="${target#去 }"
  target="${target%目录}"
  target="${target#\'}"
  target="${target%\'}"
  target="${target#\"}"
  target="${target%\"}"
  print -r -- "$(_autobashcmd_trim "$target")"
}

_autobashcmd_find_directory_matches() {
  emulate -L zsh

  local target escaped_target
  target="$(_autobashcmd_trim "$1")"

  [[ -z "$target" ]] && return 0
  escaped_target="$(print -r -- "$target" | sed 's/[][(){}.^$*+?|\\/]/\\&/g')"

  {
    find . -mindepth 1 -maxdepth 3 -type d -name "$target" 2>/dev/null
    find . -mindepth 1 -maxdepth 3 -type d -iname "$target" 2>/dev/null
    find . -mindepth 1 -maxdepth 3 -type d -regex ".*/${escaped_target}[^/]*" 2>/dev/null
    find . -mindepth 1 -maxdepth 3 -type d -iregex ".*/[^/]*${escaped_target}[^/]*" 2>/dev/null
  } | sed 's#^\./##' | awk '!seen[$0]++'
}

_autobashcmd_resolve_directory_target() {
  emulate -L zsh

  local target matches match_count
  target="$(_autobashcmd_trim "$1")"

  [[ -z "$target" ]] && return 1

  case "$target" in
    .|./*|..|../*|~|~/*|/*) print -r -- "$target"; return 0 ;;
  esac

  if [[ -d "$target" ]]; then
    print -r -- "$target"
    return 0
  fi

  matches="$(_autobashcmd_find_directory_matches "$target")"
  match_count="$(print -r -- "$matches" | sed '/^$/d' | wc -l | tr -d ' ')"

  if [[ "$match_count" == "1" ]]; then
    print -r -- "${matches%%$'\n'*}"
    return 0
  fi

  return 1
}

_autobashcmd_directory_lookup_command() {
  emulate -L zsh

  local target
  target="$(_autobashcmd_trim "$1")"
  print -r -- "find . -maxdepth 3 -type d | sed 's#^\\./##' | grep -i -- $(printf '%q' "$target")"
}

_autobashcmd_directory_command_from_target() {
  emulate -L zsh

  local target resolved
  target="$(_autobashcmd_normalize_directory_target "$1")"
  [[ -z "$target" ]] && return 1

  case "$target" in
    "-"|".."|"~"|".")
      print -r -- "cd $target"
      return 0
      ;;
  esac

  resolved="$(_autobashcmd_resolve_directory_target "$target")" || {
    _autobashcmd_directory_lookup_command "$target"
    return 0
  }

  print -r -- "cd ${(q)resolved}"
}

_autobashcmd_directory_command_from_prompt() {
  emulate -L zsh

  local prompt target resolved
  prompt="$(_autobashcmd_trim "$*")"

  case "$prompt" in
    "回到上一个目录"|"返回上一个目录"|"回到刚才那个目录") print -r -- "cd -"; return 0 ;;
    "回到上级目录"|"进入上级目录"|"去上级目录"|"到上级目录") print -r -- "cd .."; return 0 ;;
    "回到家目录"|"进入家目录"|"回到主目录"|"进入主目录"|"回到 home"|"进入 home") print -r -- "cd ~"; return 0 ;;
  esac

  case "$prompt" in
    "进入 "*) target="${prompt#进入 }" ;;
    "进到 "*) target="${prompt#进到 }" ;;
    "进 "*) target="${prompt#进 }" ;;
    "切换到 "*) target="${prompt#切换到 }" ;;
    "切到 "*) target="${prompt#切到 }" ;;
    "去到 "*) target="${prompt#去到 }" ;;
    "去 "*) target="${prompt#去 }" ;;
    "到 "*) target="${prompt#到 }" ;;
    "go to "*) target="${prompt#go to }" ;;
    "cd into "*) target="${prompt#cd into }" ;;
    "cd to "*) target="${prompt#cd to }" ;;
    "enter "*) target="${prompt#enter }" ;;
    *) return 1 ;;
  esac

	  target="$(_autobashcmd_trim "$target")"
	  target="$(_autobashcmd_normalize_directory_target "$target")"
	  [[ -z "$target" ]] && return 1
	  _autobashcmd_directory_command_from_target "$target"
}

_autobashcmd_common_command_from_prompt() {
  emulate -L zsh

  local prompt
  prompt="$(_autobashcmd_trim "$*")"

  case "$prompt" in
    "查看当前 CPU 占用最高的进程"|"查看 CPU 占用最高的进程"|"看当前 CPU 占用最高的进程")
      print -r -- "ps -Ao pid,%cpu,%mem,comm -r | head -n 11"
      return 0
      ;;
    "查看当前内存占用最高的进程"|"查看内存占用最高的进程")
      print -r -- "ps -Ao pid,%mem,%cpu,comm -r | head -n 11"
      return 0
      ;;
    "查看当前磁盘使用情况"|"查看磁盘使用情况"|"查看磁盘空间")
      print -r -- "df -h"
      return 0
      ;;
    "查看当前目录大小"|"看当前目录大小")
      print -r -- "du -sh ."
      return 0
      ;;
    "当前目录有隐含文件吗"|"当前目录有隐藏文件吗"|"当前目录有没有隐藏文件"|"当前目录有没有隐含文件"|"看看当前目录有没有隐藏文件"|"看当前目录有没有隐藏文件")
      print -r -- "find . -maxdepth 1 \\( -name '.*' ! -name '.' ! -name '..' \\) -print | sed 's#^\\./##'"
      return 0
      ;;
    "列出当前目录"|"列出当前目录下的文件"|"当前目录列出来"|"把当前目录列出来"|"把当前目录下的文件列出来")
      print -r -- "ls -la"
      return 0
      ;;
    "查看今天的日期和时间"|"查看当前日期和时间"|"看今天的日期和时间")
      print -r -- "date"
      return 0
      ;;
    "查看本机 IP 地址"|"查看本机ip地址"|"看本机 IP 地址")
      print -r -- "ipconfig getifaddr en0 || ipconfig getifaddr en1"
      return 0
      ;;
  esac

  return 1
}

_autobashcmd_is_help_prompt() {
  emulate -L zsh

  local prompt
  prompt="$(_autobashcmd_trim "$*")"

  case "$prompt" in
    *"如何使用"*|*"怎么用"*|*"怎么查看"*|*"介绍一下"*|*"解释一下"*|*"解释"*|*"是什么"*|*"什么意思"*|*"啥意思"*|*"用法"*|*"帮助"*|*"help"*|*"usage"*|*"有哪些常用参数"*|*"有什么常用参数"*|*"举个例子"*|*"举例"*|*"为什么"*|*"为啥"*|*"怎么回事"*)
      return 0
      ;;
    *"?"|*"？")
      return 0
      ;;
  esac

  return 1
}

_autobashcmd_looks_like_shell_fragment() {
  emulate -L zsh

  local text
  text="$(_autobashcmd_trim "$*")"
  [[ -z "$text" ]] && return 1

  [[ "$text" == *"&&"* ]] && return 0
  [[ "$text" == *"||"* ]] && return 0
  [[ "$text" == *";"* ]] && return 0
  [[ "$text" == *"|"* ]] && return 0
  [[ "$text" == *">"* ]] && return 0
  [[ "$text" == *"<"* ]] && return 0
  [[ "$text" == *'$('* ]] && return 0
  [[ "$text" == *'`'* ]] && return 0

  case "$text" in
    .|./*|..|../*|/*|~|~/*|\$*|-*)
      return 0
      ;;
  esac

  [[ "$text" =~ '^[A-Za-z_][A-Za-z0-9_]*=' ]] && return 0
  return 1
}

_autobashcmd_contains_non_ascii() {
  emulate -L zsh

  local text
  text="$1"
  print -r -- "$text" | LC_ALL=C grep -q '[^ -~]'
}

_autobashcmd_extract_help_subject() {
  emulate -L zsh

  local prompt subject
  prompt="$(_autobashcmd_trim "$*")"
  subject=""

  case "$prompt" in
    "介绍一下"*) subject="${prompt#介绍一下}" ;;
    "解释一下"*) subject="${prompt#解释一下}" ;;
    "解释 "*) subject="${prompt#解释 }" ;;
    "什么是 "*) subject="${prompt#什么是 }" ;;
    *"这个命令如何使用"*) subject="${prompt%%这个命令如何使用*}" ;;
    *"命令如何使用"*) subject="${prompt%%命令如何使用*}" ;;
    *"这个命令怎么用"*) subject="${prompt%%这个命令怎么用*}" ;;
    *"命令怎么用"*) subject="${prompt%%命令怎么用*}" ;;
    *"如何使用"*) subject="${prompt%%如何使用*}" ;;
    *"怎么用"*) subject="${prompt%%怎么用*}" ;;
    *"的用法"*) subject="${prompt%%的用法*}" ;;
    *"是什么意思"*) subject="${prompt%%是什么意思*}" ;;
    *"什么意思"*) subject="${prompt%%什么意思*}" ;;
    *"介绍一下"*) subject="${prompt%%介绍一下*}" ;;
    *" 是什么") subject="${prompt% 是什么}" ;;
    *"是什么") subject="${prompt%是什么}" ;;
    *) subject="$prompt" ;;
  esac

  subject="$(_autobashcmd_trim "$subject")"
  subject="${subject#\`}"
  subject="${subject%\`}"
  subject="${subject#\'}"
  subject="${subject%\'}"
  subject="${subject#\"}"
  subject="${subject%\"}"
  subject="${subject%命令}"
  subject="$(_autobashcmd_trim "$subject")"

  print -r -- "$subject"
}

_autobashcmd_help_topic_candidates() {
  emulate -L zsh

  local subject first rest
  subject="$(_autobashcmd_trim "$1")"
  [[ -z "$subject" ]] && return 0

  print -r -- "$subject"

  if [[ "$subject" == *" "* ]]; then
    print -r -- "${subject// /-}"
    first="${subject%% *}"
    print -r -- "$first"
    if [[ "$first" == "git" ]]; then
      rest="${subject#git }"
      print -r -- "git-${rest// /-}"
    fi
  fi
}

_autobashcmd_pick_help_topic() {
  emulate -L zsh

  local subject candidate
  subject="$(_autobashcmd_trim "$1")"

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    MANPAGER=cat man "$candidate" >/dev/null 2>&1 && {
      print -r -- "$candidate"
      return 0
    }
  done <<< "$(_autobashcmd_help_topic_candidates "$subject" | awk '!seen[$0]++')"

  while IFS= read -r candidate; do
    [[ -z "$candidate" ]] && continue
    whence -w -- "$candidate" >/dev/null 2>&1 && {
      print -r -- "$candidate"
      return 0
    }
  done <<< "$(_autobashcmd_help_topic_candidates "$subject" | awk '!seen[$0]++')"

  return 1
}

_autobashcmd_help_context() {
  emulate -L zsh
  setopt pipefail

  local subject topic whatis_text man_text
  subject="$(_autobashcmd_trim "$1")"
  topic="$(_autobashcmd_pick_help_topic "$subject" 2>/dev/null)"
  whatis_text=""
  man_text=""

  if [[ -n "$topic" ]]; then
    whatis_text="$(whatis "$topic" 2>/dev/null | head -n 3)"
    man_text="$(MANPAGER=cat man "$topic" 2>/dev/null | col -bx | sed -n '1,120p' | head -c 5000)"
  fi

  jq -n \
    --arg subject "$subject" \
    --arg topic "$topic" \
    --arg whatis "$whatis_text" \
    --arg man "$man_text" \
    '{
      subject: $subject,
      topic: $topic,
      whatis: $whatis,
      man: $man
    }'
}

_autobashcmd_command_candidates() {
  cat <<'EOF'
grep
rm
ls
find
sed
awk
xargs
rg
git
ps
top
du
df
date
ipconfig
cat
cp
mv
mkdir
rmdir
chmod
chown
tar
zip
unzip
curl
jq
head
tail
sort
uniq
less
more
wc
EOF
}

_autobashcmd_suggest_command() {
  emulate -L zsh
  setopt pipefail

  local token
  token="$(_autobashcmd_trim "$1")"
  [[ -z "$token" ]] && return 1

  _autobashcmd_command_candidates | awk -v target="$token" '
    function min3(a,b,c) {
      m = a
      if (b < m) m = b
      if (c < m) m = c
      return m
    }
    function levenshtein(s, t,    i, j, n, m, cost, a, b, c) {
      n = length(s)
      m = length(t)
      if (n == 0) return m
      if (m == 0) return n
      for (i = 0; i <= n; i++) d[i,0] = i
      for (j = 0; j <= m; j++) d[0,j] = j
      for (i = 1; i <= n; i++) {
        for (j = 1; j <= m; j++) {
          cost = (substr(s, i, 1) == substr(t, j, 1)) ? 0 : 1
          a = d[i-1,j] + 1
          b = d[i,j-1] + 1
          c = d[i-1,j-1] + cost
          d[i,j] = min3(a,b,c)
        }
      }
      return d[n,m]
    }
    {
      dist = levenshtein($0, target)
      if (best == "" || dist < best_dist) {
        best = $0
        best_dist = dist
      }
    }
    END {
      if (best != "" && best_dist <= 2) print best
    }'
}

_autobashcmd_help_subject_parts() {
  emulate -L zsh

  local subject
  subject="$(_autobashcmd_trim "$1")"

  print -r -- "$subject" | tr '、，,' '\n\n\n' | sed \
    -e 's/以及/\n/g' \
    -e 's/还有/\n/g' \
    -e 's/和/\n/g' \
    -e 's/都//g' \
    -e 's/是什么意思//g' \
    -e 's/是什么//g' \
    -e 's/这个命令//g' \
    -e 's/命令//g' | while IFS= read -r line; do
    line="$(_autobashcmd_trim "$line")"
    [[ -n "$line" ]] && print -r -- "$line"
  done
}

_autobashcmd_extract_option_block() {
  emulate -L zsh
  setopt pipefail

  local topic option
  topic="$1"
  option="$2"
  MANPAGER=cat man "$topic" 2>/dev/null | col -bx | awk -v opt="$option" '
    BEGIN { capture = 0; printed = 0 }
    $0 ~ "^     -" opt "([ ,]|$)" { capture = 1 }
    capture {
      if (printed && ($0 == "" || $0 ~ "^     -")) exit
      print
      printed = 1
    }' | sed '/^$/d'
}

_autobashcmd_local_help_for_command() {
  emulate -L zsh
  setopt pipefail

  local token topic summary desc suggested
  token="$(_autobashcmd_trim "$1")"
  topic="$(_autobashcmd_pick_help_topic "$token" 2>/dev/null)"

  if [[ -z "$topic" ]]; then
    suggested="$(_autobashcmd_suggest_command "$token")"
    if [[ -n "$suggested" ]]; then
      desc="$(MANPAGER=cat man "$suggested" 2>/dev/null | col -bx | sed -n '/^DESCRIPTION$/,/^$/p' | sed -n '2p' | sed 's/[[:space:]]\+/ /g')"
      print -r -- "$token 看起来不是标准 shell 命令，较可能是 $suggested。$suggested ${desc:-是一个常见 shell 命令。}"
      return 0
    fi
    return 1
  fi

  summary="$(MANPAGER=cat man "$topic" 2>/dev/null | col -bx | sed -n '/^NAME$/,/^$/p' | sed -n '2p')"
  if [[ -n "$summary" ]]; then
    print -r -- "$topic：${summary#*– }"
  else
    print -r -- "$topic 是一个常见 shell 命令。"
  fi
}

_autobashcmd_local_help_for_option() {
  emulate -L zsh

  local token raw topic block letter current
  token="$(_autobashcmd_trim "$1")"
  topic="$(_autobashcmd_trim "$2")"
  raw="${token#-}"

  [[ -z "$raw" ]] && return 1

  if [[ -z "$topic" ]]; then
    print -r -- "-$raw 不是一个可以脱离命令单独解释的通用参数，它的含义取决于前面的命令。"
    if [[ "$raw" == "Rf" || "$raw" == "rf" ]]; then
      print -r -- "常见例子：rm -Rf 里 -R 表示递归删除，-f 表示强制不提示；grep -Rf 里 -R 表示递归搜索，-f 表示从文件读取匹配模式。"
    fi
    return 0
  fi

  print -r -- "$topic -$raw 中各个参数的含义："
  for (( i = 1; i <= ${#raw}; i++ )); do
    letter="${raw[i]}"
    block="$(_autobashcmd_extract_option_block "$topic" "$letter")"
    if [[ -n "$block" ]]; then
      current="$(print -r -- "$block" | tr '\n' ' ' | sed 's/[[:space:]]\+/ /g')"
      current="${current#*-${letter}}"
      print -r -- "- -$letter：$(_autobashcmd_trim "$current")"
    else
      print -r -- "- -$letter：当前没有在 $topic 的本地帮助里解析到明确说明。"
    fi
  done
}

_autobashcmd_local_explain() {
  emulate -L zsh

  local prompt subject part exact_topic inferred_topic result lines
  local -a words
  prompt="$(_autobashcmd_trim "$*")"
  subject="$(_autobashcmd_extract_help_subject "$prompt")"
  lines=""
  inferred_topic=""

  words=(${=subject})
  if (( ${#words[@]} >= 2 )); then
    inferred_topic="$(_autobashcmd_pick_help_topic "${words[1]}" 2>/dev/null)"
    [[ -n "$inferred_topic" ]] || inferred_topic="$(_autobashcmd_suggest_command "${words[1]}")"

    if [[ -n "$inferred_topic" ]]; then
      result="$(_autobashcmd_local_help_for_command "${words[1]}")"
      [[ -n "$result" ]] && lines+="${result}"$'\n'

      for part in "${words[@]:1}"; do
        if [[ "$part" == -[A-Za-z]* ]]; then
          result="$(_autobashcmd_local_help_for_option "$part" "$inferred_topic")"
          [[ -n "$result" ]] && lines+="${result}"$'\n'
        fi
      done

      if [[ -n "$lines" ]]; then
        print -r -- "$lines" | sed '/^$/d'
        return 0
      fi
    fi
  fi

  while IFS= read -r part; do
    [[ -z "$part" ]] && continue
    exact_topic="$(_autobashcmd_pick_help_topic "$part" 2>/dev/null)"
    inferred_topic="$exact_topic"
    [[ -n "$inferred_topic" ]] || inferred_topic="$(_autobashcmd_suggest_command "$part")"

    if [[ -n "$exact_topic" ]]; then
      result="$(_autobashcmd_local_help_for_command "$part")"
    elif [[ "$part" == -[A-Za-z]* || "$part" == [A-Za-z][A-Za-z] ]]; then
      result="$(_autobashcmd_local_help_for_option "$part" "")"
    else
      result="$(_autobashcmd_local_help_for_command "$part")"
    fi

    [[ -n "$result" ]] && lines+="${result}"$'\n'
  done <<< "$(_autobashcmd_help_subject_parts "$subject")"

  [[ -n "$lines" ]] || return 1
  print -r -- "$lines" | sed '/^$/d'
}

_autobashcmd_rewrite_cd_command() {
  emulate -L zsh

  local cmd target rewritten
  cmd="$1"

  [[ "$cmd" == cd\ * ]] || {
    print -r -- "$cmd"
    return 0
  }

  target="${cmd#cd }"
  target="${target#"${target%%[![:space:]]*}"}"
  target="${target%"${target##*[![:space:]]}"}"

  [[ -z "$target" ]] && {
    print -r -- "$cmd"
    return 0
  }

  if [[ "$target" == .* || "$target" == /* || "$target" == ~* || "$target" == "-" ]]; then
    print -r -- "$cmd"
    return 0
  fi

  rewritten="$(_autobashcmd_directory_command_from_target "$target")" || {
    print -r -- "$cmd"
    return 0
  }

  print -r -- "$rewritten"
}

_autobashcmd_is_risky_command() {
  emulate -L zsh

  local cmd
  cmd="$1"

  [[ "$cmd" == sudo\ * ]] && return 0
  [[ "$cmd" == rm\ * ]] && return 0
  [[ "$cmd" == *" rm "* ]] && return 0
  [[ "$cmd" == mv\ * ]] && return 0
  [[ "$cmd" == dd\ * ]] && return 0
  [[ "$cmd" == chmod\ * ]] && return 0
  [[ "$cmd" == chown\ * ]] && return 0
  [[ "$cmd" == killall\ * ]] && return 0
  [[ "$cmd" == kill\ -9\ * ]] && return 0
  [[ "$cmd" == diskutil\ * ]] && return 0
  [[ "$cmd" == mkfs* ]] && return 0
  [[ "$cmd" == sed\ -i* ]] && return 0
  [[ "$cmd" == perl\ -pi* ]] && return 0
  [[ "$cmd" == launchctl\ unload* ]] && return 0
  [[ "$cmd" == sudo\ rm\ * ]] && return 0
  [[ "$cmd" == "git reset --hard"* ]] && return 0
  [[ "$cmd" == "git clean -fd"* ]] && return 0
  [[ "$cmd" == *"| sh"* || "$cmd" == *"| bash"* ]] && return 0
  [[ "$cmd" == *" > "* || "$cmd" == *" >> "* ]] && return 0

  return 1
}

_autobashcmd_request_classifier() {
  emulate -L zsh
  setopt pipefail

  local prompt context correction previous payload model backend system_prompt prompt_summary user_prompt
  prompt="$1"
  context="$2"
  correction="$3"
  previous="$4"
  model="$(_autobashcmd_model)" || return 1
  backend="$(_autobashcmd_backend)"
  system_prompt="$(_autobashcmd_system_prompt_classifier)"
  prompt_summary="$(_autobashcmd_trim "$prompt")"
  user_prompt="$prompt"
  if [[ -n "$correction" ]]; then
    user_prompt="$correction"$'\n\n'"原始请求：$prompt"
  fi
  _autobashcmd_debug "mode=classify backend=$backend model=$model prompt=$prompt_summary"

  if [[ "$backend" == "lmstudio" ]]; then
    payload="$(
      jq -n \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user_prompt "$user_prompt" \
        --arg previous "$previous" \
        --argjson context "$context" \
        '{
          model: $model,
          messages: (
            [
              {
                role: "system",
                content: ($system + "\n\n当前 shell 上下文(JSON):\n" + ($context | tojson))
              }
            ] +
            (if $previous != "" then [{ role: "assistant", content: $previous }] else [] end) +
            [
              {
                role: "user",
                content: $user_prompt
              }
            ]
          ),
          temperature: 0,
          stream: false
        }'
    )" || return 1

    _autobashcmd_debug "request url=$(_autobashcmd_lmstudio_base_url)/chat/completions payload_bytes=${#payload}"
    curl -fsS "$(_autobashcmd_lmstudio_base_url)/chat/completions" \
      -H 'Content-Type: application/json' \
      --data-binary "$payload" | jq -r '.choices[0].message.content'
    return 0
  fi

  payload="$(
    jq -n \
      --arg model "$model" \
      --arg system "$system_prompt" \
      --arg user_prompt "$user_prompt" \
      --arg previous "$previous" \
      --argjson context "$context" \
      '{
        model: $model,
        messages: (
          [
            {
              role: "system",
              content: $system
            },
            {
              role: "system",
              content: ("当前 shell 上下文(JSON):\n" + ($context | tojson))
            }
          ] +
          (if $previous != "" then [{ role: "assistant", content: $previous }] else [] end) +
          [
            {
              role: "user",
              content: $user_prompt
            }
          ]
        ),
        options: {
          temperature: 0
        },
        think: false,
        stream: false
      }'
  )" || return 1

  _autobashcmd_debug "request url=$(_autobashcmd_ollama_base_url)/api/chat payload_bytes=${#payload}"
  curl -fsS "$(_autobashcmd_ollama_base_url)/api/chat" \
    -H 'Content-Type: application/json' \
    --data-binary "$payload" | jq -r '.message.content'
}

_autobashcmd_request_command() {
  emulate -L zsh
  setopt pipefail

  local prompt context intent normalized correction previous payload model backend system_prompt prompt_summary user_prompt
  prompt="$1"
  context="$2"
  intent="$3"
  normalized="$4"
  correction="$5"
  previous="$6"
  model="$(_autobashcmd_model)" || return 1
  backend="$(_autobashcmd_backend)"
  system_prompt="$(_autobashcmd_system_prompt_command)"
  prompt_summary="$(_autobashcmd_trim "$prompt")"
  user_prompt="原始请求：$prompt"$'\n'"分类 intent：$intent"$'\n'"规范化内容：$normalized"
  if [[ -n "$correction" ]]; then
    user_prompt="$correction"$'\n\n'"$user_prompt"
  fi
  _autobashcmd_debug "mode=command backend=$backend model=$model prompt=$prompt_summary intent=$intent"

  if [[ "$backend" == "lmstudio" ]]; then
    payload="$(
      jq -n \
        --arg model "$model" \
        --arg system "$system_prompt" \
        --arg user_prompt "$user_prompt" \
        --arg previous "$previous" \
        --argjson context "$context" \
        '{
          model: $model,
          messages: (
            [
              {
                role: "system",
                content: ($system + "\n\n当前 shell 上下文(JSON):\n" + ($context | tojson))
              }
            ] +
            (if $previous != "" then [{ role: "assistant", content: $previous }] else [] end) +
            [
              {
                role: "user",
                content: $user_prompt
              }
            ]
          ),
          temperature: 0,
          stream: false
        }'
    )" || return 1

    _autobashcmd_debug "request url=$(_autobashcmd_lmstudio_base_url)/chat/completions payload_bytes=${#payload}"
    curl -fsS "$(_autobashcmd_lmstudio_base_url)/chat/completions" \
      -H 'Content-Type: application/json' \
      --data-binary "$payload" | jq -r '.choices[0].message.content'
    return 0
  fi

  payload="$(
    jq -n \
      --arg model "$model" \
      --arg system "$system_prompt" \
      --arg user_prompt "$user_prompt" \
      --arg previous "$previous" \
      --argjson context "$context" \
      '{
        model: $model,
        messages: (
          [
            {
              role: "system",
              content: $system
            },
            {
              role: "system",
              content: ("当前 shell 上下文(JSON):\n" + ($context | tojson))
            }
          ] +
          (if $previous != "" then [{ role: "assistant", content: $previous }] else [] end) +
          [
            {
              role: "user",
              content: $user_prompt
            }
          ]
        ),
        options: {
          temperature: 0
        },
        think: false,
        stream: false
      }'
  )" || return 1

  _autobashcmd_debug "request url=$(_autobashcmd_ollama_base_url)/api/chat payload_bytes=${#payload}"
  curl -fsS "$(_autobashcmd_ollama_base_url)/api/chat" \
    -H 'Content-Type: application/json' \
    --data-binary "$payload" | jq -r '.message.content'
}

_autobashcmd_request_text() {
  emulate -L zsh
  setopt pipefail

  local prompt help_context payload model backend system_prompt prompt_summary
  prompt="$1"
  help_context="$2"
  model="$(_autobashcmd_text_model)" || return 1
  backend="$(_autobashcmd_backend)"
  system_prompt="$(_autobashcmd_system_prompt_help)"
  prompt_summary="$(_autobashcmd_trim "$prompt")"
  _autobashcmd_debug "mode=help backend=$backend model=$model prompt=$prompt_summary"

  if [[ "$backend" == "lmstudio" ]]; then
    payload="$(
      jq -n \
        --arg model "$model" \
        --arg prompt "$prompt" \
        --arg system "$system_prompt" \
        --argjson help "$help_context" \
        '{
          model: $model,
          messages: [
            {
              role: "system",
              content: ($system + "\n\n本地帮助上下文(JSON):\n" + ($help | tojson))
            },
            {
              role: "user",
              content: $prompt
            }
          ],
          temperature: 0,
          stream: false
        }'
    )" || return 1

    _autobashcmd_debug "request url=$(_autobashcmd_lmstudio_base_url)/chat/completions payload_bytes=${#payload}"
    curl -fsS "$(_autobashcmd_lmstudio_base_url)/chat/completions" \
      -H 'Content-Type: application/json' \
      --data-binary "$payload" | jq -r '.choices[0].message.content'
    return 0
  fi

  payload="$(
    jq -n \
      --arg model "$model" \
      --arg prompt "$prompt" \
      --arg system "$system_prompt" \
      --argjson help "$help_context" \
      '{
        model: $model,
        messages: [
          {
            role: "system",
            content: $system
          },
          {
            role: "system",
            content: ("本地帮助上下文(JSON):\n" + ($help | tojson))
          },
          {
            role: "user",
            content: $prompt
          }
        ],
        options: {
          temperature: 0
        },
        think: false,
        stream: false
      }'
  )" || return 1

  _autobashcmd_debug "request url=$(_autobashcmd_ollama_base_url)/api/chat payload_bytes=${#payload}"
  curl -fsS "$(_autobashcmd_ollama_base_url)/api/chat" \
    -H 'Content-Type: application/json' \
    --data-binary "$payload" | jq -r '.message.content'
}

_autobashcmd_finalize_command() {
  emulate -L zsh

  local raw line trimmed
  raw="$1"
  _autobashcmd_debug "raw_output_first_line=$(_autobashcmd_trim "${raw%%$'\n'*}")"

  while IFS= read -r line; do
    trimmed="$(_autobashcmd_trim "$line")"
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == '```'* ]] && continue
    _autobashcmd_rewrite_cd_command "$trimmed"
    return 0
  done <<< "$raw"

  return 1
}

_autobashcmd_finalize_json_output() {
  emulate -L zsh

  local raw line trimmed joined
  raw="$1"
  joined=""
  _autobashcmd_debug "raw_json_first_line=$(_autobashcmd_trim "${raw%%$'\n'*}")"

  while IFS= read -r line; do
    trimmed="$(_autobashcmd_trim "$line")"
    [[ -z "$trimmed" ]] && continue
    [[ "$trimmed" == '```'* ]] && continue
    joined+="$trimmed"
  done <<< "$raw"

  print -r -- "$joined"
}

_autobashcmd_parse_classification() {
  emulate -L zsh

  local raw cleaned
  raw="$1"
  cleaned="$(_autobashcmd_finalize_json_output "$raw")"
  [[ -z "$cleaned" ]] && return 1

  print -r -- "$cleaned" | jq -cer '
    . as $root
    | if ($root | type) != "object" then error("invalid") else
        ($root.intent | ascii_downcase) as $intent
        | if ($intent == "command" or $intent == "cd" or $intent == "help" or $intent == "reject")
          and (($root.content // "") | type == "string")
          then {intent: $intent, content: ($root.content // "")}
          else error("invalid")
          end
      end'
}

_autobashcmd_extract_primary_command() {
  emulate -L zsh

  local cmd token rest
  cmd="$(_autobashcmd_trim "$1")"
  [[ -z "$cmd" ]] && return 1

  rest="$cmd"
  while [[ "$rest" == [A-Za-z_][A-Za-z0-9_]*=* ]]; do
    rest="${rest#* }"
    [[ "$rest" == "$cmd" ]] && break
    cmd="$rest"
  done

  token="${cmd%%[[:space:]|&;<>]*}"
  [[ -n "$token" ]] && print -r -- "$token"
}

_autobashcmd_looks_like_explanation() {
  emulate -L zsh

  local cmd
  cmd="$(_autobashcmd_trim "$1")"
  [[ -z "$cmd" ]] && return 0

  case "$cmd" in
    '```'*|'- '*|'1. '*|'2. '*|'3. '*)
      return 0
      ;;
    *'```'*|*'**'*)
      return 0
      ;;
    "这是"*|"它是"*|"这个命令"*|"你可以"*|"通常"*|"说明"*|"含义"*|"用法"*)
      return 0
      ;;
  esac

  return 1
}

_autobashcmd_is_valid_command() {
  emulate -L zsh

  local cmd first
  cmd="$(_autobashcmd_trim "$1")"
  [[ -z "$cmd" ]] && return 1
  _autobashcmd_looks_like_explanation "$cmd" && return 1

  case "$cmd" in
    ./*|../*|/*|~/*) return 0 ;;
  esac

  zsh -n -c "$cmd" >/dev/null 2>&1 || return 1
  first="$(_autobashcmd_extract_primary_command "$cmd")"

  if [[ -n "$first" ]]; then
    case "$first" in
      command|builtin|exec|env|noglob|nocorrect|time)
        return 0
        ;;
    esac

    whence -w -- "$first" >/dev/null 2>&1 && return 0
    alias "$first" >/dev/null 2>&1 && return 0
    typeset -f "$first" >/dev/null 2>&1 && return 0
    [[ "$cmd" == "$first" ]] && return 1
  fi

  return 0
}

_autobashcmd_classify_request() {
  emulate -L zsh
  setopt pipefail

  local prompt context forced_intent content raw classification correction
  prompt="$1"
  context="$2"
  forced_intent="$3"

  if [[ -n "$forced_intent" ]]; then
    case "$forced_intent" in
      help) content="$(_autobashcmd_extract_help_subject "$prompt")" ;;
      cd) content="$(_autobashcmd_normalize_directory_target "$prompt")" ;;
      command) content="$(_autobashcmd_trim "$prompt")" ;;
      reject) content="这个请求不适合直接转换成 shell 命令。" ;;
      *) return 1 ;;
    esac
    [[ -n "$content" ]] || content="$(_autobashcmd_trim "$prompt")"
    _autobashcmd_result_json "$forced_intent" "$forced_intent" "$content"
    return 0
  fi

  raw="$(_autobashcmd_request_classifier "$prompt" "$context" "" "")" || return 1
  classification="$(_autobashcmd_parse_classification "$raw" 2>/dev/null)"

  if [[ -z "$classification" ]]; then
    correction='上一条输出不是合法 JSON。请严格只输出一行 JSON，格式固定为 {"intent":"command|cd|help|reject","content":"..."}，不要输出解释、代码块或多余文字。'
    raw="$(_autobashcmd_request_classifier "$prompt" "$context" "$correction" "$raw")" || return 1
    classification="$(_autobashcmd_parse_classification "$raw" 2>/dev/null)" || return 1
  fi

  _autobashcmd_debug "classification=$(print -r -- "$classification" | jq -c .)"
  print -r -- "$classification"
}

_autobashcmd_generate_command() {
  emulate -L zsh
  setopt pipefail

  local prompt context intent content raw cmd correction
  prompt="$1"
  context="$2"
  intent="$3"
  content="$4"

  raw="$(_autobashcmd_request_command "$prompt" "$context" "$intent" "$content" "" "")" || return 1
  cmd="$(_autobashcmd_finalize_command "$raw")" || return 1

  if ! _autobashcmd_is_valid_command "$cmd"; then
    correction="上一条输出不是有效的 shell 命令。请只返回一条真实可执行的 shell 命令，不要返回说明文字，不要返回自然语言，不要返回代码块。"
    raw="$(_autobashcmd_request_command "$prompt" "$context" "$intent" "$content" "$correction" "$cmd")" || return 1
    cmd="$(_autobashcmd_finalize_command "$raw")" || return 1
  fi

  _autobashcmd_is_valid_command "$cmd" || return 1
  _autobashcmd_debug "final_command=$cmd"
  print -r -- "$cmd"
}

_autobashcmd_dispatch_request() {
  emulate -L zsh
  setopt pipefail

  local prompt forced_intent context local_cmd classification intent content subject help_context text cmd
  prompt="$(_autobashcmd_trim "$1")"
  forced_intent="$2"
  [[ -n "$prompt" ]] || return 1

  context="$(_autobashcmd_context)" || return 1

  if [[ -z "$forced_intent" ]]; then
    local_cmd="$(_autobashcmd_directory_command_from_prompt "$prompt")" && {
      _autobashcmd_debug "local_rule=directory command=$local_cmd"
      _autobashcmd_result_json "command" "cd" "$local_cmd"
      return 0
    }

    local_cmd="$(_autobashcmd_common_command_from_prompt "$prompt")" && {
      _autobashcmd_debug "local_rule=common command=$local_cmd"
      _autobashcmd_result_json "command" "command" "$local_cmd"
      return 0
    }
  fi

  classification="$(_autobashcmd_classify_request "$prompt" "$context" "$forced_intent")" || return 1
  intent="$(print -r -- "$classification" | jq -r '.intent')"
  content="$(print -r -- "$classification" | jq -r '.content')"
  content="$(_autobashcmd_trim "$content")"
  [[ -n "$content" ]] || content="$prompt"

  case "$intent" in
    help)
      text="$(_autobashcmd_local_explain "$prompt" 2>/dev/null)"
      if [[ -z "$text" ]]; then
        subject="$(_autobashcmd_trim "$content")"
        [[ -n "$subject" ]] || subject="$(_autobashcmd_extract_help_subject "$prompt")"
        help_context="$(_autobashcmd_help_context "$subject")" || return 1
        text="$(_autobashcmd_request_text "$prompt" "$help_context")" || return 1
      fi
      _autobashcmd_result_json "text" "help" "$text"
      return 0
      ;;
    reject)
      [[ -n "$content" ]] || content="这个请求不适合直接转换成 shell 命令，请改成更具体的操作。"
      _autobashcmd_result_json "text" "reject" "$content"
      return 0
      ;;
    cd)
      cmd="$(_autobashcmd_directory_command_from_target "$content" 2>/dev/null)"
      if [[ -z "$cmd" ]]; then
        cmd="$(_autobashcmd_generate_command "$prompt" "$context" "$intent" "$content")" || return 1
      fi
      _autobashcmd_result_json "command" "cd" "$cmd"
      return 0
      ;;
    command)
      cmd="$(_autobashcmd_generate_command "$prompt" "$context" "$intent" "$content")" || return 1
      _autobashcmd_result_json "command" "command" "$cmd"
      return 0
      ;;
  esac

  return 1
}

ai() {
  emulate -L zsh
  setopt pipefail

  local prompt result content
  prompt="$(_autobashcmd_trim "$*")"

  if [[ -z "$prompt" ]]; then
    print -u2 "usage: ai <自然语言请求>"
    return 1
  fi

  result="$(_autobashcmd_dispatch_request "$prompt" "")" || return 1
  content="$(print -r -- "$result" | jq -r '.content')"
  print -r -- "$content"
}

aiexplain() {
  emulate -L zsh
  setopt pipefail

  local prompt result content
  prompt="$(_autobashcmd_trim "$*")"
  [[ -z "$prompt" ]] && return 1

  result="$(_autobashcmd_dispatch_request "$prompt" "help")" || return 1
  content="$(print -r -- "$result" | jq -r '.content')"
  print -r -- "$content"
}

airun() {
  emulate -L zsh
  setopt nonomatch

  local prompt result kind cmd reply content
  prompt="$(_autobashcmd_trim "$*")"
  result="$(_autobashcmd_dispatch_request "$prompt" "")" || return 1
  kind="$(print -r -- "$result" | jq -r '.kind')"
  content="$(print -r -- "$result" | jq -r '.content')"

  if [[ "$kind" != "command" ]]; then
    print -r -- "$content"
    return 0
  fi

  cmd="$content"

  print -r -- "-> $cmd"

  if _autobashcmd_is_risky_command "$cmd"; then
    read -r "reply?危险命令，输入 yes 执行，直接回车取消: "
    [[ "$reply" == "yes" ]] || return 0
  else
    read -r "reply?回车执行，按任键取消: "
    [[ -z "$reply" ]] || return 0
  fi

  if [[ -n "$cmd" ]]; then
    eval "$cmd"
  fi
}

_autobashcmd_should_intercept_natural_language() {
  emulate -L zsh

  local joined
  joined="$*"
  _autobashcmd_contains_non_ascii "$joined" || return 1
  _autobashcmd_looks_like_shell_fragment "$joined" && return 1
  return 0
}

command_not_found_handler() {
  emulate -L zsh

  if _autobashcmd_should_intercept_natural_language "$@"; then
    airun "$@"
    return $?
  fi

  print -u2 -r -- "zsh: command not found: $1"
  return 127
}
