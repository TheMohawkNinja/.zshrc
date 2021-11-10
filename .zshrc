# Setup basic config stuff for history size, Vim keybindings, and the like
HISTFILE=~/.histfile
HISTSIZE=1000
SAVEHIST=1000
setopt autocd beep extendedglob notify
unsetopt nomatch

# Auto-completion (double-tab tab)
zstyle :compinstall filename '/home/terminus/.zshrc'
autoload -Uz compinit
compinit
zstyle ':completion:*' menu select

# Special prompt theme stuffs.
autoload -Uz promptinit
promptinit
prompt elite2

# Make Home, End and Delete do what they should do...
bindkey "^[[3~" delete-char
bindkey "^[[8~" end-of-line
bindkey "^[[7~" beginning-of-line

# Colorize ls output
alias ls='ls --color=auto'

# Colors
BUFFER_GOOD="green"
BUFFER_BAD_DIR="yellow"
BUFFER_BAD="red"
BUFFER_AMBIGUOUS="93"

# General variables
zpath="/dev/shm/zsh"
term=$(tty | grep -Eo '[0-9]{0,9}')
color=$BUFFER_GOOD
oldcolor=$color
IsCommand=false
PROMPT2='%F{$color}──>%f'
PS2=$PROMPT2

# Arrays for backspace optimization
set -A T $(date +"%s%3N")

precmd()
{
	PROMPT=$'%F{$color}┌%f%F{$(shorthash "pts/$term")}%B☾%b%y%B☽%b%f%F{$color}─%f%F{$(shorthash $PWD)}%b%B⎛%b%d%B⎠%b%f$prompt_newline%F{$color}└─> %f'
}

# Make temp directory for syntax checking
if [[ ! -d $zpath ]]
then
	mkdir $zpath
fi

# Get unique list of programs from executable directories and ZSH builtins
set -A progarr /bin/* /sbin/* /usr/bin/* /usr/sbin/* /usr/local/bin/*
progarr=("${progarr[@]##*/}")

# Add zsh-specific commands onto the list
set -A ZSH_CMDs "alias" "autoload" "bg" "break" "builtin" "cd" "command" "continue" "dirs" "disable" "disown" "echo" "emulate" "enable" "eval" "exec" "exit" "export" "false" "fc" "fg" "float" "functions" "genln" "getopts" "hash" "integer" "jobs" "kill" "let" "limit" "local" "logout" "noglob" "popd" "printf" "prompt" "pushd" "pushln" "pwd" "return" "repeat" "setopt" "shift" "source" "suspend" "test" "trap" "true" "typeset" "ulimit" "umask" "unalias" "unhash" "unlimit" "unset" "unsetopt" "wait" "whence" "where" "which" "zcompile"

