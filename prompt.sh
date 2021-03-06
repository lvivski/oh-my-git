# Symbols
: ${is_a_git_repo_symbol:='❤'}
: ${has_untracked_files_symbol:='∿'}
: ${has_adds_symbol:='+'}
: ${has_deletions_symbol:='-'}
: ${has_deletions_cached_symbol:='✖'}
: ${has_modifications_symbol:='✎'}
: ${has_modifications_cached_symbol:='☲'}
: ${ready_to_commit_symbol:='→'}
: ${is_on_a_tag_symbol:='⌫'}
: ${needs_to_merge_symbol:='ᄉ'}
: ${has_upstream_symbol:='⇅'}
: ${detached_symbol:='⚯ '}
: ${can_fast_forward_symbol:='»'}
: ${has_diverged_symbol:='Ⴤ'}
: ${rebase_tracking_branch_symbol:='↶'}
: ${merge_tracking_branch_symbol:='ᄉ'}
: ${should_push_symbol:='↑'}
: ${has_stashes_symbol:='★'}

# Flags
: ${display_has_upstream:=false}
: ${display_tag:=false}
: ${display_tag_name:=true}
: ${two_lines:=true}
: ${finally:='\w ∙ '}
: ${use_color_off:=false}

# Colors
: ${on='\[\033[0;37m\]'}
: ${off='\[\033[1;30m\]'}
: ${red='\[\033[0;31m\]'}
: ${green='\[\033[0;32m\]'}
: ${yellow='\[\033[0;33m\]'}
: ${violet='\[\033[0;35m\]'}
: ${branch_color='\[\033[0;34m\]'}
#: ${blinking='\[\033[1;5;17m\]'}
: ${reset='\[\033[0m\]'}

function enrich {
	flag=$1
	symbol=$2
	color=$on
	if [[ -n $3 ]]; then color=$3; fi
	if [[ $flag != true ]]; then color=$off; fi
	if [[ $use_color_off != true && $flag != true ]]; then symbol=' '; fi
	PS1="${PS1}${color}${symbol}${reset} "
}