for i in ${ZSH_CMDs[@]}
do
	progarr[$((${#progarr}+1))]=$i
done

# Sort list, case-sensative
IFS=$'\n' progarr=($(LC_COLLATE=C sort <<<"${progarr[*]}")); unset IFS
set -A progarr ${(u)progarr[@]}

# Get list of starting characters and their indexes to optimize searching
declare -A progarr_firstchar
declare -A progarr_firstcharindex
declare -A buffarr_old

prog_firstchar=""

for (( prog=0; prog <= ${#progarr}; prog++ ))
do
	if [ $prog -eq ${#progarr} ]
	then
		progarr_firstchar[$(($#progarr_firstchar))]=$null
		progarr_firstcharindex[$(($#progarr_firstcharindex))]=${#progarr}
	fi

	if [[ ${progarr[$prog]:0:1} != $prog_firstchar ]]
	then
		progarr_firstchar[$(($#progarr_firstchar))]=${progarr[$prog]:0:1}
		progarr_firstcharindex[$(($#progarr_firstcharindex))]=$prog
		prog_firstchar=${progarr[$prog]:0:1}
	fi
done

# Syntax checker
function syntax_validation
{
	for (( firstchar_index=0; firstchar_index < ${#progarr_firstchar}; firstchar_index++ ))
	do
		# Only check commands which start with the same first letter
		if [[ ${buffarr[$buff_index]:0:1} == ${progarr_firstchar[$firstchar_index]} ]] && [[ -n ${progarr_firstchar[$firstchar_index]} ]]
		then
			# Check to see if command string contains known commands
			for (( prog_index=${progarr_firstcharindex[$firstchar_index]}; prog_index <= ${progarr_firstcharindex[$(($firstchar_index+1))]}; prog_index++ ))
			do
				if [[ "${progarr[$prog_index]}" == ${buffarr[$buff_index]} ]]
				then
					IsCommand=true

					#For autocd. If directory of the same name exists, denote the ambiguity as purple
					if [[ -d ${buffarr[$buff_index]} ]]
					then
						color=$BUFFER_AMBIGUOUS
					fi

					break

				elif [ $prog_index -eq ${progarr_firstcharindex[$(($firstchar_index+1))]} ]
				then
					#Check for valid directory.
					if [[ -n $(echo ${buffarr[$buff_index]} | grep '\/') ]] && [[ -z $(echo ${buffarr[$buff_index]} | grep '\:\/\/') ]]
					then
						if [[ ${buffarr[$buff_index]:0:1} == "~" ]]
						then
							buffarr[$buff_index]="/home/$USER/"${buffarr[$buff_index]:1}
						fi

						if [[ ! -e ${buffarr[$buff_index]} ]] && [[ ! -d ${buffarr[$buff_index]} ]]
						then
							color=$BUFFER_BAD_DIR
						else
							color=$BUFFER_GOOD
						fi
					else
						if [[ -d ${buffarr[$buff_index]} ]]
						then
							color=$BUFFER_GOOD
						else
							IsCommand=false
						fi
					fi
				fi
			done
		fi
	done
}

# Check for command after last to cover cases like "sudo" and "nohup"
function check_next_command
{
	((buff_index++))

	if [[ -n $(echo ${buffarr[$buff_index]} | grep "sudo") ]] || [[ -n $(echo ${buffarr[$buff_index]} | grep "nohup") ]]
	then
		syntax_validation
		((buff_index++))

		if [[ $buff_index -lt ${#buffarr} ]]
		then
			syntax_validation
		fi
	elif
	then
		syntax_validation
	fi
}

# Syntax checker wrapper
function syntax_validation_precheck
{
	if [[ $(echo "$BUFFER" | grep -Eo '[[:alnum:]]') ]]
	then
		IsCommand="unknown"
	else
		color=$BUFFER_GOOD
		return
	fi

	# Extract each component of the current command string
	echo $BUFFER | grep -Eo '[[:alnum:]]{1,100}|[[:alnum:]]{1,100}\+{1,100}|[[:alnum:]]{1,100}\_{1,100)|\|\s|\|\||<\s|\$\(|\&\&|[[:punct:][:alnum:]\/]{1,100}|;{1,100}' > "$zpath/buffer"

	# Create array from buffer
	buff_index=0
	declare -A buffarr
	for buffline in "${(@f)"$(<$zpath/buffer)"}"
	{
		buffarr[${#buffarr}]=$buffline
	}

	# Check for difference between last buffer and this buffer so that we only focus on that term
	for (( i=0; i < ${#buffarr}; i++ ))
	do
		if [[ ${buffarr[$i]} != ${buffarr_old[$i]} ]]
		then
			buff_index=$i
			break
		fi
	done

	for (( i=0; i < ${#buffarr}; i++ ))
	do
		buffarr_old[$i]=${buffarr[$i]}
	done

	# First term and contains alphanumeric characters
	if [[ $buff_index -eq 0 ]] && [[ -n $(echo ${buffarr[$buff_index]} | grep -Eo '[[:alnum:]]{1,100}') ]]
	then
		syntax_validation
	
	# sudo, nohup, AND, OR, pipe, semicolon
	elif [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "sudo") ]] ||
	     [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "nohup") ]] ||
	     [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "&&") ]] ||
	     [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "||") ]] ||
	     [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep "|") ]] ||
	     [[ -n $(echo ${buffarr[$(($buff_index-1))]} | grep ";") ]]
	then
		syntax_validation
	
	# Command expression
	elif [[ -n $(echo "${buffarr[$buff_index]}" | grep "\$(") ]]
	then
		if [[ $buff_index -lt ${#buffarr} ]]
		then
			check_next_command

			if [ $IsCommand == false ]
			then
				((buff_index++))

				buffarr[$buff_index]=${buffarr[$(($buff_index-1))]:2}${buffarr[$buff_index]}
				
				if [[ -n ${buffarr[$buff_index]} ]]
				then
					syntax_validation
				fi
			fi
		fi

	elif [[ -n $(echo "${buffarr[$(($buff_index-1))]}" | grep "\$(") ]]
	then
		((buff_index--))
		if [[ $buff_index -lt ${#buffarr} ]]
		then
			check_next_command

			if [ $IsCommand == false ]
			then
				((buff_index++))

				buffarr[$buff_index]=${buffarr[$(($buff_index-1))]:2}${buffarr[$buff_index]}
				
				if [[ -n ${buffarr[$buff_index]} ]]
				then
					syntax_validation
				fi
			fi
		fi
	fi

	# Check for valid file/directories if applicable, and if they don't exist, turn prompt yellow
	if [ $color != $BUFFER_BAD ] || [ $IsCommand == true ]
	then 
		for (( i=0; i<=${#buffarr}; i++ ))
		do
			if [[ -n $(echo ${buffarr[$i]} | grep '\/') ]] && [[ -z $(echo ${buffarr[$i]} | grep '\:\/\/') ]]
			then
				if [[ ${buffarr[$i]:0:1} == "~" ]]
				then
					buffarr[$i]="/home/$USER/"${buffarr[$i]:1}
				fi

				if [[ ! -e ${buffarr[$i]} ]] && [[ ! -d ${buffarr[$i]} ]]
				then
					color=$BUFFER_BAD_DIR
				else
					color=$BUFFER_GOOD
				fi
			fi
		done
	fi

	if [ $IsCommand == true ] && [ $color != $BUFFER_BAD_DIR ] && [ $color != $BUFFER_AMBIGUOUS ]
	then
		color=$BUFFER_GOOD
	elif [ $IsCommand == false ]
	then
		color=$BUFFER_BAD
	fi
}

function do_precheck_and_redraw_prompt
{
	syntax_validation_precheck
	if [[ $color != $oldcolor ]]
	then
		zle reset-prompt
		oldcolor=$color
	fi
}

# Trap function for each key
function trap_a { BUFFER=$LBUFFER"a"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_b { BUFFER=$LBUFFER"b"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_c { BUFFER=$LBUFFER"c"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_d { BUFFER=$LBUFFER"d"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_e { BUFFER=$LBUFFER"e"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_f { BUFFER=$LBUFFER"f"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_g { BUFFER=$LBUFFER"g"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_h { BUFFER=$LBUFFER"h"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_i { BUFFER=$LBUFFER"i"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_j { BUFFER=$LBUFFER"j"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_k { BUFFER=$LBUFFER"k"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_l { BUFFER=$LBUFFER"l"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_m { BUFFER=$LBUFFER"m"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_n { BUFFER=$LBUFFER"n"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_o { BUFFER=$LBUFFER"o"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_p { BUFFER=$LBUFFER"p"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_q { BUFFER=$LBUFFER"q"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_r { BUFFER=$LBUFFER"r"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_s { BUFFER=$LBUFFER"s"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_t { BUFFER=$LBUFFER"t"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_u { BUFFER=$LBUFFER"u"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_v { BUFFER=$LBUFFER"v"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_w { BUFFER=$LBUFFER"w"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_x { BUFFER=$LBUFFER"x"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_y { BUFFER=$LBUFFER"y"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_z { BUFFER=$LBUFFER"z"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_A { BUFFER=$LBUFFER"A"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_B { BUFFER=$LBUFFER"B"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_C { BUFFER=$LBUFFER"C"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_D { BUFFER=$LBUFFER"D"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_E { BUFFER=$LBUFFER"E"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_F { BUFFER=$LBUFFER"F"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_G { BUFFER=$LBUFFER"G"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_H { BUFFER=$LBUFFER"H"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_I { BUFFER=$LBUFFER"I"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_J { BUFFER=$LBUFFER"J"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_K { BUFFER=$LBUFFER"K"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_L { BUFFER=$LBUFFER"L"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_M { BUFFER=$LBUFFER"M"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_N { BUFFER=$LBUFFER"N"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_O { BUFFER=$LBUFFER"O"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_P { BUFFER=$LBUFFER"P"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_Q { BUFFER=$LBUFFER"Q"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_R { BUFFER=$LBUFFER"R"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_S { BUFFER=$LBUFFER"S"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_T { BUFFER=$LBUFFER"T"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_U { BUFFER=$LBUFFER"U"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_V { BUFFER=$LBUFFER"V"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_W { BUFFER=$LBUFFER"W"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_X { BUFFER=$LBUFFER"X"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_Y { BUFFER=$LBUFFER"Y"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_Z { BUFFER=$LBUFFER"Z"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_0 { BUFFER=$LBUFFER"0"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_1 { BUFFER=$LBUFFER"1"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_2 { BUFFER=$LBUFFER"2"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_3 { BUFFER=$LBUFFER"3"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_4 { BUFFER=$LBUFFER"4"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_5 { BUFFER=$LBUFFER"5"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_6 { BUFFER=$LBUFFER"6"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_7 { BUFFER=$LBUFFER"7"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_8 { BUFFER=$LBUFFER"8"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_9 { BUFFER=$LBUFFER"9"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_+ { BUFFER=$LBUFFER"+"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap__ { BUFFER=$LBUFFER"_"$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_. { BUFFER=$LBUFFER"."$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_space { BUFFER=$LBUFFER" "$RBUFFER; zle vi-forward-char; do_precheck_and_redraw_prompt }
function trap_backspace
{
	zle backward-delete-char

	T[$((${#T}+1))]=$(date +"%s%3N") # Seconds and miliseconds since UNIX epoch

	# Keeo array size at 2 for memory management
	if [ -n "$T[3]" ]
	then
		T[1]=$T[2]
		T[2]=$T[3]
		T[3]=()
	fi

	# If it's been greater than 100 miliseconds between keypresses, redraw prompt, otherwise ignore
	# Prevents lag when holding in backspace
	if [ $(( ${T[2]} - ${T[1]} )) -gt 100 ]
	then
		do_precheck_and_redraw_prompt
	elif [ -z $BUFFER ]
	then
		color=$BUFFER_GOOD
		zle reset-prompt
	fi
}
function trap_enter
{
	linefill=$(printf "%*s" $(($COLUMNS-$(echo -n $term | wc -m)-$(echo -n $PWD | wc -m)-$(echo -n $(date +"%T.%N") | wc -m)-12)) "" | sed "s/ / /g")
	PROMPT=$'%F{$color}┌%f%F{$(shorthash "pts/$term")}%B☾%b%y%B☽%b%f%F{$color}─%f%F{$(shorthash $PWD)}%b%B⎛%b%d%B⎠%b%f%F{$color}$linefill%f%B⟪$(date +"%T.%N")⟫%b%F{$color}$prompt_newline└─> %f'
	zle reset-prompt
	zle accept-line
	color=$BUFFER_GOOD
}
function trap_delete
{
	zle delete-char
	do_precheck_and_redraw_prompt
}
function trap_tab
{
	# Get everyting after the last space in $a
	# ${a##* }

	set -A BUFFER_ln "${BUFFER##* }" "${BUFFER##*;}" "${BUFFER##*&}" "${BUFFER##*|}"
	zcomp=$(~/.zshcapture $BUFFER | head -1 | tail -1)
	rm ~/bufferln
	for i in "$BUFFER_ln"; do echo ${BUFFER_ln[$i]} >> ~/bufferln; done

	if [[ -n $zcomp ]]
	then
		for i in "$BUFFER_ln"
		do
			if [ ${#BUFFER_ln[$i]} -lt ${#zcomp} ]
			then
				BUFFER=${BUFFER_ln[$i]}${zcomp:0:$((${#zcomp}-1))}
			fi
		done

		for (( i=0; i<=$(echo $zcomp | wc -m); i++ ))
		do
			zle vi-forward-char
		done
		do_precheck_and_redraw_prompt
	fi
}
zle -N do_precheck_and_redraw_prompt

# Bind all letters, numbers, and backspace to it
for letter in {a..z}
do
	bindkey $letter trap_$letter
	zle -N trap_$letter
done

for LETTER in {A..Z}
do
	bindkey $LETTER trap_$LETTER
	zle -N trap_$LETTER
done

for number in {0..9}
do
	bindkey $number trap_$number
	zle -N trap_$number
done

bindkey '+' trap_+
zle -N trap_+

bindkey '_' trap__
zle -N trap__

bindkey '.' trap_.
zle -N trap_.

bindkey '^?' trap_backspace
zle -N trap_backspace

bindkey '^M' trap_enter
zle -N trap_enter

bindkey '^[[3~' trap_delete
zle -N trap_delete

bindkey ' ' trap_space
zle -N trap_space

#bindkey '	' trap_tab
#zle -N trap_tab

export EDITOR='vim'