function build_prompt {
	PS1=""

	# Git info
	current_commit_hash=$(git rev-parse HEAD 2> /dev/null)
	is_a_git_repo=false
	if [[ -n $current_commit_hash ]]; then is_a_git_repo=true; fi

	if [[ $is_a_git_repo == true ]]; then
		current_branch=$(git rev-parse --abbrev-ref HEAD 2> /dev/null)
		if [[ $current_branch == 'HEAD' ]]; then detached=true; else detached=false; fi

		number_of_logs=$(git log --pretty=oneline -n1 2> /dev/null | wc -l)
		if [[ $number_of_logs -eq 0 ]]; then
			just_init=true
		else
			upstream=$(git rev-parse --symbolic-full-name --abbrev-ref @{upstream} 2> /dev/null)
			if [[ -n $upstream ]]; then has_upstream=true; else has_upstream=false; fi

			git_status=$(git status --porcelain 2> /dev/null)

			has_modifications=false
			if [[ $git_status =~ ($'\n'|^).M ]]; then has_modifications=true; fi

			has_modifications_cached=false
			if [[ $git_status =~ ($'\n'|^)M ]]; then has_modifications_cached=true; fi

			has_adds=false
			if [[ $git_status =~ ($'\n'|^)A ]]; then has_adds=true; fi

			has_deletions=false
			if [[ $git_status =~ ($'\n'|^).D ]]; then has_deletions=true; fi

			has_deletions_cached=false
			if [[ $git_status =~ ($'\n'|^)D ]]; then has_deletions_cached=true; fi

			ready_to_commit=false
			if [[ $git_status =~ ($'\n'|^)[MAD] && ! $git_status =~ ($'\n'|^).[MAD\?] ]]; then ready_to_commit=true; fi

			has_untracked_files=false
			if [[ $git_status =~ ($'\n'|^)\?\? ]]; then has_untracked_files=true; fi

			tag_at_current_commit=$(git describe --exact-match --tags $current_commit_hash 2> /dev/null)
			is_on_a_tag=false
			if [[ -n $tag_at_current_commit ]]; then is_on_a_tag=true; fi

			if [[ $has_upstream == true ]]; then
				commits_diff=$(git log --pretty=oneline --topo-order --left-right ${current_commit_hash}...${upstream} 2> /dev/null)
				commits_ahead=$(grep -c ^\< <<< "$commits_diff")
				commits_behind=$(grep -c ^\> <<< "$commits_diff")
			fi

			has_diverged=false
			if [[ $commits_ahead -gt 0 && $commits_behind -gt 0 ]]; then has_diverged=true; fi

			can_fast_forward=false
			if [[ $commits_ahead -eq 0 && $commits_behind -gt 0 ]]; then can_fast_forward=true; fi

			will_rebase=$(git config --get branch.${current_branch}.rebase 2> /dev/null)

			number_of_stashes=$(wc -l 2> /dev/null < ${GIT_DIR:-.git}/refs/stash)
			has_stashes=false
			if [[ $number_of_stashes -gt 0 ]]; then has_stashes=true; fi
		fi
	fi

	if [[ $is_a_git_repo == true ]]; then
		enrich $is_a_git_repo $is_a_git_repo_symbol $violet
		enrich $has_stashes $has_stashes_symbol $yellow
		enrich $has_untracked_files $has_untracked_files_symbol $red
		enrich $has_adds $has_adds_symbol $yellow

		enrich $has_deletions $has_deletions_symbol $red
		enrich $has_deletions_cached $has_deletions_cached_symbol $yellow

		enrich $has_modifications $has_modifications_symbol $red
		enrich $has_modifications_cached $has_modifications_cached_symbol $yellow
		enrich $ready_to_commit $ready_to_commit_symbol $green

		enrich $detached $detached_symbol $red

		if [[ $display_has_upstream == true ]]; then
			enrich $has_upstream $has_upstream_symbol
		fi
		if [[ $detached == true ]]; then
			if [[ $just_init == true ]]; then
				PS1="${PS1} ${red}detached"
			else
				PS1="${PS1} ${on}(${current_commit_hash:0:7})"
			fi
		else
			if [[ $has_upstream == true ]]; then
				type_of_upstream=$merge_tracking_branch_symbol
				if [[ $will_rebase == true ]]; then type_of_upstream=$rebase_tracking_branch_symbol; fi

				if [[ $has_diverged == true ]]; then
					PS1="${PS1} -${commits_behind} ${has_diverged_symbol} +${commits_ahead}"
				else
					if [[ $commits_behind -gt 0 ]]; then
						PS1="${PS1} ${on}-${commits_behind} ${can_fast_forward_symbol}"
					fi
					if [[ $commits_ahead -gt 0 ]]; then
						PS1="${PS1} ${on}${should_push_symbol} +${commits_ahead}"
					fi
				fi
				PS1="${PS1} (${green}${current_branch}${reset} ${type_of_upstream} ${upstream//\/$current_branch/})"
			else
				PS1="${PS1} ${on}(${green}${current_branch}${reset})"
			fi
		fi

		if [[ $display_tag == true && $is_on_a_tag == true ]]; then
			PS1="${PS1} ${yellow}${is_on_a_tag_symbol}${reset}"
		fi
		if [[ $display_tag_name == true && $is_on_a_tag == true ]]; then
			PS1="${PS1} ${yellow}[${tag_at_current_commit}]${reset}"
		fi
	fi

	break=''
	if [[ $two_lines == true && $is_a_git_repo == true ]]; then break='\n'; fi

	PS1="${PS1}${reset}${break}${finally}"
}

PS2="${yellow}→${reset} "

PROMPT_COMMAND=build_prompt
